vlog -sv ../opa_sim_tb.vhd
-- make -f Makefile
vsim -L unisim -t 10fs work.main -voptargs="+acc"
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave.do
radix -hexadecimal
run 300us
wave zoomfull
radix -hexadecimal
