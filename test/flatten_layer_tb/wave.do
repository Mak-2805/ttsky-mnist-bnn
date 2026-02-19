onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -label Clock -noupdate -radix binary /tb_final_layer_sequential/dut/clock
add wave -label Enable -noupdate -radix binary /tb_final_layer_sequential/dut/en
add wave -label Reset -noupdate -radix binary /tb_final_layer_sequential/dut/reset
add wave -label data_in -noupdate -radix binary /tb_final_layer_sequential/dut/data_in
add wave -label weights_in -noupdate -radix binary /tb_final_layer_sequential/dut/weights_in
add wave -label xnor -noupdate -radix binary /tb_final_layer_sequential/dut/xnor_result
add wave -label next_popcount -noupdate -radix unsigned /tb_final_layer_sequential/dut/next_popcount
add wave -label round_1 -noupdate -radix unsigned /tb_final_layer_sequential/dut/round_1_idx
add wave -label round_2 -noupdate -radix unsigned /tb_final_layer_sequential/dut/round_2_idx
add wave -label round_3 -noupdate -radix unsigned /tb_final_layer_sequential/dut/round_3_idx
add wave -label answer -noupdate -radix unsigned /tb_final_layer_sequential/dut/answer
add wave -label popcount -noupdate -radix unsigned /tb_final_layer_sequential/dut/popcount
add wave -label layer_3_done -noupdate -radix unsigned /tb_final_layer_sequential/dut/layer_3_done

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {10000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 140
configure wave -valuecolwidth 80
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
WaveRestoreZoom {0 ps} {120 ns}
