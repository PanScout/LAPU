-- tb_top.vhd — add/sub only (clean, wave-friendly)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library fixed_pkg;
use fixed_pkg.fixed_pkg.all;

library tensors;
use tensors.tensors.all;

entity tb_top is
end entity;

architecture sim of tb_top is

  -- Tiny clock so waveform viewers always get timestamps
  signal clk                    : std_logic                    := '0';
  signal X, Y, Z, i_a, i_b, o_x : complex_t                    := (others => (others => '0'));
  signal i_av, i_bv, o_xv       : vector_t                     := (others => ((others => (others => '0'))));
  signal i_map_code             : std_logic_vector(1 downto 0) := "00";
  signal i_opcode               : std_logic_vector(7 downto 0) := ((others => '0'));
  -- Signals under test
begin
  -- Free-running clk (2 ns period)
  clk <= not clk after 1 ns;

  -- DUT ops (pure combinational)
  alu_inst : entity work.alu
    port map(
      i_a        => i_a,
      i_b        => i_b,
      i_av       => i_av,
      i_bv       => i_bv,
      i_map_code => i_map_code,
      i_opcode   => i_opcode,
      o_x        => o_x,
      o_xv       => o_xv
    );

  stim : process
  begin
    -- Wait past t=0 so changes land at real time
    wait for 2 ns;
    i_a        <= make_complex(-3.0, -4.0);
    i_b        <= make_complex(4.0, 3.0);
    i_opcode   <= x"03";
    i_map_code <= "00";
    wait for 2 ns;
    i_map_code <= "01";
    i_opcode  <= x"00";
    i_av       <= make_vector(
      make_complex(1, 1),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2));

    i_bv       <= make_vector(
      make_complex(1, 1),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2),
      make_complex(2, 2));
    wait for 2 ns;
    stop;
    wait;
  end process;
end architecture sim;
