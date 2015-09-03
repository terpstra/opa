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
