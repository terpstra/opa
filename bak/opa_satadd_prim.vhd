library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_internal_pkg.all;

entity opa_satadd_prim is
  generic(
    g_state : natural);
  port(
    state_i : in  t_opa_vector(g_state-1 downto 0);
    bits_i  : out t_opa_vector(c_lut_width-g_width downto 0);
    state_o : out t_opa_vector(g_state-1 downto 0));
end opa_satadd_prim;

architecture rtl of opa_satadd_prim is

  function f_lut(x : t_opa_vector(c_lut_width-1 downto 0)) return t_opa_bit is
    alias c_state : t_opa_vector(g_state-1 downto 0)           := x(c_lut_width-1 downto c_lut_width-g_state);
    alias c_bits  : t_opa_vector(c_lut_width-g_width downto 0) := x(c_lut_width-g_state downto 0);
    variable sum : integer := 0;
  begin
  end f_lut;

  constant lut : t_opa_vector(2**c_lut_width-1 downto 0) := f_lut(g_state);
  signal s_in : t_opa_vector(

begin
  
  s_in(
  state_o <= lut(s_in);
 
end rtl;
