library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

package opa_functions_pkg is

  function f_opa_log2(x : natural) return natural;
  function f_opa_bit(x : boolean) return std_logic;
  
  -- Number of types of execution units
  constant c_types     : natural := 3; -- load/store, ieu, mul
  constant c_log_types : natural;
  constant c_num_mem   : natural := 2; -- read+write memory paths
  
  -- Decode config into useful values
  function f_opa_decoders (conf : t_opa_config) return natural;
  function f_opa_executers(conf : t_opa_config) return natural;
  function f_opa_back_num (conf : t_opa_config) return natural;
  function f_opa_back_wide(conf : t_opa_config) return natural;
  function f_opa_stat_wide(conf : t_opa_config) return natural;
  function f_opa_max_typ  (conf : t_opa_config) return natural;

  type t_opa_matrix is array(natural range <>, natural range <>) of std_logic;
  
  function f_opa_select(i : natural; x : t_opa_matrix) return std_logic_vector;
  function f_opa_match(x, y : t_opa_matrix) return std_logic_vector;
  function f_opa_match_index(n : natural; x : t_opa_matrix) return std_logic_vector;
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector;

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
  
  constant c_log_types : natural := f_opa_log2(c_types);
  
  function f_opa_decoders(conf : t_opa_config) return natural is
  begin
    return 2**conf.log_decode;
  end f_opa_decoders;
  
  function f_opa_executers(conf : t_opa_config) return natural is
  begin
    return conf.num_ieu + conf.num_mul + c_num_mem;
  end f_opa_executers;
  
  function f_opa_back_num(conf : t_opa_config) return natural is
  begin
    return 2**conf.log_arch + conf.num_stat + 2**conf.log_decode*5; -- !!! 5? find the truth
  end f_opa_back_num;
  
  function f_opa_back_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_back_num(conf) + 2); -- !!! is 2 the best way to do this?
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
  
  function f_opa_select(i : natural; x : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(x'range(2));
  begin
    for j in result'range loop
      result(j) := x(i, j);
    end loop;
    return result;
  end f_opa_select;
  
  function f_opa_match(x, y : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(x'range(1)) := (others => '0');
  begin
    assert (x'low(2)  = y'low(2))  report "matrix dimension mismatch" severity failure;
    assert (x'high(2) = y'high(2)) report "matrix dimension mismatch" severity failure;
    for i in x'range(1) loop
      for j in y'range(1) loop
        result(i) := result(i) or f_opa_bit(f_opa_select(i, x) = f_opa_select(j, y));
      end loop;
    end loop;
    return result;
  end f_opa_match;
  
  function f_opa_match_index(n : natural; x : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(n-1 downto 0) := (others => '0');
    variable v_i : std_logic_vector(x'range(2));
  begin
    assert (x'length(2) = f_opa_log2(n)) report "index width mismatch" severity failure;
    for j in result'range loop
      v_i := std_logic_vector(to_unsigned(j, x'length(2)));
      for i in x'range(1) loop
        result(j) := result(j) or f_opa_bit(f_opa_select(i, x) = v_i);
      end loop;
    end loop;
    return result;
  end f_opa_match_index;
  
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(y'range(1));
  begin
    for i in result'range loop
      result(i) := x(to_integer(unsigned(f_opa_select(i, y))));
    end loop;
    return result;
  end f_opa_compose;
  
end opa_functions_pkg;
