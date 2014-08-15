library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_sim_tb is
end opa_sim_tb;

architecture rtl of opa_sim_tb is
   constant period : time := 1 ns;
   signal clk, rstn : std_logic;

   signal good   : std_logic_vector(0 downto 0);
   signal r_good : std_logic_vector(good'range);
   signal r_ok   : std_logic := '1';
   
   constant c_good : std_logic_vector(good'range) := (others => '1');
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
    rstn <= '0';
    wait for period*256;
    rstn <= '1';
    wait until rstn = '0';
  end process;
  
--  satadd_tb : opa_satadd_tb
--    port map(
--      clk_i  => clk,
--      rstn_i => rstn,
--      good_o => good(1));
--  
  opa_tb : opa_core_tb
    port map(
      clk_i  => clk,
      rstn_i => rstn,
      good_o => good(0));
  
  test : process(clk, rstn) is
  begin
    if rstn = '0' then
      r_good <= (others => '1');
      r_ok   <= '1';
    elsif rising_edge(clk) then
      r_good <= r_good and good;
      if r_good /= c_good then
        r_ok <= '0';
      end if;
    end if;
  end process;
  
  assert (r_ok = '1')
  report "Testing failed"
  severity failure;

end rtl;
