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
    
    aux_dat_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
    reg_data_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_datb_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    reg_datx_o : out std_logic_vector(2**g_config.log_width-1 downto 0));
end opa_mul;

architecture rtl of opa_mul is

  signal r_data : std_logic_vector(reg_data_i'range);
  signal r_datb : std_logic_vector(reg_datb_i'range);
  signal r_datx : std_logic_vector(reg_data_i'length*2-1 downto 0);
  signal r_daty : std_logic_vector(reg_data_i'length*2-1 downto 0);
  signal r_auxw : std_logic;
  signal r_auxx : std_logic;
  signal r_auxy : std_logic;
  signal r_regx : std_logic_vector(iss_regx_i'range);
  signal r_regy : std_logic_vector(iss_regx_i'range);
  signal r_regz : std_logic_vector(iss_regx_i'range);

begin

  iss_regx_o <= r_regy; -- latency=3
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_data <= reg_data_i;
      r_datb <= reg_datb_i;
      r_auxw <= aux_dat_i(0);
      
      r_datx <= std_logic_vector(unsigned(r_data) * unsigned(r_datb));
      r_auxx <= r_auxw;
      r_daty <= r_datx;
      r_auxy <= r_auxx;
      
      r_regx  <= iss_regx_i;
      r_regy  <= r_regx;
      r_regz  <= r_regy;
      
      reg_regx_o <= r_regz;
    end if;
  end process;
  
  reg_datx_o <= r_daty(reg_datx_o'range) when r_auxy='0' else
                r_daty(reg_data_i'length*2-1 downto reg_data_i'length);

end rtl;
