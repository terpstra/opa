library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;

package opa_functions_pkg is

  function f_opa_log2(x : natural) return natural;
  function f_opa_bit(x : boolean) return std_logic;
  function f_opa_choose(x : boolean; y : natural; z : natural) return natural; -- x?y:z
  function f_opa_choose(x : boolean; y : string; z : string) return string;
  function f_opa_or(x : std_logic_vector) return std_logic;
  function f_opa_and(x : std_logic_vector) return std_logic;
  
  -- Decode config into useful values
  function f_opa_decoders (conf : t_opa_config) return natural;
  function f_opa_executers(conf : t_opa_config) return natural;
  function f_opa_num_fast (conf : t_opa_config) return natural;
  function f_opa_num_slow (conf : t_opa_config) return natural;
  function f_opa_num_ldst (conf : t_opa_config) return natural;
  function f_opa_num_stat (conf : t_opa_config) return natural;
  function f_opa_num_arch (conf : t_opa_config) return natural;
  function f_opa_num_back (conf : t_opa_config) return natural;
  function f_opa_num_aux  (conf : t_opa_config) return natural;
  function f_opa_num_fetch(conf : t_opa_config) return natural; -- in bytes
  function f_opa_arch_wide(conf : t_opa_config) return natural;
  function f_opa_back_wide(conf : t_opa_config) return natural;
  function f_opa_stat_wide(conf : t_opa_config) return natural;
  function f_opa_adr_wide (conf : t_opa_config) return natural;
  function f_opa_aux_wide (conf : t_opa_config) return natural;
  function f_opa_reg_wide (conf : t_opa_config) return natural;
  function f_opa_arg_wide (conf : t_opa_config) return natural;
  function f_opa_imm_wide (conf : t_opa_config) return natural;
  function f_opa_dec_wide (conf : t_opa_config) return natural;
  function f_opa_fetch_wide(conf : t_opa_config) return natural;
  
  -- Mapping of execution units
  function f_opa_support_fp(conf : t_opa_config) return boolean;
  function f_opa_fast_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_slow_index(conf : t_opa_config; u : natural) return natural;

  type t_opa_matrix is array(natural range <>, natural range <>) of std_logic;
  
  function "not"(x : t_opa_matrix) return t_opa_matrix;
  function "or" (x, y : t_opa_matrix) return t_opa_matrix;
  function "and"(x, y : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_select_row(x : t_opa_matrix; i : natural) return std_logic_vector;
  function f_opa_select_col(x : t_opa_matrix; j : natural) return std_logic_vector;
  function f_opa_dup_row(n : natural; r : std_logic_vector) return t_opa_matrix;
  function f_opa_dup_col(n : natural; r : std_logic_vector) return t_opa_matrix;
  function f_opa_concat(x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_labels(n : natural; b : natural := 0; o : natural := 0) return t_opa_matrix;
  function f_opa_decrement(x : t_opa_matrix; y : natural) return t_opa_matrix;
  
  function f_opa_transpose(x : t_opa_matrix) return t_opa_matrix;
  function f_opa_product(x : t_opa_matrix; y : std_logic_vector) return std_logic_vector;
  function f_opa_product(x, y : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_match(x, y : t_opa_matrix) return t_opa_matrix; -- do any rows match?
  function f_opa_match_index(n : natural; x : t_opa_matrix) return t_opa_matrix;
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector;
  function f_opa_compose(x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_1hot_dec(x : std_logic_vector) return std_logic_vector;
  function f_opa_1hot_dec(x : t_opa_matrix) return t_opa_matrix;
  
  -- Take the '1' in the row with the biggest index
  function f_opa_pick_small(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick_big(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick_big(x : t_opa_matrix) return t_opa_matrix;
  function f_opa_reverse(x : std_logic_vector) return std_logic_vector;
  
  -- Define the arguments needed for operations in our execution units
  constant c_arg_wide : natural := 8;
  
  -- General information every instruction must provide
  type t_opa_op is record
    -- A bad instruction
    bad   : std_logic;
    -- Information for the decode stage
    jump  : std_logic;
    take  : std_logic; -- true => jump
    force : std_logic; -- true => take
    pop   : std_logic; -- pop  return stack; '-' when jump=0
    push  : std_logic; -- push return stack; '-' when jump=0
    -- Information for the rename stage
    geta  : std_logic; -- 1=rega, 0=PC
    getb  : std_logic; -- 1=regb, 0=imm
    setx  : std_logic;
    archa : std_logic_vector(c_log_arch-1 downto 0);
    archb : std_logic_vector(c_log_arch-1 downto 0);
    archx : std_logic_vector(c_log_arch-1 downto 0);
    -- Information for the issue stage
    fast  : std_logic; -- goes to fast/slow EU
    -- Information for the execute stage
    imm   : std_logic_vector(c_imm_wide-1 downto 0);
    immb  : std_logic_vector(c_imm_wide-1 downto 0); -- branch immediates; less cases than imm.
    arg   : std_logic_vector(c_arg_wide-1 downto 0);
  end record t_opa_op;
  
  constant c_opa_op_bad : t_opa_op := (
    bad   => '1',
    jump  => '-',
    take  => '-',
    force => '-',
    pop   => '-',
    push  => '-',
    geta  => '-',
    getb  => '-',
    setx  => '-',
    archa => (others => '-'),
    archb => (others => '-'),
    archx => (others => '-'),
    fast  => '-',
    imm   => (others => '-'),
    immb  => (others => '-'),
    arg   => (others => '-'));
  
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
  -- LM32 needs to fit sign extension in here somehow
  
  type t_opa_fast is record
    mode  : std_logic_vector(1 downto 0);
    raw   : std_logic_vector(5 downto 0);
  end record t_opa_fast;
  
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
  constant c_opa_slow_load  : std_logic_vector(1 downto 0) := "10";
  constant c_opa_slow_store : std_logic_vector(1 downto 0) := "11";
  
  type t_opa_slow is record
    mode  : std_logic_vector(1 downto 0);
    raw   : std_logic_vector(5 downto 0);
  end record t_opa_slow;
  
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
    size   : std_logic_vector(1 downto 0); -- 1,2,4,8
    sext   : std_logic;
  end record t_opa_ldst;
  
  -- Encode to/from types
  function f_opa_arg_from_fast(x : t_opa_fast) return std_logic_vector;
  function f_opa_arg_from_slow(x : t_opa_slow) return std_logic_vector;
  function f_opa_fast_from_arg(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_fast;
  function f_opa_slow_from_arg(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_slow;
  
  function f_opa_fast_from_adder(x : t_opa_adder) return std_logic_vector;
  function f_opa_fast_from_lut  (x : std_logic_vector(3 downto 0)) return std_logic_vector;
  function f_opa_slow_from_mul  (x : t_opa_mul)   return std_logic_vector;
  function f_opa_slow_from_shift(x : t_opa_shift) return std_logic_vector;
  function f_opa_slow_from_ldst (x : t_opa_ldst)  return std_logic_vector;
  function f_opa_adder_from_fast(x : std_logic_vector(5 downto 0)) return t_opa_adder;
  function f_opa_lut_from_fast  (x : std_logic_vector(5 downto 0)) return std_logic_vector;
  function f_opa_mul_from_slow  (x : std_logic_vector(5 downto 0)) return t_opa_mul;
  function f_opa_shift_from_slow(x : std_logic_vector(5 downto 0)) return t_opa_shift;
  function f_opa_ldst_from_slow (x : std_logic_vector(5 downto 0)) return t_opa_ldst;

end package;

package body opa_functions_pkg is

  function f_opa_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return f_opa_log2((x+1)/2)+1;
    end if;
  end f_opa_log2;
  
  function f_opa_bit(x : boolean) return std_logic is
  begin
    if x then return '1'; else return '0'; end if;
  end f_opa_bit;
  
  function f_opa_choose(x : boolean; y : natural; z : natural) return natural is
  begin
    if x then return y; else return z; end if;
  end f_opa_choose;
  
  function f_opa_choose(x : boolean; y : string; z : string) return string is
  begin
    if x then return y; else return z; end if;
  end f_opa_choose;
  
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
  
  function f_opa_decoders(conf : t_opa_config) return natural is
  begin
    return conf.num_decode;
  end f_opa_decoders;
  
  function f_opa_executers(conf : t_opa_config) return natural is
  begin
    return conf.num_fast + conf.num_slow;
  end f_opa_executers;
  
  function f_opa_num_fast(conf : t_opa_config) return natural is
  begin
    return conf.num_fast;
  end f_opa_num_fast;
  
  function f_opa_num_slow(conf : t_opa_config) return natural is
  begin
    return conf.num_slow;
  end f_opa_num_slow;
  
  function f_opa_num_ldst(conf : t_opa_config) return natural is
  begin
    return conf.num_slow;
  end f_opa_num_ldst;
  
  function f_opa_num_stat(conf : t_opa_config) return natural is
  begin
    return conf.num_stat;
  end f_opa_num_stat;
  
  function f_opa_num_arch(conf : t_opa_config) return natural is
  begin
    return 2**c_log_arch;
  end f_opa_num_arch;
  
  function f_opa_num_back(conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 1;
  begin
    return f_opa_num_arch(conf) +
           f_opa_num_stat(conf) +
           f_opa_decoders(conf)*pipeline_depth;
  end f_opa_num_back;
  
  function f_opa_num_aux(conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 4;
  begin
    return (f_opa_num_stat(conf) + f_opa_decoders(conf)*pipeline_depth) 
           / f_opa_decoders(conf);
  end f_opa_num_aux;
  
  function f_opa_num_fetch(conf : t_opa_config) return natural is
  begin
    return f_opa_decoders(conf) * c_op_avg_size;
  end f_opa_num_fetch;
  
  function f_opa_arch_wide(conf : t_opa_config) return natural is
  begin 
    return c_log_arch;
  end f_opa_arch_wide;
  
  function f_opa_back_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_back(conf));
  end f_opa_back_wide;
  
  function f_opa_stat_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_stat(conf) + f_opa_decoders(conf));
  end f_opa_stat_wide;
  
  function f_opa_adr_wide(conf : t_opa_config) return natural is
  begin
    return conf.adr_width;
  end f_opa_adr_wide;
  
  function f_opa_aux_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_aux(conf));
  end f_opa_aux_wide;
  
  function f_opa_reg_wide(conf : t_opa_config) return natural is
  begin
    return 2**conf.log_width;
  end f_opa_reg_wide;
  
  function f_opa_arg_wide(conf : t_opa_config) return natural is
  begin
    return c_arg_wide;
  end f_opa_arg_wide;
  
  function f_opa_imm_wide(conf : t_opa_config) return natural is
  begin
    return c_imm_wide;
  end f_opa_imm_wide;
  
  function f_opa_dec_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_decoders(conf));
  end f_opa_dec_wide;
  
  function f_opa_fetch_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_fetch(conf));
  end f_opa_fetch_wide;
  
  function f_opa_support_fp(conf : t_opa_config) return boolean is
  begin
    return conf.ieee_fp;
  end f_opa_support_fp;
  
  function f_opa_fast_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u;
  end f_opa_fast_index;
  
  function f_opa_slow_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + conf.num_fast;
  end f_opa_slow_index;
  
  --------------------------------------------------------------------------------------
  
  function "not"(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := not x(i, j);
      end loop;
    end loop;
    return result;
  end "not";
  
  function "or"(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    assert (x'low(1)  = y'low(1))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(1) = y'high(1)) report "matrix-matrix dimension mismatch" severity failure;
    assert (x'low(2)  = y'low(2))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(2) = y'high(2)) report "matrix-matrix dimension mismatch" severity failure;
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := x(i, j) or y(i, j);
      end loop;
    end loop;
    return result;
  end "or";
  
  function "and"(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    assert (x'low(1)  = y'low(1))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(1) = y'high(1)) report "matrix-matrix dimension mismatch" severity failure;
    assert (x'low(2)  = y'low(2))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(2) = y'high(2)) report "matrix-matrix dimension mismatch" severity failure;
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := x(i, j) and y(i, j);
      end loop;
    end loop;
    return result;
  end "and";
  
  function f_opa_select_row(x : t_opa_matrix; i : natural) return std_logic_vector is
    variable result : std_logic_vector(x'range(2));
  begin
    for j in result'range loop
      result(j) := x(i, j);
    end loop;
    return result;
  end f_opa_select_row;
  
  function f_opa_select_col(x : t_opa_matrix; j : natural) return std_logic_vector is
    variable result : std_logic_vector(x'range(1));
  begin
    for i in result'range loop
      result(i) := x(i, j);
    end loop;
    return result;
  end f_opa_select_col;
  
  function f_opa_dup_row(n : natural; r : std_logic_vector) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, r'range);
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := r(j);
      end loop;
    end loop;
    return result;
  end f_opa_dup_row;
  
  function f_opa_concat(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), y'high(2)+x'length(2) downto y'low(2));
  begin
    assert (x'low(1)  = y'low(1))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(1) = y'high(1)) report "matrix-matrix dimension mismatch" severity failure;
    
    for i in result'range(1) loop
      for j in x'length(2) downto 1 loop
        result(i,j-1+y'high(2)+1) := x(i,j-1+x'low(2));
      end loop;
      for j in y'range(2) loop
        result(i,j) := y(i,j);
      end loop;
    end loop;
    return result;
  end f_opa_concat;

  function f_opa_dup_col(n : natural; r : std_logic_vector) return t_opa_matrix is
    variable result : t_opa_matrix(r'range, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := r(i);
      end loop;
    end loop;
    return result;
  end f_opa_dup_col;
  
  function f_opa_labels(n : natural; b : natural := 0; o : natural := 0) return t_opa_matrix is
    constant bits : natural := f_opa_choose(b=0, f_opa_log2(n), b);
    variable result : t_opa_matrix(n-1 downto 0, bits-1 downto 0);
    variable row : unsigned(result'range(2));
  begin
    for i in result'range(1) loop
      row := to_unsigned(i+o, row'length);
      for j in result'range(2) loop
        result(i,j) := row(j);
      end loop;
    end loop;
    return result;
  end f_opa_labels;
  
  function f_opa_decrement(x : t_opa_matrix; y : natural) return t_opa_matrix is
    constant c_ones : unsigned(x'range(2)) := (others => '1');
    variable result : t_opa_matrix(x'range(1), x'range(2));
    variable row    : unsigned(x'range(2));
  begin
    for i in x'range(1) loop
      row := unsigned(f_opa_select_row(x,i));
      if row = c_ones or row < y then
        row := c_ones;
      else
        row := row - y;
      end if;
      for j in x'range(2) loop
        result(i,j) := row(j);
      end loop;
    end loop;
    return result;
  end f_opa_decrement;
  
  function f_opa_transpose(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(2), x'range(1));
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := x(j, i);
      end loop;
    end loop;
    return result;
  end f_opa_transpose;
  
  function f_opa_product(x : t_opa_matrix; y : std_logic_vector) return std_logic_vector is
    variable chunk  : std_logic_vector(x'range(2));
    variable result : std_logic_vector(x'range(1));
  begin
    assert (x'low(2)  = y'low)  report "matrix-vector dimension mismatch" severity failure;
    assert (x'high(2) = y'high) report "matrix-vector dimension mismatch" severity failure;
    for i in result'range loop
      for j in x'range(2) loop
        chunk(j) := x(i, j) and y(j);
      end loop;
      result(i) := f_opa_or(chunk);
    end loop;
    return result;
  end f_opa_product;
  
  function f_opa_product(x, y : t_opa_matrix) return t_opa_matrix is
    variable chunk  : std_logic_vector(y'range(1));
    variable result : t_opa_matrix(x'range(1), y'range(2));
  begin
    assert (x'low(2)  = y'low(1))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(2) = y'high(1)) report "matrix-matrix dimension mismatch" severity failure;
    for i in x'range(1) loop
      for j in y'range(2) loop
        for k in y'range(1) loop
          chunk(k) := x(i,k) and y(k,j);
        end loop;
        result(i,j) := f_opa_or(chunk);
      end loop;
    end loop;
    return result;
  end f_opa_product;
  
  function f_opa_match(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), y'range(1));
  begin
    assert (x'low(2)  = y'low(2))  report "matrix-matrix row mismatch" severity failure;
    assert (x'high(2) = y'high(2)) report "matrix-matrix row mismatch" severity failure;
    for i in x'range(1) loop
      for j in y'range(1) loop
        result(i, j) := f_opa_bit(f_opa_select_row(x, i) = f_opa_select_row(y, j));
      end loop;
    end loop;
    return result;
  end f_opa_match;
  
  function f_opa_match_index(n : natural; x : t_opa_matrix) return t_opa_matrix is
    constant c_labels : t_opa_matrix := f_opa_labels(n);
  begin
    return f_opa_match(c_labels, x);
  end f_opa_match_index;
  
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(y'range(1));
  begin
    for i in result'range loop
      result(i) := x(to_integer(unsigned(f_opa_select_row(y, i))));
    end loop;
    return result;
  end f_opa_compose;
  
  function f_opa_compose(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(y'range(1), x'range(2));
    variable index : integer;
  begin
    for i in result'range(1) loop
      index := to_integer(unsigned(f_opa_select_row(y, i)));
      for j in result'range(2) loop
        result(i, j) := x(index, j);
      end loop;
    end loop;
    return result;
  end f_opa_compose;
  
  function f_opa_1hot_dec(x : std_logic_vector) return std_logic_vector is
    constant c_log2 : natural := f_opa_log2(x'length);
    variable wide   : natural := 2**c_log2;
    variable mask   : std_logic_vector(x'range) := (others => '1');
    variable result : std_logic_vector(c_log2-1 downto 0);
  begin
    for i in result'range loop
      wide := wide / 2;
      mask := mask xor std_logic_vector(unsigned(mask) sll wide);
      result(i) := f_opa_or(x and not mask);
    end loop;
    return result;
  end f_opa_1hot_dec;
  
  function f_opa_1hot_dec(x : t_opa_matrix) return t_opa_matrix is
    constant c_wide : natural := f_opa_log2(x'length(2));
    variable result : t_opa_matrix(x'range(1), c_wide-1 downto 0);
    variable row    : std_logic_vector(c_wide-1 downto 0);
  begin
    for i in result'range(1) loop
      row := f_opa_1hot_dec(f_opa_select_row(x, i));
      for b in result'range(2) loop
        result(i,b) := row(b);
      end loop;
    end loop;
    return result;
  end f_opa_1hot_dec;
  
  -- This should only be used on small vectors!
  function f_opa_pick_small(x : std_logic_vector) return std_logic_vector is
    variable acc : std_logic_vector(x'range);
  begin
    assert (x'length <= 4) report "f_opa_pick_small is bad for large inputs" severity warning;
    for i in x'low to x'high loop
      if i = x'low then
        acc(i) := '0';
      else
        acc(i) := x(i-1) or acc(i-1);
      end if;
    end loop;
    return not acc and x;
  end f_opa_pick_small;
  
  function f_opa_pick_big(x : std_logic_vector) return std_logic_vector is
    variable acc : std_logic_vector(x'range);
  begin
    assert (x'length <= 4) report "f_opa_pick_big is bad for large inputs" severity warning;
    for i in x'high downto x'low loop
      if i = x'high then
        acc(i) := '0';
      else
        acc(i) := x(i+1) or acc(i+1);
      end if;
    end loop;
    return not acc and x;
  end f_opa_pick_big;
  
  function f_opa_pick_big(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
    variable row : std_logic_vector(x'range(2));
  begin
    for i in x'range(1) loop
      row := f_opa_pick_big(f_opa_select_row(x, i));
      for j in x'range(2) loop
        result(i, j) := row(j);
      end loop;
    end loop;
    return result;
  end f_opa_pick_big;
  
  function f_opa_reverse(x : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(x'range);
  begin
    for i in x'low to x'high loop
      result(i) := x((x'high-i) + x'low);
    end loop;
    return result;
  end f_opa_reverse;
  
  function f_opa_arg_from_fast(x : t_opa_fast) return std_logic_vector is
    variable result : std_logic_vector(c_arg_wide-1 downto 0) := (others => '-');
  begin
    result(1 downto 0) := x.mode;
    result(7 downto 2) := x.raw;
    return result;
  end f_opa_arg_from_fast;
  
  function f_opa_arg_from_slow(x : t_opa_slow) return std_logic_vector is
    variable result : std_logic_vector(c_arg_wide-1 downto 0) := (others => '-');
  begin
    result(1 downto 0) := x.mode;
    result(7 downto 2) := x.raw;
    return result;
  end f_opa_arg_from_slow;
  
  function f_opa_fast_from_arg(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_fast is
    variable result : t_opa_fast;
  begin
    result.mode := x(1 downto 0);
    result.raw  := x(7 downto 2);
    return result;
  end f_opa_fast_from_arg;
  
  function f_opa_slow_from_arg(x : std_logic_vector(c_arg_wide-1 downto 0)) return t_opa_slow is
    variable result : t_opa_slow;
  begin
    result.mode := x(1 downto 0);
    result.raw  := x(7 downto 2);
    return result;
  end f_opa_slow_from_arg;
  
  function f_opa_fast_from_adder(x : t_opa_adder) return std_logic_vector is
    variable result : std_logic_vector(5 downto 0) := (others => '-');
  begin
    result(0) := x.eq;
    result(1) := x.nota;
    result(2) := x.notb;
    result(3) := x.cin;
    result(4) := x.sign;
    result(5) := x.fault;
    return result;
  end f_opa_fast_from_adder;
  
  function f_opa_fast_from_lut  (x : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable result : std_logic_vector(5 downto 0) := (others => '-');
  begin
    result(x'range) := x;
    result(5) := '0'; -- make fault 0 for LUT mode
    return result;
  end f_opa_fast_from_lut;
  
  function f_opa_slow_from_mul  (x : t_opa_mul)   return std_logic_vector is
    variable result : std_logic_vector(5 downto 0) := (others => '-');
  begin
    result(0) := x.sexta;
    result(1) := x.sextb;
    result(2) := x.high;
    result(3) := x.divide;
    return result;
  end f_opa_slow_from_mul;
  
  function f_opa_slow_from_shift(x : t_opa_shift) return std_logic_vector is
    variable result : std_logic_vector(5 downto 0) := (others => '-');
  begin
    result(0) := x.sext;
    result(3) := x.right;
    return result;
  end f_opa_slow_from_shift;
  
  function f_opa_slow_from_ldst (x : t_opa_ldst)  return std_logic_vector is
    variable result : std_logic_vector(5 downto 0) := (others => '-');
  begin
    result(0) := x.sext;
    result(3 downto 2) := x.size;
    return result;
  end f_opa_slow_from_ldst;
  
  function f_opa_adder_from_fast(x : std_logic_vector(5 downto 0)) return t_opa_adder is
    variable result : t_opa_adder;
  begin
    result.eq    := x(0);
    result.nota  := x(1);
    result.notb  := x(2);
    result.cin   := x(3);
    result.sign  := x(4);
    result.fault := x(5);
    return result;
  end f_opa_adder_from_fast;
  
  function f_opa_lut_from_fast  (x : std_logic_vector(5 downto 0)) return std_logic_vector is
    variable result : std_logic_vector(3 downto 0);
  begin
    result := x(result'range);
    return result;
  end f_opa_lut_from_fast;
  
  function f_opa_mul_from_slow  (x : std_logic_vector(5 downto 0)) return t_opa_mul is
    variable result : t_opa_mul;
  begin
    result.sexta  := x(0);
    result.sextb  := x(1);
    result.high   := x(2);
    result.divide := x(3);
    return result;
  end f_opa_mul_from_slow;
  
  function f_opa_shift_from_slow(x : std_logic_vector(5 downto 0)) return t_opa_shift is
    variable result : t_opa_shift;
  begin
    result.sext  := x(0);
    result.right := x(3);
    return result;
  end f_opa_shift_from_slow;
  
  function f_opa_ldst_from_slow (x : std_logic_vector(5 downto 0)) return t_opa_ldst is
    variable result : t_opa_ldst;
  begin
    result.sext := x(0);
    result.size := x(3 downto 2);
    return result;
  end f_opa_ldst_from_slow;

end opa_functions_pkg;
