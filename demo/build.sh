#! /bin/sh

set -ex

SOURCES="main.c pp-printf.c pp-vsprintf.c"

gcc -DHOST -Wall -O2 $SOURCES -o main

riscv64-unknown-elf-gcc -falign-loops=16 -falign-functions=16 -Wall -O2 -m32 crt0-riscv.S $SOURCES -nostdlib -T ram.ld -o riscv.elf
riscv64-unknown-elf-objcopy -O binary riscv.elf riscv.bin

lm32-elf-gcc -mmultiply-enabled -mbarrel-shift-enabled -msign-extend-enabled -falign-loops=16 -falign-functions=16 -Wall -O2 crt0-lm32.S $SOURCES -nostdlib -T ram.ld -o lm32.elf
lm32-elf-objcopy -O binary lm32.elf lm32.bin

gcc -Wall -O2 genramvhd.c -o genramvhd
./genramvhd -p demo -l -w 4 -s 65536 riscv.bin > riscv.vhd # -w 8 for 64-bit, -w 4 for 32-bit
./genramvhd -p demo -b -w 4 -s 65536 lm32.bin  > lm32.vhd
