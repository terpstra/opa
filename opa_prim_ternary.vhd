library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

-- Implement some hand-holding for dumb synthesis tools
entity opa_prim_ternary is
  generic(
    g_wide   : natural);
  port(
    a_i      : in  unsigned(g_wide-1 downto 0);
    b_i      : in  unsigned(g_wide-1 downto 0);
    c_i      : in  unsigned(g_wide-1 downto 0);
    x_o      : out unsigned(g_wide-1 downto 0));
end opa_prim_ternary;

architecture rtl of opa_prim_ternary is
begin
  x_o <= a_i + b_i + c_i;
end rtl;
