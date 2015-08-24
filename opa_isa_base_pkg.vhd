library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RISC-V ISA properties
package opa_isa_base_pkg is
  constant c_op_align    : natural :=  2; -- 4-byte aligned riscv (can change later)
  constant c_op_avg_size : natural :=  4; -- average size of an instruction (in bytes)
  constant c_log_arch    : natural :=  5; -- 32 architectural registers
  constant c_imm_wide    : natural := 32;
  constant c_big_endian  : boolean := false;
end package;
