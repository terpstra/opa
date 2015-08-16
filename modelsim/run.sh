#! /bin/sh
git clean -xfd .
hdlmake
vsim -do run.do
