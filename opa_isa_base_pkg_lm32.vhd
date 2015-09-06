library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- LM32 ISA properties
package opa_isa_base_pkg is
  constant c_op_align    : natural :=  2; -- 4-byte aligned
  constant c_op_avg_size : natural :=  4; -- average size of an instruction (in bytes)
  constant c_log_arch    : natural :=  5; -- 32 architectural registers
  constant c_imm_wide    : natural := 32;
  constant c_big_endian  : boolean := true;
  constant c_page_size   : natural := 4096;
  constant c_dline_size  : natural := 16;
  constant c_iline_size  : natural := 16;
end package;
