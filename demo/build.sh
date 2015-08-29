#! /bin/sh
set -ex
riscv64-unknown-elf-gcc -Wall -O2 -m32 crt0.S main.c -nostdlib -T ram.ld -o demo.elf
riscv64-unknown-elf-objcopy -O binary demo.elf demo.bin
gcc -Wall -O2 genramvhd.c -o genramvhd
./genramvhd -l -w 8 demo.bin > demo.vhd # -w 8 for 64-bit, -w 4 for 32-bit
