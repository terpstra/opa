library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_syn_tb is
  port(
    clk_i  : in  std_logic;
    bits_i : in  std_logic_vector(48 downto 0);
    sums_o : out t_opa_matrix(48 downto 0, 1 downto 0));
end opa_syn_tb;

architecture rtl of opa_syn_tb is
  signal r_in : std_logic_vector(bits_i'range);
  signal s_out, r_out : t_opa_matrix(bits_i'range, 1 downto 0);
begin

  satadd : opa_satadd
    generic map(
      g_state => 2,
      g_size  => bits_i'length)
    port map(
      bits_i => r_in,
      sums_o => s_out);

  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_in  <= bits_i;
      r_out <= s_out;
    end if;
  end process;
  
  sums_o <= r_out;

end rtl;
    