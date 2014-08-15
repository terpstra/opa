library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_dpram is
  generic(
    g_width : natural;
    g_size  : natural;
    g_bypass: boolean);
  port(
    clk_i    : in  std_logic;
    rst_n_i  : in  std_logic;
    r_en_i   : in  std_logic;
    r_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    r_data_o : out std_logic_vector(g_width-1 downto 0);
    w_en_i   : in  std_logic;
    w_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    w_data_i : in  std_logic_vector(g_width-1 downto 0));
end opa_dpram;

architecture rtl of opa_dpram is
  type t_memory is array(g_size-1 downto 0) of std_logic_vector(g_width-1 downto 0);
  signal r_memory : t_memory;
  
  signal r_bypass : std_logic;
  signal r_data_n : std_logic_vector(g_width-1 downto 0);
  signal r_data_b : std_logic_vector(g_width-1 downto 0);
begin

  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if w_en_i = '1' then
        r_memory(to_integer(unsigned(w_addr_i))) <= w_data_i;
      end if;
      
      r_data_b <= w_data_i;
      r_data_n <= r_memory(to_integer(unsigned(r_addr_i)));
      r_bypass <= f_opa_bit(r_addr_i = w_addr_i);
    end if;
  end process;
  
  r_data_o <= r_data_b when (g_bypass and r_bypass = '1') else r_data_n;

end rtl;
