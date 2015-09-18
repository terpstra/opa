onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /opa_sim_tb/rstn
add wave -noupdate /opa_sim_tb/clk
add wave -noupdate -expand /opa_sim_tb/opa_core/regfile/eu_stb_o
add wave -noupdate -radix decimal -expand /opa_sim_tb/opa_core/regfile/eu_rega_o
add wave -noupdate -radix decimal -expand /opa_sim_tb/opa_core/regfile/eu_regb_o
add wave -noupdate -radix decimal -expand /opa_sim_tb/opa_core/regfile/eu_regx_i
add wave -noupdate /opa_sim_tb/opa_core/issue/r_fault_pending
add wave -noupdate /opa_sim_tb/opa_core/issue/r_fault_out
add wave -noupdate /opa_sim_tb/opa_core/predict/decode_fault_i
add wave -noupdate -radix decimal /opa_sim_tb/opa_core/decode/r_fill
add wave -noupdate /opa_sim_tb/opa_core/decode/rename_stall_i
add wave -noupdate /opa_sim_tb/opa_core/decode/icache_stb_i
add wave -noupdate /opa_sim_tb/opa_core/l1d/slow_stb_i(0)
add wave -noupdate /opa_sim_tb/opa_core/l1d/slow_we_i(0)
add wave -noupdate -radix decimal /opa_sim_tb/opa_core/l1d/slow_addr_i(0)
add wave -noupdate -radix hexadecimal /opa_sim_tb/opa_core/l1d/slow_data_i(0)
add wave -noupdate /opa_sim_tb/opa_core/l1d/slow_retry_o(0)
add wave -noupdate /opa_sim_tb/opa_core/l1d/s_wb_we(0)
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {602 ns} 0}
configure wave -namecolwidth 360
configure wave -valuecolwidth 78
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
WaveRestoreZoom {0 ns} {5250 ns}
