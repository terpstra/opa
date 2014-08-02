library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

package opa_functions_pkg is

  function f_opa_log2(x : natural) return natural;
  function f_opa_bit(x : boolean) return std_logic;
  
  -- Types of execution units; if you modify, update f_opa_unit_{type,index}
  constant c_type_ieu   : natural := 0;
  constant c_type_mul   : natural := 1;
  constant c_type_load  : natural := 2;
  constant c_type_store : natural := 3;
  constant c_types      : natural := 4;
  constant c_aux_wide   : natural := 10;
  
  -- Decode config into useful values
  function f_opa_decoders (conf : t_opa_config) return natural;
  function f_opa_executers(conf : t_opa_config) return natural;
  function f_opa_fifo_deep(conf : t_opa_config) return natural;
  function f_opa_back_num (conf : t_opa_config) return natural;
  function f_opa_back_wide(conf : t_opa_config) return natural;
  function f_opa_stat_wide(conf : t_opa_config) return natural;
  function f_opa_max_typ  (conf : t_opa_config) return natural;
  
  function f_opa_unit_type (conf : t_opa_config; u : natural) return natural;
  function f_opa_unit_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_ieu_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_mul_index(conf : t_opa_config; u : natural) return natural;
  function f_opa_load_index(conf : t_opa_config) return natural;
  function f_opa_store_index(conf : t_opa_config) return natural;

  type t_opa_matrix is array(natural range <>, natural range <>) of std_logic;
  
  function "not"(x : t_opa_matrix) return t_opa_matrix;
  function "or" (x, y : t_opa_matrix) return t_opa_matrix;
  function "and"(x, y : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_select_row(x : t_opa_matrix; i : natural) return std_logic_vector;
  function f_opa_select_col(x : t_opa_matrix; j : natural) return std_logic_vector;
  function f_opa_dup_row(n : natural; r : std_logic_vector) return t_opa_matrix;
  function f_opa_dup_col(n : natural; r : std_logic_vector) return t_opa_matrix;
  
  function f_opa_concat(x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_split2(n : natural; x : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_transpose(x : t_opa_matrix) return t_opa_matrix;
  function f_opa_product(x : t_opa_matrix; y : std_logic_vector) return std_logic_vector;
  function f_opa_product(x, y : t_opa_matrix) return t_opa_matrix;
  
  function f_opa_match(x, y : t_opa_matrix) return t_opa_matrix; -- do any rows match?
  function f_opa_match_index(n : natural; x : t_opa_matrix) return t_opa_matrix;
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector;
  function f_opa_compose(x, y : t_opa_matrix) return t_opa_matrix;
  
  -- Take the last '1' in the row
  function f_opa_pick(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick(x : t_opa_matrix) return t_opa_matrix;

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
  
  function f_opa_decoders(conf : t_opa_config) return natural is
  begin
    return conf.num_decode;
  end f_opa_decoders;
  
  function f_opa_executers(conf : t_opa_config) return natural is
  begin
    return conf.num_ieu + conf.num_mul + 1 + 1;
  end f_opa_executers;
  
  function f_opa_fifo_deep(conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 4;
  begin
    return (conf.num_stat / conf.num_decode) + pipeline_depth;
  end f_opa_fifo_deep;
  
  function f_opa_back_num(conf : t_opa_config) return natural is
  begin
    return 1                                     + -- garbage register
           2**conf.log_arch                      + -- arch map
           f_opa_fifo_deep(conf)*conf.num_decode;  -- stations+fifo
  end f_opa_back_num;
  
  function f_opa_back_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_back_num(conf));
  end f_opa_back_wide;
  
  function f_opa_stat_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(conf.num_stat);
  end f_opa_stat_wide;
  
  function f_opa_max_typ(conf : t_opa_config) return natural is
    variable max : natural := 1; -- memory unit type
  begin
    if conf.num_ieu > max then max := conf.num_ieu; end if;
    if conf.num_mul > max then max := conf.num_mul; end if;
    return max;
  end f_opa_max_typ;
  
  function f_opa_unit_type (conf : t_opa_config; u : natural) return natural is
    constant c_ieu   : natural := 0;
    constant c_mul   : natural := c_ieu + conf.num_ieu;
    constant c_load  : natural := c_mul + conf.num_mul;
    constant c_store : natural := c_load + 1;
    constant c_end   : natural := c_store + 1;
  begin
    assert (u < c_end) report "impossible unit type" severity failure;
    if u >= c_store then return c_type_store; end if;
    if u >= c_load  then return c_type_load;  end if;
    if u >= c_mul   then return c_type_mul;   end if;
    if u >= c_ieu   then return c_type_ieu;   end if;
    assert (false) report "unreachable" severity failure;
    return 0;
  end f_opa_unit_type;
  
  function f_opa_unit_index(conf : t_opa_config; u : natural) return natural is
    constant c_ieu   : natural := 0;
    constant c_mul   : natural := c_ieu + conf.num_ieu;
    constant c_load  : natural := c_mul + conf.num_mul;
    constant c_store : natural := c_load + 1;
    constant c_end   : natural := c_store + 1;
  begin
    assert (u < c_end) report "impossible unit type" severity failure;
    if u >= c_store then return u-c_store; end if;
    if u >= c_load  then return u-c_load;  end if;
    if u >= c_mul   then return u-c_mul;   end if;
    if u >= c_ieu   then return u-c_ieu;   end if;
    assert (false) report "unreachable" severity failure;
    return 0;
  end f_opa_unit_index;
  
  function f_opa_ieu_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u;
  end f_opa_ieu_index;
  
  function f_opa_mul_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + conf.num_ieu;
  end f_opa_mul_index;
  
  function f_opa_load_index(conf : t_opa_config) return natural is
  begin
    return conf.num_ieu + conf.num_mul;
  end f_opa_load_index;
  
  function f_opa_store_index(conf : t_opa_config) return natural is
  begin
    return conf.num_ieu + conf.num_mul + 1;
  end f_opa_store_index;
  
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
  
  function f_opa_split2(n : natural; x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'high(2)-n downto x'low(2));
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i, j) := x(i, j);
      end loop;
    end loop;
    return result;
  end f_opa_split2;

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
  
  -- Assumption: synthesis tool can recognize a chain of ORs and do something intelligent
  
  function f_opa_product(x : t_opa_matrix; y : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(x'range(1));
  begin
    assert (x'low(2)  = y'low)  report "matrix-vector dimension mismatch" severity failure;
    assert (x'high(2) = y'high) report "matrix-vector dimension mismatch" severity failure;
    for i in result'range loop
      result(i) := '0';
      for j in x'range(2) loop
        result(i) := result(i) or (x(i, j) and y(j));
      end loop;
    end loop;
    return result;
  end f_opa_product;
  
  function f_opa_product(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), y'range(2));
  begin
    assert (x'low(2)  = y'low(1))  report "matrix-matrix dimension mismatch" severity failure;
    assert (x'high(2) = y'high(1)) report "matrix-matrix dimension mismatch" severity failure;
    for i in x'range(1) loop
      for j in y'range(2) loop
        result(i,j) := '0';
        for k in y'range(1) loop
          result(i,j) := result(i,j) or (x(i,k) and y(k,j));
        end loop;
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
    variable result : t_opa_matrix(n-1 downto 0, x'range(1));
    variable v_i : std_logic_vector(x'range(2));
  begin
    assert (x'length(2) = f_opa_log2(n)) report "index width mismatch" severity failure;
    for i in result'range loop
      v_i := std_logic_vector(to_unsigned(i, x'length(2)));
      for j in x'range(1) loop
        result(i, j) := f_opa_bit(f_opa_select_row(x, j) = v_i);
      end loop;
    end loop;
    return result;
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
  
  function f_opa_pick(x : std_logic_vector) return std_logic_vector is
    constant u : unsigned(x'range) := unsigned(x);
  begin
    return std_logic_vector(u and not (u-1));
  end f_opa_pick;
  
  function f_opa_pick(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
    variable u : unsigned(result'range(2));
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        u(j) := x(i, j);
      end loop;
      u := u and not (u-1);
      for j in x'range(2) loop
        result(i, j) := u(j);
      end loop;
    end loop;
    return result;
  end f_opa_pick;
  
end opa_functions_pkg;
