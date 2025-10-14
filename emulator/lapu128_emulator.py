#!/usr/bin/env python3
import argparse, sys
from dataclasses import dataclass
from typing import List, Tuple, Dict
from decimal import Decimal, getcontext
getcontext().prec = 80

# ------------------------------ Fixed-point helpers ------------------------------

FRAC_BITS = 32  # Q32.32
INT_BITS  = 32
RAW_MIN = -(1 << (FRAC_BITS + INT_BITS - 1))  # -2^63
RAW_MAX =  (1 << (FRAC_BITS + INT_BITS - 1)) - 1  # 2^63-1

def sat64(x: int) -> int:
    if x < RAW_MIN: return RAW_MIN
    if x > RAW_MAX: return RAW_MAX
    return x

def add_q(a: int, b: int) -> int:
    return sat64(a + b)

def sub_q(a: int, b: int) -> int:
    return sat64(a - b)

def trunc_shr(x: int, n: int) -> int:
    # Truncate toward zero after shifting right by n
    if x >= 0:
        return x >> n
    else:
        return -((-x) >> n)

def mul_q(a: int, b: int) -> int:
    # (a * b) >> FRAC_BITS, trunc toward zero, then saturate
    wide = a * b  # Python int (unbounded)
    res = trunc_shr(wide, FRAC_BITS)
    return sat64(res)

def recip_q(a: int) -> int:
    # 1.0 / a in Q32.32 => (1<<FRAC_BITS) << FRAC_BITS / a
    if a == 0:
        return 0
    wide = (1 << (FRAC_BITS * 2))  # 1.0 in Q32.32, scaled up by FRAC_BITS for division
    res = trunc_shr(wide, 0) // a  # exact integer division followed by trunc toward zero
    return sat64(res)

def div_q(num: int, den: int) -> int:
    if den == 0:
        return 0
    # (num << FRAC_BITS) / den, truncate toward zero
    wide = num << FRAC_BITS
    # Python truncates toward -inf; fix to toward zero:
    if (wide >= 0 and den > 0) or (wide <= 0 and den < 0):
        q = abs(wide) // abs(den)
    else:
        q = - (abs(wide) // abs(den))
    return sat64(q)

def abs_q(a: int) -> int:
    return a if a >= 0 else sat64(-a)

def to_float(a: int) -> float:
    return a / (1 << FRAC_BITS)

def from_float(x: float) -> int:
    # Truncate toward zero
    raw = int(x * (1 << FRAC_BITS))
    return sat64(raw)

# Complex pair stored as (re_raw, im_raw)
def c_add(a: Tuple[int,int], b: Tuple[int,int]) -> Tuple[int,int]:
    return (add_q(a[0], b[0]), add_q(a[1], b[1]))

def c_sub(a: Tuple[int,int], b: Tuple[int,int]) -> Tuple[int,int]:
    return (sub_q(a[0], b[0]), sub_q(a[1], b[1]))

def c_mul(a: Tuple[int,int], b: Tuple[int,int]) -> Tuple[int,int]:
    ar, ai = a
    br, bi = b
    real = sub_q(mul_q(ar, br), mul_q(ai, bi))
    imag = add_q(mul_q(ar, bi), mul_q(ai, br))
    return (real, imag)

def c_div(a: Tuple[int,int], b: Tuple[int,int]) -> Tuple[int,int]:
    ar, ai = a
    br, bi = b
    # (a * conj(b)) / |b|^2
    denom = add_q(mul_q(br, br), mul_q(bi, bi))  # Q32.32
    num   = c_mul(a, (br, -bi))
    if denom == 0:
        return (0, 0)
    rr = div_q(num[0], denom)
    ii = div_q(num[1], denom)
    return (rr, ii)

def c_conj(a: Tuple[int,int]) -> Tuple[int,int]:
    return (a[0], sat64(-a[1]))

def c_abs2(a: Tuple[int,int]) -> int:
    # returns |a|^2 in Q32.32 (real scalar), computed as (ar*ar + ai*ai) >> 32
    ar, ai = a
    wide = ar * ar + ai * ai
    return sat64(trunc_shr(wide, FRAC_BITS))

def c_abs(a: Tuple[int,int]) -> int:
    # returns |a| in Q32.32: floor_sqrt(|a|^2) in fixed-point
    # y_raw = floor(sqrt(mag2_raw << FRAC_BITS))
    mag2 = c_abs2(a)
    if mag2 < 0:  # shouldn't happen
        return 0
    import math
    y = math.isqrt(mag2 << FRAC_BITS)
    return sat64(y)

def c_sqrt(a: Tuple[int,int]) -> Tuple[int,int]:
    # Complex sqrt via Decimal; truncate to Q32.32
    ar, ai = a
    Re = Decimal(ar) / (1 << FRAC_BITS)
    Im = Decimal(ai) / (1 << FRAC_BITS)
    # Compute sqrt using complex formula: sqrt(r) * (cos(theta/2) + i sin(theta/2))
    # Use Python complex for phase, then cast back with truncation.
    import cmath
    z = complex(float(Re), float(Im))
    w = cmath.sqrt(z)
    return (from_float(w.real), from_float(w.imag))

# ------------------------------ ISA decode helpers ------------------------------

def get_bits(word: int, hi: int, lo: int) -> int:
    mask = (1 << (hi - lo + 1)) - 1
    return (word >> lo) & mask

def get_bits_signed(word: int, hi: int, lo: int) -> int:
    width = hi - lo + 1
    val = get_bits(word, hi, lo)
    signbit = 1 << (width - 1)
    if val & signbit:
        val -= (1 << width)
    return val

# ------------------------------ Machine state ------------------------------

@dataclass
class MachineConfig:
    vlen: int = 8
    banks: int = 4            # up to 16 by mbid field
    rows_mult: int = 1        # rows = rows_mult * vlen
    cols_mult: int = 1        # cols = cols_mult * vlen
    pred_uses_real_only: bool = True  # s1 predicate: test real != 0

class Machine:
    def __init__(self, cfg: MachineConfig):
        self.cfg = cfg
        self.pc = 0  # instruction index
        # Scalar regs s0..s7, complex pairs
        self.s = [(0,0) for _ in range(8)]
        # Vector regs v0..v7, each is list of complex pairs
        self.v = [[(0,0) for _ in range(cfg.vlen)] for __ in range(8)]
        # Matrix banks: list of banks; each bank is rows x cols array of complex pairs
        rows = cfg.rows_mult * cfg.vlen
        cols = cfg.cols_mult * cfg.vlen
        self.rows = rows
        self.cols = cols
        self.bank: List[List[List[Tuple[int,int]]]] = [
            [[(0,0) for _ in range(cols)] for __ in range(rows)]
            for b in range(cfg.banks)
        ]
        # Hard-wire s0 and v0 to zero (enforced on writes)
        self.s[0] = (0,0)
        self.v[0] = [(0,0) for _ in range(cfg.vlen)]

    def write_s(self, idx: int, val: Tuple[int,int]):
        if idx == 0:
            raise RuntimeError("Illegal write to s0 (architectural zero)")
        self.s[idx] = (sat64(val[0]), sat64(val[1]))

    def write_v(self, idx: int, vec: List[Tuple[int,int]]):
        if idx == 0:
            raise RuntimeError("Illegal write to v0 (architectural zero)")
        if len(vec) != self.cfg.vlen:
            raise RuntimeError("Vector length mismatch")
        self.v[idx] = [(sat64(x), sat64(y)) for (x,y) in vec]

    def pred_true(self) -> bool:
        re, im = self.s[1]
        if self.cfg.pred_uses_real_only:
            return re != 0
        else:
            return (re != 0) or (im != 0)

# ------------------------------ Pretty printer ------------------------------

def fmt_c(z: Tuple[int,int]) -> str:
    re, im = z
    return f"({to_float(re): .6f} + {to_float(im): .6f}i)"

def fmt_vec(v: List[Tuple[int,int]], max_elems: int = 8) -> str:
    n = len(v)
    show = min(n, max_elems)
    head = ", ".join(fmt_c(v[i]) for i in range(show))
    if show < n:
        head += ", ..."
    return f"[{head}] (VLEN={n})"

def fmt_matrix(bank: List[List[Tuple[int,int]]], max_rows: int, max_cols: int) -> str:
    rows = len(bank); cols = len(bank[0]) if rows else 0
    rr = min(rows, max_rows); cc = min(cols, max_cols)
    lines = [f"{rows}x{cols} matrix, top-left {rr}x{cc} window:"]
    for r in range(rr):
        row = " | ".join(f"{to_float(bank[r][c][0]): .3f}+{to_float(bank[r][c][1]): .3f}i" for c in range(cc))
        lines.append(f"  r{r:02d}: {row}")
    if rr < rows or cc < cols:
        lines.append("  ...")
    return "\n".join(lines)

def dump_state(m: Machine, step: int, instr_word: int, max_vec_elems: int, show_matrix: bool, max_rows: int, max_cols: int):
    print(f"\n--- Step {step} | PC={m.pc:04d} | INSTR=0x{instr_word:032X} ---")
    for i in range(8):
        print(f"s{i}: {fmt_c(m.s[i])}")
    for i in range(8):
        print(f"v{i}: {fmt_vec(m.v[i], max_elems=max_vec_elems)}")
    if show_matrix and len(m.bank) > 0:
        print("[bank 0]")
        print(fmt_matrix(m.bank[0], max_rows, max_cols))

# ------------------------------ Instruction execution ------------------------------

# Subop tables (must match assembler/spec)
R_SCALAR_UNARY = {'cneg':0x00, 'conj':0x01, 'csqrt':0x02, 'cabs2':0x03, 'cabs':0x04, 'creal':0x05, 'cimag':0x06, 'crecip':0x07}
R_SCALAR_BINARY= {'cadd':0x08, 'csub':0x09, 'cmul':0x0A, 'cdiv':0x0B, 'cmaxabs':0x0C, 'cminabs':0x0D, 'cmplt.re':0x0E, 'cmpgt.re':0x0F, 'cmple.re':0x10}
R_VECTOR_LANE  = {'vadd':0x00, 'vsub':0x01, 'vmul':0x02, 'vmac':0x03, 'vdiv':0x04, 'vconj':0x05}
R_REDUCTIONS   = {'dotc':0x00, 'dotu':0x01, 'iamax':0x02, 'sum':0x03, 'asum':0x04}
R_VEC_SCALAR   = {'vsadd':0x18, 'vssub':0x19, 'vsmul':0x1A, 'vsdiv':0x1B}

MAP_SS_to_S = 0b00
MAP_VV_to_V = 0b01
MAP_VV_to_S = 0b10
MAP_VS_to_V = 0b11

I_SUBOPS = {'cloadi':0x00, 'cadd_i':0x01, 'cmul_i':0x02, 'csub_i':0x03, 'cdiv_i':0x04, 'cmaxabs_i':0x05, 'cminabs_i':0x06, 'cscale_i':0x10}

def exec_r(m: Machine, w: int):
    subop = get_bits(w, 119,112)
    mapbits = get_bits(w, 97,96)
    rd  = get_bits(w, 95,93)
    rs1 = get_bits(w, 92,90)
    rs2 = get_bits(w, 89,87)
    # imm16 must be zero; ignore
    if mapbits == MAP_SS_to_S:
        # try unary first
        if subop in R_SCALAR_UNARY.values():
            a = m.s[rs1]
            if subop == R_SCALAR_UNARY['cneg']:
                m.write_s(rd, (-m.s[rs1][0], -m.s[rs1][1]))
            elif subop == R_SCALAR_UNARY['conj']:
                m.write_s(rd, c_conj(a))
            elif subop == R_SCALAR_UNARY['csqrt']:
                m.write_s(rd, c_sqrt(a))
            elif subop == R_SCALAR_UNARY['cabs2']:
                m.write_s(rd, (c_abs2(a), 0))
            elif subop == R_SCALAR_UNARY['cabs']:
                m.write_s(rd, (c_abs(a), 0))
            elif subop == R_SCALAR_UNARY['creal']:
                m.write_s(rd, (a[0], 0))
            elif subop == R_SCALAR_UNARY['cimag']:
                m.write_s(rd, (a[1], 0))
            elif subop == R_SCALAR_UNARY['crecip']:
                # 1 / a
                m.write_s(rd, c_div((1<<FRAC_BITS, 0), a))
            else:
                raise RuntimeError("Unknown scalar unary subop")
        else:
            # binary
            a = m.s[rs1]; b = m.s[rs2]
            if subop == R_SCALAR_BINARY['cadd']:
                m.write_s(rd, c_add(a,b))
            elif subop == R_SCALAR_BINARY['csub']:
                m.write_s(rd, c_sub(a,b))
            elif subop == R_SCALAR_BINARY['cmul']:
                m.write_s(rd, c_mul(a,b))
            elif subop == R_SCALAR_BINARY['cdiv']:
                m.write_s(rd, c_div(a,b))
            elif subop == R_SCALAR_BINARY['cmaxabs']:
                m.write_s(rd, a if c_abs2(a) >= c_abs2(b) else b)
            elif subop == R_SCALAR_BINARY['cminabs']:
                m.write_s(rd, a if c_abs2(a) <= c_abs2(b) else b)
            elif subop == R_SCALAR_BINARY['cmplt.re']:
                res = (1<<FRAC_BITS) if a[0] < b[0] else 0
                m.write_s(rd, (res, 0))
            elif subop == R_SCALAR_BINARY['cmpgt.re']:
                res = (1<<FRAC_BITS) if a[0] > b[0] else 0
                m.write_s(rd, (res, 0))
            elif subop == R_SCALAR_BINARY['cmple.re']:
                res = (1<<FRAC_BITS) if a[0] <= b[0] else 0
                m.write_s(rd, (res, 0))
            else:
                raise RuntimeError("Unknown scalar binary subop")
    elif mapbits == MAP_VV_to_V:
        # vector lane ops
        A = m.v[rs1]; B = m.v[rs2]; D = []
        if subop == R_VECTOR_LANE['vconj']:
            for ai in A:
                D.append(c_conj(ai))
        elif subop == R_VECTOR_LANE['vadd']:
            for ai, bi in zip(A,B):
                D.append(c_add(ai, bi))
        elif subop == R_VECTOR_LANE['vsub']:
            for ai, bi in zip(A,B):
                D.append(c_sub(ai, bi))
        elif subop == R_VECTOR_LANE['vmul']:
            for ai, bi in zip(A,B):
                D.append(c_mul(ai, bi))
        elif subop == R_VECTOR_LANE['vmac']:
            D = m.v[rd][:]  # read-before-write
            for i,(di, ai, bi) in enumerate(zip(D, A, B)):
                D[i] = c_add(di, c_mul(ai, bi))
        elif subop == R_VECTOR_LANE['vdiv']:
            for ai, bi in zip(A,B):
                D.append(c_div(ai, bi))
        else:
            raise RuntimeError("Unknown vector-lane subop")
        m.write_v(rd, D)
    elif mapbits == MAP_VV_to_S:
        # reductions
        A = m.v[rs1]; B = m.v[rs2]
        if subop == R_REDUCTIONS['dotc']:
            acc = (0,0)
            for ai, bi in zip(A,B):
                acc = c_add(acc, c_mul(c_conj(ai), bi))
            m.write_s(rd, acc)
        elif subop == R_REDUCTIONS['dotu']:
            acc = (0,0)
            for ai, bi in zip(A,B):
                acc = c_add(acc, c_mul(ai, bi))
            m.write_s(rd, acc)
        elif subop == R_REDUCTIONS['iamax']:
            # index of max |A[i]|; tie => lowest index
            best_idx = 0
            best_val = c_abs2(A[0])
            for i in range(1, len(A)):
                val = c_abs2(A[i])
                if val > best_val:
                    best_val = val; best_idx = i
            m.write_s(rd, (sat64(best_idx << FRAC_BITS), 0))
        elif subop == R_REDUCTIONS['sum']:
            acc = (0,0)
            for ai in A:
                acc = c_add(acc, ai)
            m.write_s(rd, acc)
        elif subop == R_REDUCTIONS['asum']:
            acc_real = 0
            for ai in A:
                acc_real = add_q(acc_real, c_abs(ai))
            m.write_s(rd, (acc_real, 0))
        else:
            raise RuntimeError("Unknown reduction subop")
    elif mapbits == MAP_VS_to_V:
        # vector-scalar
        A = m.v[rs1]; sB = m.s[rs2]; D = []
        if subop == R_VEC_SCALAR['vsadd']:
            for ai in A: D.append(c_add(ai, sB))
        elif subop == R_VEC_SCALAR['vssub']:
            for ai in A: D.append(c_sub(ai, sB))
        elif subop == R_VEC_SCALAR['vsmul']:
            for ai in A: D.append(c_mul(ai, sB))
        elif subop == R_VEC_SCALAR['vsdiv']:
            for ai in A: D.append(c_div(ai, sB))
        else:
            raise RuntimeError("Unknown VxS subop")
        m.write_v(rd, D)
    else:
        raise RuntimeError("Unknown mapping bits")

def q22_23_to_q32_32_pair(imm90: int) -> Tuple[int,int]:
    # imm90 has Re in [44:0], Im in [89:45], two's complement 45-bit
    def sign_extend(val: int, bits: int) -> int:
        sign = 1 << (bits - 1)
        return (val ^ sign) - sign
    re45 = imm90 & ((1<<45)-1)
    im45 = (imm90 >> 45) & ((1<<45)-1)
    re = sign_extend(re45, 45)
    im = sign_extend(im45, 45)
    # Convert from Q22.23 to Q32.32 => multiply by 2^(32-23) = 512
    re_q32 = sat64(re * (1 << (32-23)))
    im_q32 = sat64(im * (1 << (32-23)))
    return (re_q32, im_q32)

def exec_i(m: Machine, w: int):
    subop = get_bits(w, 119,112)
    rd  = get_bits(w, 95,93)
    rs1 = get_bits(w, 92,90)
    imm90 = get_bits(w, 89,0)
    if subop == 0x00:  # cloadi
        val = q22_23_to_q32_32_pair(imm90)
        m.write_s(rd, val)
    elif subop in (0x01,0x02,0x03,0x04,0x05,0x06):  # c*_i with complex imm
        a = m.s[rs1]
        cimm = q22_23_to_q32_32_pair(imm90)
        if   subop == 0x01: m.write_s(rd, c_add(a, cimm))
        elif subop == 0x02: m.write_s(rd, c_mul(a, cimm))
        elif subop == 0x03: m.write_s(rd, c_sub(a, cimm))
        elif subop == 0x04: m.write_s(rd, c_div(a, cimm))
        elif subop == 0x05: m.write_s(rd, a if c_abs2(a) >= c_abs2(cimm) else cimm)
        elif subop == 0x06: m.write_s(rd, a if c_abs2(a) <= c_abs2(cimm) else cimm)
    elif subop == 0x10:  # cscale_i, real only in imm90(Re set, Im=0)
        a = m.s[rs1]
        scale = q22_23_to_q32_32_pair(imm90)[0]  # real part
        m.write_s(rd, (mul_q(a[0], scale), mul_q(a[1], scale)))
    else:
        raise RuntimeError(f"Unknown I-type subop 0x{subop:02X}")

def exec_j(m: Machine, w: int, program_len: int):
    subop = get_bits(w, 119,112)
    rs1 = get_bits(w, 95,93)  # should be 1 (s1)
    offs = get_bits_signed(w, 92,60)  # signed 33-bit
    if subop != 0x00:
        raise RuntimeError("Unknown J subop")
    # predicate: s1
    if m.pred_true():
        new_pc = m.pc + offs  # offs in instruction units, relative to THIS instruction
        if new_pc < 0 or new_pc >= program_len:
            # allow PC to escape to terminate
            m.pc = new_pc
        else:
            m.pc = new_pc
    else:
        m.pc += 1  # fall-through

def exec_s(m: Machine, w: int):
    subop = get_bits(w, 119,112)
    rc = get_bits(w, 111,111)  # bit 111
    reg3 = get_bits(w, 95,93)
    mbid = get_bits(w, 92,89)
    i16  = get_bits(w, 88,73)
    j16  = get_bits(w, 72,57)
    len16= get_bits(w, 56,41)
    if mbid >= len(m.bank):
        raise RuntimeError(f"mbid {mbid} out of range; banks={len(m.bank)}")
    rows = m.rows; cols = m.cols
    if subop == 0x00:  # vld
        L = len16 if len16 != 0 else m.cfg.vlen
        if rc == 0:
            r = i16
            if r >= rows or L > cols:
                raise RuntimeError("vld row range OOB")
            seq = [m.bank[mbid][r][c] for c in range(L)]
        else:
            c = i16
            if c >= cols or L > rows:
                raise RuntimeError("vld col range OOB")
            seq = [m.bank[mbid][r][c] for r in range(L)]
        # load into vector reg (broadcast or pad with zeros if L<VLEN)
        vec = [(0,0)] * m.cfg.vlen
        for k in range(min(L, m.cfg.vlen)):
            vec[k] = seq[k]
        m.write_v(reg3, vec)
        m.pc += 1
    elif subop == 0x01:  # vst
        L = len16 if len16 != 0 else m.cfg.vlen
        src = m.v[reg3]
        if rc == 0:
            r = i16
            if r >= rows or L > cols:
                raise RuntimeError("vst row range OOB")
            for c in range(L):
                m.bank[mbid][r][c] = src[c] if c < m.cfg.vlen else (0,0)
        else:
            c = i16
            if c >= cols or L > rows:
                raise RuntimeError("vst col range OOB")
            for r in range(L):
                m.bank[mbid][r][c] = src[r] if r < m.cfg.vlen else (0,0)
        m.pc += 1
    elif subop == 0x02:  # sld.xy
        x = i16; y = j16
        if y >= rows or x >= cols:
            raise RuntimeError("sld.xy OOB")
        m.write_s(reg3, m.bank[mbid][y][x])
        m.pc += 1
    elif subop == 0x03:  # sst.xy
        x = i16; y = j16
        if y >= rows or x >= cols:
            raise RuntimeError("sst.xy OOB")
        m.bank[mbid][y][x] = m.s[reg3]
        m.pc += 1
    else:
        raise RuntimeError("Unknown S subop")

def exec_one(m: Machine, w: int, program_len: int):
    opc = get_bits(w, 127,120)
    if opc == 0x01:       # R
        exec_r(m, w); m.pc += 1
    elif opc == 0x02:     # I
        exec_i(m, w); m.pc += 1
    elif opc == 0x03:     # J
        exec_j(m, w, program_len)
    elif opc == 0x04:     # S
        exec_s(m, w)
    else:
        raise RuntimeError(f"Unknown opcode 0x{opc:02X}")

# ------------------------------ Program loading ------------------------------

def load_hex(path: str) -> List[int]:
    words = []
    with open(path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            t = line.strip()
            if not t: continue
            if len(t) != 32 or any(c not in "0123456789ABCDEF" for c in t):
                raise RuntimeError(f"{path}:{line_no}: invalid 128-bit hex word")
            words.append(int(t, 16))
    return words

# ------------------------------ CLI ------------------------------

def main():
    ap = argparse.ArgumentParser(description="LAPU-128 Emulator")
    ap.add_argument("hexfile", help=".hex program (32 hex chars per line)")
    ap.add_argument("--vlen", type=int, default=8, help="Vector length (VLEN)")
    ap.add_argument("--banks", type=int, default=4, help="(ignored) Always 4 banks per spec")
    ap.add_argument("--n-mult", type=int, default=2, help="Square bank side = N * VLEN (N>1)")
    ap.add_argument("--max-steps", type=int, default=50, help="Max steps before stopping")
    ap.add_argument("--pp-vec-elems", type=int, default=8, help="Max vector elems to print")
    ap.add_argument("--pp-matrix", action="store_true", help="Print bank 0 window each step")
    ap.add_argument("--pp-rows", type=int, default=8, help="Rows to print from bank 0")
    ap.add_argument("--pp-cols", type=int, default=8, help="Cols to print from bank 0")
    ap.add_argument("--predicate-imag", action="store_true", help="Predicate uses real OR imag nonzero")
    args = ap.parse_args()

    if args.vlen <= 0: raise SystemExit("vlen must be > 0")
    args.banks = 4  # per spec, exactly 4 banks
    # no validation needed

    if args.n_mult <= 1:
        raise SystemExit("--n-mult must be > 1 (spec: square matrix side N*VLEN, N>1)")
    cfg = MachineConfig(
        vlen=args.vlen,
        banks=args.banks,
        rows_mult=args.n_mult,
        cols_mult=args.n_mult,
        pred_uses_real_only=(not args.predicate_imag)
    )
    m = Machine(cfg)
    prog = load_hex(args.hexfile)

    step = 0
    while 0 <= m.pc < len(prog) and step < args.max_steps:
        w = prog[m.pc]
        exec_one(m, w, len(prog))
        dump_state(m, step, w, args.pp_vec_elems, args.pp_matrix, args.pp_rows, args.pp_cols)
        step += 1

    if not (0 <= m.pc < len(prog)):
        print(f"\nProgram terminated: PC={m.pc} out of range.")
    else:
        print(f"\nStopped after reaching max steps ({args.max_steps}).")

if __name__ == "__main__":
    main()
