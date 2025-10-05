library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port(
        i_clock : in  std_logic;
        i_reset : in  std_logic;        -- synchronous, active-high
        -- inputs
        i_cu_start : in  std_logic;
        o_cu_done  : out std_logic;
        --Program Counter inteface
        i_program_count: in std_logic_vector(31 downto 0);
        o_program_counter_ready: out std_logic;
        o_new_program_count: out std_logic_vector(31 downto 0);
        o_jump_flag: out std_logic;
        --Instruction memory interface
        o_rom_addresss: out std_logic_vector(31 downto 0);
        o_rom_ready: out std_logic
    );
end entity;

architecture rtl of control_unit is
    -- 1) State type
    type   state_t           is (S_IDLE, S_FETCH, S_DECODE, S_EXECUTE, S_MEM, S_WRITEBACK, S_ERROR, S_DONE);
    signal state, state_next : state_t;

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
    -- 2) Register, for normal registers
    --------------------------------------------------------------------

    registers : process(i_clock) is
    begin
        if (rising_edge(i_clock)) then
            null;
        end if;
    end process registers;

    --------------------------------------------------------------------
    -- 3) Next-state + Mealy output logic (combinational)
    --------------------------------------------------------------------
    p_next : process(state, i_cu_start)
    begin
        -- safe defaults (avoid inferred latches)
        state_next <= state;
        case state is
            when S_IDLE =>
                if (i_cu_start = '1') then
                    state_next <= S_FETCH;
                end if;
            when S_FETCH => null;
                state_next <= S_DECODE;
            when S_DECODE => null;
                state_next <= S_EXECUTE;
            when S_EXECUTE => null;
                state_next <= S_MEM;
            when S_MEM => null;
                state_next <= S_WRITEBACK;
            when S_WRITEBACK => null;
                state_next <= S_FETCH;
            when S_ERROR => null;
                if (i_reset = '0') then
                    state_next <= S_IDLE;
                else
                    state_next <= S_ERROR;
                end if;
            when S_DONE =>
                if (i_reset = '0') then
                    state_next <= S_DONE;
                else
                    state_next <= S_IDLE;
                end if;
        end case;

    end process;

end architecture;
