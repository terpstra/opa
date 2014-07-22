library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_satadd_ks is
  generic(
    g_state : natural;  -- bits in the adder
    g_size  : natural); -- elements in the array
  port(
    states_i : in  t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0);
    states_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
end opa_satadd_ks;

architecture rtl of opa_satadd_ks is

  constant c_step : natural := c_lut_width / g_state; -- rounded down
  constant c_wide : natural := c_step * g_state; -- maybe a bit less than a LUT
  
  subtype t_lut is std_logic_vector(2**c_wide-1 downto 0);
  type t_prim is array(g_state-1 downto 0) of t_lut;

  -- Define LUTs that reduces *c_step inputs.
  -- Any unused high bits are ignored.
  function f_lut return t_prim is
    variable shf : integer;
    variable sum : integer;
    variable bin : std_logic_vector(g_state-1 downto 0);
    variable result : t_prim;
  begin
    -- For all inputs to the LUT
    for i in 0 to 2**c_wide-1 loop
      -- Determine the sum of the fields
      sum := 0;
      shf := i;
      for j in 0 to c_step-1 loop
        sum := sum + (shf mod 2**g_state);
        shf := shf / 2**g_state;
      end loop;
      
      -- Saturate the arithmetic and convert to unsigned
      if sum >= 2**g_state then sum := 2**g_state-1; end if;
      bin := std_logic_vector(to_unsigned(sum, g_state));
      
      -- Split result into LUT tables
      for b in 0 to g_state-1 loop
        result(b)(i) := bin(b);
      end loop;
    end loop;
    return result;
  end f_lut;
  constant c_lut : t_prim := f_lut;
  
  -- A function that uses the LUT for given input position and stride
  function f_reduce(x : t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0); i, gap : natural) 
    return std_logic_vector is
    variable index  : std_logic_vector(c_wide-1 downto 0) := (others => '0');
    variable result : std_logic_vector(g_state-1 downto 0);
  begin
    -- Mux the input pins
    for j in 0 to c_step-1 loop
      if i >= j*gap then
        for s in 0 to g_state-1 loop
          index(j*g_state+s) := x(i-j*gap, s);
        end loop;
      end if;
    end loop;
    
    -- Feed the LUTs,
    for j in 0 to g_state-1 loop
      result(j) := c_lut(j)(to_integer(unsigned(index)));
    end loop;
    
    return result;
  end f_reduce;
  
  function f_ks(x : t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0); gap : natural)
    return t_opa_matrix is
    variable state  : std_logic_vector(g_state-1 downto 0);
    variable result : t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0);
  begin
    -- base case
    if gap >= g_size then return x; end if;
    
    for i in 0 to g_size-1 loop
      state := f_reduce(x, i, gap);
      for s in 0 to g_state-1 loop
        result(i, s) := state(s);
      end loop;
    end loop;
    
    -- Recursively divide
    return f_ks(result, gap*c_step);
  end f_ks;
  
begin

  states_o <= f_ks(states_i, 1);
  
end rtl;
