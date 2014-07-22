onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /opa_sim_tb/clk
add wave -noupdate /opa_sim_tb/rstn
add wave -noupdate /opa_sim_tb/r_ok
add wave -noupdate /opa_sim_tb/satadd_tb/expected
add wave -noupdate /opa_sim_tb/satadd_tb/resulted
add wave -noupdate /opa_sim_tb/satadd_tb/good_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
configure wave -namecolwidth 150
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
WaveRestoreZoom {0 ns} {1 us}
