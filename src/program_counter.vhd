library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity program_counter is
    port(
        i_clock             : in  std_logic;
        i_reset             : in  std_logic;
        i_pc_ready             : in  std_logic;
        o_program_count     : out std_logic_vector(31 downto 0);
        i_new_program_count : in  std_logic_vector(31 downto 0);
        i_jump_flag              : in  std_logic
    );
end entity program_counter;

architecture RTL of program_counter is

    signal program_count : unsigned(31 downto 0) := (others => '0');

begin
    o_program_count <= std_logic_vector(program_count);

    pc : process(i_clock) is
    begin
        if rising_edge(i_clock) then
            if i_pc_ready = '1' and i_reset = '0' then
                if (i_jump_flag = '1') then
                    program_count <= unsigned(i_new_program_count);
                else
                    program_count <= program_count + 1;
                end if;
            elsif i_reset = '0' then
                program_count <= (others => '0');
            end if;
        end if;
    end process pc;
end architecture RTL;
