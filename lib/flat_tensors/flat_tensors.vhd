-- flat_tensors.vhd
-- VHDL-2008
-- Flat complex scalar as a single std_logic_vector.
-- Upper half = real (two’s complement Q format), lower half = imag.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package flat_tensors is
  -----------------------------------------------------------------------------
  -- Elaboration time constants 
  -----------------------------------------------------------------------------
  constant COMPLEX_WIDTH  : positive := 128; -- total width (must be even)
  constant PART_INT_BITS  : natural  := 32; -- integer bits per part
  constant PART_FRAC_BITS : natural  := 32; -- fractional bits per part
  constant PART_WIDTH     : positive := COMPLEX_WIDTH/2; -- derived

  constant VECTOR_WORD_WIDTH : positive := 8; -- derived
  constant VECTOR_BIT_WIDTH  : positive := VECTOR_WORD_WIDTH * COMPLEX_WIDTH;

  constant MATRIX_FACTOR     : positive := 2;
  constant MATRIX_WORD_WIDTH : positive := (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * (VECTOR_WORD_WIDTH * MATRIX_FACTOR);
  constant MATRIX_BIT_WIDTH  : positive := (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * COMPLEX_WIDTH;

  constant MATRIX_SUBVECTORS : positive := MATRIX_FACTOR;
  constant WORDS_PER_AXIS    : positive := MATRIX_FACTOR * VECTOR_WORD_WIDTH;
  -----------------------------------------------------------------------------
  -- Data types
  -----------------------------------------------------------------------------
  subtype complex_t is std_logic_vector(COMPLEX_WIDTH - 1 downto 0);
  subtype vector_t is std_logic_vector(VECTOR_BIT_WIDTH - 1 downto 0);
  subtype matrix_t is std_logic_vector(MATRIX_BIT_WIDTH - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Helper type functions
  -----------------------------------------------------------------------------
  function add_parts(a, b : std_logic_vector) return std_logic_vector;
  function sub_parts(a, b : std_logic_vector) return std_logic_vector;
  function sqrt_part(a    : std_logic_vector) return std_logic_vector;
  -----------------------------------------------------------------------------
  -- Complex data type functions
  -----------------------------------------------------------------------------
  function get_re(x        : complex_t) return std_logic_vector;
  function get_im(x        : complex_t) return std_logic_vector;
  function set_re(x : complex_t; new_re : std_logic_vector) return complex_t;
  function set_im(x : complex_t; new_im : std_logic_vector) return complex_t;
  function make_complex(re_part : std_logic_vector; im_part : std_logic_vector) return complex_t;
  function scalar_add(a, b : complex_t) return complex_t;
  function scalar_sub(a, b : complex_t) return complex_t;
  function scalar_mul(a, b : complex_t) return complex_t;
  function scalar_div(a, b : complex_t) return complex_t;
  function scalar_conj(a   : complex_t) return complex_t;
  function scalar_abs2(a   : complex_t) return std_logic_vector;
  function scalar_abs(a    : complex_t) return std_logic_vector;

  -----------------------------------------------------------------------------
  -- Vector data type functions
  -----------------------------------------------------------------------------
  function get_vec_num(a : vector_t; n : integer) return complex_t;
  function set_vec_num(a : vector_t; n : integer; c : complex_t) return vector_t;
  function add_vec(a, b : vector_t) return vector_t;
  function sub_vec(a, b : vector_t) return vector_t;
  function make_vec(a   : std_logic_vector) return vector_t;
  function vec_plus_complex(a : vector_t; b : complex_t) return vector_t;
  function vec_minus_complex(a : vector_t; b : complex_t) return vector_t;

  -----------------------------------------------------------------------------
  -- Matrix data type functions
  -----------------------------------------------------------------------------
  function get_mat_num(a : matrix_t; i, j : integer) return complex_t;
  function set_mat_num(a : matrix_t; i, j : integer; c : complex_t) return matrix_t;

end package flat_tensors;

package body flat_tensors is
  -----------------------------------------------------------------------------
  -- Elaboration-time checks (tool-friendly)
  -----------------------------------------------------------------------------
  pure function config_ok return boolean is
begin
  assert (COMPLEX_WIDTH mod 2) = 0
  report "flat_tensors: COMPLEX_WIDTH must be even (real/imag halves)."
    severity failure;

  assert (PART_INT_BITS + PART_FRAC_BITS) = PART_WIDTH
  report "flat_tensors: PART_INT_BITS + PART_FRAC_BITS must equal COMPLEX_WIDTH/2."
    severity failure;

  return true;
end function;

constant CONFIG_CHECK_PASSED : boolean := config_ok;

-----------------------------------------------------------------------------
-- Bitfield indices
-----------------------------------------------------------------------------
constant RE_MSB : natural := COMPLEX_WIDTH - 1;
constant RE_LSB : natural := PART_WIDTH;
constant IM_MSB : natural := PART_WIDTH - 1;
constant IM_LSB : natural := 0;

-----------------------------------------------------------------------------
-- Accessors (read)
-----------------------------------------------------------------------------
function get_re(x : complex_t) return std_logic_vector is
  variable r        : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  r := x(RE_MSB downto RE_LSB);
  return r;
end function;

function get_im(x : complex_t) return std_logic_vector is
  variable r        : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  r := x(IM_MSB downto IM_LSB);
  return r;
end function;

-----------------------------------------------------------------------------
-- Accessors (write)
-----------------------------------------------------------------------------
function set_re(x : complex_t; new_re : std_logic_vector) return complex_t is
  variable y : complex_t := x;
begin
  assert new_re'length = PART_WIDTH
  report "flat_tensors.set_re: new_re must be PART_WIDTH bits."
    severity failure;
  y(RE_MSB downto RE_LSB) := new_re;
  return y;
end function;

function set_im(x : complex_t; new_im : std_logic_vector) return complex_t is
  variable y : complex_t := x;
begin
  assert new_im'length = PART_WIDTH
  report "flat_tensors.set_im: new_im must be PART_WIDTH bits."
    severity failure;
  y(IM_MSB downto IM_LSB) := new_im;
  return y;
end function;

-----------------------------------------------------------------------------
-- Constructor
-----------------------------------------------------------------------------
function make_complex(re_part : std_logic_vector; im_part : std_logic_vector)
  return complex_t is
  variable y : complex_t;
begin
  assert re_part'length = PART_WIDTH
  report "flat_tensors.make_complex: re_part must be PART_WIDTH bits."
    severity failure;
  assert im_part'length = PART_WIDTH
  report "flat_tensors.make_complex: im_part must be PART_WIDTH bits."
    severity failure;
  y := re_part & im_part; -- [ REAL | IMAG ]
  return y;
end function;

-----------------------------------------------------------------------------
-- Internal helpers (signed add/sub on PART_WIDTH slices)
-----------------------------------------------------------------------------
function add_parts(a, b : std_logic_vector) return std_logic_vector is
  variable sa, sb, ss     : signed(a'range);
begin
  sa := signed(a);
  sb := signed(b);
  ss := sa + sb;
  return std_logic_vector(ss);
end function;

function sub_parts(a, b : std_logic_vector) return std_logic_vector is
  variable sa, sb, ss     : signed(a'range);
begin
  sa := signed(a);
  sb := signed(b);
  ss := sa - sb;
  return std_logic_vector(ss);
end function;

function sqrt_part(a : std_logic_vector) return std_logic_vector is

begin

end;

-----------------------------------------------------------------------------
-- Complex add / sub (component-wise)
-----------------------------------------------------------------------------
function scalar_add(a, b : complex_t) return complex_t is
  variable rr              : std_logic_vector(PART_WIDTH - 1 downto 0);
  variable ii              : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  rr := add_parts(get_re(a), get_re(b));
  ii := add_parts(get_im(a), get_im(b));
  return make_complex(rr, ii);
end function;

function scalar_sub(a, b : complex_t) return complex_t is
  variable rr              : std_logic_vector(PART_WIDTH - 1 downto 0);
  variable ii              : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  rr := sub_parts(get_re(a), get_re(b));
  ii := sub_parts(get_im(a), get_im(b));
  return make_complex(rr, ii);
end function;

function scalar_mul (a, b : complex_t) return complex_t is
  constant EXT_WIDTH        : positive := 256; -- intermediate width (truncate later)

  -- unpack parts as signed Q(PART_INT_BITS.PART_FRAC_BITS)
  variable ar, ai : signed(PART_WIDTH - 1 downto 0);
  variable br, bi : signed(PART_WIDTH - 1 downto 0);

  -- Gauss partials
  variable p1 : signed(2 * PART_WIDTH - 1 downto 0); -- ar*br
  variable p2 : signed(2 * PART_WIDTH - 1 downto 0); -- ai*bi
  variable sA : signed(PART_WIDTH downto 0); -- (ar+ai)  (one extra bit)
  variable sB : signed(PART_WIDTH downto 0); -- (br+bi)
  variable p3 : signed(2 * (PART_WIDTH + 1) - 1 downto 0); -- (ar+ai)*(br+bi)

  -- widen to 256 bits for safe add/sub, then scale and truncate
  variable p1e, p2e, p3e            : signed(EXT_WIDTH - 1 downto 0);
  variable real_ext, imag_ext       : signed(EXT_WIDTH - 1 downto 0);
  variable real_scaled, imag_scaled : signed(EXT_WIDTH - 1 downto 0);
  variable rr, ii                   : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  -- extract
  ar := signed(get_re(a));
  ai := signed(get_im(a));
  br := signed(get_re(b));
  bi := signed(get_im(b));

  -- three multiplies (Gauss)
  p1 := ar * br;
  p2 := ai * bi;
  sA := resize(ar, sA'length) + resize(ai, sA'length);
  sB := resize(br, sB'length) + resize(bi, sB'length);
  p3 := sA * sB;

  -- sign-extend to 256
  p1e := resize(p1, EXT_WIDTH);
  p2e := resize(p2, EXT_WIDTH);
  p3e := resize(p3, EXT_WIDTH);

  -- re = p1 - p2
  real_ext := p1e - p2e;

  -- im = p3 - p1 - p2
  imag_ext := p3e - p1e - p2e;

  -- product has 2*PART_FRAC_BITS fractional bits; rescale back by shifting
  real_scaled := shift_right(real_ext, PART_FRAC_BITS);
  imag_scaled := shift_right(imag_ext, PART_FRAC_BITS);

  -- truncate down to PART_WIDTH (no saturation, per request)
  rr := std_logic_vector(resize(real_scaled, PART_WIDTH));
  ii := std_logic_vector(resize(imag_scaled, PART_WIDTH));

  return make_complex(rr, ii);
end function;

function scalar_div (a, b : complex_t) return complex_t is
  constant EXT_WIDTH        : positive := 256; -- wide intermediates; we truncate later

  -- unpack inputs as signed Q(PART_INT_BITS.PART_FRAC_BITS)
  variable ar, ai : signed(PART_WIDTH - 1 downto 0);
  variable br, bi : signed(PART_WIDTH - 1 downto 0);

  -- Gauss-style numerator (3 multiplies)
  -- re_num = ac + bd
  -- im_num = (a+b)*(c-d) - ac + bd
  variable ac  : signed(2 * PART_WIDTH - 1 downto 0); -- a*c
  variable bd  : signed(2 * PART_WIDTH - 1 downto 0); -- b*d
  variable apb : signed(PART_WIDTH downto 0); -- a+b
  variable cmd : signed(PART_WIDTH downto 0); -- c-d
  variable t   : signed(2 * (PART_WIDTH + 1) - 1 downto 0); -- (a+b)*(c-d)

  -- denominator: c^2 + d^2 (2 multiplies)
  variable br2 : signed(2 * PART_WIDTH - 1 downto 0);
  variable bi2 : signed(2 * PART_WIDTH - 1 downto 0);

  -- extended to 256 bits for safe shifts/divs
  variable ac_e, bd_e, t_e    : signed(EXT_WIDTH - 1 downto 0);
  variable br2_e, bi2_e       : signed(EXT_WIDTH - 1 downto 0);
  variable re_num_e, im_num_e : signed(EXT_WIDTH - 1 downto 0);
  variable denom_e            : signed(EXT_WIDTH - 1 downto 0);

  -- scaled before division (to keep Q format)
  variable re_scaled, im_scaled : signed(EXT_WIDTH - 1 downto 0);

  -- quotient (still EXT_WIDTH, then truncated)
  variable re_q, im_q : signed(EXT_WIDTH - 1 downto 0);

  variable rr, ii : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  -- extract parts
  ar := signed(get_re(a));
  ai := signed(get_im(a));
  br := signed(get_re(b));
  bi := signed(get_im(b));

  -- three multiplies for numerator
  ac  := ar * br;
  bd  := ai * bi;
  apb := resize(ar, apb'length) + resize(ai, apb'length);
  cmd := resize(br, cmd'length) - resize(bi, cmd'length);
  t   := apb * cmd;

  -- two multiplies for denominator
  br2 := br * br;
  bi2 := bi * bi;

  -- sign-extend to 256
  ac_e  := resize(ac, EXT_WIDTH);
  bd_e  := resize(bd, EXT_WIDTH);
  t_e   := resize(t, EXT_WIDTH);
  br2_e := resize(br2, EXT_WIDTH);
  bi2_e := resize(bi2, EXT_WIDTH);

  -- numerator
  re_num_e := ac_e + bd_e;
  im_num_e := t_e - ac_e + bd_e;

  -- denominator
  denom_e := br2_e + bi2_e;

  -- rescale: both numerators and denominator are Q with 2*PART_FRAC_BITS.
  -- To get a Q(PART_FRAC_BITS) result, shift numerator left by PART_FRAC_BITS before division.
  re_scaled := shift_left(re_num_e, PART_FRAC_BITS);
  im_scaled := shift_left(im_num_e, PART_FRAC_BITS);

  -- divide (simple truncation toward zero). Guard divide-by-zero -> return 0.
  if denom_e = to_signed(0, EXT_WIDTH) then
    re_q := (others => '0');
    im_q := (others => '0');
  else
    re_q := re_scaled / denom_e;
    im_q := im_scaled / denom_e;
  end if;

  -- truncate down to PART_WIDTH (no rounding/saturation)
  rr := std_logic_vector(resize(re_q, PART_WIDTH));
  ii := std_logic_vector(resize(im_q, PART_WIDTH));

  return make_complex(rr, ii);
end function;

function scalar_conj(a : complex_t) return complex_t is
  variable re_part       : std_logic_vector(PART_WIDTH - 1 downto 0);
  variable im_neg        : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  re_part := get_re(a);
  im_neg  := std_logic_vector(-signed(get_im(a))); -- two’s complement negate
  return make_complex(re_part, im_neg);
end function;

function scalar_abs2(a : complex_t) return std_logic_vector is
  constant EXT_WIDTH     : positive := 256;

  -- unpack as signed Q(PART_INT_BITS.PART_FRAC_BITS)
  variable ar, ai : signed(PART_WIDTH - 1 downto 0);

  -- squares (non-negative but typed signed)
  variable ar2, ai2 : signed(2 * PART_WIDTH - 1 downto 0);

  -- widen for safe accumulation and rescale
  variable ar2_e, ai2_e : signed(EXT_WIDTH - 1 downto 0);
  variable sum_e        : signed(EXT_WIDTH - 1 downto 0);
  variable sum_scaled   : signed(EXT_WIDTH - 1 downto 0);

  variable res : std_logic_vector(PART_WIDTH - 1 downto 0);
begin
  -- extract parts
  ar := signed(get_re(a));
  ai := signed(get_im(a));

  -- square each part
  ar2 := ar * ar;
  ai2 := ai * ai;

  -- extend to 256 and sum
  ar2_e := resize(ar2, EXT_WIDTH);
  ai2_e := resize(ai2, EXT_WIDTH);
  sum_e := ar2_e + ai2_e; -- re^2 + im^2 in Q(2*PART_FRAC_BITS)

  -- rescale back to Q(PART_FRAC_BITS)
  sum_scaled := shift_right(sum_e, PART_FRAC_BITS);

  -- truncate to PART_WIDTH (no rounding/saturation)
  res := std_logic_vector(resize(sum_scaled, PART_WIDTH));
  return res;
end function;
function scalar_abs(a : complex_t) return std_logic_vector is
  variable ar           : signed(COMPLEX_WIDTH/2 downto 0) := signed(get_re(a));
  variable ai           : signed(COMPLEX_WIDTH/2 downto 0) := signed(get_im(a));
  variable mag          : signed(COMPLEX_WIDTH/2 downto 0) := (others => '0');
begin

  if ar < 0 then
    ar := ar * (-1);
  end if;

  if ai < 0 then
    ai := ai * (-1);
  end if;

  --PUT A sqrt(a^2+b^2) here

  return make_complex(std_logic_vector(ar), std_logic_vector(ai));
end;
----------------------------------------------------------------------------

function get_vec_num(a : vector_t; n : integer) return complex_t is
  variable complex_num : complex_t;
begin
  complex_num := a(n * COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n * COMPLEX_WIDTH);
  return complex_num;
end function;
function set_vec_num(a : vector_t; n : integer; c : complex_t) return vector_t is
  variable rvector : vector_t;
begin
  rvector                                                                   := a;
  rvector(n * COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n * COMPLEX_WIDTH) := c;
  return rvector;
end function;

function add_vec(a, b                      : vector_t) return vector_t is
  variable rvector                           : vector_t := (others => '0');
  variable r_complex_t, a_complex, b_complex : complex_t;
begin
  for n in 0 to VECTOR_WORD_WIDTH - 1 loop
    a_complex                                                                 := get_vec_num(a, n);
    b_complex                                                                 := get_vec_num(b, n);
    r_complex_t                                                               := scalar_add(a_complex, b_complex);
    rvector(n * COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n * COMPLEX_WIDTH) := r_complex_t;
  end loop;
  return rvector;
end function;

function sub_vec(a, b                      : vector_t) return vector_t is
  variable rvector                           : vector_t  := (others => '0');
  variable r_complex_t, a_complex, b_complex : complex_t := (others => '0');
begin
  for n in 0 to VECTOR_WORD_WIDTH - 1 loop
    a_complex                                                                 := get_vec_num(a, n);
    b_complex                                                                 := get_vec_num(b, n);
    r_complex_t                                                               := scalar_sub(a_complex, b_complex);
    rvector(n * COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n * COMPLEX_WIDTH) := r_complex_t;
  end loop;
  return rvector;
end function;
function make_vec(a : std_logic_vector) return vector_t is
  variable rvector    : vector_t := (others => '0');
begin
  rvector := a;
  return rvector;
end;

function vec_plus_complex (a : vector_t; b : complex_t) return vector_t is
  variable rvector : vector_t  := (others => '0');
  variable x, y    : complex_t := (others => '0');
begin
  for n in 0 to VECTOR_WORD_WIDTH - 1 loop
    x       := get_vec_num(a, n);
    y       := scalar_add(x, b);
    rvector := set_vec_num(rvector, n, y);
  end loop;
  return rvector;
end function;
function vec_minus_complex (a : vector_t; b : complex_t) return vector_t is
  variable rvector : vector_t  := (others => '0');
  variable x, y    : complex_t := (others => '0');
begin
  for n in 0 to VECTOR_WORD_WIDTH - 1 loop
    x       := get_vec_num(a, n);
    y       := scalar_sub(x, b);
    rvector := set_vec_num(rvector, n, y);
  end loop;
  return rvector;
end function;

function get_mat_num (a : matrix_t; i, j : integer) return complex_t is
  variable rcomplex : complex_t := (others => '0');
begin
  rcomplex := a((i * MATRIX_FACTOR * VECTOR_BIT_WIDTH + j * COMPLEX_WIDTH + COMPLEX_WIDTH) - 1 downto (i * MATRIX_FACTOR * VECTOR_BIT_WIDTH + (j * COMPLEX_WIDTH)));
  return rcomplex;
end function;

function set_mat_num (a : matrix_t; i, j : integer; c : complex_t) return matrix_t is
  variable buffer_matrix : matrix_t := a;
begin
  buffer_matrix((i * MATRIX_FACTOR * VECTOR_BIT_WIDTH + j * COMPLEX_WIDTH + COMPLEX_WIDTH) - 1 downto (i * MATRIX_FACTOR * VECTOR_BIT_WIDTH + (j * COMPLEX_WIDTH))) := c;
  return buffer_matrix;
end function;
end package body flat_tensors;
