onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color {Cornflower Blue} -radix sfixed /tb_top/alu_inst/i_a
add wave -noupdate -color {Cornflower Blue} -radix sfixed /tb_top/alu_inst/i_b
add wave -noupdate -color {Cornflower Blue} -radix sfixed /tb_top/alu_inst/i_av
add wave -noupdate -color {Cornflower Blue} -radix sfixed /tb_top/alu_inst/i_bv
add wave -noupdate -color {Cornflower Blue} /tb_top/alu_inst/i_map_code
add wave -noupdate -color {Cornflower Blue} -radix sfixed /tb_top/alu_inst/i_opcode
add wave -noupdate -color Red -radix sfixed /tb_top/alu_inst/o_x
add wave -noupdate -color Red -radix sfixed /tb_top/alu_inst/o_xv
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 252
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
configure wave -timelineunits ns
update
WaveRestoreZoom {1 ns} {3 ns}
