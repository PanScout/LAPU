#!/usr/bin/env python3
import sys, re, argparse
from decimal import Decimal, getcontext
from typing import List, Tuple, Dict, Any, Optional

getcontext().prec = 80

class AsmError(Exception):
    pass

def err(line_no: int, msg: str) -> None:
    raise AsmError(f"Line {line_no}: {msg}")

# Bit helpers
def set_bits(word: int, val: int, hi: int, lo: int, *, signed: bool=False, line_no: int=0, field_name: str="") -> int:
    width = hi - lo + 1
    if signed:
        minv = -(1 << (width - 1))
        maxv =  (1 << (width - 1)) - 1
    else:
        minv = 0
        maxv = (1 << width) - 1
    if val < minv or val > maxv:
        raise AsmError(f"Line {line_no}: value {val} does not fit in field {field_name}[{hi}:{lo}] ({'signed' if signed else 'unsigned'} {width}-bit range {minv}..{maxv})")
    # two's complement for signed negatives
    if signed and val < 0:
        val = (1 << width) + val
    mask = ((1 << width) - 1) << lo
    return (word & ~mask) | ((val << lo) & mask)

def parse_int(token: str, line_no: int, *, signed: bool=False, bits: Optional[int]=None) -> int:
    # Accept decimal like -123 or 456, or hex like 0x1A or -0x20
    t = token.strip().lower()
    neg = False
    if t.startswith('-'):
        neg = True
        t = t[1:]
    if t.startswith('0x'):
        base = 16
        tnum = t[2:]
    else:
        base = 10
        tnum = t
    if not tnum or any(c not in '0123456789abcdef' for c in tnum) if base==16 else not tnum.isdigit():
        raise AsmError(f"Line {line_no}: invalid integer literal '{token}'")
    val = int(tnum, base)
    if neg:
        val = -val
    if bits is not None:
        width = bits
        if signed:
            minv = -(1 << (width - 1))
            maxv =  (1 << (width - 1)) - 1
        else:
            minv = 0
            maxv = (1 << width) - 1
        if val < minv or val > maxv:
            raise AsmError(f"Line {line_no}: integer {val} does not fit in {bits}-bit {'signed' if signed else 'unsigned'} range {minv}..{maxv}")
    return val

def parse_real_decimal(token: str, line_no: int) -> Decimal:
    # Accept decimal like -1.25 or 2 or 3.0; also hex integer '0x...' means exact integer
    t = token.strip()
    if t.lower().startswith('0x'):
        # Treat hex as exact integer (no fractional part)
        return Decimal(int(t, 16))
    try:
        return Decimal(t)
    except Exception:
        raise AsmError(f"Line {line_no}: invalid real literal '{token}'")

def q_fixed_pack(value: Decimal, frac_bits: int, total_bits: int, line_no: int, what: str) -> int:
    """
    Pack a Decimal value into signed fixed-point with given frac_bits and total_bits.
    We do NOT round. We require exact representability (scaled integer).
    """
    scaled = value * (1 << frac_bits)
    # exact representability check
    if scaled != scaled.to_integral_value():
        raise AsmError(f"Line {line_no}: {what}={value} is not exactly representable in Q{total_bits-frac_bits-1}.{frac_bits} (no rounding policy specified)")
    intval = int(scaled)
    # Range check against signed total_bits
    minv = -(1 << (total_bits - 1))
    maxv = (1 << (total_bits - 1)) - 1
    if intval < minv or intval > maxv:
        raise AsmError(f"Line {line_no}: {what} out of range for signed {total_bits}-bit fixed-point: {value}")
    # convert negative to two's complement for storage convenience; we will mask later anyway
    if intval < 0:
        intval = (1 << total_bits) + intval
    return intval

# Tokenizer that preserves parenthesized immediates like c(1.5, -2.25)
def tokenize(line: str) -> List[str]:
    out = []
    buf = []
    paren = 0
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '#':  # comment start
            break
        if ch == '(':
            paren += 1
            buf.append(ch)
        elif ch == ')':
            paren = max(paren - 1, 0)
            buf.append(ch)
        elif paren == 0 and ch in ', \t\r\n':
            if buf:
                out.append(''.join(buf))
                buf = []
            # skip separators
        else:
            buf.append(ch)
        i += 1
    if buf:
        out.append(''.join(buf))
    return out

# Register parsing
def parse_reg(token: str, line_no: int) -> Tuple[str, int]:
    t = token.strip().lower()
    m = re.fullmatch(r'([sv])([0-7])', t)
    if not m:
        raise AsmError(f"Line {line_no}: expected register s0..s7 or v0..v7, got '{token}'")
    cls = m.group(1)
    idx = int(m.group(2))
    return cls, idx

def is_scalar_reg(token: str) -> bool:
    t = token.strip().lower()
    return re.fullmatch(r's[0-7]', t) is not None

def is_vector_reg(token: str) -> bool:
    t = token.strip().lower()
    return re.fullmatch(r'v[0-7]', t) is not None

# ISA tables (from the spec)
OPCODES = {
    'r': 0x01,
    'i': 0x02,
    'j': 0x03,
    's': 0x04,
}

# R-type subops grouped by mapping category
R_SCALAR_UNARY = {
    'cneg': 0x00,
    'conj': 0x01,
    'csqrt': 0x02,
    'cabs2': 0x03,
    'cabs': 0x04,
    'creal': 0x05,
    'cimag': 0x06,
    'crecip': 0x07,
}
R_SCALAR_BINARY = {
    'cadd': 0x08,
    'csub': 0x09,
    'cmul': 0x0A,
    'cdiv': 0x0B,
    'cmaxabs': 0x0C,
    'cminabs': 0x0D,
    'cmplt.re': 0x0E,
    'cmpgt.re': 0x0F,
    'cmple.re': 0x10,
}
R_VECTOR_LANE = {
    'vadd': 0x00,
    'vsub': 0x01,
    'vmul': 0x02,
    'vmac': 0x03,
    'vdiv': 0x04,
    'vconj': 0x05,  # unary
}
R_REDUCTIONS = {
    'dotc': 0x00,
    'dotu': 0x01,
    'iamax': 0x02,
    'sum': 0x03,
    'asum': 0x04,
}
R_VEC_SCALAR = {
    'vsadd': 0x18,
    'vssub': 0x19,
    'vsmul': 0x1A,
    'vsdiv': 0x1B,
    'vscale': 0x1C,  # present in spec; user said they won't use it
}

# mapping bits in flags[97:96]
MAPBITS = {
    'SS_to_S': 0b00,
    'VV_to_V': 0b01,
    'VV_to_S': 0b10,
    'VS_to_V': 0b11,
}

# I-type subops
I_SUBOPS = {
    'cloadi': 0x00,
    'cadd_i': 0x01,
    'cmul_i': 0x02,
    'csub_i': 0x03,
    'cdiv_i': 0x04,
    'cmaxabs_i': 0x05,
    'cminabs_i': 0x06,
    'cscale_i': 0x10,
}

# J-type
J_SUBOPS = {
    'jrel': 0x00,
}

# S-type
S_SUBOPS = {
    'vld': 0x00,
    'vst': 0x01,
    'sld.xy': 0x02,
    'sst.xy': 0x03,
}

def assemble_line(tokens: List[str], line_no: int, labels: Dict[str, int], pc_index: int) -> int:
    if not tokens:
        return None  # no instruction
    mn = tokens[0].lower()
    word = 0

    def set_common(opcode: int, subop: int):
        nonlocal word
        word = set_bits(word, opcode, 127, 120, line_no=line_no, field_name="opcode")
        word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")

    def parse_imm_or_label(tok: str) -> int:
        # returns a signed int for immediate (for jrel we need signed 33-bit in instruction units)
        # label: compute (target_pc - current_pc)
        if re.fullmatch(r'[A-Za-z_]\w*', tok):
            if tok not in labels:
                err(line_no, f"unknown label '{tok}'")
            return labels[tok] - pc_index
        else:
            # number literal (decimal or hex), signed allowed
            return parse_int(tok, line_no, signed=True)

    # ----- R-type -----
    if mn in R_SCALAR_UNARY or mn in R_SCALAR_BINARY or mn in R_VECTOR_LANE or mn in R_REDUCTIONS or mn in R_VEC_SCALAR:
        set_common(OPCODES['r'], 0)  # we'll set subop shortly
        # Initialize zeros for all reserved/unused fields
        # flags later, imm16 zero, reserved zeros by default (word is all zeros)
        # Parse operands based on category
        if mn in R_SCALAR_UNARY:
            # cneg d, a
            if len(tokens) != 3:
                err(line_no, f"{mn} expects 2 operands: d, a")
            if not (is_scalar_reg(tokens[1]) and is_scalar_reg(tokens[2])):
                err(line_no, f"{mn} requires scalar registers (s*)")
            _, rd = parse_reg(tokens[1], line_no)
            _, rs1 = parse_reg(tokens[2], line_no)
            subop = R_SCALAR_UNARY[mn]
            word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
            # mapping 00
            word = set_bits(word, MAPBITS['SS_to_S'], 97, 96, line_no=line_no, field_name="flags.map")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, 0, 89, 87, line_no=line_no, field_name="rs2")
            # imm16 zero
            word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
            # reserved zeros already
            if rd == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
        elif mn in R_SCALAR_BINARY:
            # cadd d, a, b
            if len(tokens) != 4:
                err(line_no, f"{mn} expects 3 operands: d, a, b")
            if not (is_scalar_reg(tokens[1]) and is_scalar_reg(tokens[2]) and is_scalar_reg(tokens[3])):
                err(line_no, f"{mn} requires scalar registers (s*)")
            _, rd = parse_reg(tokens[1], line_no)
            _, rs1 = parse_reg(tokens[2], line_no)
            _, rs2 = parse_reg(tokens[3], line_no)
            subop = R_SCALAR_BINARY[mn]
            word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
            word = set_bits(word, MAPBITS['SS_to_S'], 97, 96, line_no=line_no, field_name="flags.map")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, rs2, 89, 87, line_no=line_no, field_name="rs2")
            word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
            if rd == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
        elif mn in R_VECTOR_LANE:
            if mn == 'vconj':
                # vconj d, a
                if len(tokens) != 3:
                    err(line_no, f"{mn} expects 2 operands: vD, vA")
                if not (is_vector_reg(tokens[1]) and is_vector_reg(tokens[2])):
                    err(line_no, f"{mn} requires vector registers (v*)")
                _, rd = parse_reg(tokens[1], line_no)
                _, rs1 = parse_reg(tokens[2], line_no)
                subop = R_VECTOR_LANE[mn]
                word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
                word = set_bits(word, MAPBITS['VV_to_V'], 97, 96, line_no=line_no, field_name="flags.map")
                word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
                word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
                word = set_bits(word, 0, 89, 87, line_no=line_no, field_name="rs2")
                word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
                if rd == 0:
                    err(line_no, "writing to v0 is illegal (hard error)")
            else:
                # vadd/vsub/vmul/vmac/vdiv d, a, b
                if len(tokens) != 4:
                    err(line_no, f"{mn} expects 3 operands: vD, vA, vB")
                if not (is_vector_reg(tokens[1]) and is_vector_reg(tokens[2]) and is_vector_reg(tokens[3])):
                    err(line_no, f"{mn} requires vector registers (v*)")
                _, rd = parse_reg(tokens[1], line_no)
                _, rs1 = parse_reg(tokens[2], line_no)
                _, rs2 = parse_reg(tokens[3], line_no)
                subop = R_VECTOR_LANE[mn]
                word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
                word = set_bits(word, MAPBITS['VV_to_V'], 97, 96, line_no=line_no, field_name="flags.map")
                word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
                word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
                word = set_bits(word, rs2, 89, 87, line_no=line_no, field_name="rs2")
                word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
                if rd == 0:
                    err(line_no, "writing to v0 is illegal (hard error)")
        elif mn in R_REDUCTIONS:
            # dotc/dotu/iamax/sum/asum (v... -> s), forms:
            # dotc sD, vA, vB
            # dotu sD, vA, vB
            # iamax sD, vA
            # sum sD, vA
            # asum sD, vA
            subop = R_REDUCTIONS[mn]
            if mn in ('dotc', 'dotu'):
                if len(tokens) != 4:
                    err(line_no, f"{mn} expects 3 operands: sD, vA, vB")
                if not (is_scalar_reg(tokens[1]) and is_vector_reg(tokens[2]) and is_vector_reg(tokens[3])):
                    err(line_no, f"{mn} requires sD, vA, vB")
                _, rd = parse_reg(tokens[1], line_no)
                _, rs1 = parse_reg(tokens[2], line_no)
                _, rs2 = parse_reg(tokens[3], line_no)
            else:
                if len(tokens) != 3:
                    err(line_no, f"{mn} expects 2 operands: sD, vA")
                if not (is_scalar_reg(tokens[1]) and is_vector_reg(tokens[2])):
                    err(line_no, f"{mn} requires sD, vA")
                _, rd = parse_reg(tokens[1], line_no)
                _, rs1 = parse_reg(tokens[2], line_no)
                rs2 = 0
            word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
            word = set_bits(word, MAPBITS['VV_to_S'], 97, 96, line_no=line_no, field_name="flags.map")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, rs2, 89, 87, line_no=line_no, field_name="rs2")
            word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
            if rd == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
        elif mn in R_VEC_SCALAR:
            # vsadd/vssub/vsmul/vsdiv vD, vA, sB
            if len(tokens) != 4:
                err(line_no, f"{mn} expects 3 operands: vD, vA, sB")
            if not (is_vector_reg(tokens[1]) and is_vector_reg(tokens[2]) and is_scalar_reg(tokens[3])):
                err(line_no, f"{mn} requires vD, vA, sB")
            _, rd = parse_reg(tokens[1], line_no)
            _, rs1 = parse_reg(tokens[2], line_no)
            _, rs2 = parse_reg(tokens[3], line_no)
            subop = R_VEC_SCALAR[mn]
            word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
            word = set_bits(word, MAPBITS['VS_to_V'], 97, 96, line_no=line_no, field_name="flags.map")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, rs2, 89, 87, line_no=line_no, field_name="rs2")
            word = set_bits(word, 0, 86, 71, line_no=line_no, field_name="imm16")
            if rd == 0:
                err(line_no, "writing to v0 is illegal (hard error)")
        else:
            err(line_no, f"unrecognized R-type mnemonic '{mn}'")
        return word

    # ----- I-type -----
    if mn in I_SUBOPS:
        subop = I_SUBOPS[mn]
        word = set_bits(word, OPCODES['i'], 127, 120, line_no=line_no, field_name="opcode")
        word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
        # flags[111:96] = 0
        # rd [95:93], rs1 [92:90], imm_90 [89:0]
        if mn == 'cloadi':
            # cloadi sD, cIMM
            if len(tokens) != 3:
                err(line_no, "cloadi expects 2 operands: sD, cIMM")
            if not is_scalar_reg(tokens[1]):
                err(line_no, "cloadi requires scalar destination sD")
            _, rd = parse_reg(tokens[1], line_no)
            # cIMM syntax c(re,im)
            imm_tok = tokens[2]
            m = re.fullmatch(r'c\((.+)\)', imm_tok, flags=re.IGNORECASE)
            if not m:
                err(line_no, "cloadi requires c(re,im) as immediate")
            parts = m.group(1)
            # split re,im respecting nested? We assume no nested parens inside.
            parts = [p.strip() for p in parts.split(',')]
            if len(parts) != 2:
                err(line_no, "cIMM must be c(re, im)")
            re_val = parse_real_decimal(parts[0], line_no)
            im_val = parse_real_decimal(parts[1], line_no)
            # Pack Q22.23 into 90 bits as two 45-bit halves: Re [44:0], Im [89:45]
            re_bits = q_fixed_pack(re_val, frac_bits=23, total_bits=45, line_no=line_no, what="Re(cIMM)")
            im_bits = q_fixed_pack(im_val, frac_bits=23, total_bits=45, line_no=line_no, what="Im(cIMM)")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, 0, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, re_bits, 44, 0, line_no=line_no, field_name="imm90.Re")
            word = set_bits(word, im_bits, 89, 45, line_no=line_no, field_name="imm90.Im")
            if rd == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
            return word
        else:
            # cadd_i/cm ul_i/csub_i/cdiv_i/cmaxabs_i/cminabs_i: sD, sA, cIMM
            # cscale_i: sD, sA, rIMM (real), but we will still pack into imm_90 with Im=0
            if len(tokens) != 4:
                err(line_no, f"{mn} expects 3 operands: sD, sA, IMM")
            if not (is_scalar_reg(tokens[1]) and is_scalar_reg(tokens[2])):
                err(line_no, f"{mn} requires sD, sA, IMM")
            _, rd = parse_reg(tokens[1], line_no)
            _, rs1 = parse_reg(tokens[2], line_no)
            imm_tok = tokens[3]
            if mn == 'cscale_i':
                # real immediate
                val = parse_real_decimal(imm_tok, line_no)
                re_bits = q_fixed_pack(val, 23, 45, line_no, "rIMM(Re)")
                im_bits = 0
            else:
                m = re.fullmatch(r'c\((.+)\)', imm_tok, flags=re.IGNORECASE)
                if not m:
                    err(line_no, f"{mn} requires c(re,im) as immediate")
                parts = [p.strip() for p in m.group(1).split(',')]
                if len(parts) != 2:
                    err(line_no, "cIMM must be c(re, im)")
                re_val = parse_real_decimal(parts[0], line_no)
                im_val = parse_real_decimal(parts[1], line_no)
                re_bits = q_fixed_pack(re_val, 23, 45, line_no, "Re(cIMM)")
                im_bits = q_fixed_pack(im_val, 23, 45, line_no, "Im(cIMM)")
            word = set_bits(word, rd, 95, 93, line_no=line_no, field_name="rd")
            word = set_bits(word, rs1, 92, 90, line_no=line_no, field_name="rs1")
            word = set_bits(word, re_bits, 44, 0, line_no=line_no, field_name="imm90.Re")
            word = set_bits(word, im_bits, 89, 45, line_no=line_no, field_name="imm90.Im")
            if rd == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
            return word

    # ----- J-type -----
    if mn in J_SUBOPS:
        if mn != 'jrel':
            err(line_no, f"unsupported J-type mnemonic '{mn}'")
        # jrel offs33
        if len(tokens) != 2:
            err(line_no, "jrel expects 1 operand: offs33 (label or integer)")
        subop = J_SUBOPS[mn]
        word = set_bits(word, OPCODES['j'], 127, 120, line_no=line_no, field_name="opcode")
        word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
        # flags16 zeros except rc bit if applicable (not used here)
        # rs1 hard-encoded to s1
        word = set_bits(word, 1, 95, 93, line_no=line_no, field_name="rs1")
        offs = parse_imm_or_label(tokens[1])
        # offs is in instruction units; field is signed 33 bits
        word = set_bits(word, offs, 92, 60, line_no=line_no, field_name="offs33", signed=True)
        # reserved [59:0] = 0
        return word

    # ----- S-type -----
    if mn in S_SUBOPS:
        subop = S_SUBOPS[mn]
        word = set_bits(word, OPCODES['s'], 127, 120, line_no=line_no, field_name="opcode")
        word = set_bits(word, subop, 119, 112, line_no=line_no, field_name="subop")
        # FLAGS16[111:96]; rc at bit 111 (MSB); others zero
        if mn in ('vld','vst'):
            # vld vD, mbid, rc, idx16, len16
            # vst vS, mbid, rc, idx16, len16
            if len(tokens) != 6:
                err(line_no, f"{mn} expects 5 operands: v*, mbid, rc, idx16, len16")
            if not is_vector_reg(tokens[1]):
                err(line_no, f"{mn} requires vector register in operand 1")
            _, reg3 = parse_reg(tokens[1], line_no)
            mbid = parse_int(tokens[2], line_no, signed=False, bits=4)
            if not (0 <= mbid < 4):
                err(line_no, f"mbid {mbid} out of range (must be 0..3 for 4 banks)")
            rc    = parse_int(tokens[3], line_no, signed=False, bits=1)
            idx16 = parse_int(tokens[4], line_no, signed=False, bits=16)
            len16 = parse_int(tokens[5], line_no, signed=False, bits=16)
            word = set_bits(word, rc, 111, 111, line_no=line_no, field_name="FLAGS16.rc")
            word = set_bits(word, reg3, 95, 93, line_no=line_no, field_name="reg3")
            word = set_bits(word, mbid, 92, 89, line_no=line_no, field_name="mbid")
            # x16 -> i16, y16 -> j16 for sld/sst; here idx16 is placed into i16 (as per table)
            word = set_bits(word, idx16, 88, 73, line_no=line_no, field_name="i16/idx16")
            word = set_bits(word, 0, 72, 57, line_no=line_no, field_name="j16")
            word = set_bits(word, len16, 56, 41, line_no=line_no, field_name="len16")
            if reg3 == 0:
                err(line_no, "writing to v0 is illegal (hard error)")
        elif mn == 'sld.xy':
            # sld.xy sD, mbid, x16, y16  (map x->i16, y->j16)
            if len(tokens) != 5:
                err(line_no, "sld.xy expects 4 operands: sD, mbid, x16, y16")
            if not is_scalar_reg(tokens[1]):
                err(line_no, "sld.xy requires scalar destination sD")
            _, reg3 = parse_reg(tokens[1], line_no)
            mbid = parse_int(tokens[2], line_no, signed=False, bits=4)
            if not (0 <= mbid < 4):
                err(line_no, f"mbid {mbid} out of range (must be 0..3 for 4 banks)")
            x16  = parse_int(tokens[3], line_no, signed=False, bits=16)
            y16  = parse_int(tokens[4], line_no, signed=False, bits=16)
            word = set_bits(word, reg3, 95, 93, line_no=line_no, field_name="reg3")
            word = set_bits(word, mbid, 92, 89, line_no=line_no, field_name="mbid")
            word = set_bits(word, x16, 88, 73, line_no=line_no, field_name="i16/x16")
            word = set_bits(word, y16, 72, 57, line_no=line_no, field_name="j16/y16")
            word = set_bits(word, 0, 56, 41, line_no=line_no, field_name="len16")
            # FLAGS16.rc not used; leave zero
            if reg3 == 0:
                err(line_no, "writing to s0 is illegal (hard error)")
        elif mn == 'sst.xy':
            # sst.xy sS, mbid, x16, y16  (store scalar to matrix bank; writing memory only, so sS can be s0? spec doesn't forbid store-from-zero; but we won't forbid)
            if len(tokens) != 5:
                err(line_no, "sst.xy expects 4 operands: sS, mbid, x16, y16")
            if not is_scalar_reg(tokens[1]):
                err(line_no, "sst.xy requires scalar source sS")
            _, reg3 = parse_reg(tokens[1], line_no)
            mbid = parse_int(tokens[2], line_no, signed=False, bits=4)
            if not (0 <= mbid < 4):
                err(line_no, f"mbid {mbid} out of range (must be 0..3 for 4 banks)")
            x16  = parse_int(tokens[3], line_no, signed=False, bits=16)
            y16  = parse_int(tokens[4], line_no, signed=False, bits=16)
            word = set_bits(word, reg3, 95, 93, line_no=line_no, field_name="reg3")
            word = set_bits(word, mbid, 92, 89, line_no=line_no, field_name="mbid")
            word = set_bits(word, x16, 88, 73, line_no=line_no, field_name="i16/x16")
            word = set_bits(word, y16, 72, 57, line_no=line_no, field_name="j16/y16")
            word = set_bits(word, 0, 56, 41, line_no=line_no, field_name="len16")
            # FLAGS16.rc not used; leave zero
        else:
            err(line_no, f"unsupported S-type mnemonic '{mn}'")
        return word

    err(line_no, f"unknown mnemonic '{mn}'")

def assemble_text(lines: List[str]) -> List[int]:
    # First pass: collect labels and instruction addresses (in instruction units)
    labels: Dict[str, int] = {}
    instrs: List[Tuple[int, List[str]]] = []
    pc = 0
    label_pattern = re.compile(r'^([A-Za-z_]\w*):$')
    for idx, raw in enumerate(lines, start=1):
        # strip comments for label detection
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        # allow labels on their own line OR label + instruction on same line
        # Split potential leading label
        tokens = tokenize(line)
        if not tokens:
            continue
        # If first token ends with ":" in original, handle; else detect with regex on stripped text
        # We'll parse labels in a simple way: while tokens[0] is "label:" add label; then process rest.
        rest_tokens = tokens[:]
        while rest_tokens and rest_tokens[0].endswith(':'):
            lab = rest_tokens.pop(0)[:-1]
            if not re.fullmatch(r'[A-Za-z_]\w*', lab):
                raise AsmError(f"Line {idx}: invalid label '{lab}'")
            if lab in labels:
                raise AsmError(f"Line {idx}: duplicate label '{lab}'")
            labels[lab] = pc
        if not rest_tokens:
            continue
        # If first token is a bare label (without colon) followed by nothing? Not allowed
        # Record instruction tokens and line number
        instrs.append((idx, rest_tokens))
        pc += 1

    # Second pass: encode each instruction
    enc: List[int] = []
    pc = 0
    for line_no, tokens in instrs:
        word = assemble_line(tokens, line_no, labels, pc_index=pc)
        enc.append(word)
        pc += 1
    return enc

def format_hex128(word: int) -> str:
    if word < 0 or word >= (1 << 128):
        raise AsmError(f"encoded word out of 128-bit range: {word}")
    return f"{word:032X}"  # uppercase, 32 hex digits

def main():
    ap = argparse.ArgumentParser(description="LAPU-128 Assembler (hex output)")
    ap.add_argument("input", help="input .asm file")
    ap.add_argument("-o", "--output", required=True, help="output .hex file")
    args = ap.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        lines = f.readlines()

    try:
        words = assemble_text(lines)
    except AsmError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    with open(args.output, "w", encoding="utf-8") as f:
        for w in words:
            f.write(format_hex128(w) + "\n")

if __name__ == "__main__":
    main()
