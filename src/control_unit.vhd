library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

library constants;
use constants.constants.all;

library fixed_pkg;
use fixed_pkg.fixed_pkg.all;

entity control_unit is
    port(
        i_clock                                                    : in  std_logic;
        i_reset                                                    : in  std_logic; -- synchronous, active-high
        o_error                                                    : out std_logic;
        -- inputs
        i_cu_start                                                 : in  std_logic;
        o_cu_done                                                  : out std_logic;
        --Instruction memory interface
        o_rom_address                                              : out std_logic_vector(31 downto 0);
        i_current_instruction                                      : in  std_logic_vector(127 downto 0);
        --Matrix Bank Interface
        o_matrix_sel                                               : out integer range 0 to 3;
        o_scalar_or_vector_action                                  : out std_logic;
        o_rw_vector                                                : out std_logic;
        o_column_or_row_order                                      : out std_logic;
        o_vector_i, o_vector_j                                     : out integer range 0 to VECTOR_SIZE - 1;
        o_vector                                                   : out vector_t;
        i_vector                                                   : in  vector_t;
        o_rw_scalar                                                : out std_logic;
        o_scalar_i, o_scalar_j                                     : out integer range 0 to VECTOR_SIZE - 1;
        o_scalar                                                   : out complex_t;
        i_scalar                                                   : in  complex_t;
        --ALU Interface
        o_a, o_b                                                   : out complex_t;
        o_av, o_bv                                                 : out vector_t;
        o_map_code                                                 : out std_logic_vector(1 downto 0);
        o_opcode                                                   : out std_logic_vector(7 downto 0);
        i_x                                                        : in  complex_t;
        i_xv                                                       : in  vector_t;
        --Register File Interface
        o_scalar_reg_sel_1, o_scalar_reg_sel_2, o_scalar_write_sel : out integer range 0 to VECTOR_SIZE - 1;
        i_scalar_reg_1, i_scalar_reg_2                             : in  complex_t;
        o_scalar_reg_input                                         : out complex_t;
        o_scalar_write_enable, o_vector_write_enable               : out std_logic;
        o_vector_reg_sel_1, o_vector_reg_sel_2, o_vector_write_sel : out integer range 0 to VECTOR_SIZE - 1;
        i_vector_reg_1, i_vector_reg_2                             : in  vector_t;
        o_vector_reg_input                                         : out vector_t
    );
end entity;

architecture rtl of control_unit is
    -- 1) State type
    type   state_t                                                                                                      is (S_IDLE, S_ADDRESS_FETCH, S_INSTRUCTION_FETCH, S_DECODE, S_REGISTER_SELECT, S_EXECUTE, S_WRITEBACK, S_ERROR, S_DONE);
    signal state, state_next                                                                                            : state_t;
    --2) Program Counter
    signal r_PC                                                                                                         : signed(31 downto 0)                := (others => '0');
    signal r_jump_flag                                                                                                  : std_logic                          := '0';
    --3) Output Registers
    signal r_current_instruction                                                                                        : std_logic_vector(127 downto 0)     := (others => '0');
    signal r_current_address, r_new_program_count                                                                       : std_logic_vector(31 downto 0)      := (others => '0');
    signal r_cu_done, r_rw_scalar, r_program_count_ready, r_column_or_row_order, r_rw_vector, r_scalar_or_vector_action : std_logic                          := '0';
    signal r_matrix_sel                                                                                                 : integer range 0 to 3               := 0;
    signal r_vector_i, r_vector_j, r_scalar_i, r_scalar_j                                                               : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_vector, r_av, r_bv                                                                                         : vector_t                           := VECTOR_ZERO;
    signal r_scalar, r_a, r_b                                                                                           : complex_t                          := COMPLEX_ZERO;
    signal r_map_code                                                                                                   : std_logic_vector(1 downto 0)       := (others => '0');
    signal r_error_flag                                                                                                 : std_logic                          := '0';
    signal r_scalar_reg_sel_1                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_scalar_reg_sel_2                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_scalar_write_sel                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_scalar_reg_input                                                                                           : complex_t                          := COMPLEX_ZERO;
    signal r_scalar_write_enable                                                                                        : std_logic                          := '0';
    signal r_vector_write_enable                                                                                        : std_logic                          := '0';
    signal r_vector_reg_sel_1                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_vector_reg_sel_2                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_vector_write_sel                                                                                           : integer range 0 to VECTOR_SIZE - 1 := 0;
    signal r_vector_reg_input                                                                                           : vector_t                           := VECTOR_ZERO; -- assuming o_vector_reg_input : out vector_t

    --4) Field Registers (Some of these are mapped to outputs though)
    signal r_opcode, r_subop  : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_flags            : std_logic_vector(15 downto 0) := (others => '0');
    signal r_function_mapping : std_logic_vector(1 downto 0)  := (others => '0');
    signal r_imm16            : std_logic_vector(15 downto 0) := (others => '0');
    signal r_imm90            : std_logic_vector(89 downto 0) := (others => '0');
    signal r_offs33           : std_logic_vector(32 downto 0) := (others => '0');

    --For some reason these are needed for proper scaling.
    subtype q32_32 is sfixed(31 downto -32);
    subtype q22_23 is sfixed(21 downto -23);

    function imm90_to_complex_t(imm90 : std_logic_vector(89 downto 0))
    return complex_t is
        variable ret    : complex_t := COMPLEX_ZERO; -- assume re/im are q32_32
        variable re_q23 : q22_23;
        variable im_q23 : q22_23;
    begin
        re_q23 := to_sfixed(imm90(44 downto 0), 21, -23); -- overload from slv
        im_q23 := to_sfixed(imm90(89 downto 45), 21, -23);

        ret.re := resize(re_q23, 31, -32);
        ret.im := resize(im_q23, 31, -32);
        return ret;
    end;

begin
    -- Gated Output Registers
    o_cu_done                 <= r_cu_done;
    o_rom_address             <= std_logic_vector(r_PC);
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
    o_opcode                  <= r_subop;
    o_map_code                <= r_map_code;
    o_a                       <= r_a;
    o_b                       <= r_b;
    o_av                      <= r_av;
    o_bv                      <= r_bv;
    o_scalar_reg_sel_1        <= r_scalar_reg_sel_1;
    o_scalar_reg_sel_2        <= r_scalar_reg_sel_2;
    o_scalar_write_sel        <= r_scalar_write_sel;
    o_scalar_reg_input        <= r_scalar_reg_input;
    o_scalar_write_enable     <= r_scalar_write_enable;
    o_vector_write_enable     <= r_vector_write_enable;
    o_vector_reg_sel_1        <= r_vector_reg_sel_1;
    o_vector_reg_sel_2        <= r_vector_reg_sel_2;
    o_vector_write_sel        <= r_vector_write_sel;
    o_vector_reg_input        <= r_vector_reg_input;
    o_error                   <= r_error_flag;

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
        variable rd, rs1, rs2     : std_logic_vector(2 downto 0)  := (others => '0');
        variable imm16            : std_logic_vector(15 downto 0) := (others => '0');
        variable imm90            : std_logic_vector(89 downto 0) := (others => '0');
        variable offs33           : std_logic_vector(32 downto 0) := (others => '0');
        variable mbid             : std_logic_vector(3 downto 0)  := (others => '0');
        variable i16, j16, len16  : std_logic_vector(15 downto 0) := (others => '0');

    begin
        if (rising_edge(i_clock)) then
            case state is
                when S_IDLE =>
                    null;
                when S_ADDRESS_FETCH =>
                    --r_current_address <= std_logic_vector(r_PC); --NOTE this is delayed one cycle for no reason, get rid of it later.
                when S_INSTRUCTION_FETCH =>
                    r_current_instruction <= i_current_instruction;
                when S_DECODE =>
                    --These fields are used for all types of instructions
                    opcode := r_current_instruction(127 downto 120);
                    subop  := r_current_instruction(119 downto 112);
                    flags  := r_current_instruction(111 downto 96);

                    r_subop  <= subop;
                    r_flags  <= flags;
                    r_opcode <= opcode;
                    case opcode is
                        when R_TYPE =>
                            rd               := r_current_instruction(95 downto 93);
                            rs1              := r_current_instruction(92 downto 90);
                            rs2              := r_current_instruction(89 downto 87);
                            imm16            := r_current_instruction(86 downto 71);
                            function_mapping := r_current_instruction(97 downto 96);

                            case function_mapping is
                                when SCALAR_TO_SCALAR =>
                                    r_scalar_reg_sel_1 <= to_integer(unsigned(rs1));
                                    r_scalar_reg_sel_2 <= to_integer(unsigned(rs2));
                                    r_scalar_write_sel <= to_integer(unsigned(rd));
                                    r_map_code         <= function_mapping;
                                when VECTOR_TO_VECTOR =>
                                    r_vector_reg_sel_1 <= to_integer(unsigned(rs1));
                                    r_vector_reg_sel_2 <= to_integer(unsigned(rs2));
                                    r_vector_write_sel <= to_integer(unsigned(rd));
                                    r_map_code         <= function_mapping;
                                when VECTOR_TO_SCALAR =>
                                    r_vector_reg_sel_1 <= to_integer(unsigned(rs1));
                                    r_vector_reg_sel_2 <= to_integer(unsigned(rs2));
                                    r_scalar_write_sel <= to_integer(unsigned(rd));
                                    r_map_code         <= function_mapping;
                                when VECTOR_SCALAR_BROADCAST =>
                                    r_vector_reg_sel_1 <= to_integer(unsigned(rs1));
                                    r_scalar_reg_sel_2 <= to_integer(unsigned(rs2));
                                    r_vector_write_sel <= to_integer(unsigned(rd));
                                    r_map_code         <= function_mapping;
                                when others =>
                                    r_error_flag <= '1';
                            end case;

                        when I_TYPE =>
                            rd    := r_current_instruction(95 downto 93);
                            rs1   := r_current_instruction(92 downto 90);
                            imm90 := r_current_instruction(89 downto 0);

                            r_scalar_write_sel <= to_integer(unsigned(rd));
                            r_scalar_reg_sel_1 <= to_integer(unsigned(rs1));
                            r_imm90            <= imm90;

                            case subop is
                                when I_CLOADI =>
                                    r_scalar_reg_input <= imm90_to_complex_t(imm90);
                                when I_CADDI =>
                                    null;
                                when I_CMULI =>
                                    null;
                                when I_CSUB =>
                                    null;
                                when I_CDIVI =>
                                    null;
                                when I_MAXABSI =>
                                    null;
                                when I_MINABSI =>
                                    null;
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when J_TYPE =>
                            offs33 := r_current_instruction(92 downto 60);
                            rs1    := r_current_instruction(95 downto 93);

                            r_scalar_reg_sel_1 <= to_integer(unsigned(rs1));
                            r_offs33           <= offs33;

                        when S_TYPE =>  
                            rd   := r_current_instruction(95 downto 93);
                            mbid  := r_current_instruction(92 downto 89);
                            i16   := r_current_instruction(88 downto 73);
                            j16   := r_current_instruction(72 downto 57);
                            len16 := r_current_instruction(56 downto 41);

                            r_matrix_sel <= to_integer(unsigned(mbid));

                            case subop is
                                when S_VLD =>
                                    r_vector_write_sel        <= to_integer(unsigned(rd));
                                    r_vector_i                <= to_integer(unsigned(i16));
                                    r_vector_j                <= to_integer(unsigned(j16));
                                    r_column_or_row_order     <= flags(15);
                                    r_scalar_or_vector_action <= '1';
                                    r_rw_vector               <= '0';
                                when S_VST =>
                                    r_vector_reg_sel_1        <= to_integer(unsigned(rd));
                                    r_vector_i                <= to_integer(unsigned(i16));
                                    r_vector_j                <= to_integer(unsigned(j16));
                                    r_column_or_row_order     <= flags(15);
                                    r_scalar_or_vector_action <= '1';
                                    r_rw_vector               <= '1';
                                when S_SLD =>
                                    r_scalar_write_sel        <= to_integer(unsigned(rd));
                                    r_scalar_i                <= to_integer(unsigned(i16));
                                    r_scalar_j                <= to_integer(unsigned(j16));
                                    r_scalar_reg_sel_1        <= to_integer(unsigned(rs1));
                                    r_scalar_or_vector_action <= '0';
                                    r_scalar_write_enable     <= '0';
                                when S_SST =>
                                    r_scalar_i                <= to_integer(unsigned(i16));
                                    r_scalar_j                <= to_integer(unsigned(j16));
                                    r_scalar_reg_sel_1        <= to_integer(unsigned(rd));
                                    r_scalar_write_enable     <= '0';
                                    r_scalar_or_vector_action <= '0';
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when others =>
                            r_error_flag <= '1';
                    end case;
                when S_REGISTER_SELECT =>
                    case r_opcode is
                        when R_TYPE =>
                            case r_map_code is
                                when SCALAR_TO_SCALAR =>
                                    r_a <= i_scalar_reg_1;
                                    r_b <= i_scalar_reg_2;
                                when VECTOR_TO_VECTOR => null;
                                    r_av <= i_vector_reg_1;
                                    r_bv <= i_vector_reg_2;
                                when VECTOR_TO_SCALAR =>
                                    r_av <= i_vector_reg_1;
                                    r_bv <= i_vector_reg_2;
                                when VECTOR_SCALAR_BROADCAST =>
                                    r_av <= i_vector_reg_1;
                                    r_b  <= i_scalar_reg_1;
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when I_TYPE =>
                            case subop is
                                when I_CLOADI =>
                                    r_scalar_write_enable <= '1';
                                when I_CADDI =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CADD;
                                when I_CMULI =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CMUL;
                                when I_CSUB =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CSUB;
                                when I_CDIVI =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CDIV;
                                when I_MAXABSI =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CDIV;
                                when I_MINABSI =>
                                    r_a      <= i_scalar_reg_1;
                                    r_b      <= imm90_to_complex_t(r_imm90);
                                    r_opcode <= R_CDIV;
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when J_TYPE =>
                            if (signed(i_scalar_reg_1.re) /= 0) then
                                r_jump_flag <= '1';
                            end if;
                        when S_TYPE =>
                          null;

                        when others => r_error_flag <= '1';
                    end case;
                when S_EXECUTE =>
                    case r_opcode is
                        when R_TYPE =>
                            case r_map_code is
                                when SCALAR_TO_SCALAR =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when VECTOR_TO_VECTOR => null;
                                    r_vector_reg_input    <= i_xv;
                                    r_vector_write_enable <= '1';
                                when VECTOR_SCALAR_BROADCAST =>
                                    r_vector_reg_input    <= i_xv;
                                    r_vector_write_enable <= '1';
                                when VECTOR_TO_SCALAR =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when others => r_error_flag <= '1';
                            end case;
                        when I_TYPE =>
                            case subop is
                                when I_CLOADI =>
                                    r_scalar_write_enable <= '0';
                                when I_CADDI =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when I_CMULI =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when I_CSUB =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when I_CDIVI =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when I_MAXABSI =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when I_MINABSI =>
                                    r_scalar_reg_input    <= i_x;
                                    r_scalar_write_enable <= '1';
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when J_TYPE =>
                            null;
                        when S_TYPE =>
                              case r_subop is
                                when S_VLD =>
                                    r_vector_reg_input    <= i_vector;
                                    r_vector_write_enable <= '1';
                                when S_VST =>
                                    r_vector <= i_vector_reg_1;
                                when S_SLD =>
                                    r_scalar_reg_input    <= i_scalar;
                                    r_scalar_write_enable <= '1';
                                    r_rw_scalar           <= '0';
                                when S_SST =>
                                    r_scalar    <= i_scalar_reg_1;
                                    r_rw_scalar <= '1';
                                when others =>
                                    r_error_flag <= '1';
                            end case;
                        when others => r_error_flag <= '1';
                    end case;

                    if (r_jump_flag = '1') then
                        r_PC <= r_PC + resize(signed(offs33), 32);
                    else
                        r_PC <= r_PC + 1;
                    end if;

                when S_WRITEBACK =>

                    r_matrix_sel              <= 0;
                    r_vector_i                <= 0;
                    r_vector_j                <= 0;
                    r_scalar_i                <= 0;
                    r_scalar_j                <= 0;
                    r_scalar_reg_sel_1        <= 0;
                    r_scalar_reg_sel_2        <= 0;
                    r_scalar_write_sel        <= 0;
                    r_vector_reg_sel_1        <= 0;
                    r_vector_reg_sel_2        <= 0;
                    r_vector_write_sel        <= 0;
                    r_jump_flag               <= '0';
                    r_cu_done                 <= '0';
                    r_rw_vector               <= '0';
                    r_column_or_row_order     <= '0';
                    r_rw_scalar               <= '0';
                    r_scalar_or_vector_action <= '0';
                    r_scalar_write_enable     <= '0';
                    r_vector_write_enable     <= '0';
                    r_error_flag              <= '0';
                    r_opcode                  <= (others => '0');
                    r_subop                   <= (others => '0');
                    r_map_code                <= (others => '0');
                    r_scalar                  <= COMPLEX_ZERO;
                    r_a                       <= COMPLEX_ZERO;
                    r_b                       <= COMPLEX_ZERO;
                    r_scalar_reg_input        <= COMPLEX_ZERO;
                    r_vector                  <= VECTOR_ZERO;
                    r_av                      <= VECTOR_ZERO;
                    r_bv                      <= VECTOR_ZERO;
                    r_vector_reg_input        <= VECTOR_ZERO;

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
    next_state_logic : process(state, r_error_flag, i_cu_start, i_reset)
        constant ZERO_OP : std_logic_vector(127 downto 0) := (others => '0');
    begin
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
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                else
                    state_next <= S_INSTRUCTION_FETCH;
                end if;
            when S_INSTRUCTION_FETCH =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                elsif i_current_instruction = ZERO_OP then
                    state_next <= S_DONE;
                else
                    state_next <= S_DECODE;
                end if;
            when S_DECODE =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                else
                    state_next <= S_REGISTER_SELECT;
                end if;
            when S_REGISTER_SELECT =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                else
                    state_next <= S_EXECUTE;
                end if;
            when S_EXECUTE =>
                if i_reset = '1' then
                    state_next <= S_IDLE;
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                else
                    state_next <= S_WRITEBACK;
                end if;
            when S_WRITEBACK =>
                if (i_reset = '1') then
                    state_next <= S_IDLE;
                else
                    state_next <= S_ADDRESS_FETCH;
                end if;
            when S_ERROR =>
                if (i_reset = '1') then
                    state_next <= S_IDLE;
                else
                    state_next <= S_ERROR;
                end if;
            when S_DONE =>
                if (i_reset = '1') then
                    state_next <= S_IDLE;
                elsif r_error_flag = '1' then
                    state_next <= S_ERROR;
                else
                    state_next <= S_DONE;
                end if;
        end case;

    end process;

end architecture;
