library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_satadd_tb is
  port(
    clk_i  : in std_logic;
    rstn_i : in std_logic;
    good_o : out std_logic);
end opa_satadd_tb;

architecture rtl of opa_satadd_tb is

   signal counter  : std_logic_vector(20 downto 0);
   signal expected : t_opa_matrix(counter'range, 1 downto 0);
   signal sums     : t_opa_matrix(counter'range, 1 downto 0);

begin

  count : process(clk_i, rstn_i) is
  begin
    if rstn_i = '0' then
      counter <= (others => '0');
    elsif rising_edge(clk_i) then
      counter <= std_logic_vector(unsigned(counter) + 1);
    end if;
  end process;
  
  calc : process(clk_i) is
    variable sum : integer;
  begin
    if rstn_i = '0' then
      expected <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      sum := 0;
      for i in 0 to 20 loop
        sum := sum + to_integer(unsigned(counter(i downto i)));
        if sum > 3 then sum := 3; end if;
        expected(i,0) <= f_opa_bit(sum mod 2 = 1);
        expected(i,1) <= f_opa_bit(sum /   2 = 1);
      end loop;
    end if;
  end process;
  
  satadd : opa_satadd
    generic map(
      g_state => 2,
      g_size  => counter'length)
    port map(
      bits_i => counter,
      sums_o => sums);

  good_o <= f_opa_bit(expected = sums);
  
end rtl;
