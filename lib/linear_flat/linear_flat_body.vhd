-- linear_flat_body.vhd
-- Library: flat_linear
-- Package: linear_flat (body)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package body linear_flat is

  ------------------------------------------------------------------------------
  -- Fixed-point conversions
  ------------------------------------------------------------------------------
  function fx_from_slv(x : std_logic_vector(FX_W-1 downto 0)) return fx64_s is
  begin
    return signed(x);
  end function;

  function slv_from_fx(x : fx64_s) return std_logic_vector is
  begin
    return std_logic_vector(x);
  end function;

  ------------------------------------------------------------------------------
  -- Basic arithmetic
  ------------------------------------------------------------------------------
  function fx_add(a,b : fx64_s) return fx64_s is
  begin
    return a + b;
  end function;

  function fx_sub(a,b : fx64_s) return fx64_s is
  begin
    return a - b;
  end function;


  ------------------------------------------------------------------------------
  -- Saturation helper
  ------------------------------------------------------------------------------
  -- Saturate an arbitrary-width signed to 64-bit Q31.32
function fx_sat(x : signed) return fx64_s is
  constant MAX64 : fx64_s := (FX_W-1 => '0', others => '1'); -- 0x7FFF...FFFF
  constant MIN64 : fx64_s := (FX_W-1 => '1', others => '0'); -- 0x8000...000
  variable sign      : std_logic := x(x'high);
  variable overflow  : boolean := false;
begin
  -- If already <= 64 bits, just resize (sign-extend/truncate)
  if x'length <= FX_W then
    return resize(x, FX_W);
  end if;

  -- Check all bits above the low 64 equal the sign bit
  -- (i.e., x[h-1:64] must be all 0s for positive or all 1s for negative)
  for k in x'high-1 downto FX_W loop
    if (sign = '0' and x(k) = '1') or (sign = '1' and x(k) = '0') then
      overflow := true;
      exit;
    end if;
  end loop;

  if overflow then
    if sign = '0' then
      return MAX64;
    else
      return MIN64;
    end if;
  else
    return fx64_s(x(FX_W-1 downto 0));
  end if;
end function;


  ------------------------------------------------------------------------------
  -- Multiply with rounding and scaling (Q31.32)
  ------------------------------------------------------------------------------
-- Multiply with rounding and scaling (Q format with FX_FRAC fractional bits)
function fx_mul(a, b : fx64_s) return fx64_s is
  -- Full-precision product: 64 x 64 -> 128 bits
  variable prod   : signed(127 downto 0);
  variable adj    : signed(127 downto 0);
  variable half_v : signed(127 downto 0);
  -- After dropping FX_FRAC LSBs we keep the top (128 - FX_FRAC) bits
  subtype post_t is signed(127 - FX_FRAC downto 0);
  variable sh_slice : post_t;
begin
  -- Sanity: FX_FRAC must not exceed 127 or the slice becomes negative width
  assert (FX_FRAC <= 127)
    report "fx_mul: FX_FRAC must be <= 127"
    severity failure;

  -- 64x64 -> 128 exact product
  prod := signed(a) * signed(b);

  -- 0.5 ulp at the target shift for round-to-nearest (symmetric)
  if FX_FRAC = 0 then
    half_v := (others => '0');
  else
    half_v := (others => '0');
    half_v(FX_FRAC - 1) := '1';  -- exactly 1<<(FX_FRAC-1)
  end if;

  -- Symmetric rounding: add HALF for nonnegative, subtract for negative
  if prod(127) = '0' then
    adj := prod + half_v;
  else
    adj := prod - half_v;
  end if;

  if FX_FRAC = 0 then
    -- No scaling drop; just saturate the rounded 128-bit value
    return fx_sat(adj);
  else
    -- Drop FX_FRAC LSBs without a shift operator; take the upper bits directly
    sh_slice := adj(127 downto FX_FRAC);
    return fx_sat(sh_slice);
  end if;
end function;






  ------------------------------------------------------------------------------
  -- Complex packing
  ------------------------------------------------------------------------------
  function pack_complex(re_i, im_i : fx64_s) return std_logic_vector is
    variable c : std_logic_vector(CMP_W-1 downto 0);
  begin
    c(CMP_W-1 downto 64) := std_logic_vector(re_i);
    c(63 downto 0)       := std_logic_vector(im_i);
    return c;
  end function;

  function unpack_re(c : std_logic_vector) return fx64_s is
    -- take the upper 64 bits, regardless of c's absolute range
    variable r : fx64_s;
  begin
    r := signed(c(c'high downto c'high-63));
    return r;
  end function;

  function unpack_im(c : std_logic_vector) return fx64_s is
    -- take the lower 64 bits, relative to c'low
    variable i : fx64_s;
  begin
    i := signed(c(c'low+63 downto c'low));
    return i;
  end function;


  ------------------------------------------------------------------------------
  -- Vector/matrix sizing
  ------------------------------------------------------------------------------
  function vec_bits(N : natural) return natural is
  begin
    return N * CMP_W;
  end function;

  function mat_bits(N : natural) return natural is
  begin
    return N * N * CMP_W;
  end function;

  ------------------------------------------------------------------------------
  -- Vector accessors
  ------------------------------------------------------------------------------
  function vec_get(vec : std_logic_vector; N, idx : natural) return std_logic_vector is
    variable lo : integer := idx * CMP_W;
    variable hi : integer := lo + CMP_W - 1;
  begin
    return vec(hi downto lo);
  end function;

  function vec_set(vec : std_logic_vector; N, idx : natural; val : std_logic_vector)
    return std_logic_vector is
    variable r  : std_logic_vector(vec'range) := vec;
    variable lo : integer := idx * CMP_W;
    variable hi : integer := lo + CMP_W - 1;
  begin
    r(hi downto lo) := val;
    return r;
  end function;

  ------------------------------------------------------------------------------
  -- Matrix helpers (row-major)
  ------------------------------------------------------------------------------
  function mat_idx(N,row,col : natural) return natural is
  begin
    return row * N + col;
  end function;

  function mat_get(mat : std_logic_vector; N, row, col : natural) return std_logic_vector is
    variable idx : natural := mat_idx(N,row,col);
    variable lo  : integer := idx * CMP_W;
    variable hi  : integer := lo + CMP_W - 1;
  begin
    return mat(hi downto lo);
  end function;

  function mat_set(mat : std_logic_vector; N, row, col : natural; val : std_logic_vector)
    return std_logic_vector is
    variable r   : std_logic_vector(mat'range) := mat;
    variable idx : natural := mat_idx(N,row,col);
    variable lo  : integer := idx * CMP_W;
    variable hi  : integer := lo + CMP_W - 1;
  begin
    r(hi downto lo) := val;
    return r;
  end function;

end package body linear_flat;
