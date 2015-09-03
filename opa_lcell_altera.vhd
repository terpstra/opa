library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity opa_lcell is
 port(
   a_i : in  std_logic;
   b_o : out std_logic);
end opa_lcell;

architecture rtl of opa_lcell is
begin
  imp : lcell port map(a_in => a_i, a_out => b_o);
end rtl;
