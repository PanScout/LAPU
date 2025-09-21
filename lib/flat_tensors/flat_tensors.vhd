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
  constant COMPLEX_WIDTH  : positive := 128;  -- total width (must be even)
  constant PART_INT_BITS  : natural  := 32;   -- integer bits per part
  constant PART_FRAC_BITS : natural  := 32;   -- fractional bits per part
  constant PART_WIDTH     : positive := COMPLEX_WIDTH/2;  -- derived

  constant VECTOR_WORD_WIDTH   : positive := 8;  -- derived
  constant VECTOR_BIT_WIDTH : positive := VECTOR_WORD_WIDTH * COMPLEX_WIDTH;
  
  constant MATRIX_FACTOR: positive := 2;
  constant MATRIX_WORD_WIDTH : positive := (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * (VECTOR_WORD_WIDTH * MATRIX_FACTOR);
  constant MATRIX_BIT_WIDTH : positive := (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * (MATRIX_FACTOR * VECTOR_WORD_WIDTH) * COMPLEX_WIDTH;

  constant MATRIX_SUBVECTORS: positive := MATRIX_FACTOR;
  constant WORDS_PER_AXIS: positive := MATRIX_FACTOR * VECTOR_WORD_WIDTH;
  -----------------------------------------------------------------------------
  -- Data types
  -----------------------------------------------------------------------------
  subtype complex_t is std_logic_vector(COMPLEX_WIDTH-1 downto 0);
  subtype vector_t is std_logic_vector(VECTOR_BIT_WIDTH-1 downto 0);
  subtype matrix_t is std_logic_vector(MATRIX_BIT_WIDTH - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Complex data type functions
  -----------------------------------------------------------------------------
  function get_re(x : complex_t) return std_logic_vector;
  function get_im(x : complex_t) return std_logic_vector;
  function set_re(x : complex_t; new_re : std_logic_vector) return complex_t;
  function set_im(x : complex_t; new_im : std_logic_vector) return complex_t;
  function make_complex(re_part : std_logic_vector; im_part : std_logic_vector) return complex_t;
  function scalar_add(a, b : complex_t) return complex_t;
  function scalar_sub(a, b : complex_t) return complex_t;
  function add_parts(a, b : std_logic_vector) return std_logic_vector;
  function sub_parts(a, b : std_logic_vector) return std_logic_vector;


  -----------------------------------------------------------------------------
  -- Vector data type functions
  -----------------------------------------------------------------------------
  function get_vec_num(a : vector_t; n : integer) return complex_t;
  function set_vec_num(a : vector_t; n : integer; c: complex_t) return vector_t;
  function add_vec(a, b : vector_t) return vector_t;
  function sub_vec(a, b : vector_t) return vector_t;
  function make_vec(a : std_logic_vector) return vector_t;
  function vec_plus_complex(a: vector_t; b: complex_t) return vector_t;
  function vec_minus_complex(a: vector_t; b: complex_t) return vector_t;

  -----------------------------------------------------------------------------
  -- Matrix data type functions
  -----------------------------------------------------------------------------
  function get_mat_num(a: matrix_t; i,j: integer) return complex_t;
  function set_mat_num(a: matrix_t; i,j: integer; c: complex_t) return matrix_t;



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

  -- In GHDL, null-parameter function call is written without parentheses.
  constant CONFIG_CHECK_PASSED : boolean := config_ok;

  -----------------------------------------------------------------------------
  -- Bitfield indices
  -----------------------------------------------------------------------------
  constant RE_MSB : natural := COMPLEX_WIDTH-1;
  constant RE_LSB : natural := PART_WIDTH;
  constant IM_MSB : natural := PART_WIDTH-1;
  constant IM_LSB : natural := 0;

  -----------------------------------------------------------------------------
  -- Accessors (read)
  -----------------------------------------------------------------------------
  function get_re(x : complex_t) return std_logic_vector is
    variable r : std_logic_vector(PART_WIDTH-1 downto 0);
  begin
    r := x(RE_MSB downto RE_LSB);
    return r;
  end function;

  function get_im(x : complex_t) return std_logic_vector is
    variable r : std_logic_vector(PART_WIDTH-1 downto 0);
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
    y := re_part & im_part;  -- [ REAL | IMAG ]
    return y;
  end function;

  -----------------------------------------------------------------------------
  -- Internal helpers (signed add/sub on PART_WIDTH slices)
  -----------------------------------------------------------------------------
  function add_parts(a, b : std_logic_vector) return std_logic_vector is
    variable sa, sb, ss : signed(a'range);
  begin
    sa := signed(a);
    sb := signed(b);
    ss := sa + sb;
    return std_logic_vector(ss);
  end function;

  function sub_parts(a, b : std_logic_vector) return std_logic_vector is
    variable sa, sb, ss : signed(a'range);
  begin
    sa := signed(a);
    sb := signed(b);
    ss := sa - sb;
    return std_logic_vector(ss);
  end function;

  -----------------------------------------------------------------------------
  -- Complex add / sub (component-wise)
  -----------------------------------------------------------------------------
  function scalar_add(a, b : complex_t) return complex_t is
    variable rr : std_logic_vector(PART_WIDTH-1 downto 0);
    variable ii : std_logic_vector(PART_WIDTH-1 downto 0);
  begin
    rr := add_parts(get_re(a), get_re(b));
    ii := add_parts(get_im(a), get_im(b));
    return make_complex(rr, ii);
  end function;

  function scalar_sub(a, b : complex_t) return complex_t is
    variable rr : std_logic_vector(PART_WIDTH-1 downto 0);
    variable ii : std_logic_vector(PART_WIDTH-1 downto 0);
  begin
    rr := sub_parts(get_re(a), get_re(b));
    ii := sub_parts(get_im(a), get_im(b));
    return make_complex(rr, ii);
  end function;

    ----------------------------------------------------------------------------

  function get_vec_num(a : vector_t; n : integer) return complex_t is
    variable complex_num: complex_t;
  begin
     complex_num := a(n*COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n*COMPLEX_WIDTH);
     return complex_num; 
  end function;


  function set_vec_num(a : vector_t; n : integer; c: complex_t) return vector_t is
    variable rvector: vector_t;
  begin
    rvector := a;
    rvector(n*COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n*COMPLEX_WIDTH) := c;
    return rvector;
  end function;

  function add_vec(a, b : vector_t ) return vector_t is
    variable rvector: vector_t := (others => '0');
    variable r_complex_t, a_complex, b_complex : complex_t;
  begin
    for n in 0 to VECTOR_WORD_WIDTH - 1 loop
      a_complex := get_vec_num(a, n);
      b_complex := get_vec_num(b, n);
      r_complex_t := scalar_add(a_complex, b_complex);
      rvector(n*COMPLEX_WIDTH + (COMPLEX_WIDTH -1) downto n*COMPLEX_WIDTH) := r_complex_t;
    end loop;
    return rvector;
  end function;

  function sub_vec(a, b : vector_t ) return vector_t is
    variable rvector: vector_t := (others => '0');
    variable r_complex_t, a_complex, b_complex : complex_t := (others => '0');
  begin
    for n in 0 to VECTOR_WORD_WIDTH - 1 loop
      a_complex := get_vec_num(a, n);
      b_complex := get_vec_num(b, n);
      r_complex_t := scalar_sub(a_complex, b_complex);
      rvector(n*COMPLEX_WIDTH + (COMPLEX_WIDTH - 1) downto n*COMPLEX_WIDTH) := r_complex_t;
    end loop;
    return rvector;
  end function;


  function make_vec(a: std_logic_vector) return vector_t is 
      variable rvector: vector_t := (others => '0');
  begin
    rvector := a;
    return rvector;
  end;

  function vec_plus_complex (a: vector_t; b: complex_t) return vector_t is
    variable rvector: vector_t := (others => '0');
    variable x,y: complex_t := (others => '0');
  begin
    for n in 0 to VECTOR_WORD_WIDTH -1  loop
      x := get_vec_num(a, n);
      y := scalar_add(x, b);
      rvector := set_vec_num(rvector, n, y);
    end loop;
   return rvector; 
  end function;


  function vec_minus_complex (a: vector_t; b: complex_t) return vector_t is
    variable rvector: vector_t := (others => '0');
    variable x,y: complex_t := (others => '0');
  begin
    for n in 0 to VECTOR_WORD_WIDTH -1  loop
      x := get_vec_num(a, n);
      y := scalar_sub(x, b);
      rvector := set_vec_num(rvector, n, y);
    end loop;
   return rvector; 
  end function;

  function get_mat_num (a: matrix_t; i,j: integer) return complex_t is
    variable rcomplex: complex_t := (others => '0');
  begin
    rcomplex := a( (i*MATRIX_FACTOR*VECTOR_BIT_WIDTH + j*COMPLEX_WIDTH  + COMPLEX_WIDTH) - 1 downto (i*MATRIX_FACTOR*VECTOR_BIT_WIDTH + (j*COMPLEX_WIDTH)));
    return rcomplex;
  end function;

  function set_mat_num (a: matrix_t; i,j: integer; c: complex_t) return matrix_t is
    variable buffer_matrix: matrix_t := a;
  begin
    buffer_matrix( (i*MATRIX_FACTOR*VECTOR_BIT_WIDTH + j*COMPLEX_WIDTH  + COMPLEX_WIDTH) - 1 downto (i*MATRIX_FACTOR*VECTOR_BIT_WIDTH + (j*COMPLEX_WIDTH))) := c;
    return buffer_matrix;
  end function;


end package body flat_tensors;
