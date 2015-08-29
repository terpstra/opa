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
  .boot : 
  {
    . = ALIGN(8); _fboot = .;
    *(.boot .boot.*)
    . = ALIGN(8); _eboot = .;
  } > ram

  .text : 
  {
    . = ALIGN(8); _ftext = .;
    *(.text .stub .text.* .gnu.linkonce.t.*)
    . = ALIGN(8); _etext = .;
  } > ram

  .rodata : 
  {
    . = ALIGN(8); _frodata = .;
    *(.rodata .rodata1 .rodata.* .gnu.linkonce.r.*)
    . = ALIGN(8); _erodata = .;
  } > ram

  .data :
  {
    . = ALIGN(8); _fdata = .;
    *(.data .data1 .data.* .gnu.linkonce.d.*)
    *(.sdata .sdata1 .sdata.* .gnu.linkonce.s.*)
    . = ALIGN(8); _edata = .;
  } > ram

  .bss :
  {
    . = ALIGN(8); _fbss = .;
    *(.dynsbss .dynbss .scommon COMMON)
    *(.bss .bss.* .gnu.linkonce.b.*)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    . = ALIGN(8); _ebss = .;   
  } > ram
  _end = .;
}

PROVIDE(_endram = ORIGIN(stack));
PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack) - 4);
