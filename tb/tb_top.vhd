-- tb_top.vhd — add/sub only (clean, wave-friendly)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

library fixed_pkg;
use fixed_pkg.fixed_pkg.all;

library tensors;
use tensors.tensors.all;

entity tb_top is
end entity;

architecture sim of tb_top is

  -- Tiny clock so waveform viewers always get timestamps
  signal clk : std_logic := '0';
  signal X,Y, Z : complex_t := (others => (others => '0'));
  

  -- Signals under test
begin
  -- Free-running clk (2 ns period)
  clk <= not clk after 1 ns;
   
   X <= make_complex(3.0,4.0);
   Y <= make_complex(4.0,3.0);

  -- DUT ops (pure combinational)

  stim: process
  begin
    -- Wait past t=0 so changes land at real time
    wait for 1 ns;
    Z <= X / Y;
    wait for 2 ns;
    stop;
    wait;
  end process;
end architecture sim;
