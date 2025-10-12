library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity instruction_memory is
    generic(
        MAX_ADDRESS      : positive := 256;
        INSTRUCTION_SIZE : positive := 128
    );
    port(
        i_clock       : in  std_logic;
        i_rom_ready   : in  std_logic;
        i_rom_address : in  std_logic_vector(31 downto 0);
        o_instruction : out std_logic_vector(INSTRUCTION_SIZE - 1 downto 0)
    );
end entity;

architecture RTL of instruction_memory is
    subtype word_t is std_logic_vector(INSTRUCTION_SIZE - 1 downto 0);
    type    mem_t  is array (0 to MAX_ADDRESS - 1) of word_t;

    impure function init_rom_hex(fname : string) return mem_t is
        file     f   : text open read_mode is fname;
        variable l   : line;
        variable tmp : word_t;
        variable ram : mem_t   := (others => (others => '0'));
        variable i   : integer := 0;
    begin
        while not endfile(f) and i < ram'length loop
            readline(f, l);
            if l'length > 0 then
                hread(l, tmp);          -- read one 128-bit word in hex from the line
                ram(i) := tmp;
                i      := i + 1;
            end if;
        end loop;
        return ram;
    end function;

    signal mem : mem_t := init_rom_hex("prog.hex");
begin
    process(i_clock) is
    begin
        if rising_edge(i_clock) and i_rom_ready = '1' and to_integer(unsigned(i_rom_address)) < MAX_ADDRESS then
            o_instruction <= mem(to_integer(unsigned(i_rom_address)));
        end if;
    end process;
end architecture;
