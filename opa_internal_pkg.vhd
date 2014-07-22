library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

-- Open Processor Architecture
package opa_internal_pkg is

  function f_opa_log2(x : natural) return natural;
  function f_opa_bit(x : boolean) return std_logic;
  
  -- Number of types of execution units
  constant c_types     : natural := 3; -- load/store, ieu, mul
  constant c_log_types : natural := 2;

  -- Declare all vector types as (1 to x*y*z)
  type t_opa_matrix is array(natural range <>, natural range <>)                   of std_logic;
  type t_opa_cube   is array(natural range <>, natural range <>, natural range <>) of std_logic;
  
  function f_cmp(x : t_opa_matrix; y : t_opa_matrix) return boolean;
  
  -- Work around VHDL's complete failure to include reasonable semantics
--  function f_opa_index_cube  (a, b, c, x, y, z : natural) return natural;
--  function f_opa_index_matrix(   b, c,    y, z : natural) return natural;
--  function f_opa_index_vector(      c,       z : natural) return natural;
  
--  function f_opa_or_cube  (x, y, z : natural; C : t_opa_map) return t_opa_map;
--  function f_opa_or_matrix(   y, z : natural; M : t_opa_map) return t_opa_map;
--  function f_opa_or_vector(      z : natural; V : t_opa_map) return t_opa_map;
  
--  function f_opa_select_matrix(a, x, y, z : natural; C : t_opa_map) return t_opa_map;
--  function f_opa_select_vector(b,    y, z : natural; M : t_opa_map) return t_opa_map;
  
  -- Register -1 is never read
  -- Register -2 is never written
  
  -- Policy:    inputs always registered INSIDE core
  --            outputs always left unregistered
  -- Exception: top-level core registers its bus outputs
  
  component opa_satadd_ks is
    generic(
      g_state : natural;  -- bits in the adder
      g_size  : natural); -- elements in the array
    port(
      states_i : in  t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0);
      states_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
  end component;

  component opa_satadd is
    generic(
      g_state : natural;  -- bits in the adder
      g_size  : natural); -- elements in the array
    port(
      bits_i : in  std_logic_vector(g_size-1 downto 0);
      sums_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
  end component;
  
  component opa_satadd_tb is
    port(
      clk_i  : in std_logic;
      rstn_i : in  std_logic;
      good_o : out std_logic);
  end component;

end package;

package body opa_internal_pkg is

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
  
  function f_cmp(x : t_opa_matrix; y : t_opa_matrix) return boolean is
  begin
    if x'high(1) /= y'high(1) then return false; end if;
    if x'high(2) /= y'high(2) then return false; end if;
    if x'low(1) /= y'low(1) then return false; end if;
    if x'low(2) /= y'low(2) then return false; end if;
    for i in x'range(1) loop
      for j in x'range(2) loop
        if x(i,j) /= y(i,j) then return false; end if;
      end loop;
    end loop;
    return true;
  end f_cmp;
  
end opa_internal_pkg;
