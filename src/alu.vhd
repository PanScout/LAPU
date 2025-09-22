library ieee;
use ieee.std_logic_1164.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity alu is
    port (
        i_clock   : in std_logic;
        i_reset : in std_logic;

        i_a, i_b: in complex_t;
        i_av, i_bv: in vector_t;

        i_map_code: in std_logic_vector(1 downto 0);
        i_opcode: in std_logic_vector(7 downto 0);

        i_start: in std_logic;
        o_ready: out std_logic;

        o_x: out complex_t;
        o_xv: out vector_t
        
    
        
    );
end entity alu;

architecture rtl of alu is

type state_t is (S_IDLE_COMB, S_COMPUTE, S_RESULT);
signal state, next_state: state_t;

begin



state_register: process (i_clock)
begin
    if rising_edge(i_clock) then
        state <= next_state;
    end if;
end process;

next_state_logic: process(all)
begin

end process;

output_logic: process(all)
begin
end process;



comb_operations : process(all)
begin
if(state = S_IDLE_COMB) then
case i_map_code is
    when "00" =>
        case i_opcode is
            when x"00" => --example
                o_x <= scalar_add(i_a,i_b);
            when x"01" =>
            when x"02" =>
            when x"03" =>
            when others =>
                null;
        end case;
    when "01" =>
        case i_opcode is
            when x"01" =>
            when x"02" =>
            when x"03" =>
            when others =>
                null;
        end case;
    when "10" =>
        case i_opcode is
            when x"01" =>
            when x"02" =>
            when x"03" =>
            when others =>
                null;
        end case;
    when "11" =>
        case i_opcode is
            when x"01" =>
            when x"02" =>
            when x"03" =>
            when others =>
                null;
        end case;
    when others =>
        null;
end case;
end if;
end process;

fsm_operations : process(i_clock)
begin
    if rising_edge(i_clock) then
        
    end if;
end process;

end architecture;