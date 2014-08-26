onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /opa_sim_tb/clk
add wave -noupdate /opa_sim_tb/rstn
add wave -noupdate /opa_sim_tb/r_ok
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/stb_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/stall_o
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/rename/r_dec_archx
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/rename/r_dec_archa
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/rename/r_dec_archb
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/rename/r_commit_bakx
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/rename/r_map
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_sh1_bakx
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_sh1_baka
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_sh1_bakb
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_fast
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_slow
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_issued
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_issued
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_ready
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_ready
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_final
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_final
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_kill
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_kill
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_quash
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_quash
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_commit
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_stat_o
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_ready_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_final_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_quash_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_kill_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/eu_stall_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_readya
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/s_readyb
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_stata
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_statb
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_baka
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_bakb
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_bakx0
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/issue/r_bakx1
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/regfile/eu_aux_o
add wave -noupdate -expand /opa_sim_tb/opa_tb/opa_core/regfile/eu_stb_o
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/regfile/eu_stb_i
add wave -noupdate -expand /opa_sim_tb/opa_tb/opa_core/regfile/eu_rega_o
add wave -noupdate -expand /opa_sim_tb/opa_tb/opa_core/regfile/eu_regb_o
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/regfile/eu_bakx_o
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/regfile/eu_bakx_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/regfile/eu_regx_i
add wave -noupdate /opa_sim_tb/opa_tb/opa_core/commit/r_map
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {18 ns} 0}
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
WaveRestoreZoom {0 ns} {525 ns}
