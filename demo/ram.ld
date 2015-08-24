OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY
{
    ram :
 ORIGIN = 0x00000000,
 LENGTH = 131072 - 10240
    stack :
 ORIGIN = 131072 - 10240,
 LENGTH = 10240
}
SECTIONS
{
 .boot   : { . = ALIGN(8); _fboot   = .; *(.boot)              _eboot   = .; } > ram
 .text   : { . = ALIGN(8); _ftext   = .; *(.text   .text.*)    _etext   = .; } > ram
 .rodata : { . = ALIGN(8); _frodata = .; *(.rodata .rodata.*); _erodata = .; } > ram
 .data   : { . = ALIGN(8); _fdata   = .; *(.data   .data.*)    _edata   = .; } > ram
 .bss    : { . = ALIGN(8); _fbss    = .; *(.bss    .bss.*);    _ebss    = .; } > ram
 PROVIDE(_endram = ORIGIN(stack));
 PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack) - 4);
}
