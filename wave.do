onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label i_clock /tb_lapu/instruction_memory_inst/i_clock
add wave -noupdate -divider {Instruction Memory}
add wave -noupdate -label i_rom_address -radix unsigned /tb_lapu/instruction_memory_inst/i_rom_address
add wave -noupdate -label o_instruction -radix hexadecimal /tb_lapu/instruction_memory_inst/o_instruction
add wave -noupdate -divider {Control Unit}
add wave -noupdate -label i_clock /tb_lapu/control_unit_inst/i_clock
add wave -noupdate -label state_next /tb_lapu/control_unit_inst/state_next
add wave -noupdate -label state /tb_lapu/control_unit_inst/state
add wave -noupdate -color {Cornflower Blue} -label i_reset /tb_lapu/control_unit_inst/i_reset
add wave -noupdate -color {Cornflower Blue} -label i_cu_start /tb_lapu/control_unit_inst/i_cu_start
add wave -noupdate -color {Cornflower Blue} -label i_current_instruction -radix hexadecimal /tb_lapu/control_unit_inst/i_current_instruction
add wave -noupdate -color {Cornflower Blue} -label i_vector -radix sfixed /tb_lapu/control_unit_inst/i_vector
add wave -noupdate -color {Cornflower Blue} -label i_scalar -radix sfixed /tb_lapu/control_unit_inst/i_scalar
add wave -noupdate -color Yellow -label r_scalar_reg_sel_1 /tb_lapu/control_unit_inst/r_scalar_reg_sel_1
add wave -noupdate -color Yellow -label r_scalar_reg_sel_2 /tb_lapu/control_unit_inst/r_scalar_reg_sel_2
add wave -noupdate -color Yellow -label r_current_instruction -radix hexadecimal /tb_lapu/control_unit_inst/r_current_instruction
add wave -noupdate -color Yellow -label r_new_program_count -radix unsigned /tb_lapu/control_unit_inst/r_new_program_count
add wave -noupdate -color Yellow -label r_new_program_count /tb_lapu/control_unit_inst/r_cu_done
add wave -noupdate -color Yellow -label r_jump_flag /tb_lapu/control_unit_inst/r_jump_flag
add wave -noupdate -color Yellow -label r_rw_scalar /tb_lapu/control_unit_inst/r_rw_scalar
add wave -noupdate -color Yellow -label r_PC -radix unsigned /tb_lapu/control_unit_inst/r_PC
add wave -noupdate -color Yellow -label r_current_address -radix unsigned /tb_lapu/control_unit_inst/r_current_address
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
add wave -noupdate -color Red -radix sfixed /tb_lapu/control_unit_inst/o_a
add wave -noupdate -color Red -radix sfixed /tb_lapu/control_unit_inst/o_b
add wave -noupdate -color Red -label o_cu_done /tb_lapu/control_unit_inst/o_cu_done
add wave -noupdate -color Red -label o_rom_address -radix sfixed /tb_lapu/control_unit_inst/o_rom_address
add wave -noupdate -color Red -label o_matrix_sel -radix sfixed /tb_lapu/control_unit_inst/o_matrix_sel
add wave -noupdate -color Red -label o_scalar_or_vector_action -radix sfixed /tb_lapu/control_unit_inst/o_scalar_or_vector_action
add wave -noupdate -color Red -label o_rw_vector -radix sfixed /tb_lapu/control_unit_inst/o_rw_vector
add wave -noupdate -color Red -label o_column_or_row_order -radix sfixed /tb_lapu/control_unit_inst/o_column_or_row_order
add wave -noupdate -color Red -label o_vector_i -radix sfixed /tb_lapu/control_unit_inst/o_vector_i
add wave -noupdate -color Red -label o_vector_j -radix sfixed /tb_lapu/control_unit_inst/o_vector_j
add wave -noupdate -color Red -label o_vector -radix sfixed /tb_lapu/control_unit_inst/o_vector
add wave -noupdate -color Red -label o_rw_scalar -radix sfixed /tb_lapu/control_unit_inst/o_rw_scalar
add wave -noupdate -color Red -label o_scalar_i -radix sfixed /tb_lapu/control_unit_inst/o_scalar_i
add wave -noupdate -color Red -label o_scalar_j -radix sfixed /tb_lapu/control_unit_inst/o_scalar_j
add wave -noupdate -divider {Register File}
add wave -noupdate -color Red -format Event -label o_scalar -radix sfixed /tb_lapu/control_unit_inst/o_scalar
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_clock
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_reset
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_scalar_reg_sel_1
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_scalar_reg_sel_2
add wave -noupdate -radix sfixed -childformat {{/tb_lapu/register_file_inst/o_scalar_reg_1.re -radix sfixed} {/tb_lapu/register_file_inst/o_scalar_reg_1.im -radix sfixed}} -subitemconfig {/tb_lapu/register_file_inst/o_scalar_reg_1.re {-height 19 -radix sfixed} /tb_lapu/register_file_inst/o_scalar_reg_1.im {-height 19 -radix sfixed}} /tb_lapu/register_file_inst/o_scalar_reg_1
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/o_scalar_reg_2
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_scalar_reg_input
add wave -noupdate /tb_lapu/register_file_inst/i_scalar_write_sel
add wave -noupdate /tb_lapu/register_file_inst/i_scalar_write_enable
add wave -noupdate /tb_lapu/register_file_inst/i_vector_reg_sel_1
add wave -noupdate /tb_lapu/register_file_inst/i_vector_reg_sel_2
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/o_vector_reg_1
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/o_vector_reg_2
add wave -noupdate -radix sfixed /tb_lapu/register_file_inst/i_vector_reg_input
add wave -noupdate /tb_lapu/register_file_inst/i_vector_write_sel
add wave -noupdate /tb_lapu/register_file_inst/i_vector_write_enable
add wave -noupdate -radix sfixed -childformat {{/tb_lapu/register_file_inst/scalar_regs(0) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(1) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(2) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(3) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(4) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(5) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(6) -radix sfixed} {/tb_lapu/register_file_inst/scalar_regs(7) -radix sfixed}} -expand -subitemconfig {/tb_lapu/register_file_inst/scalar_regs(0) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(1) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(2) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(3) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(4) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(5) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(6) {-height 19 -radix sfixed} /tb_lapu/register_file_inst/scalar_regs(7) {-height 19 -radix sfixed}} /tb_lapu/register_file_inst/scalar_regs
add wave -noupdate -expand -subitemconfig {/tb_lapu/register_file_inst/vector_regs(0) -expand} /tb_lapu/register_file_inst/vector_regs
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4656 ps} 0}
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
WaveRestoreZoom {0 ps} {175005 ps}
