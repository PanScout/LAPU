library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

library tensors;
use tensors.tensors.all;

library std;
use std.env.all;
entity tb_lapu is
end entity;

architecture sim of tb_lapu is

  signal stop_sim : std_logic := '0';

  signal w_clock, w_reset, w_cu_start, w_done, w_program_count_ready, w_rom_ready, w_scalar_or_vector_action, w_rw_vector, w_column_or_row_order, w_rw_scalar : std_logic                            := '0';
  signal w_jump_flag                                                                                                                                          : std_logic                            := '0';
  signal w_program_count, w_new_program_count, w_rom_address                                                                                                  : std_logic_vector(31 downto 0)        := (others => '0');
  signal w_instruction                                                                                                                                        : std_logic_vector((127) downto 0)     := (others => '0');
  signal w_matrix_sel                                                                                                                                         : integer range 0 to 3                 := 0;
  signal w_vector_i, w_vector_j, w_scalar_i, w_scalar_j                                                                                                       : integer range 0 to (VECTOR_SIZE - 1) := 0;
  signal w_in_vector, w_out_vector, w_av, w_bv, w_xv                                                                                                          : vector_t                             := VECTOR_ZERO;
  signal w_in_scalar, w_out_scalar, w_a, w_b, w_x                                                                                                             : complex_t                            := COMPLEX_ZERO;
  signal w_map_code                                                                                                                                           : std_logic_vector(1 downto 0)         := (others => '0');
  signal w_opcode                                                                                                                                             : std_logic_vector(7 downto 0)         := (others => '0');
  signal w_scalar_reg_sel_1, w_scalar_reg_sel_2, w_scalar_write_sel, w_vector_reg_sel_1, w_vector_reg_sel_2, w_vector_write_sel                               : integer range 0 to 7                 := 0;
  signal w_scalar_reg_1, w_scalar_reg_2, w_scalar_reg_input                                                                                                   : complex_t                            := COMPLEX_ZERO;
  signal w_scalar_write_enable, w_vector_write_enable                                                                                                         : std_logic                            := '0';
  signal w_vector_reg_1, w_vector_reg_2, w_vector_reg_input                                                                                                   : vector_t                             := VECTOR_ZERO;

begin

  w_clock <= not w_clock after 1 ns;

  register_file_inst : entity work.register_file
    port map(
      i_clock               => w_clock,
      i_reset               => w_reset,
      i_scalar_reg_sel_1    => w_scalar_reg_sel_1,
      i_scalar_reg_sel_2    => w_scalar_reg_sel_2,
      o_scalar_reg_1        => w_scalar_reg_1,
      o_scalar_reg_2        => w_scalar_reg_2,
      i_scalar_reg_input    => w_scalar_reg_input,
      i_scalar_write_sel    => w_scalar_write_sel,
      i_scalar_write_enable => w_scalar_write_enable,
      i_vector_reg_sel_1    => w_vector_reg_sel_1,
      i_vector_reg_sel_2    => w_vector_reg_sel_2,
      o_vector_reg_1        => w_vector_reg_1,
      o_vector_reg_2        => w_vector_reg_2,
      i_vector_reg_input    => w_vector_reg_input,
      i_vector_write_sel    => w_vector_write_sel,
      i_vector_write_enable => w_vector_write_enable
    );

  alu_inst : entity work.alu
    port map(
      i_a        => w_a,
      i_b        => w_b,
      i_av       => w_av,
      i_bv       => w_bv,
      i_map_code => w_map_code,
      i_opcode   => w_opcode,
      o_x        => w_x,
      o_xv       => w_xv
    );

  control_unit_inst : entity work.control_unit
    port map(
      i_clock                   => w_clock,
      i_reset                   => w_reset,
      i_cu_start                => w_cu_start,
      o_cu_done                 => w_done,
      o_rom_address             => w_rom_address,
      i_current_instruction     => w_instruction,
      o_matrix_sel              => w_matrix_sel,
      o_scalar_or_vector_action => w_scalar_or_vector_action,
      o_rw_vector               => w_rw_vector,
      o_column_or_row_order     => w_column_or_row_order,
      o_vector_i                => w_vector_i,
      o_vector_j                => w_vector_j,
      o_vector                  => w_out_vector,
      i_vector                  => w_in_vector,
      o_rw_scalar               => w_rw_scalar,
      o_scalar_i                => w_scalar_i,
      o_scalar_j                => w_scalar_j,
      o_scalar                  => w_out_scalar,
      i_scalar                  => w_in_scalar,
      o_a                       => w_a,
      o_b                       => w_b,
      o_av                      => w_av,
      o_bv                      => w_bv,
      o_map_code                => w_map_code,
      o_opcode                  => w_opcode,
      i_x                       => w_x,
      i_xv                      => w_xv,
      o_scalar_reg_sel_1        => w_scalar_reg_sel_1,
      o_scalar_reg_sel_2        => w_scalar_reg_sel_2,
      o_scalar_write_sel        => w_scalar_write_sel,
      i_scalar_reg_1            => w_scalar_reg_1,
      i_scalar_reg_2            => w_scalar_reg_2,
      o_scalar_reg_input        => w_scalar_reg_input,
      o_scalar_write_enable     => w_scalar_write_enable,
      o_vector_write_enable     => w_vector_write_enable,
      o_vector_reg_sel_1        => w_vector_reg_sel_1,
      o_vector_reg_sel_2        => w_vector_reg_sel_2,
      o_vector_write_sel        => w_vector_write_sel,
      i_vector_reg_1            => w_vector_reg_1,
      i_vector_reg_2            => w_vector_reg_2,
      o_vector_reg_input        => w_vector_reg_input
    );

  instruction_memory_inst : entity work.instruction_memory
    generic map(
      MAX_ADDRESS      => 256,
      INSTRUCTION_SIZE => 128
    )
    port map(
      i_clock       => w_clock,
      i_rom_address => w_rom_address,
      o_instruction => w_instruction
    );

  matrix_bank_inst : entity work.matrix_bank
    port map(
      i_clock                   => w_clock,
      i_reset                   => w_reset,
      i_matrix_sel              => w_matrix_sel,
      i_scalar_or_vector_action => w_scalar_or_vector_action,
      i_rw_vector               => w_rw_vector,
      i_column_or_row_order     => w_column_or_row_order,
      i_vector_i                => w_vector_i,
      i_vector_j                => w_vector_j,
      i_vector                  => w_out_vector,
      o_vector                  => w_in_vector,
      i_rw_scalar               => w_rw_scalar,
      i_scalar_i                => w_scalar_i,
      i_scalar_j                => w_scalar_j,
      i_scalar                  => w_out_scalar,
      o_scalar                  => w_in_scalar
    );
  stim : process
  begin
    -- Wait past t=0 so changes land at real time
    w_reset    <= '0';
    w_cu_start <= '1';
    stop_sim   <= '1';
    wait for 1000 ns;
  end process;
end architecture sim;
