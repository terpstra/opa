library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_satadd is
  generic(
    g_state : natural;  -- bits in the adder
    g_size  : natural); -- elements in the array
  port(
    bits_i : in  std_logic_vector(g_size-1 downto 0);
    sums_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
end opa_satadd;

architecture rtl of opa_satadd is

  -- How many bits can we expand at once?
  constant c_step    : natural := c_lut_width - g_state + 1;
  constant c_ks_size : natural := g_size / c_step; -- rounded down
  
  subtype t_lut is std_logic_vector(2**c_lut_width-1 downto 0);
  type t_prim is array(g_state-1 downto 0) of t_lut;
  
  -- Define LUTs that reduce c_step-1 bits + state
  function f_lut return t_prim is
    variable sum : integer;
    variable shf : integer;
    variable bin : std_logic_vector(g_state-1 downto 0);
    variable result : t_prim;
  begin
    -- For all inputs to the LUT
    for i in 0 to 2**c_lut_width-1 loop
      -- Determine the sum of the fields
      sum := i / 2**(c_lut_width-g_state);
      shf := i;
      for j in 0 to c_lut_width-g_state-1 loop
        sum := sum + (shf mod 2);
        shf := shf / 2;
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
  
  function f_compress(bits : std_logic_vector(g_size-1 downto 0))
    return t_opa_matrix is
    variable index : std_logic_vector(c_lut_width-1 downto 0) := (others => '0');
    variable result : t_opa_matrix(c_ks_size-1 downto 0, g_state-1 downto 0);
  begin
    for i in 0 to c_ks_size-1 loop
      index(c_step-1 downto 0) := bits((i+1)*c_step-1 downto i*c_step);
      for b in 0 to g_state-1 loop
        result(i, b) := c_lut(b)(to_integer(unsigned(index)));
      end loop;
    end loop;
    return result;
  end f_compress;
  
  function f_expand(bits : std_logic_vector(g_size-1 downto 0); 
                    s : t_opa_matrix(c_ks_size-1 downto 0, g_state-1 downto 0))
    return t_opa_matrix is
    variable offset : integer;
    variable index  : std_logic_vector(c_lut_width-1 downto 0);
    variable result : t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0);
  begin
    for i in 0 to g_size-1 loop
      index := (others => '0');
      offset := (i+1) / c_step;
      
      -- Pull in the prior state (if any)
      if offset > 0 then
        for b in 0 to g_state-1 loop
          index(c_lut_width-g_state+b) := s(offset-1, b);
        end loop;
      end if;
      
      -- Pull in unincluded bits (if any)
      if offset*c_step < i+1 then
        for b in 0 to i-offset*c_step loop
          index(b) := bits(offset*c_step + b);
        end loop;
      end if;
      
      -- Grab the result from the LUTs
      for b in 0 to g_state-1 loop
        result(i, b) := c_lut(b)(to_integer(unsigned(index)));
      end loop;
    end loop;
    return result;
  end f_expand;
  
  signal ks_out : t_opa_matrix(c_ks_size-1 downto 0, g_state-1 downto 0);
  
begin

  ks : opa_satadd_ks
    generic map(
      g_state  => g_state,
      g_size   => c_ks_size)
    port map(
      states_i => f_compress(bits_i),
      states_o => ks_out);
  
  sums_o <= f_expand(bits_i, ks_out);

end rtl;
