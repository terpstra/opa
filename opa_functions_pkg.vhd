library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

package opa_functions_pkg is

  function f_opa_log2(x : natural) return natural;
  function f_opa_bit(x : boolean) return std_logic;
  function f_opa_or(x : std_logic_vector) return std_logic;
  function f_opa_and(x : std_logic_vector) return std_logic;
  
  -- Types of execution units; if you modify, update f_opa_unit_{type,index}
  constant c_type_lsb   : natural := 0; -- load/store/branch + (mul/shift)
  constant c_type_ieu   : natural := 1; -- logic/add/compare
  constant c_type_mul   : natural := 2; -- mul/shift
  constant c_type_fp    : natural := 3; -- floating point
  constant c_types      : natural := 4;
  constant c_aux_wide   : natural := 10;
  
  -- Decode config into useful values
  function f_opa_decoders (conf : t_opa_config) return natural;
  function f_opa_executers(conf : t_opa_config) return natural;
  function f_opa_num_wait (conf : t_opa_config) return natural;
  function f_opa_num_stat (conf : t_opa_config) return natural;
  function f_opa_num_arch (conf : t_opa_config) return natural;
  function f_opa_num_back (conf : t_opa_config) return natural;
  function f_opa_arch_wide(conf : t_opa_config) return natural;
  function f_opa_back_wide(conf : t_opa_config) return natural;
  function f_opa_stat_wide(conf : t_opa_config) return natural;
  function f_opa_reg_wide (conf : t_opa_config) return natural;
  
  -- Mapping of execution units
  function f_opa_lsb_does_mul(conf : t_opa_config) return boolean;
  function f_opa_support_fp(conf : t_opa_config) return boolean;
  function f_opa_unit_type (conf : t_opa_config; u : natural) return natural;
  function f_opa_unit_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_unit_count(conf : t_opa_config; t : natural) return natural;
  function f_opa_lsb_index(conf : t_opa_config)              return natural;
  function f_opa_ieu_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_mul_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_fp_index(conf : t_opa_config; u : natural) return natural;

  type t_opa_matrix is array(natural range <>, natural range <>) of std_logic;
  
  function "not"(x : t_opa_matrix) return t_opa_matrix;
  function "or" (x, y : t_opa_matrix) return t_opa_matrix;
  function "and"(x, y : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_select_row(x : t_opa_matrix; i : natural) return std_logic_vector;
  function f_opa_select_col(x : t_opa_matrix; j : natural) return std_logic_vector;
  function f_opa_dup_row(n : natural; r : std_logic_vector) return t_opa_matrix;
  function f_opa_dup_col(n : natural; r : std_logic_vector) return t_opa_matrix;
  function f_opa_concat(x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_labels(n : natural; o : natural := 0) return t_opa_matrix;
  
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
  function f_opa_pick_big(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick_big(x : t_opa_matrix) return t_opa_matrix;

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
    return conf.num_ieu + 1 + conf.num_mul + conf.num_fp;
  end f_opa_executers;
  
  function f_opa_num_wait(conf : t_opa_config) return natural is
  begin
    return conf.num_wait;
  end f_opa_num_wait;
  
  function f_opa_num_stat(conf : t_opa_config) return natural is
  begin
    return conf.num_issue + conf.num_wait;
  end f_opa_num_stat;
  
  function f_opa_num_arch(conf : t_opa_config) return natural is
  begin
    return 2**conf.log_arch;
  end f_opa_num_arch;
  
  function f_opa_num_back(conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 3;
  begin
    return f_opa_num_arch(conf) +
           f_opa_num_stat(conf) +
           conf.num_decode*pipeline_depth;
  end f_opa_num_back;
  
  function f_opa_arch_wide(conf : t_opa_config) return natural is
  begin 
    return conf.log_arch;
  end f_opa_arch_wide;
  
  function f_opa_back_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_back(conf));
  end f_opa_back_wide;
  
  function f_opa_stat_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_stat(conf));
  end f_opa_stat_wide;
  
  function f_opa_reg_wide(conf : t_opa_config) return natural is
  begin
    return 2**conf.log_width;
  end f_opa_reg_wide;
  
  function f_opa_lsb_does_mul(conf : t_opa_config) return boolean is
  begin
    return conf.num_mul = 0;
  end f_opa_lsb_does_mul;
  
  function f_opa_support_fp(conf : t_opa_config) return boolean is
  begin
    return conf.num_fp /= 0;
  end f_opa_support_fp;
  
  function f_opa_unit_type (conf : t_opa_config; u : natural) return natural is
    constant c_lsb   : natural := 0;
    constant c_ieu   : natural := c_lsb + 1;
    constant c_mul   : natural := c_ieu + conf.num_ieu;
    constant c_fp    : natural := c_mul + conf.num_mul;
    constant c_end   : natural := c_fp  + conf.num_fp;
  begin
    assert (u < c_end) report "impossible unit type" severity failure;
    if u >= c_fp  then return c_type_fp;  end if;
    if u >= c_mul then return c_type_mul; end if;
    if u >= c_ieu then return c_type_ieu; end if;
    if u >= c_lsb then return c_type_lsb; end if;
    assert (false) report "unreachable" severity failure;
    return 0;
  end f_opa_unit_type;
  
  function f_opa_unit_index(conf : t_opa_config; u : natural) return natural is
    constant c_lsb   : natural := 0;
    constant c_ieu   : natural := c_lsb + 1;
    constant c_mul   : natural := c_ieu + conf.num_ieu;
    constant c_fp    : natural := c_mul + conf.num_mul;
    constant c_end   : natural := c_fp  + conf.num_fp;
  begin
    assert (u < c_end) report "impossible unit type" severity failure;
    if u >= c_fp  then return u-c_fp;  end if;
    if u >= c_mul then return u-c_mul; end if;
    if u >= c_ieu then return u-c_ieu; end if;
    if u >= c_lsb then return u-c_lsb; end if;
    assert (false) report "unreachable" severity failure;
    return 0;
  end f_opa_unit_index;
  
  function f_opa_unit_count(conf : t_opa_config; t : natural) return natural is
  begin
    if t = c_type_lsb then return 1;            end if;
    if t = c_type_ieu then return conf.num_ieu; end if;
    if t = c_type_mul then return conf.num_mul; end if;
    if t = c_type_fp  then return conf.num_fp;  end if;
    assert (false) report "invalid unti type" severity failure;
    return 0;
  end f_opa_unit_count;
  
  function f_opa_lsb_index(conf : t_opa_config) return natural is
  begin
    return 0;
  end f_opa_lsb_index;
  
  function f_opa_ieu_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + 1;
  end f_opa_ieu_index;
  
  function f_opa_mul_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + 1 + conf.num_ieu;
  end f_opa_mul_index;
  
  function f_opa_fp_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + 1 + conf.num_ieu + conf.num_mul;
  end f_opa_fp_index;
  
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
      for j in x'length(2)-1 downto 0 loop
        result(i,j+y'high(2)+1) := x(i,j+x'low(2));
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
  
  function f_opa_labels(n : natural; o : natural := 0) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, f_opa_log2(n+o)-1 downto 0);
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
  
end opa_functions_pkg;
