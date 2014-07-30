library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

entity opa_core_tb is
  port(
    clk_i  : in std_logic;
    rstn_i : in std_logic;
    good_o : out std_logic);
end opa_core_tb;

architecture rtl of opa_core_tb is

begin

  opa_core : opa
    generic map(
      g_config => c_opa_full)
    port map(
      clk_i   => clk_i,
      rst_n_i => rstn_i,
      stb_i   => '1',
      stall_o => open,
      data_i  => x"0002000100030201000402010000070000");

  good_o <= '1';

end rtl;
