#! /bin/sh

set -e

# incomplete
#	opa_l1d.vhd
#	opa_fetch.vhd

for i in 			\
	opa_pkg.vhd 		\
	opa_isa_base_pkg.vhd	\
	opa_functions_pkg.vhd	\
	opa_components_pkg.vhd	\
	opa_isa_pkg.vhd		\
	opa_dpram.vhd		\
	opa_lcell.vhd		\
	opa_prim_ternary.vhd	\
	opa_prim_mul.vhd	\
	opa_prefixsum.vhd	\
	opa_decode.vhd		\
	opa_rename.vhd		\
	opa_issue.vhd		\
	opa_regfile.vhd		\
	opa_fast.vhd		\
	opa_slow.vhd		\
	opa.vhd			\
	opa_core_tb.vhd		\
	opa_sim_tb.vhd;		\
do echo $i; ghdl -a --std=93 --ieee=standard --syn-binding  ../$i
done

echo link
ghdl -e --std=93 --ieee=standard --syn-binding opa_sim_tb

echo run
./opa_sim_tb --stop-time=500ns --wave=testbench.ghw 2>&1 | grep -v metavalue

gtkwave testbench.ghw wave.gtkw
