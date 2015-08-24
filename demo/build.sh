#! /bin/sh
riscv-gcc -Wall -O2 -m32 crt0.S main.c -nostdlib -T ram.ld -o demo.elf
riscv-objcopy -O binary demo.elf demo.bin
gcc -Wall -O2 genramvhd.c -o genramvhd
./genramvhd  demo.bin > demo.vhd
