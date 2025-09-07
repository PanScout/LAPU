-- tb_complex_mul.vhd (fixed: clocked handshakes, watchdog)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity tb_complex_mul is
end entity;

architecture sim of tb_complex_mul is
  -----------------------------------------------------------------------------
  -- Helpers
  -----------------------------------------------------------------------------
  function part_from_int(n : integer) return std_logic_vector is
    variable s : signed(PART_WIDTH-1 downto 0);
  begin
    s := to_signed(n, PART_WIDTH);
    s := shift_left(s, PART_FRAC_BITS);
    return std_logic_vector(s);
  end function;

  -- Local fixed-point multiply: (a*b)>>FRAC, truncate
  function fx_mul_trunc_q(a, b : std_logic_vector) return std_logic_vector is
    variable sa         : signed(PART_WIDTH-1 downto 0);
    variable sb         : signed(PART_WIDTH-1 downto 0);
    variable prod_full  : signed((2*PART_WIDTH)-1 downto 0);
    variable prod_shift : signed((2*PART_WIDTH)-1 downto 0);
  begin
    sa := signed(a);
    sb := signed(b);
    prod_full  := sa * sb;  -- W×W -> 2W
    prod_shift := shift_right(prod_full, PART_FRAC_BITS);
    return std_logic_vector(resize(prod_shift, PART_WIDTH));
  end function;

  -- Bit-exact reference complex multiply (4 multiplies)
  function ref_complex_mul(a, b : complex_t) return complex_t is
    variable ar, ai : std_logic_vector(PART_WIDTH-1 downto 0);
    variable br, bi : std_logic_vector(PART_WIDTH-1 downto 0);
    variable ac, bd, ad, bc : std_logic_vector(PART_WIDTH-1 downto 0);
    variable rr, ii : std_logic_vector(PART_WIDTH-1 downto 0);
  begin
    ar := get_re(a);  ai := get_im(a);
    br := get_re(b);  bi := get_im(b);

    ac := fx_mul_trunc_q(ar, br);
    bd := fx_mul_trunc_q(ai, bi);
    ad := fx_mul_trunc_q(ar, bi);
    bc := fx_mul_trunc_q(ai, br);

    rr := sub_parts(ac, bd);
    ii := add_parts(ad, bc);
    return make_complex(rr, ii);
  end function;

  -----------------------------------------------------------------------------
  -- DUT I/O
  -----------------------------------------------------------------------------
  signal i_clk   : std_logic := '0';
  signal i_rst   : std_logic := '0';
  signal i_start : std_logic := '0';
  signal i_a     : complex_t := (others => '0');
  signal i_b     : complex_t := (others => '0');
  signal o_ready : std_logic;
  signal o_valid : std_logic;
  signal o_y     : complex_t;

  -- For waves
  signal exp_y       : complex_t := (others => '0');
  signal exp_re_bits : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal exp_im_bits : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
begin
  -----------------------------------------------------------------------------
  -- Clock (2 ns period)
  -----------------------------------------------------------------------------
  i_clk <= not i_clk after 1 ns;

  -----------------------------------------------------------------------------
  -- DUT instance
  -----------------------------------------------------------------------------
  dut: entity work.complex_mul_fsm
    port map (
      i_clk   => i_clk,
      i_rst   => i_rst,
      i_start => i_start,
      i_a     => i_a,
      i_b     => i_b,
      o_ready => o_ready,
      o_valid => o_valid,
      o_y     => o_y
    );

  -----------------------------------------------------------------------------
  -- Stimulus
  -----------------------------------------------------------------------------
  stim: process
    -- Clocked wait for o_ready=1 (don’t hang if it’s already 1)
    procedure wait_ready is
    begin
      -- Sample on rising edges until ready is high
      while o_ready = '0' loop
        wait until rising_edge(i_clk);
      end loop;
    end procedure;

    -- Clocked wait for a single-cycle o_valid pulse, with watchdog
    procedure wait_valid_with_timeout(constant max_cycles : in natural := 50) is
      variable cnt : natural := 0;
    begin
      loop
        wait until rising_edge(i_clk);
        if o_valid = '1' then
          exit;
        end if;
        cnt := cnt + 1;
        if cnt > max_cycles then
          assert false report "Timeout waiting for o_valid" severity failure;
          exit;
        end if;
      end loop;
    end procedure;

    -- Drive one test, check against reference
    procedure do_case(
      constant name        : in string;
      constant a_re_int    : in integer;
      constant a_im_int    : in integer;
      constant b_re_int    : in integer;
      constant b_im_int    : in integer
    ) is
      variable a_loc, b_loc : complex_t;
      variable y_ref        : complex_t;
    begin
      a_loc := make_complex(part_from_int(a_re_int), part_from_int(a_im_int));
      b_loc := make_complex(part_from_int(b_re_int), part_from_int(b_im_int));
      y_ref := ref_complex_mul(a_loc, b_loc);

      -- Present inputs when ready (clocked)
      wait_ready;
      i_a   <= a_loc;
      i_b   <= b_loc;
      exp_y <= y_ref;
      exp_re_bits <= get_re(y_ref);
      exp_im_bits <= get_im(y_ref);

      -- Pulse start for exactly one cycle
      i_start <= '1';
      wait until rising_edge(i_clk);
      i_start <= '0';

      -- Wait for valid (robust to 1-cycle pulse)
      wait_valid_with_timeout(50);

      -- Check result
      assert get_re(o_y) = get_re(y_ref)
        report "Mismatch (RE) in " & name severity error;
      assert get_im(o_y) = get_im(y_ref)
        report "Mismatch (IM) in " & name severity error;

      report "PASS: " & name severity note;

      -- One spacer cycle for tidy waves
      wait until rising_edge(i_clk);
    end procedure;

  begin
    -- Synchronous reset for a few cycles
    i_rst <= '1';
    i_start <= '0';
    wait until rising_edge(i_clk);
    wait until rising_edge(i_clk);
    wait until rising_edge(i_clk);
    i_rst <= '0';

    -- Tests
    do_case("T1: (1+2i)*(-3+4i)",   1,  2,  -3,  4);  -- -> (-11 - 2i)
    do_case("T2: (3-1i)*(2+5i)",    3, -1,   2,  5);  -- -> (11 + 13i)
    do_case("T3: (0+0i)*(7-8i)",    0,  0,   7, -8);  -- -> (0 + 0i)
    do_case("T4: (-1-1i)*(-1-1i)", -1, -1,  -1, -1);  -- -> (0 + 2i)

    report "tb_complex_mul: all tests passed" severity note;

    -- Give the wave dump a tail and end
    wait for 6 ns;
    stop;
    wait;
  end process;

end architecture sim;
