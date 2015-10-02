#! /bin/sh
g++ -Wall -O2 jtag-gpio.cpp opa.cpp bb.cpp -lftdi -o jtag-gpio
g++ -Wall -O2 jtag-rw.cpp   opa.cpp bb.cpp -lftdi -o jtag-rw
g++ -Wall -O2 jtag-load.cpp opa.cpp bb.cpp -lftdi -o jtag-load
