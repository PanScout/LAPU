library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm_mealy is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;            -- synchronous, active-high

    -- inputs
    start : in  std_logic;
    ready : in  std_logic
  );
end entity;

architecture rtl of fsm_mealy is
  -- 1) State type
  type state_t is (S_IDLE, S_WAIT, S_RUN, S_DONE, S_ERROR);
  signal state, state_next : state_t;

begin

  --------------------------------------------------------------------
  -- 2) State register (sequential)
  --------------------------------------------------------------------
  p_state : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
      else
        state <= state_next;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- 3) Next-state + Mealy output logic (combinational)
  --------------------------------------------------------------------
  p_next : process(state, start, ready)
  begin
    -- safe defaults (avoid inferred latches)
    state_next <= state;
    ack        <= '0';
    load       <= '0';

    case state is
      when S_IDLE =>
        -- Mealy example: output uses inputs directly
        load <= start;                     -- assert when start='1'
        if start = '1' then
          state_next <= S_WAIT;
        end if;

      when S_WAIT =>
        ack  <= ready;                     -- assert when input says ready
        if ready = '1' then
          state_next <= S_RUN;
        end if;

      when S_RUN =>
        load <= '1';
        if ready = '0' then
          state_next <= S_DONE;
        end if;

      when S_DONE =>
        ack <= '1';
        if start = '0' then
          state_next <= S_IDLE;
        end if;

      when others =>
        -- optional safety net
        state_next <= S_IDLE;
    end case;
  end process;

end architecture;
