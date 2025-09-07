-- tb_top_signals.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.stop;

library linear_flat;
use linear_flat.linear_flat.all;

entity tb_top is end entity;
architecture sim of tb_top is
  signal a, b, r : fx64_s;
  -- Q31.32 hex constants
  constant FX_1P5   : fx64_s := fx_from_slv(x"0000000180000000");
  constant FX_N1P5  : fx64_s := fx_from_slv(x"FFFFFFFE80000000");
  constant FX_N2P25 : fx64_s := fx_from_slv(x"FFFFFFFDC0000000");
  constant FX_ZERO  : fx64_s := to_signed(0, FX_W);
begin
  -- simple “DUT” signals you can see in waves
  process
  begin
    a <= FX_1P5; b <= FX_N1P5;
    wait for 5 ns;
    r <= fx_add(a, b);                 -- visible transition
    wait for 5 ns;
    assert r = FX_ZERO report "add failed" severity error;

    r <= fx_mul(FX_1P5, FX_N1P5);      -- visible transition
    wait for 5 ns;
    --assert r = FX_N2P25 report "mul failed" severity error;

    report "done" severity note;
    wait for 5 ns;                     -- let the last value land in the dump
    stop;
  end process;
end architecture;
