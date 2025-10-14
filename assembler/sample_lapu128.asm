# sample_lapu128.asm
# Demonstrates: labels, jrel, scalar ops, I-type imm, S-type load/store, vector ops.
start:
    cloadi s1 c(1.5, -2.25)   # load exact Q22.23-representable constants
    cloadi s2 c(0, 0)         # zero via imm (legal; s0 is hardware zero but we won't write it)
    cadd   s3 s1 s2
    vld    v1  3 1 5 0        # mbid=3, rc=1 (column), idx16=5, len16=0 => L=VLEN
    vld    v2  3 0 0 8        # rc=0 (row), idx16=0, len16=8
    vmul   v3  v1 v2
    dotc   s4  v1 v2
loop:
    jrel   start              # PC := PC + (start - this) => backward branch
    sld.xy s5 2 10 12
    sst.xy s5 2 11 12
