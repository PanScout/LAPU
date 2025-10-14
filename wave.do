onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label i_clock /tb_lapu/instruction_memory_inst/i_clock
add wave -noupdate -divider {Instruction Memory}
add wave -noupdate -label i_rom_address -radix unsigned /tb_lapu/instruction_memory_inst/i_rom_address
add wave -noupdate -label o_instruction -radix hexadecimal /tb_lapu/instruction_memory_inst/o_instruction
add wave -noupdate -divider {Program Counter}
add wave -noupdate -label i_reset /tb_lapu/program_counter_inst/i_reset
add wave -noupdate -label i_pc_ready /tb_lapu/program_counter_inst/i_pc_ready
add wave -noupdate -label o_program_count /tb_lapu/program_counter_inst/o_program_count
add wave -noupdate -label i_new_program_count /tb_lapu/program_counter_inst/i_new_program_count
add wave -noupdate -label i_jump_flag /tb_lapu/program_counter_inst/i_jump_flag
add wave -noupdate -label program_count /tb_lapu/program_counter_inst/program_count
add wave -noupdate -divider {Control Unit}
add wave -noupdate -label i_clock /tb_lapu/control_unit_inst/i_clock
add wave -noupdate -label state /tb_lapu/control_unit_inst/state
add wave -noupdate -label state_next /tb_lapu/control_unit_inst/state_next
add wave -noupdate -color {Cornflower Blue} -label i_reset /tb_lapu/control_unit_inst/i_reset
add wave -noupdate -color {Cornflower Blue} -label i_cu_start /tb_lapu/control_unit_inst/i_cu_start
add wave -noupdate -color {Cornflower Blue} -label i_program_count -radix unsigned /tb_lapu/control_unit_inst/i_program_count
add wave -noupdate -color {Cornflower Blue} -label i_current_instruction -radix hexadecimal /tb_lapu/control_unit_inst/i_current_instruction
add wave -noupdate -color {Cornflower Blue} -label i_vector -radix sfixed /tb_lapu/control_unit_inst/i_vector
add wave -noupdate -color {Cornflower Blue} -label i_scalar -radix sfixed /tb_lapu/control_unit_inst/i_scalar
add wave -noupdate -color Yellow -label r_current_instruction -radix hexadecimal /tb_lapu/control_unit_inst/r_current_instruction
add wave -noupdate -color Yellow -label r_current_address -radix unsigned /tb_lapu/control_unit_inst/r_current_address
add wave -noupdate -color Yellow -label r_new_program_count -radix unsigned /tb_lapu/control_unit_inst/r_new_program_count
add wave -noupdate -color Yellow -label r_new_program_count /tb_lapu/control_unit_inst/r_cu_done
add wave -noupdate -color Yellow -label r_jump_flag /tb_lapu/control_unit_inst/r_jump_flag
add wave -noupdate -color Yellow -label r_rw_scalar /tb_lapu/control_unit_inst/r_rw_scalar
add wave -noupdate -color Yellow -label r_program_count_ready /tb_lapu/control_unit_inst/r_program_count_ready
add wave -noupdate -color Yellow -label r_column_or_row_order /tb_lapu/control_unit_inst/r_column_or_row_order
add wave -noupdate -color Yellow -label r_rw_vector /tb_lapu/control_unit_inst/r_rw_vector
add wave -noupdate -color Yellow -label r_scalar_or_vector_action /tb_lapu/control_unit_inst/r_scalar_or_vector_action
add wave -noupdate -color Yellow -label r_matrix_sel /tb_lapu/control_unit_inst/r_matrix_sel
add wave -noupdate -color Yellow -label r_vector_i /tb_lapu/control_unit_inst/r_vector_i
add wave -noupdate -color Yellow -label r_vector_j /tb_lapu/control_unit_inst/r_vector_j
add wave -noupdate -color Yellow -label r_scalar_i /tb_lapu/control_unit_inst/r_scalar_i
add wave -noupdate -color Yellow -label r_scalar_j /tb_lapu/control_unit_inst/r_scalar_j
add wave -noupdate -color Yellow -label r_vector -radix sfixed /tb_lapu/control_unit_inst/r_vector
add wave -noupdate -color Yellow -label r_scalar -radix sfixed /tb_lapu/control_unit_inst/r_scalar
add wave -noupdate -color Red -label o_cu_done /tb_lapu/control_unit_inst/o_cu_done
add wave -noupdate -color Red -label o_program_counter_ready /tb_lapu/control_unit_inst/o_program_counter_ready
add wave -noupdate -color Red -label o_new_program_count -radix unsigned /tb_lapu/control_unit_inst/o_new_program_count
add wave -noupdate -color Red -label o_jump_flag /tb_lapu/control_unit_inst/o_jump_flag
add wave -noupdate -color Red -label o_rom_address -radix unsigned /tb_lapu/control_unit_inst/o_rom_address
add wave -noupdate -color Red -label o_matrix_sel /tb_lapu/control_unit_inst/o_matrix_sel
add wave -noupdate -color Red -label o_scalar_or_vector_action /tb_lapu/control_unit_inst/o_scalar_or_vector_action
add wave -noupdate -color Red -label o_rw_vector /tb_lapu/control_unit_inst/o_rw_vector
add wave -noupdate -color Red -label o_column_or_row_order /tb_lapu/control_unit_inst/o_column_or_row_order
add wave -noupdate -color Red -label o_vector_i /tb_lapu/control_unit_inst/o_vector_i
add wave -noupdate -color Red -label o_vector_j /tb_lapu/control_unit_inst/o_vector_j
add wave -noupdate -color Red -label o_vector /tb_lapu/control_unit_inst/o_vector
add wave -noupdate -color Red -label o_rw_scalar /tb_lapu/control_unit_inst/o_rw_scalar
add wave -noupdate -color Red -label o_scalar_i /tb_lapu/control_unit_inst/o_scalar_i
add wave -noupdate -color Red -label o_scalar_j /tb_lapu/control_unit_inst/o_scalar_j
add wave -noupdate -color Red -format Event -label o_scalar -radix sfixed /tb_lapu/control_unit_inst/o_scalar
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {105493 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 355
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {210 ns}
