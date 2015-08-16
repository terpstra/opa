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
	opa.vhd;		\
do ghdl -a --std=02 --ieee=synopsys ../$i
done

ghdl -e --std=02 --ieee=synopsys opa_sim_tb
./opa_sim_tb --stop-time=500ns --vcd=testbench.vcd
gtkwave testbench.vcd wave.gtkw
