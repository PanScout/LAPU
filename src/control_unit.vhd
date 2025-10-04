library tensors;
use tensors.tensors.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port(
        i_clock : in std_logic;
        i_reset : in std_logic
    );
end entity control_unit;

architecture RTL of control_unit is
    type stateType is (state0, state1, state2);
    signal state : stateType;
begin
    process(i_clock, i_reset) is
    begin
        if i_reset = '1' then
            state <= state0;
        elsif rising_edge(i_clock) then
            case state is
                when state0 =>
                    state <= state1;
                when state1 =>
                    state <= state2;
                when state2 =>
                    state <= state0;
            end case;
        end if;
    end process;
end architecture RTL;

