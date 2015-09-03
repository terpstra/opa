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
    . = ALIGN(16); _fboot = .;
    *(.boot .boot.*)
    . = ALIGN(16); _eboot = .;
  } > ram

  .text : 
  {
    . = ALIGN(16); _ftext = .;
    *(.text .stub .text.* .gnu.linkonce.t.*)
    . = ALIGN(16); _etext = .;
  } > ram

  .rodata : 
  {
    . = ALIGN(16); _frodata = .;
    *(.rodata .rodata1 .rodata.* .gnu.linkonce.r.*)
    . = ALIGN(16); _erodata = .;
  } > ram

  .data :
  {
    . = ALIGN(16); _fdata = .;
    *(.data .data1 .data.* .gnu.linkonce.d.*)
    *(.sdata .sdata1 .sdata.* .gnu.linkonce.s.*)
    . = ALIGN(16); _edata = .;
  } > ram

  .bss :
  {
    . = ALIGN(16); _fbss = .;
    *(.dynsbss .dynbss .scommon COMMON)
    *(.bss .bss.* .gnu.linkonce.b.*)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    . = ALIGN(16); _ebss = .;
  } > ram
  _end = .;
}

PROVIDE(_endram = ORIGIN(stack));
PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack) - 4);
