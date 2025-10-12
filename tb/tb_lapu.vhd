-- tb_top.vhd — add/sub only (clean, wave-friendly)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library fixed_pkg;
use fixed_pkg.fixed_pkg.all;

library tensors;
use tensors.tensors.all;

entity tb_lapu is
end entity;

architecture sim of tb_lapu is

  -- Tiny clock so waveform viewers always get timestamps
  signal w_clock, w_reset, w_cu_start, w_done, w_program_count_ready, w_rom_ready : std_logic                        := '0';
  signal w_jump_flag                                                              : std_logic                        := '0';
  signal w_program_count, w_new_program_count, w_rom_address                      : std_logic_vector(31 downto 0)    := (others => '0');
  signal w_instruction                                                            : std_logic_vector((127) downto 0) := (others => '0');

begin
  w_clock <= not w_clock after 1 ns;

  program_counter_inst : entity work.program_counter
    port map(
      i_clock             => w_clock,
      i_reset             => w_reset,
      i_pc_ready          => w_program_count_ready,
      o_program_count     => w_program_count,
      i_new_program_count => w_new_program_count,
      i_jump_flag         => w_jump_flag
    );

  control_unit_inst : entity work.control_unit
    port map(
      i_clock                 => w_clock,
      i_reset                 => w_reset,
      i_cu_start              => w_cu_start,
      o_cu_done               => w_done,
      i_program_count         => w_program_count,
      o_program_counter_ready => w_program_count_ready,
      o_new_program_count     => w_new_program_count,
      o_jump_flag             => w_jump_flag,
      i_current_instruction   => w_instruction
    );

  instruction_memory_inst : entity work.instruction_memory
    generic map(
      MAX_ADDRESS      => 256,
      INSTRUCTION_SIZE => 128
    )
    port map(
      i_clock       => w_clock,
      i_rom_ready   => w_rom_ready,
      i_rom_address => w_rom_address,
      o_instruction => w_instruction
    );

  stim : process
  begin
    -- Wait past t=0 so changes land at real time
    w_reset    <= '0';
    wait for 100 ns;
    w_cu_start <= '1';
    wait for 100 ns;
    stop;
    wait;
  end process;
end architecture sim;
