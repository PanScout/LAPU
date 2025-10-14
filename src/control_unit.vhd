library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

library constants;
use constants.constants.all;

entity control_unit is
    port(
        i_clock                   : in  std_logic;
        i_reset                   : in  std_logic; -- synchronous, active-high
        -- inputs
        i_cu_start                : in  std_logic;
        o_cu_done                 : out std_logic;
        --Program Counter inteface
        i_program_count           : in  std_logic_vector(31 downto 0);
        o_program_counter_ready   : out std_logic;
        o_new_program_count       : out std_logic_vector(31 downto 0);
        o_jump_flag               : out std_logic;
        --Instruction memory interface
        o_rom_address             : out std_logic_vector(31 downto 0);
        i_current_instruction     : in  std_logic_vector(127 downto 0);
        --Matrix Bank Interface
        o_matrix_sel              : out integer range 0 to 3;
        o_scalar_or_vector_action : out std_logic;
        o_rw_vector               : out std_logic;
        o_column_or_row_order     : out std_logic;
        o_vector_i, o_vector_j    : out integer range 0 to VECTOR_SIZE - 1;
        o_vector                  : out vector_t;
        i_vector                  : in  vector_t;
        o_rw_scalar               : out std_logic;
        o_scalar_i, o_scalar_j    : out integer range 0 to VECTOR_SIZE - 1;
        o_scalar                  : out complex_t;
        i_scalar                  : in  complex_t
    );
end entity;

architecture rtl of control_unit is
    -- 1) State type
    type   state_t                                                                                                                                is (S_IDLE, S_ADDRESS_FETCH, S_INSTRUCTION_FETCH, S_DECODE, S_EXECUTE, S_WRITEBACK, S_ERROR, S_DONE);
    signal state, state_next                                                                                                                      : state_t;
    --2) Output Registers
    signal r_current_instruction                                                                                                                  : std_logic_vector(127 downto 0)     := (others => '0');
    signal r_current_address, r_new_program_count                                                                                                 : std_logic_vector(31 downto 0)      := (others => '0');
    signal r_cu_done, r_jump_flag, r_rw_scalar, r_program_count_ready, r_column_or_row_order, r_rw_vector, r_scalar_or_vector_action : std_logic                          := '0';
    signal r_matrix_sel                                                                                                                           : integer range 0 to 3               := 0;
    signal r_vector_i, r_vector_j, r_scalar_i, r_scalar_j                                                                                         : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_vector                                                                                                                               : vector_t                           := VECTOR_ZERO;
    signal r_scalar                                                                                                                               : complex_t                          := COMPLEX_ZERO;

begin
    -- Gated Output Registers
    o_cu_done                 <= r_cu_done;
    o_jump_flag               <= r_jump_flag;
    o_new_program_count       <= r_new_program_count;
    o_program_counter_ready   <= r_program_count_ready;
    o_rom_address             <= r_current_address;
    o_matrix_sel              <= r_matrix_sel;
    o_scalar_or_vector_action <= r_scalar_or_vector_action;
    o_rw_vector               <= r_rw_vector;
    o_column_or_row_order     <= r_column_or_row_order;
    o_rw_scalar               <= r_rw_scalar;
    o_vector_i                <= r_vector_i;
    o_vector_j                <= r_vector_j;
    o_scalar_i                <= r_scalar_i;
    o_scalar_j                <= r_scalar_j;
    o_vector                  <= r_vector;
    o_scalar                  <= r_scalar;

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
        variable opcode, subop    : std_logic_vector(7 downto 0)  := (others => '0');
        variable flags            : std_logic_vector(15 downto 0) := (others => '0');
        variable function_mapping : std_logic_vector(1 downto 0)  := (others => '0');
        variable rd, rs1, rs2     : std_logic_vector(3 downto 0)  := (others => '0');
        variable imm16            : std_logic_vector(15 downto 0) := (others => '0');
    begin
        if (rising_edge(i_clock)) then
            case state is
                when S_IDLE =>
                    null;
                when S_ADDRESS_FETCH =>
                    r_current_address <= i_program_count;
                when S_INSTRUCTION_FETCH =>
                    r_current_instruction <= i_current_instruction;
                when S_DECODE =>
                    case opcode is
                        when R_TYPE => 
                            null;
                        when I_TYPE => 
                            null;
                        when J_TYPE => 
                            null;
                        when S_TYPE => 
                            null;
                        when others => null;
                    end case;
                    
                    null;
                when S_EXECUTE =>
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
    next_state_logic : process(state, i_cu_start, i_reset)
    begin
        state_next <= state;
        case state is
            when S_IDLE =>
                if (i_cu_start = '1') then
                    state_next <= S_ADDRESS_FETCH;
                else
                    state_next <= S_IDLE;
                end if;
            when S_ADDRESS_FETCH =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_INSTRUCTION_FETCH;
            when S_INSTRUCTION_FETCH =>
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
                state_next <= S_WRITEBACK;
            when S_WRITEBACK =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                end if;
                state_next <= S_ADDRESS_FETCH;
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

    -- output_logic : process(i_cu_start, i_program_count, i_current_instruction, i_vector, i_scalar, i_reset) is
    -- begin
    --     o_cu_done                 <= '0';
    --     o_jump_flag               <= '0';
    --     o_program_counter_ready   <= '0';
    --     o_rom_ready               <= '0';
    --     o_scalar_or_vector_action <= '0';
    --     o_rw_vector               <= '0';
    --     o_rw_scalar               <= '0';
    --     o_column_or_row_order     <= '0';
    --     o_matrix_sel              <= 0;
    --     o_vector_i                <= 0;
    --     o_vector_j                <= 0;
    --     o_scalar_i                <= 0;
    --     o_scalar_j                <= 0;
    --     o_new_program_count       <= (others => '0');
    --     o_rom_address             <= (others => '0');
    --     o_vector                  <= VECTOR_ZERO;
    --     o_scalar                  <= COMPLEX_ZERO;
    --     case state is
    --         when S_IDLE =>
    --             null;
    --         when S_FETCH =>
    --             o_rom_address <= i_program_count;
    --         when S_DECODE =>
    --             o_rom_address <= r_current_address;
    --             null;
    --         when S_EXECUTE =>
    --             null;
    --         when S_MEM =>
    --             null;
    --         when S_WRITEBACK =>
    --             null;
    --         when S_ERROR =>
    --             null;
    --         when S_DONE =>
    --             null;
    --     end case;
    -- end process output_logic;
end architecture;
