make -f Makefile
vsim -L unisim -t 1ns work.opa_sim_tb -voptargs="+acc"
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave.do
radix -hexadecimal
run 500ns
wave zoomfull
radix -hexadecimal
