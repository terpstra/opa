library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_satadd is
  generic(
    g_state : natural;
    g_width : natural);
  port(
    state_i : in  t_opa_map(1 to g_width);
    state_o : out t_opa_map(1 to g_width*g_state));
end opa_satadd;

architecture rtl of opa_satadd is
  constant c_step : natural := c_lut_width / g_state;
begin
end rtl;
