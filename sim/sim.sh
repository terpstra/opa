#! /bin/sh

set -e

for i in \
	opa_pkg.vhd 		\
	opa_functions_pkg.vhd	\
	opa_components_pkg.vhd	\
	opa_commit.vhd		\
	opa_core_tb.vhd		\
	opa_decode.vhd		\
	opa_dpram.vhd		\
	opa_fast.vhd		\
	opa_issue.vhd		\
	opa_lcell.vhd		\
	opa_prefixsum.vhd	\
	opa_prim_mul.vhd	\
	opa_prim_ternary.vhd	\
	opa_regfile.vhd		\
	opa_rename.vhd		\
	opa_sim_tb.vhd		\
	opa_slow.vhd		\
	opa_l1d.vhd		\
	opa.vhd;			\
do ghdl -a --std=93 --ieee=standard --syn-binding  ../$i
done
ghdl -e --std=93 --ieee=standard --syn-binding opa_sim_tb

./opa_sim_tb --stop-time=500ns --wave=testbench.ghw 2>&1 | grep -v metavalue
gtkwave testbench.ghw wave.gtkw
