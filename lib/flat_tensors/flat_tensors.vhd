-- flat_tensors.vhd
-- VHDL-2008
-- Flat complex scalar as a single std_logic_vector.
-- Upper half = real (two’s complement Q format), lower half = imag.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package flat_tensors is
  -----------------------------------------------------------------------------
  -- Configuration (NOW bound in the spec; edit here to reconfigure)
  -----------------------------------------------------------------------------
  constant COMPLEX_WIDTH  : positive := 128;  -- total width (must be even)
  constant PART_INT_BITS  : natural  := 32;   -- integer bits per part
  constant PART_FRAC_BITS : natural  := 32;   -- fractional bits per part
  constant PART_WIDTH     : positive := COMPLEX_WIDTH/2;  -- derived

  -----------------------------------------------------------------------------
  -- Public flat type: [ REAL | IMAG ], each PART_WIDTH bits, two's complement
  -----------------------------------------------------------------------------
  subtype complex_t is std_logic_vector(COMPLEX_WIDTH-1 downto 0);

  -----------------------------------------------------------------------------
  -- Accessors (read): raw PART_WIDTH-wide two's-complement bitfields
  -----------------------------------------------------------------------------
  function get_re(x : complex_t) return std_logic_vector;
  function get_im(x : complex_t) return std_logic_vector;

  -----------------------------------------------------------------------------
  -- Accessors (write): return x with updated field
  -----------------------------------------------------------------------------
  function set_re(x : complex_t; new_re : std_logic_vector) return complex_t;
  function set_im(x : complex_t; new_im : std_logic_vector) return complex_t;

  -----------------------------------------------------------------------------
  -- Constructor from raw parts
  -----------------------------------------------------------------------------
  function make_complex(re_part : std_logic_vector; im_part : std_logic_vector)
    return complex_t;

  -----------------------------------------------------------------------------
  -- Arithmetic (same Q-format on both operands)
  -----------------------------------------------------------------------------
  function scalar_add(a, b : complex_t) return complex_t;
  function scalar_sub(a, b : complex_t) return complex_t;

  -----------------------------------------------------------------------------
  -- Public scalar helpers (PART_WIDTH-wide, two's complement)
  -----------------------------------------------------------------------------
  function add_parts(a, b : std_logic_vector) return std_logic_vector;
  function sub_parts(a, b : std_logic_vector) return std_logic_vector;



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



end package body flat_tensors;
