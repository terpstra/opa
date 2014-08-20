library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_ls is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    issue_shift_i  : in  std_logic;
    issue_stb_i    : in  std_logic;
    issue_stat_i   : in  std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    issue_stb_o    : out std_logic;
    issue_kill_o   : out std_logic;
    issue_stat_o   : out std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_bakx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_aux_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
    
    regfile_stb_o  : out std_logic;
    regfile_bakx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    
    d_stb_o   : out std_logic;
    d_we_o    : out std_logic;
    d_stall_i : in  std_logic;
    d_ack_i   : in  std_logic;
    d_err_i   : in  std_logic;
    d_addr_o  : out std_logic_vector(g_config.da_bits-1 downto 0);
    d_sel_o   : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    d_data_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_data_i  : out std_logic_vector(2**g_config.log_width  -1 downto 0));
end opa_ls;

architecture rtl of opa_ls is
begin
end rtl;
