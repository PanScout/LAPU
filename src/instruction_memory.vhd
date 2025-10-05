library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_memory is
    generic(
        MAX_ADDRESS: positive:= 256;
        INSTRUCTION_SIZE: positive := 128
    );
    port(
        i_clock : in std_logic;
        i_rom_ready: in std_logic; --Control unit is ready for next instruction
        i_rom_address: in std_logic_vector(31 downto 0);
        o_instruction: out std_logic_vector(127 downto 0)
        

    );
end entity instruction_memory;

architecture RTL of instruction_memory is
    type mem_t is array (0 to MAX_ADDRESS-1) of std_logic_vector(INSTRUCTION_SIZE-1 downto 0);
    signal mem: mem_t := (others => (others => '0'));
begin

    name : process (i_clock) is
    begin
        if rising_edge(i_clock) and i_rom_ready = '1' and to_integer(unsigned(i_rom_address)) < MAX_ADDRESS then
            o_instruction <= mem(to_integer(unsigned(i_rom_address)));
        end if;
    end process name;
    

end architecture RTL;
