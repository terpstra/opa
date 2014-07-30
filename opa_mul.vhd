library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_mul is
  generic(
    g_config   : t_opa_config);
  port(
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    
    iss_regx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    iss_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    
    reg_data_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_datb_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    reg_datx_o : out std_logic_vector(2**g_config.log_width-1 downto 0));
end opa_mul;

architecture rtl of opa_mul is

  signal r_data : std_logic_vector(reg_data_i'range);
  signal r_datb : std_logic_vector(reg_datb_i'range);
  signal r_datx : std_logic_vector(reg_data_i'length*2-1 downto 0);
  signal r_regx : std_logic_vector(iss_regx_i'range);
  signal r_regy : std_logic_vector(iss_regx_i'range);

begin

  iss_regx_o <= r_regx; -- latency=2
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_data <= reg_data_i;
      r_datb <= reg_datb_i;
      r_regx <= iss_regx_i;
      r_regy <= r_regx;
      
      reg_regx_o <= r_regy;
      r_datx <= std_logic_vector(unsigned(r_data) * unsigned(r_datb));
    end if;
  end process;
  
  reg_datx_o <= r_datx(reg_datx_o'range);

end rtl;
