
#!/usr/bin/env python3
import argparse, re, math
from typing import List, Tuple, Dict, Optional

OPC_R = 0x01
OPC_I = 0x02
OPC_J = 0x03
OPC_S = 0x04

MAP_SS = 0b00
MAP_VV = 0b01
MAP_VS = 0b10
MAP_VS_BCAST = 0b11

R_SCALAR_SUBOPS = {
    'cneg':0x00,'conj':0x01,'csqrt':0x02,'cabs2':0x03,'cabs':0x04,'creal':0x05,'cimag':0x06,'crecip':0x07,
    'cadd':0x08,'csub':0x09,'cmul':0x0A,'cdiv':0x0B,
}
R_VECTOR_SUBOPS = {'vadd':0x00,'vsub':0x01,'vmul':0x02,'vdiv':0x04,'vconj':0x05}
R_REDUCE_SUBOPS = {'dotu':0x01,'iamax':0x02,'sum':0x03}
R_BCAST_SUBOPS  = {'vsadd':0x18,'vssub':0x19,'vsmul':0x1A,'vsdiv':0x1B}
I_SUBOPS        = {'cloadi':0x00,'cadd_i':0x01,'cmul_i':0x02,'csub_i':0x03,'cdiv_i':0x04}
J_SUBOPS        = {'jrel':0x00}
S_SUBOPS        = {'vld':0x00,'vst':0x01,'sld.xy':0x02,'sst.xy':0x03}

REG_RE = re.compile(r'([sv])([0-7])$')
MB_RE  = re.compile(r'mb([0-3])$')
NUM_RE = re.compile(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$')

def reg_to_num(tok: str):
    m = REG_RE.match(tok.strip())
    if not m: raise ValueError(f"Bad register '{tok}'. Use s0..s7 or v0..v7.")
    return m.group(1), int(m.group(2))

def mb_to_num(tok: str):
    t = tok.strip().lower()
    m = MB_RE.match(t)
    if m: return int(m.group(1))
    # allow plain numeric 0..3
    try:
        v = int(t, 0)  # auto base (0x.. or decimal)
    except:
        v = None
    if v is None or not (0 <= v <= 3):
        raise ValueError(f"Bad matrix-bank '{tok}'. Use mb0..mb3 or 0..3.")
    return v

def parse_number_like(s: str) -> int:
    return int(s.strip(), 0)

def parse_complex_any(tok: str) -> Tuple[str, float, float]:
    """
    Returns ('int', re, im) for c(RE,IM) integer form (units of 1.0 to be scaled by 2^23),
            ('float', re, im) for (re,im) float form.
    """
    s = tok.strip()
    if s.startswith('c(') and s.endswith(')'):
        body = s[2:-1]
        parts = [p.strip() for p in body.split(',')]
        if len(parts)!=2: raise ValueError("c(RE,IM) needs two ints")
        re_i = parse_number_like(parts[0]); im_i = parse_number_like(parts[1])
        return 'int', float(re_i), float(im_i)
    if s.startswith('(') and s.endswith(')'):
        body = s[1:-1]
        parts = [p.strip() for p in body.split(',')]
        if len(parts)!=2: raise ValueError("(re,im) needs two floats")
        def to_float(x):
            if NUM_RE.match(x): return float(x)
            raise ValueError(f"Expected number, got {x}")
        return 'float', to_float(parts[0]), to_float(parts[1])
    raise ValueError(f"Expected (re,im) or c(RE,IM), got {tok}")

def sat_to_signed(val: int, bits: int):
    minv = -(1 << (bits-1)); maxv = (1 << (bits-1)) - 1
    return min(max(val, minv), maxv)

def pack_imm90_q22_23_from_floats(re_f: float, im_f: float) -> int:
    scale = 1 << 23
    re_i = sat_to_signed(int((re_f) * scale), 45)
    im_i = sat_to_signed(int((im_f) * scale), 45)
    if re_i < 0: re_i = (1 << 45) + re_i
    if im_i < 0: im_i = (1 << 45) + im_i
    return (re_i << 45) | im_i

def pack_imm90_q22_23_from_ints(re_int: int, im_int: int) -> int:
    scale = 1 << 23
    re_scaled = sat_to_signed(int(re_int) * scale, 45)
    im_scaled = sat_to_signed(int(im_int) * scale, 45)
    if re_scaled < 0: re_scaled = (1 << 45) + re_scaled
    if im_scaled < 0: im_scaled = (1 << 45) + im_scaled
    return (re_scaled << 45) | im_scaled

def twos_comp(value: int, bits: int) -> int:
    if value < 0: value = (1 << bits) + value
    return value & ((1 << bits) - 1)

def put_bits(word: int, val: int, hi: int, lo: int) -> int:
    width = hi - lo + 1
    mask = ((1 << width) - 1) << lo
    return (word & ~mask) | ((val & ((1 << width) - 1)) << lo)

def encode_R(subop: int, mapping: int, rd: int, rs1: int, rs2: int) -> int:
    w=0; w=put_bits(w,OPC_R,127,120); w=put_bits(w,subop,119,112)
    w=put_bits(w,mapping,97,96); w=put_bits(w,rd,95,93); w=put_bits(w,rs1,92,90); w=put_bits(w,rs2,89,87)
    return w

def encode_I(subop:int, rd:int, rs1:int, imm90:int) -> int:
    w=0; w=put_bits(w,OPC_I,127,120); w=put_bits(w,subop,119,112)
    w=put_bits(w,rd,95,93); w=put_bits(w,rs1,92,90); w=put_bits(w,imm90,89,0)
    return w

def encode_J(subop:int, offs33:int) -> int:
    w=0; w=put_bits(w,OPC_J,127,120); w=put_bits(w,subop,119,112)
    w=put_bits(w,0,111,96); w=put_bits(w,0b001,95,93); w=put_bits(w,twos_comp(offs33,33),92,60)
    return w

def encode_S_vec(subop:int, rc:int, rd:int, mbid:int, i16:int, j16:int) -> int:
    w=0; w=put_bits(w,OPC_S,127,120); w=put_bits(w,subop,119,112)
    w=put_bits(w,(rc & 1),111,111); w=put_bits(w,rd,95,93); w=put_bits(w,mbid,92,89)
    w=put_bits(w,i16 & 0xFFFF,88,73); w=put_bits(w,j16 & 0xFFFF,72,57)
    return w

def encode_S_sca(subop:int, rd:int, mbid:int, x:int, y:int) -> int:
    return encode_S_vec(subop, 0, rd, mbid, x, y)

class AsmError(Exception): pass

def strip_comments(line: str) -> str:
    semi = line.find(';')
    hashp = line.find('#')
    cut = len(line)
    if semi != -1: cut = min(cut, semi)
    if hashp != -1: cut = min(cut, hashp)
    return line[:cut].rstrip()

def tokenize_operands(ops: str):
    parts=[]; buf=''; depth=0
    for ch in ops:
        if ch=='(':
            depth+=1; buf+=ch
        elif ch==')':
            depth=max(0,depth-1); buf+=ch
        elif ch==',' and depth==0:
            parts.append(buf.strip()); buf=''
        else:
            buf+=ch
    if buf.strip(): parts.append(buf.strip())
    return parts

def split_multi_instr(line: str) -> list:
    mlist = [
        'cloadi','cadd_i','cmul_i','csub_i','cdiv_i',
        'cneg','conj','csqrt','cabs2','cabs','creal','cimag','crecip','cadd','csub','cmul','cdiv',
        'vadd','vsub','vmul','vdiv','vconj',
        'dotu','iamax','sum',
        'vsadd','vssub','vsmul','vsdiv',
        'jrel',
        'vld.rm','vld.cm','vst.rm','vst.cm',
        'sld.xy','sst.xy'
    ]
    pattern = r'(?:^|\s)(' + '|'.join(re.escape(m) for m in mlist) + r')\b'
    # find all occurrences
    starts = [m.start(1) for m in re.finditer(pattern, line)]
    if not starts:
        return [line.strip()]
    chunks = []
    for i, st in enumerate(starts):
        end = starts[i+1] if i+1 < len(starts) else len(line)
        chunks.append(line[st:end].strip())
    return chunks

def assemble_line(line: str, labels, cur_pc: int) -> Optional[int]:
    s=line.strip()
    if not s: return None
    if s.endswith(':'): return None
    if s.upper().startswith('ORG'): return None
    m=re.match(r'^([A-Za-z_][\w\.]*)(?:\s+(.*))?$', s)
    if not m: raise AsmError(f"Cannot parse line: {line}")
    mnem_full=m.group(1).lower(); ops_str=(m.group(2) or '').strip()
    ops=tokenize_operands(ops_str) if ops_str else []

    if mnem_full in R_SCALAR_SUBOPS:
        subop=R_SCALAR_SUBOPS[mnem_full]
        if subop<=0x07:
            if len(ops)!=2: raise AsmError(f"{mnem_full} requires 2 operands: d, a")
            tD,tA=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA)
            if cD!='s' or cA!='s': raise AsmError(f"{mnem_full} expects scalar regs s*")
            return encode_R(subop, MAP_SS, rd, ra, 0)
        else:
            if len(ops)!=3: raise AsmError(f"{mnem_full} requires 3 operands: d, a, b")
            tD,tA,tB=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA); cB,rb=reg_to_num(tB)
            if cD!='s' or cA!='s' or cB!='s': raise AsmError(f"{mnem_full} expects scalar regs s*")
            return encode_R(subop, MAP_SS, rd, ra, rb)

    if mnem_full in R_VECTOR_SUBOPS:
        subop=R_VECTOR_SUBOPS[mnem_full]
        if mnem_full=='vconj':
            if len(ops)!=2: raise AsmError('vconj requires 2 operands: vD, vA')
            tD,tA=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA)
            if cD!='v' or cA!='v': raise AsmError('vconj expects v*, v*')
            return encode_R(subop, MAP_VV, rd, ra, 0)
        else:
            if len(ops)!=3: raise AsmError(f"{mnem_full} requires 3 operands: vD, vA, vB")
            tD,tA,tB=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA); cB,rb=reg_to_num(tB)
            if cD!='v' or cA!='v' or cB!='v': raise AsmError(f"{mnem_full} expects v*, v*, v*")
            return encode_R(subop, MAP_VV, rd, ra, rb)

    if mnem_full in R_REDUCE_SUBOPS:
        subop=R_REDUCE_SUBOPS[mnem_full]
        if mnem_full=='iamax':
            if len(ops)!=2: raise AsmError("iamax requires 2 operands: sD, vA")
            tD,tA=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA)
            if cD!='s' or cA!='v': raise AsmError("iamax expects s*, v*")
            return encode_R(subop, MAP_VS, rd, ra, 0)
        elif mnem_full=='sum':
            if len(ops)!=2: raise AsmError("sum requires 2 operands: sD, vA")
            tD,tA=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA)
            if cD!='s' or cA!='v': raise AsmError("sum expects s*, v*")
            return encode_R(subop, MAP_VS, rd, ra, 0)
        else:
            if len(ops)!=3: raise AsmError(f"{mnem_full} requires 3 operands: sD, vA, vB")
            tD,tA,tB=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA); cB,rb=reg_to_num(tB)
            if cD!='s' or cA!='v' or cB!='v': raise AsmError(f"{mnem_full} expects s*, v*, v*")
            return encode_R(subop, MAP_VS, rd, ra, rb)

    if mnem_full in R_BCAST_SUBOPS:
        subop=R_BCAST_SUBOPS[mnem_full]
        if len(ops)!=3: raise AsmError(f"{mnem_full} requires 3 operands: vD, vA, sB")
        tD,tA,tB=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA); cB,rb=reg_to_num(tB)
        if cD!='v' or cA!='v' or cB!='s': raise AsmError(f"{mnem_full} expects v*, v*, s*")
        return encode_R(subop, MAP_VS_BCAST, rd, ra, rb)

    if mnem_full in I_SUBOPS:
        subop=I_SUBOPS[mnem_full]
        if mnem_full=='cloadi':
            if len(ops)!=2: raise AsmError("cloadi requires 2 operands: sD, (re,im) or c(RE,IM)")
            tD,cimm=ops; cD,rd=reg_to_num(tD)
            if cD!='s': raise AsmError("cloadi destination must be s*")
            kind,re_v,im_v = parse_complex_any(cimm)
            if kind=='int':
                imm90 = pack_imm90_q22_23_from_ints(int(re_v), int(im_v))
            else:
                imm90 = pack_imm90_q22_23_from_floats(re_v, im_v)
            return encode_I(subop, rd, 0, imm90)
        else:
            if len(ops)!=3: raise AsmError(f"{mnem_full} requires 3 operands: sD, sA, (re,im)|c(RE,IM)")
            tD,tA,cimm=ops; cD,rd=reg_to_num(tD); cA,ra=reg_to_num(tA)
            if cD!='s' or cA!='s': raise AsmError(f"{mnem_full} expects s*, s*")
            kind,re_v,im_v = parse_complex_any(cimm)
            if kind=='int':
                imm90 = pack_imm90_q22_23_from_ints(int(re_v), int(im_v))
            else:
                imm90 = pack_imm90_q22_23_from_floats(re_v, im_v)
            return encode_I(subop, rd, ra, imm90)

    if mnem_full in J_SUBOPS:
        subop=J_SUBOPS[mnem_full]
        if len(ops)!=1: raise AsmError("jrel requires 1 operand: label")
        label=ops[0]
        if label not in labels: raise AsmError(f"Unknown label '{label}'")
        offs=labels[label]-cur_pc
        if offs < -(1<<32) or offs > ((1<<32)-1): raise AsmError(f"jrel offset {offs} out of 33-bit signed range")
        return encode_J(subop, offs)

    if mnem_full.startswith('vld.') or mnem_full.startswith('vst.'):
        base, rc_spec = mnem_full.split('.',1)
        if rc_spec not in ('rm','cm'): raise AsmError("Use .rm or .cm")
        rc = 0 if rc_spec=='rm' else 1
        subop = S_SUBOPS[base]
        if len(ops)!=4: raise AsmError(f"{mnem_full} requires 4 operands: vX, MB(0..3), I, J")
        cD,rd=reg_to_num(ops[0])
        if cD!='v': raise AsmError(f"{mnem_full} first operand must be v*")
        mbid=mb_to_num(ops[1])
        i16 = parse_number_like(ops[2])
        j16 = parse_number_like(ops[3])
        return encode_S_vec(subop, rc, rd, mbid, i16, j16)

    if mnem_full in ('sld.xy','sst.xy'):
        subop=S_SUBOPS[mnem_full]
        if len(ops)!=4: raise AsmError(f"{mnem_full} requires 4 operands: sX, MB(0..3), X, Y")
        cS,rd=reg_to_num(ops[0])
        if cS!='s': raise AsmError(f"{mnem_full} first operand must be s*")
        mbid=mb_to_num(ops[1])
        x = parse_number_like(ops[2]); y = parse_number_like(ops[3])
        return encode_S_sca(subop, rd, mbid, x, y)

    raise AsmError(f"Unknown mnemonic '{mnem_full}'")

def assemble(text: str, want_bin: bool=False):
    lines = text.splitlines()
    labels = {}
    cur_pc = 0
    # Pass 1
    for raw in lines:
        line = strip_comments(raw.strip())
        if not line: continue
        chunks = split_multi_instr(line) if not line.endswith(':') else [line]
        for chunk in chunks:
            if not chunk: continue
            if chunk.endswith(':'):
                lab = chunk[:-1].strip()
                if not re.match(r'^[A-Za-z_]\w*$', lab): raise AsmError(f"Bad label name '{lab}'")
                labels[lab] = cur_pc; continue
            if chunk.upper().startswith('ORG'):
                parts = chunk.split()
                if len(parts)!=2 or not parts[1].isdigit(): raise AsmError("ORG requires a decimal address (word index)")
                cur_pc = int(parts[1]); continue
            cur_pc += 1
    # Pass 2
    words = []; cur_pc = 0
    for raw in lines:
        line = strip_comments(raw.strip())
        if not line: continue
        chunks = split_multi_instr(line) if not line.endswith(':') else [line]
        for chunk in chunks:
            if not chunk: continue
            if chunk.endswith(':'): continue
            if chunk.upper().startswith('ORG'):
                cur_pc = int(chunk.split()[1]); continue
            w = assemble_line(chunk, labels, cur_pc)
            if w is not None: words.append(w); cur_pc += 1
    bin_out = b''
    if want_bin:
        for w in words: bin_out += int.to_bytes(w, 16, byteorder='little', signed=False)
    return words, bin_out

def write_outputs(words, out_prefix: str, bin_bytes: bytes=None):
    with open(out_prefix + '.hex','w') as f:
        for w in words: f.write(f"{w:032x}\n")
    if bin_bytes is not None and len(bin_bytes)>0:
        with open(out_prefix + '.bin','wb') as f: f.write(bin_bytes)

def main():
    ap=argparse.ArgumentParser(description="LAPU-128 assembler (tile-per-op, positional S-type, c() immediates)")
    ap.add_argument('input'); ap.add_argument('-o','--out', default=None); ap.add_argument('--bin', action='store_true')
    args=ap.parse_args()
    src=open(args.input,'r').read()
    words,bin_bytes=assemble(src, want_bin=args.bin)
    import re as _re
    out_prefix=args.out or _re.sub(r'\.[^\.]+$','', args.input)
    write_outputs(words, out_prefix, bin_bytes if args.bin else None)

if __name__=='__main__':
    main()
