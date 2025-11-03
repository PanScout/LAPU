###############################################
# LAPU-128 division-free smoke test
# - NO division ops whatsoever (no cdiv/cdiv_i/vdiv/vsdiv/crecip)
# - Uses vld.rm / vld.cm and vst.rm / vst.cm
# - Leaves s7 = 2 + 0j at the end
###############################################

start:
# ---------- I-type: load constants (exact Q22.23 representable) ----------
cloadi s1, c(0x1, 0x0)      # 1
cloadi s2, c(0x2, 0x0)      # 2
cloadi s3, c(0x4, 0x0)      # 4
cloadi s4, c(0x0, 0x1)      # j
cloadi s5, c(0x8, 0x0)      # 8
cloadi s6, c(0x0, 0x0)      # scratch

# ---------- I-type ALU (no division) ----------
cadd_i s6, s1, c(0x5, 0x0)  # 1 + 5 -> 6
cmul_i s6, s1, c(0x3, 0x0)  # 1 * 3 -> 3
csub_i s6, s2, c(0x1, 0x0)  # 2 - 1 -> 1

# ---------- R-type scalar unary (skip crecip; skip csqrt) ----------
cneg   s1, s1               # -1
conj   s2, s2               # 2 (real) stays 2
cabs2  s4, s4               # |j|^2 -> 1
cabs   s5, s5               # |8| -> 8
creal  s6, s6               # real(1) -> 1
cimag  s1, s1               # imag(-1) -> 0

# ---------- R-type scalar binary (no cdiv) ----------
cloadi s1, c(0x3, 0x0)
cloadi s2, c(0x1, 0x0)
cadd s6, s1, s2             # 3 + 1 -> 4
csub s6, s1, s2             # 3 - 1 -> 2
cmul s6, s1, s2             # 3 * 1 -> 3

# ---------- Seed matrix memory with known values ----------
# Row y=3 : x=0..7 = 1..8
cloadi s1, c(0x1, 0x0)  
sst.xy s1, 0, 0, 3
cloadi s1, c(0x2, 0x0)
sst.xy s1, 0, 1, 3
cloadi s1, c(0x3, 0x0)
sst.xy s1, 0, 2, 3
cloadi s1, c(0x4, 0x0)
sst.xy s1, 0, 3, 3
cloadi s1, c(0x5, 0x0)
sst.xy s1, 0, 4, 3
cloadi s1, c(0x6, 0x0)
sst.xy s1, 0, 5, 3
cloadi s1, c(0x7, 0x0)
sst.xy s1, 0, 6, 3
cloadi s1, c(0x8, 0x0)
sst.xy s1, 0, 7, 3

# Column x=12 : y=0..7 = 1..8
cloadi s1, c(0x1, 0x0)
sst.xy s1, 0, 12, 0
cloadi s1, c(0x2, 0x0)
sst.xy s1, 0, 12, 1
cloadi s1, c(0x3, 0x0)
sst.xy s1, 0, 12, 2
cloadi s1, c(0x4, 0x0)
sst.xy s1, 0, 12, 3
cloadi s1, c(0x5, 0x0)
sst.xy s1, 0, 12, 4
cloadi s1, c(0x6, 0x0)
sst.xy s1, 0, 12, 5
cloadi s1, c(0x7, 0x0)
sst.xy s1, 0, 12, 6
cloadi s1, c(0x8, 0x0)
sst.xy s1, 0, 12, 7

# ---------- S-type: scalar element loads ----------
sld.xy s2, 0, 3, 3          # expect 4
sld.xy s3, 0, 12, 6         # expect 7

# Row-major vector ops (safe):
vld.rm v1, 0, 0, 3   # read row y=3, first 8 columns
vst.rm v1, 0, 0, 4   # write to row y=4, first 8 columns

# Column-major vector ops (safe):
vld.cm v2, 0, 0, 12  # read column x=12, first 8 rows
vst.cm v2, 0, 0, 13  # write to column x=13, first 8 rows


# ---------- R-type: vector lane ops (no vdiv) ----------
vadd  v3, v1, v2
vsub  v4, v3, v2
vmul  v5, v1, v2
vconj v6, v5

# ---------- Reductions (no division involved) ----------
dotu  s1, v1, v1            # sum of |v1|^2
iamax s2, v2                # index of max |.| in v2
sum   s3, v1                # sum of v1

# ---------- Vector + scalar (no vsdiv) ----------
cloadi s4, c(0x2, 0x0)      # scalar = 2
vsadd v1, v1, s4
vssub v2, v2, s4
vsmul v3, v3, s4

# ---------- J-type (predicated on s1.re != 0) ----------
# Ensure s1.re != 0 so jump is taken; s1 currently holds dotu(v1,v1) so it’s > 0
jrel done
cloadi s6, c(0x3E7, 0x0)    # would be skipped

done:
# ---------- Final deterministic result ----------
cloadi s7, c(0x0, 0x0)
cadd_i s7, s7, c(0x1, 0x0)  # 1
cadd_i s7, s7, c(0x1, 0x0)  # 2  -> expect s7 = 2 + 0j
