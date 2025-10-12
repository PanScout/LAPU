library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port(
        i_clock                 : in  std_logic;
        i_reset                 : in  std_logic; -- synchronous, active-high
        -- inputs
        i_cu_start              : in  std_logic;
        o_cu_done               : out std_logic;
        --Program Counter inteface
        i_program_count         : in  std_logic_vector(31 downto 0);
        o_program_counter_ready : out std_logic;
        o_new_program_count     : out std_logic_vector(31 downto 0);
        o_jump_flag             : out std_logic;
        --Instruction memory interface
        o_rom_addresss          : out std_logic_vector(31 downto 0);
        i_current_instruction   : in  std_logic_vector(127 downto 0);
        o_rom_ready             : out std_logic
    );
end entity;

architecture rtl of control_unit is
    -- 1) State type
    type   state_t               is (S_IDLE, S_FETCH, S_DECODE, S_EXECUTE, S_MEM, S_WRITEBACK, S_ERROR, S_DONE);
    signal state, state_next     : state_t;
    signal r_current_instruction : std_logic_vector(127 downto 0);
    signal r_current_address : std_logic_vector(31 downto 0);

begin

    --------------------------------------------------------------------
    -- 2) State register, advances to next state and determines if reset is needed
    --------------------------------------------------------------------
    p_state : process(i_clock)
    begin
        if rising_edge(i_clock) then
            if i_reset = '1' then
                state <= S_IDLE;
            else
                state <= state_next;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- 2) Register, for normal registers and clocked behavior
    --------------------------------------------------------------------

    registers : process(i_clock) is
    begin
        if (rising_edge(i_clock)) then
            case state is
                when S_IDLE =>
                    null;
                when S_FETCH =>
                    r_current_address <= i_program_count;
                when S_DECODE =>
                    r_current_instruction <= i_current_instruction;
                    null;
                when S_EXECUTE =>
                    null;
                when S_MEM =>
                    null;
                when S_WRITEBACK =>
                    null;
                when S_ERROR =>
                    null;
                when S_DONE =>
                    null;
            end case;
        end if;
    end process registers;

    --------------------------------------------------------------------
    -- 3) Next-state 
    --------------------------------------------------------------------
    next_state_logic: process(state, i_cu_start, i_reset)
    begin
        state_next <= state;
        case state is
            when S_IDLE =>
                if (i_cu_start = '1') then
                    state_next <= S_FETCH;
                else
                    state_next <= S_IDLE;
                end if;
            when S_FETCH =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_DECODE;
            when S_DECODE =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_EXECUTE;
            when S_EXECUTE =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_MEM;
            when S_MEM =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_WRITEBACK;
            when S_WRITEBACK =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_FETCH;
            when S_ERROR =>
                if (i_reset = '0') then
                    state_next <= S_IDLE;
                else
                    state_next <= S_ERROR;
                end if;
            when S_DONE =>
                if (i_reset = '0') then
                    state_next <= S_IDLE;
                else
                    state_next <= S_DONE;
                end if;
        end case;

    end process;

    output_logic: process is
    begin
        o_cu_done <= '0';
        o_jump_flag <= '0';
        o_new_program_count <= (others => '0');
        o_program_counter_ready <= '0';
        o_rom_addresss <= (others => '0');
        o_rom_ready <= '0';
        case state is
            when S_IDLE =>
                null;
            when S_FETCH =>
                o_rom_addresss <= i_program_count;
            when S_DECODE =>
                o_rom_addresss <= r_current_address;
                null;
            when S_EXECUTE =>
                null;
            when S_MEM =>
                null;
            when S_WRITEBACK =>
                null;
            when S_ERROR =>
                null;
            when S_DONE =>
                null;
        end case;
    end process output_logic;
    

end architecture;
