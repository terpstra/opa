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

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;

-- RISC-V ISA
package opa_riscv_pkg is

  constant c_opa_rv32 : t_opa_isa_info := (
    big_endian => false,
    num_arch   => 32,
    imm_wide   => 32,
    op_wide    => 32,
    page_size  => 4096);

  function f_opa_accept_rv32(config : t_opa_config) return std_logic;
  function f_opa_decode_rv32(config : t_opa_config; x : std_logic_vector) return t_opa_op;

end package;

package body opa_riscv_pkg is

  constant c_arch_wide : natural := f_opa_log2(c_opa_rv32.num_arch);
  
  function f_zero(x : std_logic_vector) return std_logic is
  begin
    return not f_opa_or(x(c_arch_wide-1 downto 0));
  end f_zero;
  
  function f_one(x : std_logic_vector) return std_logic is
  begin
    return f_opa_and(x(c_arch_wide-1 downto 0));
  end f_one;
  
  function f_parse_rtype (x : std_logic_vector) return t_opa_op is
    variable result : t_opa_op := c_opa_op_undef;
  begin
    result.archb(c_arch_wide-1 downto 0) := x(24 downto 20);
    result.archa(c_arch_wide-1 downto 0) := x(19 downto 15);
    result.archx(c_arch_wide-1 downto 0) := x(11 downto  7);
    result.geta  := '1'; -- use both input registers
    result.getb  := '1';
    result.setx  := not f_zero(x);
    result.bad   := '0';
    result.jump  := '0';
    result.take  := '0';
    result.force := '0';
    result.order := '0';
    return result;
  end f_parse_rtype;
  
  function f_parse_itype (x : std_logic_vector) return t_opa_op is
    variable result : t_opa_op := c_opa_op_undef;
  begin
    result.archa(c_arch_wide-1 downto 0) := x(19 downto 15);
    result.archx(c_arch_wide-1 downto 0) := x(11 downto  7);
    result.getb  := '0'; -- immediate
    result.geta  := '1';
    result.setx  := not f_zero(result.archx);
    result.bad   := '0';
    result.jump  := '0';
    result.take  := '0';
    result.force := '0';
    result.order := '0';
    result.imm := (others => x(31));
    result.imm(10 downto 0) := x(30 downto 20);
    return result;
  end f_parse_itype;
  
  function f_parse_stype (x : std_logic_vector) return t_opa_op is
    variable result : t_opa_op := c_opa_op_undef;
  begin
    result.archb(c_arch_wide-1 downto 0) := x(24 downto 20);
    result.archa(c_arch_wide-1 downto 0) := x(19 downto 15);
    result.getb  := '1';
    result.geta  := '1';
    result.setx  := '0';
    result.bad   := '0';
    result.jump  := '0';
    result.take  := '0';
    result.force := '0';
    result.order := '1';
    result.imm := (others => x(31));
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 0) := x(11 downto 7);
    return result;
  end f_parse_stype;
  
  function f_parse_utype (x : std_logic_vector) return t_opa_op is
    variable result : t_opa_op := c_opa_op_undef;
  begin
    result.archx(c_arch_wide-1 downto 0) := x(11 downto  7);
    result.geta  := '0';
    result.getb  := '0';
    result.setx  := not f_zero(result.archx);
    result.bad   := '0';
    result.jump  := '0';
    result.take  := '0';
    result.force := '0';
    result.order := '0';
    result.imm(31 downto 12) := x(31 downto 12);
    result.imm(11 downto  0) := (others => '0');
    return result;
  end f_parse_utype;
  
  function f_parse_sbtype(x : std_logic_vector) return t_opa_op is
    variable result : t_opa_op := c_opa_op_undef;
  begin
    result.archb(c_arch_wide-1 downto 0) := x(24 downto 20);
    result.archa(c_arch_wide-1 downto 0) := x(19 downto 15);
    result.getb  := '1';
    result.geta  := '1';
    result.setx  := '0';
    result.bad   := '0';
    result.jump  := '1';
    result.take  := x(31); -- static prediction: negative = taken
    result.force := '0';
    result.pop   := '0';
    result.push  := '0';
    result.order := '0';
    result.imm := (others => x(31));
    result.imm(11)          := x(7);
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 1) := x(11 downto 8);
    result.imm(0)           := '0';
    result.immb := result.imm;
    return result;
  end f_parse_sbtype;
  
  -- JAL has a special format
  function f_decode_jal  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := c_opa_op_undef;
  begin
    op.archx(c_arch_wide-1 downto 0)    := x(11 downto  7);
    op.getb     := '0'; -- imm
    op.geta     := '0'; -- PC
    op.setx     := not f_zero(op.archx);
    op.bad      := '0';
    op.jump     := '1';
    op.take     := '1';
    op.force    := '1';
    op.order    := '0';
    op.pop      := '0';
    op.push     := f_one(op.archx);
    -- a very strange immediate format:
    op.imm := (others => x(31));
    op.imm(19 downto 12) := x(19 downto 12);
    op.imm(11)           := x(20);
    op.imm(10 downto  1) := x(30 downto 21);
    op.imm(0) := '0';
    op.immb := op.imm;
    
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '-';
    op.arg.fmode       := c_opa_fast_jump;
    op.fast            := '1';
    return op;
  end f_decode_jal;
  
  function f_decode_jalr (x : std_logic_vector) return t_opa_op is
    variable op  : t_opa_op := f_parse_itype(x);
    variable ret : std_logic;
  begin
    -- immb stays don't care as we can't make a static prediction anyway
    ret         := f_zero(op.archx) and f_one(op.archa); -- is this a return?
    op.jump     := '1';
    op.take     := ret;
    op.force    := '0';
    op.pop      := ret;
    op.push     := f_one(op.archx);

    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '-';
    op.arg.fmode       := c_opa_fast_jump;
    op.fast            := '1';
    return op;
  end f_decode_jalr;
  
  function f_decode_lui  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_utype(x);
  begin
    op.arg.lut   := "1010"; -- X = B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_lui;
  
  function f_decode_auipc(x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_utype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addl;
    op.fast            := '1';
    return op;
  end f_decode_auipc;
  
  function f_decode_beq  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '1';
    op.arg.adder.nota  := '1';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '1';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_beq;
  
  function f_decode_bne  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '1';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '1';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_bne;
  
  function f_decode_blt  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '1';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_blt;
  
  function f_decode_bge  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    op.arg.adder.notb  := '1';
    op.arg.adder.cin   := '1';
    op.arg.adder.sign  := '1';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_bge;
  
  function f_decode_bltu (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_bltu;
  
  function f_decode_bgeu (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_sbtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    op.arg.adder.notb  := '1';
    op.arg.adder.cin   := '1';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '1';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_bgeu;
  
  function f_decode_lb   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.ldst.store := '0';
    op.arg.ldst.sext  := '1';
    op.arg.ldst.size  := c_opa_ldst_byte;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_lb;
  
  function f_decode_lh   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.ldst.store := '0';
    op.arg.ldst.sext  := '1';
    op.arg.ldst.size  := c_opa_ldst_half;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_lh;
  
  function f_decode_lw   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.ldst.store := '0';
    op.arg.ldst.sext  := '1';
    op.arg.ldst.size  := c_opa_ldst_word;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_lw;
  
  function f_decode_lbu  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.ldst.store := '0';
    op.arg.ldst.sext  := '0';
    op.arg.ldst.size  := c_opa_ldst_byte;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_lbu;
  
  function f_decode_lhu  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.ldst.store := '0';
    op.arg.ldst.sext  := '0';
    op.arg.ldst.size  := c_opa_ldst_half;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_lhu;
  
  function f_decode_sb   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_stype(x);
  begin
    op.arg.ldst.store := '1';
    op.arg.ldst.sext  := '-';
    op.arg.ldst.size  := c_opa_ldst_byte;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_sb;
  
  function f_decode_sh   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_stype(x);
  begin
    op.arg.ldst.store := '1';
    op.arg.ldst.sext  := '-';
    op.arg.ldst.size  := c_opa_ldst_half;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_sh;
  
  function f_decode_sw   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_stype(x);
  begin
    op.arg.ldst.store := '1';
    op.arg.ldst.sext  := '-';
    op.arg.ldst.size  := c_opa_ldst_word;
    op.arg.smode      := c_opa_slow_ldst;
    op.fast           := '0';
    return op;
  end f_decode_sw;
  
  function f_decode_addi (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addl;
    op.fast            := '1';
    return op;
  end f_decode_addi;
  
  function f_decode_slti (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '1';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_slti;
  
  function f_decode_sltiu(x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_sltiu;
  
  function f_decode_xori (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.lut   := "0110"; -- X = A xor B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_xori;
  
  function f_decode_ori  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.lut   := "1110"; -- X = A or B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_ori;
  
  function f_decode_andi (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.lut   := "1000"; -- X = A and B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_andi;
  
  function f_decode_slli (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.shift.right := '0';
    op.arg.shift.sext  := '0';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_slli;
  
  function f_decode_srli (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.shift.right := '1';
    op.arg.shift.sext  := '0';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_srli;
  
  function f_decode_srai (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_itype(x);
  begin
    op.arg.shift.right := '1';
    op.arg.shift.sext  := '1';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_srai;
  
  function f_decode_add  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addl;
    op.fast            := '1';
    return op;
  end f_decode_add;
  
  function f_decode_sub  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '0';
    op.arg.adder.notb  := '1';
    op.arg.adder.cin   := '1';
    op.arg.adder.sign  := '-';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addl;
    op.fast            := '1';
    return op;
  end f_decode_sub;
  
  function f_decode_slt  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '1';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_slt;
  
  function f_decode_sltu (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.adder.eq    := '0';
    op.arg.adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    op.arg.adder.notb  := '0';
    op.arg.adder.cin   := '0';
    op.arg.adder.sign  := '0';
    op.arg.adder.fault := '0';
    op.arg.fmode       := c_opa_fast_addh;
    op.fast            := '1';
    return op;
  end f_decode_sltu;
  
  function f_decode_xor  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.lut   := "0110"; -- X = A xor B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_xor;
  
  function f_decode_or   (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.lut   := "1110"; -- X = A or B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_or;
  
  function f_decode_and  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.lut   := "1000"; -- X = A and B
    op.arg.fmode := c_opa_fast_lut;
    op.fast      := '1';
    return op;
  end f_decode_and;
  
  function f_decode_sll  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.shift.right := '0';
    op.arg.shift.sext  := '0';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_sll;
  
  function f_decode_srl  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.shift.right := '1';
    op.arg.shift.sext  := '0';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_srl;
  
  function f_decode_sra  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.shift.right := '1';
    op.arg.shift.sext  := '1';
    op.arg.smode       := c_opa_slow_shift;
    op.fast            := '0';
    return op;
  end f_decode_sra;
  
  function f_decode_mul  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '-';
    op.arg.mul.sextb  := '-';
    op.arg.mul.high   := '0';
    op.arg.mul.divide := '0';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_mul;
  
  function f_decode_mulh (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '1';
    op.arg.mul.sextb  := '1';
    op.arg.mul.high   := '1';
    op.arg.mul.divide := '0';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_mulh;
  
  function f_decode_mulhsu(x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '1';
    op.arg.mul.sextb  := '0';
    op.arg.mul.high   := '1';
    op.arg.mul.divide := '0';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_mulhsu;
  
  function f_decode_mulhu(x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '0';
    op.arg.mul.sextb  := '0';
    op.arg.mul.high   := '1';
    op.arg.mul.divide := '0';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_mulhu;
  
  function f_decode_div  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '-';
    op.arg.mul.sextb  := '1';
    op.arg.mul.high   := '0';
    op.arg.mul.divide := '1';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_div;
  
  function f_decode_divu (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '-';
    op.arg.mul.sextb  := '0';
    op.arg.mul.high   := '0';
    op.arg.mul.divide := '1';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_divu;
  
  function f_decode_rem  (x : std_logic_vector) return t_opa_op is
    variable op : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '1';
    op.arg.mul.sextb  := '1';
    op.arg.mul.high   := '1';
    op.arg.mul.divide := '1';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_rem;
  
  function f_decode_remu (x : std_logic_vector) return t_opa_op is
    variable op   : t_opa_op := f_parse_rtype(x);
  begin
    op.arg.mul.sexta  := '0';
    op.arg.mul.sextb  := '0';
    op.arg.mul.high   := '1';
    op.arg.mul.divide := '1';
    op.arg.smode      := c_opa_slow_mul;
    op.fast           := '0';
    return op;
  end f_decode_remu;
  
  function f_opa_accept_rv32(config : t_opa_config) return std_logic is
  begin
    assert (config.reg_width = 32) report "RV32 requires 32-bit registers" severity failure;
    return '1';
  end f_opa_accept_rv32;
  
  function f_opa_decode_rv32(config : t_opa_config; x : std_logic_vector) return t_opa_op is
    constant c_opcode : std_logic_vector(6 downto 0) := x( 6 downto  0);
    constant c_funct3 : std_logic_vector(2 downto 0) := x(14 downto 12);
    constant c_funct7 : std_logic_vector(6 downto 0) := x(31 downto 25);
  begin
    case c_opcode is
      when "0110111"  => return f_decode_lui(x);
      when "0010111"  => return f_decode_auipc(x);
      when "1101111"  => return f_decode_jal(x);
      when "1100111"  => --
        case c_funct3 is
          when "000"  => return f_decode_jalr(x);
          when others => return c_opa_op_bad;
        end case;
      when "1100011"  => --
        case c_funct3 is
          when "000"  => return f_decode_beq(x);
          when "001"  => return f_decode_bne(x);
          when "100"  => return f_decode_blt(x);
          when "101"  => return f_decode_bge(x);
          when "110"  => return f_decode_bltu(x);
          when "111"  => return f_decode_bgeu(x);
          when others => return c_opa_op_bad;
        end case;
      when "0000011"  => --
        case c_funct3 is
          when "000"  => return f_decode_lb(x);
          when "001"  => return f_decode_lh(x);
          when "010"  => return f_decode_lw(x);
          when "100"  => return f_decode_lbu(x);
          when "101"  => return f_decode_lhu(x);
          when others => return c_opa_op_bad;
        end case;
      when "0100011"  => --
        case c_funct3 is
          when "000"  => return f_decode_sb(x);
          when "001"  => return f_decode_sh(x);
          when "010"  => return f_decode_sw(x);
          when others => return c_opa_op_bad;
        end case;
      when "0010011"  => --
        case c_funct3 is
          when "000"  => return f_decode_addi(x);
          when "010"  => return f_decode_slti(x);
          when "011"  => return f_decode_sltiu(x);
          when "100"  => return f_decode_xori(x);
          when "110"  => return f_decode_ori(x);
          when "111"  => return f_decode_andi(x);
          when "001"  => --
            case c_funct7 is
              when "0000000" => return f_decode_slli(x);
              when others    => return c_opa_op_bad;
            end case;
          when "101"  => --
            case c_funct7 is
              when "0000000" => return f_decode_srli(x);
              when "0100000" => return f_decode_srai(x);
              when others    => return c_opa_op_bad;
            end case;
          when others     => return c_opa_op_bad;
        end case;
      when "0110011"      => --
        case c_funct7 is
          when "0000000"  => --
            case c_funct3 is
              when "000"  => return f_decode_add(x);
              when "001"  => return f_decode_sll(x);
              when "010"  => return f_decode_slt(x);
              when "011"  => return f_decode_sltu(x);
              when "100"  => return f_decode_xor(x);
              when "101"  => return f_decode_srl(x);
              when "110"  => return f_decode_or(x);
              when "111"  => return f_decode_and(x);
              when others => return c_opa_op_bad;
            end case;
          when "0100000"  => --
            case c_funct3 is
              when "000"  => return f_decode_sub(x);
              when "101"  => return f_decode_sra(x);
              when others => return c_opa_op_bad;
            end case;
          when "0000001"  => --
            case c_funct3 is
              when "000"  => return f_decode_mul(x);
              when "001"  => return f_decode_mulh(x);
              when "010"  => return f_decode_mulhsu(x);
              when "011"  => return f_decode_mulhu(x);
              when "100"  => return f_decode_div(x);
              when "101"  => return f_decode_divu(x);
              when "110"  => return f_decode_rem(x);
              when "111"  => return f_decode_remu(x);
              when others => return c_opa_op_bad;
            end case;
          when others     => return c_opa_op_bad;
        end case;
      when others         => return c_opa_op_bad;
    end case;
  end f_opa_decode_rv32;
end opa_riscv_pkg;
