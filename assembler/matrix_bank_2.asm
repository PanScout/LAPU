# --- Fill row y=0 with 8 scalars at x=0..7 (mbid=0) ---
cloadi s1, c(0x1, 0x0)   # 1 + 0j
sst.xy  s1, 0, 0, 0      # M[0,0] = 1

cloadi s1, c(0x2, 0x0)
sst.xy  s1, 0, 1, 0      # M[1,0] = 2
#
cloadi s1, c(0x3, 0x0)
sst.xy  s1, 0, 2, 0      # M[2,0] = 3
#
cloadi s1, c(0x4, 0x0)
sst.xy  s1, 0, 3, 0      # M[3,0] = 4
#
cloadi s1, c(0x5, 0x0)
sst.xy  s1, 0, 4, 0      # M[4,0] = 5
#
cloadi s1, c(0x6, 0x0)
sst.xy  s1, 0, 5, 0      # M[5,0] = 6
#
cloadi s1, c(0x7, 0x0)
sst.xy  s1, 0, 6, 0      # M[6,0] = 7
#
cloadi s1, c(0x8, 0x0)
sst.xy  s1, 0, 7, 0      # M[7,0] = 8
#
## --- Vector load 8 contiguous values (VECTOR_LEN=8) starting at (x=0,y=0) ---
## Row-major means X increments while Y stays fixed.
vld.rm  v1, 0, 0, 0      # v1 <- [M[0,0], M[1,0], ..., M[7,0]]

# --- Fill row y=0 with 8 scalars at x=0..7 (mbid=0) ---
cloadi s1, c(0x1, 0x0)   # 1 + 0j
sst.xy  s1, 0, 0, 0      # M[0,0] = 1

cloadi s1, c(0x2, 0x0)
sst.xy  s1, 0, 0, 1      # M[1,0] = 2
#
cloadi s1, c(0x3, 0x0)
sst.xy  s1, 0, 0, 2      # M[2,0] = 3
#
cloadi s1, c(0x4, 0x0)
sst.xy  s1, 0, 0, 3      # M[3,0] = 4
#
cloadi s1, c(0x5, 0x0)
sst.xy  s1, 0, 0, 4      # M[4,0] = 5
#
cloadi s1, c(0x6, 0x0)
sst.xy  s1, 0, 0, 5      # M[5,0] = 6
#
cloadi s1, c(0x7, 0x0)
sst.xy  s1, 0, 0, 6      # M[6,0] = 7
#
cloadi s1, c(0x8, 0x0)
sst.xy  s1, 0, 0, 7      # M[7,0] = 8
vld.cm  v2, 0, 0, 0      # v1 <- [M[0,0], M[1,0], ..., M[7,0]]
vadd v3, v2, v1