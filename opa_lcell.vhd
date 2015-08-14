library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_lcell is
 port(
   a_i : in  std_logic;
   b_o : out std_logic);
end opa_lcell;

architecture rtl of opa_lcell is
begin
  b_o <= a_i;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_lcell_vector is
  generic(
    g_wide : natural);
  port(
    a_i : in  std_logic_vector(g_wide-1 downto 0);
    b_o : out std_logic_vector(g_wide-1 downto 0));
end opa_lcell_vector;

architecture rtl of opa_lcell_vector is
begin
  b_o <= a_i;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_lcell_matrix is
  generic(
    g_rows : natural;
    g_cols : natural);
  port(
    a_i : in  t_opa_matrix(g_rows-1 downto 0, g_cols-1 downto 0);
    b_o : out t_opa_matrix(g_rows-1 downto 0, g_cols-1 downto 0));
end opa_lcell_matrix;

architecture rtl of opa_lcell_matrix is
begin
  b_o <= a_i;
end rtl;
