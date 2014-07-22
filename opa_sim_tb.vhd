library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_sim_tb is
end opa_sim_tb;

architecture rtl of opa_sim_tb is
   constant period : time := 1 ns;
   signal clk, rstn : std_logic;
   signal good : std_logic_vector(0 to 0);
begin

  clock : process
  begin
    clk <= '0';
    wait for period;
    clk <= '1';
    wait for period;
  end process;

  reset : process
  begin
    loop
      rstn <= '0';
      wait for period*256;
      rstn <= '1';
      wait for 1 ms;
    end loop;
  end process;
  
  satadd : opa_satadd_tb
    port map(
      clk_i  => clk,
      rstn_i => rstn,
      good_o => good(0));

end rtl;
