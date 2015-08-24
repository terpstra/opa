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
  
  type t_riscv_rtype is record
    archb  : std_logic_vector( 4 downto 0);
    archa  : std_logic_vector( 4 downto 0);
    archx  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_rtype;
  
  type t_riscv_itype is record
    archa  : std_logic_vector( 4 downto 0);
    archx  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_itype;
  
  type t_riscv_stype is record
    archb  : std_logic_vector( 4 downto 0);
    archa  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_stype;
  
  type t_riscv_sbtype is record
    archb  : std_logic_vector( 4 downto 0);
    archa  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_sbtype;
  
  type t_riscv_utype is record
    archx  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_utype;
  
  type t_riscv_ujtype is record
    archx  : std_logic_vector( 4 downto 0);
    imm    : std_logic_vector(31 downto 0);
  end record t_riscv_ujtype;
  
  function f_parse_rtype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_rtype;
  function f_parse_itype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_itype;
  function f_parse_stype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_stype;
  function f_parse_sbtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_sbtype;
  function f_parse_utype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_utype;
  function f_parse_ujtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_ujtype;
  function f_zero(x : std_logic_vector(4 downto 0)) return std_logic;
  function f_one (x : std_logic_vector(4 downto 0)) return std_logic;
  
  function f_decode_lui  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_auipc(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_jal  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  function f_decode_jalr (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
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
  function f_decode      (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op;
  
end package;

package body opa_isa_pkg is
  
  function f_parse_rtype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_rtype is
    variable result : t_riscv_rtype;
  begin
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.archx := x(11 downto  7);
    result.imm   := (others => '-');
    return result;
  end f_parse_rtype;
  
  function f_parse_itype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_itype is
    variable result : t_riscv_itype;
  begin
    result.archa := x(19 downto 15);
    result.archx := x(11 downto  7);
    result.imm := (others => x(31));
    result.imm(10 downto 0) := x(30 downto 20);
    return result;
  end f_parse_itype;
  
  function f_parse_stype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_stype is
    variable result : t_riscv_stype;
  begin
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.imm := (others => x(31));
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 0) := x(11 downto 7);
    return result;
  end f_parse_stype;
  
  function f_parse_sbtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_sbtype is
    variable result : t_riscv_sbtype;
  begin
    result.archb := x(24 downto 20);
    result.archa := x(19 downto 15);
    result.imm := (others => x(31));
    result.imm(11)          := x(7);
    result.imm(10 downto 5) := x(30 downto 25);
    result.imm( 4 downto 1) := x(11 downto 8);
    result.imm(0)           := '0';
    return result;
  end f_parse_sbtype;
  
  function f_parse_utype (x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_utype is
    variable result : t_riscv_utype;
  begin
    result.archx := x(11 downto  7);
    result.imm(31 downto 12) := x(31 downto 12);
    result.imm(11 downto  0) := (others => '0');
    return result;
  end f_parse_utype;
  
  function f_parse_ujtype(x : std_logic_vector(c_op_wide-1 downto 0)) return t_riscv_ujtype is
    variable result : t_riscv_ujtype;
  begin
    result.archx := x(11 downto  7);
    result.imm := (others => x(31));
    result.imm(19 downto 12) := x(19 downto 12);
    result.imm(11)           := x(20);
    result.imm(10 downto  1) := x(30 downto 21);
    result.imm(0) := '0';
    return result;
  end f_parse_ujtype;
   
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
  
  -- !!! make this a fault handler invocation
  constant c_bad_op : t_opa_op := (
    jump  => "--",
    dest  => "--",
    push  => '-',
    geta  => '-',
    getb  => '-',
    setx  => '-',
    archa => (others => '-'),
    archb => (others => '-'),
    archx => (others => '-'),
    fast  => '-',
    imm   => (others => '-'),
    arg   => (others => '-'));
  
  function f_decode_lui  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_utype := f_parse_utype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1010"; -- X = B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '0';
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := (others => '-');
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_lui;
  
  function f_decode_auipc(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_utype := f_parse_utype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '0'; -- PC
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := (others => '-');
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_auipc;
  
  function f_decode_jal  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_ujtype := f_parse_ujtype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    -- !!! this one needs to be somehow confirmed in EU still.
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1100"; -- X = A
    fast.fault  := '0'; -- no need to fault; never mispredicted
    op.jump     := c_opa_jump_always;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := f_one(fmt.archx);
    op.geta     := '0'; -- PC
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := (others => '-');
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_jal;
  
  function f_decode_jalr (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1100"; -- X = A
    fast.fault  := '1';
    op.jump     := c_opa_jump_always;
    if (f_zero(fmt.archx) and f_one(fmt.archa)) = '1' then
      op.dest   := c_opa_jump_return_stack;
    else
      op.dest   := c_opa_jump_unknown;
    end if;      
    op.push     := f_one(fmt.archx);
    op.geta     := '0'; -- a = PC
    op.getb     := '1'; -- b = register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := (others => '-');
    op.archb    := fmt.archa; -- Not a bug! We want the target in regb
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_jalr;
  
  function f_decode_beq  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0';
    adder.notb  := '-'; -- We don't actually use the adder
    adder.cin   := '-';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_beq;
  
  function f_decode_bne  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1';
    adder.notb  := '-'; -- We don't actually use the adder
    adder.cin   := '-';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bne;
  
  function f_decode_blt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_blt;
  
  function f_decode_bge  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '1';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bge;
  
  function f_decode_bltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bltu;
  
  function f_decode_bgeu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_sbtype := f_parse_sbtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0'; -- x=(a>=b)=(a-b>=0)=overflow(a-b)=overflow(a+!b+1)
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '0';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '1';
    if fmt.imm(fmt.imm'high) = '1' then
      op.jump   := c_opa_jump_often; -- static prediction: negative = taken
    else
      op.jump   := c_opa_jump_seldom;
    end if;
    op.dest     := c_opa_jump_add_immediate;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '1';
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_bgeu;
  
  function f_decode_lb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lb;
  
  function f_decode_lh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lh;
  
  function f_decode_lw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_word;
    ldst.sext   := '1';
    slow.mode   := c_opa_slow_load;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lw;
  
  function f_decode_lbu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '0';
    slow.mode   := c_opa_slow_load;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lbu;
  
  function f_decode_lhu  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '0';
    slow.mode   := c_opa_slow_load;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0';
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_lhu;
  
  function f_decode_sb   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_stype := f_parse_stype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_byte;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sb;
  
  function f_decode_sh   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_stype := f_parse_stype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_half;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sh;
  
  function f_decode_sw   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_stype := f_parse_stype(x);
    variable ldst  : t_opa_ldst;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    ldst.size   := c_opa_ldst_word;
    ldst.sext   := '-';
    slow.mode   := c_opa_slow_store;
    slow.table  := f_opa_slow_from_ldst(ldst);
    op.jump     := c_opa_jump_seldom; -- segfault
    op.dest     := c_opa_jump_unknown;
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := '0';
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := (others => '-');
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sw;
  
  function f_decode_addi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_addi;
  
  function f_decode_slti (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_slti;
  
  function f_decode_sltiu(x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sltiu;
  
  function f_decode_xori (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "0110"; -- X = A xor B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_xori;
  
  function f_decode_ori  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1110"; -- X = A or B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_ori;
  
  function f_decode_andi (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1000"; -- X = A and B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '0'; -- immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_andi;
  
  function f_decode_slli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '0';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0'; -- b = immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_slli;
  
  function f_decode_srli (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '1';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0'; -- b = immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srli;
  
  function f_decode_srai (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_itype := f_parse_itype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '1';
    shift.sext  := '1';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '0'; -- b = immediate
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := (others => '-');
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srai;
  
  function f_decode_add  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0';
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_add;
  
  function f_decode_sub  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '0';
    adder.notb  := '1';
    adder.cin   := '1';
    adder.sign  := '-';
    fast.mode   := c_opa_fast_addl;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sub;
  
  function f_decode_slt  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '1';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_slt;
  
  function f_decode_sltu (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable adder : t_opa_adder;
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    adder.nota  := '1'; -- x=(a<b)=(b-a>0)=(b-a-1>=0)=overflow(b-a-1)=overflow(b+!a)
    adder.notb  := '0';
    adder.cin   := '0';
    adder.sign  := '0';
    fast.mode   := c_opa_fast_addh;
    fast.table  := f_opa_fast_from_adder(adder);
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_sltu;
  
  function f_decode_xor  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "0110"; -- X = A xor B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_xor;
  
  function f_decode_or   (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1110"; -- X = A or B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_or;
  
  function f_decode_and  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable fast  : t_opa_fast;
    variable op    : t_opa_op;
  begin
    fast.mode   := c_opa_fast_lut;
    fast.table  := "1000"; -- X = A and B
    fast.fault  := '0';
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- register
    op.getb     := '1'; -- register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.fast     := '1';
    op.imm      := fmt.imm;
    op.arg      := f_opa_arg_from_fast(fast);
    return op;
  end f_decode_and;
  
  function f_decode_sll  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '0';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sll;
  
  function f_decode_srl  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '1';
    shift.sext  := '0';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_srl;
  
  function f_decode_sra  (x : std_logic_vector(c_op_wide-1 downto 0)) return t_opa_op is
    constant fmt   : t_riscv_rtype := f_parse_rtype(x);
    variable shift : t_opa_shift;
    variable slow  : t_opa_slow;
    variable op    : t_opa_op;
  begin
    shift.right := '1';
    shift.sext  := '1';
    slow.mode   := c_opa_slow_shift;
    slow.table  := f_opa_slow_from_shift(shift);
    op.jump     := c_opa_jump_never;
    op.dest     := "--";
    op.push     := '0';
    op.geta     := '1'; -- a = register
    op.getb     := '1'; -- b = register
    op.setx     := not f_zero(fmt.archx);
    op.archa    := fmt.archa;
    op.archb    := fmt.archb;
    op.archx    := fmt.archx;
    op.imm      := fmt.imm;
    op.fast     := '0';
    op.arg      := f_opa_arg_from_slow(slow);
    return op;
  end f_decode_sra;
  
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
          when others => return c_bad_op;
        end case;
      when "1100011"  => --
        case c_funct3 is
          when "000"  => return f_decode_beq(x);
          when "001"  => return f_decode_bne(x);
          when "100"  => return f_decode_blt(x);
          when "101"  => return f_decode_bge(x);
          when "110"  => return f_decode_bltu(x);
          when "111"  => return f_decode_bgeu(x);
          when others => return c_bad_op;
        end case;
      when "0000011"  => --
        case c_funct3 is
          when "000"  => return f_decode_lb(x);
          when "001"  => return f_decode_lh(x);
          when "010"  => return f_decode_lw(x);
          when "100"  => return f_decode_lbu(x);
          when "101"  => return f_decode_lhu(x);
          when others => return c_bad_op;
        end case;
      when "0100011"  => --
        case c_funct3 is
          when "000"  => return f_decode_sb(x);
          when "001"  => return f_decode_sh(x);
          when "010"  => return f_decode_sw(x);
          when others => return c_bad_op;
        end case;
      when "0010011"  => --
        case c_funct3 is
          when "000"  => return f_decode_addi(x);
          when "010"  => return f_decode_slti(x);
          when "011"  => return f_decode_sltiu(x);
          when "100"  => return f_decode_xori(x);
          when "110"  => return f_decode_ori(x);
          when "111"  => return f_decode_andi(x);
          when "001"  => return f_decode_slli(x); -- !!! check funct7?
          when "101"  => return f_decode_srli(x); -- !!! srai
          when others => return c_bad_op;
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
              when others => return c_bad_op;
            end case;
          when "0100000"  => --
            case c_funct3 is
              when "000"  => return f_decode_sub(x);
              when "101"  => return f_decode_sra(x);
              when others => return c_bad_op;
            end case;
          when others     => return c_bad_op;
        end case;
      when others         => return c_bad_op;
    end case;
  end f_decode;
end opa_isa_pkg;
