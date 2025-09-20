library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity complex_div_fsm is
  port (
    i_clock: in std_logic;
    i_rst: in std_logic;
    i_start: in std_logic;
    i_a: in complex_t;
    i_b: in complex_t;
    o_ready: in std_logic
  ) ;
end;

architecture rtl of complex_div_fsm is

type state_t is (S_IDLE, S_PARTIALS, S_FINAL, S_OUT);



begin



end architecture ; -- arch