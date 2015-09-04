library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;

-- RISC-V ISA
package opa_isa_pkg is

  constant c_op_wide : natural := 32;
  
  function f_zero(x : std_logic_vector(4 downto 0)) return std_logic;
  function f_one (x : std_logic_vector(4 downto 0)) return std_logic;
  function f_parse_rtype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_parse_itype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_parse_stype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_parse_sbtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_parse_utype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  
  function f_decode_jal  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_jalr (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lui  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_auipc(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_beq  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_bne  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_blt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_bge  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_bltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_bgeu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lbu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_lhu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_addi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_slti (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sltiu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_xori (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_ori  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_andi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_slli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_srli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_srai (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_add  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sub  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sll  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_slt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_xor  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_srl  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_sra  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_or   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_and  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_mul  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_mulh (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_mulhsu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_mulhu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_div  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_divu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_rem  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_remu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode      (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  
end package;

package body opa_isa_pkg is
  
  function f_zero(x : std_logic_vector(4 downto 0)) return std_logic is
    constant c_zero : std_logic_vector(x'range) := (others => '0');
  begin
    if x = c_zero then
      return '1';
    else
      return '0';
    end if;
  end f_zero;
  
  function f_one(x : std_logic_vector(4 downto 0)) return std_logic is
    constant c_one : std_logic_vector(x'range) := (0 => '1', others => '0');
  begin
    if x = c_one then
      return '1';
    else
      return '0';
    end if;
  end f_one;
  
  function f_parse_rtype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable result : t_opa_op := c_opa_op_bad;
  begin
    result.bad   := '0';
    result.jump  := c_opa_jump_never;
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.archx := x(11 downto  7);
    result.geta  := '1'; -- use both input registers
    result.getb  := '1';
    result.setx  := not f_zero(result.archx);
    return result;
  end f_parse_rtype;
  
  function f_parse_itype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable result : t_opa_op := c_opa_op_bad;
  begin
    result.bad   := '0';
    result.jump  := c_opa_jump_never;
    result.archa := x(19 downto 15);
    result.archx := x(11 downto  7);
    result.getb  := '0'; -- immediate
    result.geta  := '1';
    result.setx  := not f_zero(result.archx);
    result.imm := (others => x(31));
    result.imm(10 downto 0) := x(30 downto 20);
    return result;
  end f_parse_itype;
  
  function f_parse_stype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable result : t_opa_op := c_opa_op_bad;
  begin
    result.bad   := '0';
    result.jump  := c_opa_jump_never; -- never predict segfault
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.getb  := '1';
    result.geta  := '1';
    result.setx  := '0';
    result.imm := (others => x(31));
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 0) := x(11 downto 7);
    return result;
  end f_parse_stype;
  
  function f_parse_sbtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable result : t_opa_op := c_opa_op_bad;
  begin
    result.bad   := '0';
    if x(31) = '1' then
      result.jump := c_opa_jump_often; -- static prediction: negative = taken
    else
      result.jump := c_opa_jump_seldom;
    end if;
    result.dest  := c_opa_jump_add_immediate;
    result.push  := '0';
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.getb  := '1';
    result.geta  := '1';
    result.setx  := '0';
    result.imm := (others => x(31));
    result.imm(11)          := x(7);
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 1) := x(11 downto 8);
    result.imm(0)           := '0';
    return result;
  end f_parse_sbtype;
  
  function f_parse_utype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable result : t_opa_op := c_opa_op_bad;
  begin
    result.bad   := '0';
    result.jump  := c_opa_jump_never;
    result.archx := x(11 downto  7);
    result.geta  := '0';
    result.getb  := '0';
    result.setx  := not f_zero(result.archx);
    result.imm(31 downto 12) := x(31 downto 12);
    result.imm(11 downto  0) := (others => '0');
    return result;
  end f_parse_utype;
  
  -- JAL has a special format
  function f_decode_jal  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op := c_opa_op_bad;
  begin
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    adder.fault := '-';
    fast.mode   := c_opa_fast_jump;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.bad      := '0';
    op.jump     := c_opa_jump_always;
    op.dest     := c_opa_jump_add_immediate;
    op.geta     := '0'; -- PC
    op.getb     := '0'; -- imm
    op.archx    := x(11 downto  7);
    op.setx     := not f_zero(op.archx);
    op.push     := f_one(op.archx);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    -- a very strange immediate format:
    op.imm := (others => x(31));
    op.imm(19 downto 12) := x(19 downto 12);
    op.imm(11)           := x(20);
    op.imm(10 downto  1) := x(30 downto 21);
    op.imm(0) := '0';
    return op;
  end f_decode_jal;
  
  function f_decode_jalr (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    adder.fault := '-';
    fast.mode   := c_opa_fast_jump;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.jump     := c_opa_jump_always;
    op.push     := f_one(op.archx);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    if (f_zero(op.archx) and f_one(op.archb)) = '1' then
      op.dest   := c_opa_jump_return_stack;
    else
      op.dest   := c_opa_jump_unknown;
    end if;      
    return op;
  end f_decode_jalr;
  
  function f_decode_lui  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_utype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("1010"); -- X = B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_lui;
  
  function f_decode_auipc(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_utype(x);
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addl;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_auipc;
  
  function f_decode_beq  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '1';
    adder.nota  := '1';
    adder.notb  := '0';
    adder.cin   := '1';
    adder.sign  := '0';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_beq;
  
  function f_decode_bne  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '1';
    adder.nota  := '0';
    adder.notb  := '1';
    adder.cin   := '0';
    adder.sign  := '0';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bne;
  
  function f_decode_blt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_blt;
  
  function f_decode_bge  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '0';
    adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '1';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bge;
  
  function f_decode_bltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bltu;
  
  function f_decode_bgeu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_sbtype(x);
    adder.eq    := '0';
    adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '0';
    adder.fault := '1';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bgeu;
  
  function f_decode_lb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lb;
  
  function f_decode_lh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lh;
  
  function f_decode_lw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    ldst.size   := c_opa_ldst_word;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lw;
  
  function f_decode_lbu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '0';
    slow.mode   := c_opa_slow_load;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lbu;
  
  function f_decode_lhu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '0';
    slow.mode   := c_opa_slow_load;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lhu;
  
  function f_decode_sb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_stype(x);
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sb;
  
  function f_decode_sh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_stype(x);
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sh;
  
  function f_decode_sw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_stype(x);
    ldst.size   := c_opa_ldst_word;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.raw    := f_opa_slow_from_ldst(ldst);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sw;
  
  function f_decode_addi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addl;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_addi;
  
  function f_decode_slti (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_slti;
  
  function f_decode_sltiu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sltiu;
  
  function f_decode_xori (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("0110"); -- X = A xor B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_xori;
  
  function f_decode_ori  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("1110"); -- X = A or B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_ori;
  
  function f_decode_andi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("1000"); -- X = A and B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_andi;
  
  function f_decode_slli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    shift.right := '0';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_slli;
  
  function f_decode_srli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    shift.right := '1';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srli;
  
  function f_decode_srai (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_itype(x);
    shift.right := '1';
    shift.sext  := '1';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srai;
  
  function f_decode_add  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addl;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_add;
  
  function f_decode_sub  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    adder.eq    := '0';
    adder.nota  := '0';
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '-';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addl;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sub;
  
  function f_decode_slt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_slt;
  
  function f_decode_sltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    adder.eq    := '0';
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    adder.fault := '0';
    fast.mode   := c_opa_fast_addh;
    fast.raw    := f_opa_fast_from_adder(adder);
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sltu;
  
  function f_decode_xor  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("0110"); -- X = A xor B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_xor;
  
  function f_decode_or   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("1110"); -- X = A or B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_or;
  
  function f_decode_and  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    fast.mode   := c_opa_fast_lut;
    fast.raw    := f_opa_fast_from_lut("1000"); -- X = A and B
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_and;
  
  function f_decode_sll  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    shift.right := '0';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sll;
  
  function f_decode_srl  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    shift.right := '1';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srl;
  
  function f_decode_sra  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    op := f_parse_rtype(x);
    shift.right := '1';
    shift.sext  := '1';
    slow.mode   := c_opa_slow_shift;
    slow.raw    := f_opa_slow_from_shift(shift);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sra;
  
  function f_decode_mul  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '-';
    mul.sextb   := '-';
    mul.high    := '0';
    mul.divide  := '0';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_mul;
  
  function f_decode_mulh (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '1';
    mul.sextb   := '1';
    mul.high    := '1';
    mul.divide  := '0';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_mulh;
  
  function f_decode_mulhsu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '1';
    mul.sextb   := '0';
    mul.high    := '1';
    mul.divide  := '0';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_mulhsu;
  
  function f_decode_mulhu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '0';
    mul.sextb   := '0';
    mul.high    := '1';
    mul.divide  := '0';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_mulhu;
  
  function f_decode_div  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '-';
    mul.sextb   := '1';
    mul.high    := '0';
    mul.divide  := '1';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_div;
  
  function f_decode_divu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '-';
    mul.sextb   := '0';
    mul.high    := '0';
    mul.divide  := '1';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_divu;
  
  function f_decode_rem  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '1';
    mul.sextb   := '1';
    mul.high    := '1';
    mul.divide  := '1';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_rem;
  
  function f_decode_remu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    variable mul  : t_opa_mul;
    variable slow : t_opa_slow;
    variable op   : t_opa_op;
  begin
    op := f_parse_rtype(x);
    mul.sexta   := '0';
    mul.sextb   := '0';
    mul.high    := '1';
    mul.divide  := '1';
    slow.mode   := c_opa_slow_mul;
    slow.raw    := f_opa_slow_from_mul(mul);
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_remu;
  
  function f_decode(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
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
  end f_decode;
end opa_isa_pkg;
