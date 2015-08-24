library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_icache is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    fetch_stb_i    : in  std_logic;
    fetch_stall_o  : out std_logic;
    fetch_pc_i     : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_fetch_wide(g_config));
    
    decode_dat_o   : out std_logic_vector(f_opa_num_fetch(g_config)*8-1 downto 0);
    decode_stb_o   : out std_logic;
    decode_stall_i : in  std_logic;
    
    i_stb_o        : out std_logic;
    i_stall_i      : in  std_logic;
    i_ack_i        : in  std_logic;
    i_err_i        : in  std_logic;
    i_addr_o       : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    i_data_i       : in  std_logic_vector(2**g_config.log_width  -1 downto 0));
end opa_icache;

architecture rtl of opa_icache is
begin

  -- think about what to do on i_err_i
 
end rtl;
