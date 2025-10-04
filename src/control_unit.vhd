library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_mealy is
    port(
        i_clk   : in  std_logic;
        i_rst   : in  std_logic;        -- synchronous, active-high
        -- inputs
        i_start : in  std_logic;
        o_done  : out std_logic;
    );
end entity;

architecture rtl of fsm_mealy is
    -- 1) State type
    type   state_t           is (S_IDLE, S_FETCH, S_DECODE, S_EXECUTE, S_MEM, S_WRITEBACK, S_ERROR, S_DONE);
    signal state, state_next : state_t;

begin

    --------------------------------------------------------------------
    -- 2) State register (sequential)
    --------------------------------------------------------------------
    p_state : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state <= S_IDLE;
            else
                state <= state_next;
            end if;
        end if;
    end process;

    registers : process is
    begin
        if(rising_edge(i_clk)) then
            null;
        end if;
    end process registers;
    

    --------------------------------------------------------------------
    -- 3) Next-state + Mealy output logic (combinational)
    --------------------------------------------------------------------
    p_next : process(state, i_start)
    begin
        -- safe defaults (avoid inferred latches)
        state_next <= state;
        case state is
            when S_IDLE      => null;
            when S_FETCH     => null;
            when S_DECODE    => null;
            when S_EXECUTE   => null;
            when S_MEM       => null;
            when S_WRITEBACK => null;
            when S_ERROR     => null;
            when S_DONE      => null;
            when others      => null;
        end case;

    end process;

end architecture;
