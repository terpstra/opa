#! /bin/sh

set -e

arch="${arch:-riscv}"
if [ "$arch" != "lm32" -a "$arch" != "riscv" ]; then
  echo Unsupported architecture ${arch} >&2
  exit 1
fi

echo "Building for $arch"
for i in 				\
	opa_pkg.vhd 			\
	opa_isa_base_pkg.vhd		\
	opa_riscv_pkg.vhd		\
	opa_lm32_pkg.vhd		\
	opa_isa_pkg.vhd			\
	opa_functions_pkg.vhd		\
	opa_components_pkg.vhd		\
	opa_dpram.vhd			\
	opa_tdpram.vhd			\
	opa_lcell.vhd			\
	opa_prim_ternary.vhd		\
	opa_prim_mul.vhd		\
	opa_lfsr.vhd			\
	opa_prefixsum.vhd		\
	opa_predict.vhd			\
	opa_icache.vhd			\
	opa_decode.vhd			\
	opa_rename.vhd			\
	opa_issue.vhd			\
	opa_regfile.vhd			\
	opa_fast.vhd			\
	opa_slow.vhd			\
	opa_l1d.vhd			\
	opa_dbus.vhd			\
	opa_pbus.vhd			\
	opa.vhd				\
	demo/$arch.vhd			\
	opa_sim_tb.vhd;			\
do echo $i; ghdl -a --std=93 --ieee=standard --syn-binding  ../$i
done

echo link
ghdl -e --std=93 --ieee=standard --syn-binding opa_sim_tb

echo run
./opa_sim_tb --stop-time=80us --wave=testbench.ghw

gtkwave testbench.ghw wave.gtkw
