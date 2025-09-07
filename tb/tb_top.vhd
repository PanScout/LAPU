-- tb_top.vhd — add/sub only (clean, wave-friendly)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity tb_top is
end entity;

architecture sim of tb_top is
  -- Pack integer -> Q(int.frac) bitfield
  function part_from_int(n : integer) return std_logic_vector is
    variable s : signed(PART_WIDTH-1 downto 0);
  begin
    s := to_signed(n, PART_WIDTH);
    s := shift_left(s, PART_FRAC_BITS);
    return std_logic_vector(s);
  end function;

  -- Tiny clock so waveform viewers always get timestamps
  signal clk : std_logic := '0';

  -- Signals under test
  signal a_sig, b_sig   : complex_t := (others => '0');
  signal sum_sig        : complex_t := (others => '0');
  signal diff_sig       : complex_t := (others => '0');

  -- Expected components (visible in waves)
  signal exp_sum_re  : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal exp_sum_im  : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal exp_diff_re : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal exp_diff_im : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
begin
  -- Free-running clk (2 ns period)
  clk <= not clk after 1 ns;

  -- DUT ops (pure combinational)
  sum_sig  <= scalar_add(a_sig, b_sig);
  diff_sig <= scalar_sub(a_sig, b_sig);

  stim: process
  begin
    -- Wait past t=0 so changes land at real time
    wait for 2 ns;

    ----------------------------------------------------------------------------
    -- TEST 1
    -- a = 1 + 2i, b = -3 + 4i
    -- sum  = (-2 + 6i)
    -- diff = ( 4 - 2i)
    ----------------------------------------------------------------------------
    a_sig <= make_complex(part_from_int( 1), part_from_int( 2));
    b_sig <= make_complex(part_from_int(-3), part_from_int( 4));

    exp_sum_re  <= part_from_int(-2);
    exp_sum_im  <= part_from_int( 6);
    exp_diff_re <= part_from_int( 4);
    exp_diff_im <= part_from_int(-2);

    wait for 4 ns;

    assert get_re(sum_sig)  = exp_sum_re  report "T1 Mismatch: sum.re"  severity error;
    assert get_im(sum_sig)  = exp_sum_im  report "T1 Mismatch: sum.im"  severity error;
    assert get_re(diff_sig) = exp_diff_re report "T1 Mismatch: diff.re" severity error;
    assert get_im(diff_sig) = exp_diff_im report "T1 Mismatch: diff.im"  severity error;

    ----------------------------------------------------------------------------
    -- TEST 2
    -- a = 3 - 1i, b = 2 + 5i
    -- sum  = (5 + 4i)
    -- diff = (1 - 6i)
    ----------------------------------------------------------------------------
    wait for 6 ns;

    a_sig <= make_complex(part_from_int( 3), part_from_int(-1));
    b_sig <= make_complex(part_from_int( 2), part_from_int( 5));

    exp_sum_re  <= part_from_int( 5);
    exp_sum_im  <= part_from_int( 4);
    exp_diff_re <= part_from_int( 1);
    exp_diff_im <= part_from_int(-6);

    wait for 4 ns;

    assert get_re(sum_sig)  = exp_sum_re  report "T2 Mismatch: sum.re"  severity error;
    assert get_im(sum_sig)  = exp_sum_im  report "T2 Mismatch: sum.im"  severity error;
    assert get_re(diff_sig) = exp_diff_re report "T2 Mismatch: diff.re" severity error;
    assert get_im(diff_sig) = exp_diff_im report "T2 Mismatch: diff.im"  severity error;

    report "tb_top: add/sub tests passed" severity note;

    -- Keep sim alive a tad so viewers have trailing timestamps
    wait for 4 ns;
    stop;
    wait;
  end process;
end architecture sim;
