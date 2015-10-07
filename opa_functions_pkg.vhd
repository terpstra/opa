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
use work.opa_isa_pkg.all;

package opa_functions_pkg is

  function f_opa_bit(x : boolean) return std_logic;
  function f_opa_choose(x : boolean; y : natural; z : natural) return natural; -- x?y:z
  function f_opa_choose(x : boolean; y : string; z : string) return string;
  
  -- Comparisons, but where a meta-value results in 'X'
  function f_opa_eq(x, y : std_logic_vector) return std_logic;
  function f_opa_eq(x, y : unsigned) return std_logic;
  function f_opa_eq(x : unsigned; y : natural) return std_logic;
  function f_opa_lt(x, y : natural) return std_logic;
  function f_opa_lt(x, y : unsigned) return std_logic;
  function f_opa_lt(x : natural;  y : unsigned) return std_logic;
  function f_opa_lt(x : unsigned; y : natural) return std_logic;
--  function f_opa_le(x, y : unsigned) return std_logic;
  -- Returns '1' when no meta-values
  function f_opa_safe(x : std_logic) return std_logic;
  function f_opa_safe(x : std_logic_vector) return std_logic;
  function f_opa_safe(x : unsigned) return std_logic;
  -- Result is v(to_integer(idx)), except returns 'X' if idx has meta-values
  function f_opa_index(v : std_logic_vector; idx : unsigned) return std_logic;
  -- Rotation, returning 'X' if index was bad
  function f_opa_rotate_left (x : std_logic_vector; y : unsigned; f : integer := 1) return std_logic_vector;
  function f_opa_rotate_right(x : std_logic_vector; y : unsigned; f : integer := 1) return std_logic_vector;
  
  -- ISA dependant values
  function f_opa_big_endian(isa : t_opa_isa) return boolean;
  function f_opa_num_arch (isa : t_opa_isa) return natural;
  function f_opa_imm_wide (isa : t_opa_isa) return natural;
  function f_opa_op_wide  (isa : t_opa_isa) return natural;
  function f_opa_op_align (isa : t_opa_isa) return natural;
  function f_opa_page_size(isa : t_opa_isa) return natural;
  function f_opa_arch_wide(isa : t_opa_isa) return natural;
  
  -- Decode config into useful values
  function f_opa_fetchers (conf : t_opa_config) return natural;
  function f_opa_renamers (conf : t_opa_config) return natural;
  function f_opa_executers(conf : t_opa_config) return natural;
  function f_opa_num_fast (conf : t_opa_config) return natural;
  function f_opa_num_slow (conf : t_opa_config) return natural;
  function f_opa_num_ldst (conf : t_opa_config) return natural;
  function f_opa_num_stat (conf : t_opa_config) return natural;
  function f_opa_num_aux  (conf : t_opa_config) return natural;
  function f_opa_num_dway (conf : t_opa_config) return natural;
  function f_opa_stat_wide(conf : t_opa_config) return natural;
  function f_opa_adr_wide (conf : t_opa_config) return natural;
  function f_opa_aux_wide (conf : t_opa_config) return natural;
  function f_opa_reg_wide (conf : t_opa_config) return natural;
  function f_opa_arg_wide (conf : t_opa_config) return natural;
  function f_opa_ren_wide (conf : t_opa_config) return natural;
  function f_opa_fet_wide (conf : t_opa_config) return natural;
  function f_opa_dline_size(conf : t_opa_config) return natural;
  function f_opa_iline_size(conf : t_opa_config) return natural;
  function f_opa_alias_high (isa  : t_opa_isa)    return natural;
  function f_opa_alias_low  (conf : t_opa_config) return natural;

  function f_opa_num_back   (isa : t_opa_isa; conf : t_opa_config) return natural;
  function f_opa_back_wide  (isa : t_opa_isa; conf : t_opa_config) return natural;
  function f_opa_fetch_align(isa : t_opa_isa; conf : t_opa_config) return natural;
  function f_opa_fetch_bytes(isa : t_opa_isa; conf : t_opa_config) return natural;
  function f_opa_fetch_bits (isa : t_opa_isa; conf : t_opa_config) return natural;
  
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
  function f_opa_mux(c : std_logic; x, y : std_logic) return std_logic;
  function f_opa_mux(c : std_logic; x, y : std_logic_vector) return std_logic_vector;
  function f_opa_mux(c, x, y : std_logic_vector) return std_logic_vector;
  function f_opa_mux(c : std_logic_vector; x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector;
  function f_opa_compose(x, y : t_opa_matrix) return t_opa_matrix;
  function f_opa_1hot_dec(x : std_logic_vector) return std_logic_vector;
  function f_opa_1hot_dec(x : t_opa_matrix) return t_opa_matrix;
  
  -- Take the '1' in the row with the biggest index
  function f_opa_pick_small(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick_big(x : std_logic_vector) return std_logic_vector;
  function f_opa_pick_big(x : t_opa_matrix) return t_opa_matrix;
  function f_opa_reverse(x : std_logic_vector) return std_logic_vector;
  
end package;

package body opa_functions_pkg is

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
  
  function f_opa_eq(x, y : std_logic_vector) return std_logic is
  begin
    assert (x'low  = y'low)  report "vector-vector dimension mismatch" severity failure;
    assert (x'high = y'high) report "vector-vector dimension mismatch" severity failure;
    return f_opa_and(not (x xor y));
  end f_opa_eq;
  
  function f_opa_eq(x, y : unsigned) return std_logic is
  begin
    return f_opa_eq(std_logic_vector(x), std_logic_vector(y));
  end f_opa_eq;
  
  function f_opa_eq(x : unsigned; y : natural) return std_logic is
    variable z : unsigned(x'range);
  begin
    z  := to_unsigned(y, x'length);
    return f_opa_eq(x, z);
  end f_opa_eq;
  
  function f_opa_lt(x, y : natural) return std_logic is
  begin
    if x < y then return '1'; else return '0'; end if;
  end f_opa_lt;
  
  function f_opa_lt(x, y : unsigned) return std_logic is
  begin
    if f_opa_safe(x) = '1' and f_opa_safe(y) = '1' then
      return f_opa_lt(to_integer(x), to_integer(y));
    else
      return 'X';
    end if;
  end f_opa_lt;
  
  function f_opa_lt(x : natural;  y : unsigned) return std_logic is
  begin
    if f_opa_safe(y) = '1' then
      return f_opa_lt(x, to_integer(y));
    else
      return 'X';
    end if;
  end f_opa_lt;
  
  function f_opa_lt(x : unsigned; y : natural) return std_logic is
  begin
    if f_opa_safe(x) = '1' then
      return f_opa_lt(to_integer(x), y);
    else
      return 'X';
    end if;
  end f_opa_lt;
  
  function f_opa_safe(x : std_logic) return std_logic is
  begin
    return not (x xor x);
  end f_opa_safe;
  
  function f_opa_safe(x : std_logic_vector) return std_logic is
  begin
    return f_opa_eq(x, x);
  end f_opa_safe;
  
  function f_opa_safe(x : unsigned) return std_logic is
  begin
    return f_opa_eq(x, x);
  end f_opa_safe;
  
  function f_opa_index(v : std_logic_vector; idx : unsigned) return std_logic is
  begin
    assert (v'low = 0) report "vector-index not at zero" severity failure;
    assert (v'length=1 or f_opa_log2(v'length) = idx'length) report "vector-index dimension mismatch" severity failure;
    
    if v'length = 1 then
      return v(0);
    elsif f_opa_safe(idx) = '1' then
      return v(to_integer(idx));
    else
      return 'X';
    end if;
  end f_opa_index;
  
  function f_opa_rotate_left (x : std_logic_vector; y : unsigned; f : integer := 1) return std_logic_vector is
    constant bad : std_logic_vector(x'range) := (others => 'X');
  begin
    if f_opa_safe(y) = '1' then
      return std_logic_vector(rotate_left(unsigned(x), to_integer(unsigned(y))*f));
    else
      return bad;
    end if;
  end f_opa_rotate_left;
  
  function f_opa_rotate_right(x : std_logic_vector; y : unsigned; f : integer := 1) return std_logic_vector is
    constant bad : std_logic_vector(x'range) := (others => 'X');
  begin
    if f_opa_safe(y) = '1' then
      return std_logic_vector(rotate_right(unsigned(x), to_integer(unsigned(y))*f));
    else
      return bad;
    end if;
  end f_opa_rotate_right;
  
  function f_opa_big_endian(isa : t_opa_isa) return boolean is
  begin
    return f_opa_isa_info(isa).big_endian;
  end f_opa_big_endian;
  
  function f_opa_num_arch(isa : t_opa_isa) return natural is
  begin
    return f_opa_isa_info(isa).num_arch;
  end f_opa_num_arch;
  
  function f_opa_imm_wide(isa : t_opa_isa) return natural is
  begin
    return f_opa_isa_info(isa).imm_wide;
  end f_opa_imm_wide;
  
  function f_opa_op_wide(isa : t_opa_isa) return natural is
  begin
    return f_opa_isa_info(isa).op_wide;
  end f_opa_op_wide;
  
  function f_opa_op_align(isa : t_opa_isa) return natural is
  begin
    return f_opa_log2(f_opa_isa_info(isa).op_wide) - 3;
  end f_opa_op_align;
  
  function f_opa_page_size(isa : t_opa_isa) return natural is
  begin
    return f_opa_isa_info(isa).page_size;
  end f_opa_page_size;
  
  function f_opa_arch_wide(isa : t_opa_isa) return natural is
  begin 
    return f_opa_log2(f_opa_num_arch(isa));
  end f_opa_arch_wide;
  
  function f_opa_fetchers(conf : t_opa_config) return natural is
  begin
    return conf.num_fetch;
  end f_opa_fetchers;
  
  function f_opa_renamers(conf : t_opa_config) return natural is
  begin
    return conf.num_rename;
  end f_opa_renamers;
  
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
  
  function f_opa_num_aux(conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 4;
  begin
    return (f_opa_num_stat(conf) + f_opa_renamers(conf)*pipeline_depth) 
           / f_opa_renamers(conf);
  end f_opa_num_aux;
  
  function f_opa_num_dway(conf : t_opa_config) return natural is
  begin
    return conf.dc_ways;
  end f_opa_num_dway;
  
  function f_opa_stat_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_stat(conf) + f_opa_renamers(conf));
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
    return conf.reg_width;
  end f_opa_reg_wide;
  
  function f_opa_arg_wide(conf : t_opa_config) return natural is
  begin
    return c_arg_wide;
  end f_opa_arg_wide;
  
  function f_opa_ren_wide(conf : t_opa_config) return natural is
    constant c_renamers : natural := f_opa_renamers(conf);
  begin
    if c_renamers = 1 then
      return 1; -- avoid null range warnings all over the place
    else
      return f_opa_log2(c_renamers);
    end if;
  end f_opa_ren_wide;
  
  function f_opa_fet_wide(conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_fetchers(conf));
  end f_opa_fet_wide;
  
  function f_opa_dline_size(conf : t_opa_config) return natural is
  begin
    return conf.dline_size;
  end f_opa_dline_size;
  
  function f_opa_iline_size(conf : t_opa_config) return natural is
  begin
    return conf.iline_size;
  end f_opa_iline_size;
  
  function f_opa_support_fp(conf : t_opa_config) return boolean is
  begin
    return conf.ieee_fp;
  end f_opa_support_fp;
  
  function f_opa_alias_high (isa : t_opa_isa) return natural is
  begin
    return f_opa_log2(f_opa_page_size(isa))-1;
  end f_opa_alias_high;
  
  function f_opa_alias_low  (conf : t_opa_config) return natural is
  begin
    return f_opa_log2(conf.reg_width)-3;
  end f_opa_alias_low;
  
  function f_opa_fast_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u;
  end f_opa_fast_index;
  
  function f_opa_slow_index(conf : t_opa_config; u : natural) return natural is
  begin
    return u + conf.num_fast;
  end f_opa_slow_index;
  
  function f_opa_num_back(isa : t_opa_isa; conf : t_opa_config) return natural is
    constant pipeline_depth : natural := 1;
  begin
    return f_opa_num_arch(isa) +
           f_opa_num_stat(conf) +
           f_opa_renamers(conf)*pipeline_depth;
  end f_opa_num_back;
  
  function f_opa_back_wide(isa : t_opa_isa; conf : t_opa_config) return natural is
  begin
    return f_opa_log2(f_opa_num_back(isa, conf));
  end f_opa_back_wide;
  
  function f_opa_fetch_align(isa : t_opa_isa; conf : t_opa_config) return natural is
  begin
    return f_opa_fet_wide(conf) + f_opa_op_align(isa);
  end f_opa_fetch_align;
  
  function f_opa_fetch_bytes(isa : t_opa_isa; conf : t_opa_config) return natural is
  begin
    return 2**f_opa_fetch_align(isa, conf);
  end f_opa_fetch_bytes;
  
  function f_opa_fetch_bits(isa : t_opa_isa; conf : t_opa_config) return natural is
  begin
    return f_opa_fetch_bytes(isa, conf)*8;
  end f_opa_fetch_bits;
  
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
      if f_opa_safe(row) /= '1' then
        row := (others => 'X');
      elsif row = c_ones or row < y then
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
        result(i, j) := f_opa_eq(f_opa_select_row(x, i), f_opa_select_row(y, j));
      end loop;
    end loop;
    return result;
  end f_opa_match;
  
  function f_opa_match_index(n : natural; x : t_opa_matrix) return t_opa_matrix is
    constant c_labels : t_opa_matrix := f_opa_labels(n);
  begin
    return f_opa_match(c_labels, x);
  end f_opa_match_index;
  
  function f_opa_mux(c : std_logic; x, y : std_logic) return std_logic is
  begin
    case c is
      when '1' => return x;
      when '0' => return y;
      when others => return 'X';
    end case;
  end f_opa_mux;
  
  function f_opa_mux(c : std_logic; x, y : std_logic_vector) return std_logic_vector is
    constant bad : std_logic_vector(x'range) := (others => 'X');
  begin
    assert (x'length = y'length)  report "vector-vector size mismatch" severity failure;
    case c is
      when '1' => return x;
      when '0' => return y;
      when others => return bad;
    end case;
  end f_opa_mux;
  
  function f_opa_mux(c, x, y : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(x'range);
  begin
    assert (c'low  = y'low)  report "vector-vector size mismatch" severity failure;
    assert (x'low  = y'low)  report "vector-vector size mismatch" severity failure;
    assert (c'high = y'high) report "vector-vector size mismatch" severity failure;
    assert (x'high = y'high) report "vector-vector size mismatch" severity failure;
    for i in x'range loop
      result(i) := f_opa_mux(c(i), x(i), y(i));
    end loop;
    return result;
  end f_opa_mux;
  
  function f_opa_mux(c : std_logic_vector; x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    assert (x'low(1)  = y'low(1))  report "matrix-matrix row mismatch" severity failure;
    assert (x'low(2)  = y'low(2))  report "matrix-matrix row mismatch" severity failure;
    assert (x'high(1) = y'high(1)) report "matrix-matrix row mismatch" severity failure;
    assert (x'high(2) = y'high(2)) report "matrix-matrix row mismatch" severity failure;
    assert (c'low     = x'low(1))  report "matrix-vector row mismatch" severity failure;
    assert (c'high    = x'high(1)) report "matrix-vector row mismatch" severity failure;
    
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i,j) := f_opa_mux(c(i), x(i,j), y(i,j));
      end loop;
    end loop;
    return result;
  end f_opa_mux;
  
  function f_opa_compose(x : std_logic_vector; y : t_opa_matrix) return std_logic_vector is
    variable result : std_logic_vector(y'range(1));
  begin
    for i in result'range loop
      result(i) := f_opa_index(x, unsigned(f_opa_select_row(y, i)));
    end loop;
    return result;
  end f_opa_compose;
  
  function f_opa_compose(x, y : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(y'range(1), x'range(2));
    variable indexu : unsigned(y'range(2));
    variable index  : integer;
  begin
    assert (x'low(1) = 0) report "matrix-index not at zero" severity failure;
    assert (x'length(1) = 1 or f_opa_log2(x'length(1)) = indexu'length) report "matrix-index dimension mismatch" severity failure;
    for i in result'range(1) loop
      indexu := unsigned(f_opa_select_row(y, i));
      if x'length(1) = 1 then
        for j in result'range(2) loop
          result(i, j) := x(0, j);
        end loop;
      elsif f_opa_safe(indexu) = '1' then
        index  := to_integer(indexu);
        for j in result'range(2) loop
          result(i, j) := x(index, j);
        end loop;
      else
        for j in result'range(2) loop
          result(i, j) := 'X';
        end loop;
      end if;
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

end opa_functions_pkg;
