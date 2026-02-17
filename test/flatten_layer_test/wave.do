onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -label data_in -noupdate -radix binary /tb_final_layer_sequential/dut/data_in
add wave -label weights_in -noupdate -radix binary /tb_final_layer_sequential/dut/weights_in
add wave -label answer -noupdate -radix unsigned /tb_final_layer_sequential/dut/answer
add wave -label popcount -noupdate -radix unsigned /tb_final_layer_sequential/dut/popcount

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {10000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 80
configure wave -valuecolwidth 40
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
