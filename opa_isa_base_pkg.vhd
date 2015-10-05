--  opa: Open Processor Architecture
--  Copyright (C) 2014-2016  Wesley W. Terpstra
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  To apply the GPL to my VHDL, please follow these definitions:
--    Program        - The entire collection of VHDL in this project and any
--                     netlist or floorplan derived from it.
--    System Library - Any macro that translates directly to hardware
--                     e.g. registers, IO pins, or memory blocks
--    
--  My intent is that if you include OPA into your project, all of the HDL
--  and other design files that go into the same physical chip must also
--  be released under the GPL. If this does not cover your usage, then you
--  must consult me directly to receive the code under a different license.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package opa_isa_base_pkg is

  type t_opa_isa_info is record
    big_endian : boolean;
    num_arch   : natural;
    imm_wide   : natural;
    op_wide    : natural;
    page_size  : natural;
  end record t_opa_isa_info;
  
  -- All processors must fit under these limits. Increase them if needed.
  constant c_imm_wide_max : natural := 128;
  constant c_log_arch_max : natural := 8; -- log2(num_arch)

  -- Fast execute units operate in one of four modes
  -- An example of instructions each mode can handle:
  --   lut:   XORI, ORI,  ANDI,  XOR, OR, AND, LUI
  --   addlu: AUIPC, ADDI, ADD, SUB
  --   addhs: BLT,  BGE,  SLTI,  SLT, BLTU, BGEU, SLTIU, SLTU, BEQ, BNE
  --   jump:  JAL,  JALR
  
  constant c_opa_fast_lut  : std_logic_vector(1 downto 0) := "00";
  constant c_opa_fast_addl : std_logic_vector(1 downto 0) := "01";
  constant c_opa_fast_addh : std_logic_vector(1 downto 0) := "10";
  constant c_opa_fast_jump : std_logic_vector(1 downto 0) := "11";
  
  type t_opa_adder is record 
    eq    : std_logic;
    nota  : std_logic;
    notb  : std_logic;
    cin   : std_logic;
    sign  : std_logic;
    fault : std_logic;
  end record t_opa_adder;
  
  -- Slow execute units operate in one of four modes
  --   mul   (00)
  --   shift (01)
  --   load  (10)
  --   store (11)
  -- An example of instructions each mode can handle:
  --   mul:   MUL, MULH, MULHSU, MULHU  [DIV, DIVU, REM, REMU]
  --   shift: SLLI, SRLI, SRAI, SLL, SRL, SRA
  --   load:  LB, LH, LW, LBU, LHU
  --   store: SB, SH, SW
  
  constant c_opa_slow_mul   : std_logic_vector(1 downto 0) := "00";
  constant c_opa_slow_shift : std_logic_vector(1 downto 0) := "01";
  constant c_opa_slow_ldst  : std_logic_vector(1 downto 0) := "10";
  constant c_opa_slow_sext  : std_logic_vector(1 downto 0) := "11";
  
  type t_opa_mul is record
    sexta  : std_logic; -- DIV|DIVU
    sextb  : std_logic;
    high   : std_logic; -- MULH|REM vs. MUL|DIV
    divide : std_logic;
  end record t_opa_mul;
  
  type t_opa_shift is record
    right  : std_logic;
    sext   : std_logic;
  end record t_opa_shift;
  
  constant c_opa_ldst_byte : std_logic_vector(1 downto 0) := "00";
  constant c_opa_ldst_half : std_logic_vector(1 downto 0) := "01";
  constant c_opa_ldst_word : std_logic_vector(1 downto 0) := "10";
  constant c_opa_ldst_quad : std_logic_vector(1 downto 0) := "11";
  
  type t_opa_ldst is record
    store  : std_logic;
    sext   : std_logic;
    size   : std_logic_vector(1 downto 0); -- 1,2,4,8
  end record t_opa_ldst;
  
  type t_opa_sext is record
    size   : std_logic_vector(1 downto 0);
  end record t_opa_sext;
  
  type t_opa_arg is record
    fmode : std_logic_vector(1 downto 0);
    adder : t_opa_adder;
    lut   : std_logic_vector(3 downto 0);
    smode : std_logic_vector(1 downto 0);
    mul   : t_opa_mul;
    shift : t_opa_shift;
    ldst  : t_opa_ldst;
    sext  : t_opa_sext;
  end record t_opa_arg;
  
  -- General information every instruction must provide
  type t_opa_op is record
    -- Information for the rename stage
    archa : std_logic_vector(c_log_arch_max-1 downto 0);
    archb : std_logic_vector(c_log_arch_max-1 downto 0);
    archx : std_logic_vector(c_log_arch_max-1 downto 0);
    geta  : std_logic; -- 1=rega, 0=PC
    getb  : std_logic; -- 1=regb, 0=imm
    setx  : std_logic;
    -- Information for the decode stage
    bad   : std_logic;
    jump  : std_logic;
    take  : std_logic; -- true => jump
    force : std_logic; -- true => take
    pop   : std_logic; -- pop  return stack; '-' when jump=0
    push  : std_logic; -- push return stack; '-' when jump=0
    immb  : std_logic_vector(c_imm_wide_max-1 downto 0); -- branch immediates; less cases than imm.
    -- Information for the issue stage
    fast  : std_logic; -- goes to fast/slow EU
    order : std_logic; -- don't issue it unless it is last
    -- Information for the execute stage
    imm   : std_logic_vector(c_imm_wide_max-1 downto 0);
    arg   : t_opa_arg;
  end record t_opa_op;
  
  constant c_opa_op_bad : t_opa_op := (
    archa => (others => '-'),
    archb => (others => '-'),
    archx => (others => '-'),
    geta  => '-',
    getb  => '-',
    setx  => '-',
    bad   => '1',
    jump  => '-',
    take  => '-',
    force => '-',
    pop   => '-',
    push  => '-',
    immb  => (others => '-'),
    fast  => '-',
    order => '-',
    imm   => (others => '-'),
    arg   => (
      fmode => (others => '-'),
      adder => (eq => '-', nota => '-', notb => '-', cin => '-', sign => '-', fault => '-'),
      lut   => (others => '-'),
      smode => (others => '-'),
      mul   => (sexta => '-', sextb => '-', high => '-', divide => '-'),
      shift => (right => '-', sext => '-'),
      ldst  => (store => '-', sext => '-', size => (others => '-')),
      sext  => (size => (others => '-'))));
  
  constant c_opa_op_undef : t_opa_op := (
    archa => (others => 'X'),
    archb => (others => 'X'),
    archx => (others => 'X'),
    geta  => 'X',
    getb  => 'X',
    setx  => 'X',
    bad   => 'X',
    jump  => 'X',
    take  => 'X',
    force => 'X',
    pop   => 'X',
    push  => 'X',
    immb  => (others => 'X'),
    fast  => 'X',
    order => 'X',
    imm   => (others => 'X'),
    arg   => (
      fmode => (others => 'X'),
      adder => (eq => 'X', nota => 'X', notb => 'X', cin => 'X', sign => 'X', fault => 'X'),
      lut   => (others => 'X'),
      smode => (others => 'X'),
      mul   => (sexta => 'X', sextb => 'X', high => 'X', divide => 'X'),
      shift => (right => 'X', sext => 'X'),
      ldst  => (store => 'X', sext => 'X', size => (others => 'X')),
      sext  => (size => (others => 'X'))));
  
  -- Even ISAs need this function
  function f_opa_log2(x : natural) return natural;
  function f_opa_and(x : std_logic_vector) return std_logic;
  function f_opa_or(x : std_logic_vector) return std_logic;
  
  -- Define the arguments needed for operations in our execution units
  constant c_arg_wide : natural := 26;
  function f_opa_vec_from_arg(x : t_opa_arg) return std_logic_vector;
  function f_opa_arg_from_vec(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_arg;
    
end package;

package body opa_isa_base_pkg is

  function f_opa_vec_from_arg(x : t_opa_arg) return std_logic_vector is
    variable result : std_logic_vector(c_arg_wide-1 downto 0);
  begin
    result := 
      x.fmode &
      x.adder.eq & x.adder.nota & x.adder.notb & x.adder.cin & x.adder.sign & x.adder.fault &
      x.lut &
      x.smode &
      x.mul.sexta & x.mul.sextb & x.mul.high & x.mul.high &
      x.shift.right & x.shift.sext &
      x.ldst.store & x.ldst.sext & x.ldst.size & 
      x.sext.size;
    return result;
  end f_opa_vec_from_arg;
  
  function f_opa_arg_from_vec(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_arg is
    variable result : t_opa_arg;
  begin
    result.fmode       := x(25 downto 24);
    result.adder.eq    := x(23);
    result.adder.nota  := x(22);
    result.adder.notb  := x(21);
    result.adder.cin   := x(20);
    result.adder.sign  := x(19);
    result.adder.fault := x(18);
    result.lut         := x(17 downto 14);
    result.smode       := x(13 downto 12);
    result.mul.sexta   := x(11);
    result.mul.sextb   := x(10);
    result.mul.high    := x(9);
    result.mul.divide  := x(8);
    result.shift.right := x(7);
    result.shift.sext  := x(6);
    result.ldst.store  := x(5);
    result.ldst.sext   := x(4);
    result.ldst.size   := x(3 downto 2);
    result.sext.size   := x(1 downto 0);
    return result;
  end f_opa_arg_from_vec;

  function f_opa_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return f_opa_log2((x+1)/2)+1;
    end if;
  end f_opa_log2;
  
  function f_opa_or(x : std_logic_vector) return std_logic is
    alias y : std_logic_vector(x'length-1 downto 0) is x;
    constant c_mid : natural := (y'high + y'low) / 2;
  begin
    if y'length = 0 then return '0'; end if;
    if y'length = 1 then return y(y'low); end if;
    return f_opa_or(y(y'high downto c_mid+1)) or
           f_opa_or(y(c_mid downto y'low));
  end f_opa_or;
  
  function f_opa_and(x : std_logic_vector) return std_logic is
    alias y : std_logic_vector(x'length-1 downto 0) is x;
    constant c_mid : natural := (y'high + y'low) / 2;
  begin
    if y'length = 0 then return '1'; end if;
    if y'length = 1 then return y(y'left); end if;
    return f_opa_and(y(y'high downto c_mid+1)) and
           f_opa_and(y(c_mid downto y'low));
  end f_opa_and;
  
end opa_isa_base_pkg;
