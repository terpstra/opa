library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_ldst is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    issue_shift_i  : in  std_logic;
    issue_stat_i   : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_num_stat(g_config)-1 downto 0);
    issue_ready_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_final_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_quash_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    -- issue_kill_o   : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_stall_o  : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    commit_stall_o : out std_logic;
    
    regfile_stb_i  : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    regfile_rega_i : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    regfile_regb_i : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    regfile_bakx_i : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    regfile_aux_i  : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, c_aux_wide-1 downto 0);
    
    regfile_stb_o  : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    regfile_bakx_o : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); 
    regfile_regx_o : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    
    d_stall_i : in  std_logic;
    d_stb_o   : out std_logic;
    d_we_o    : out std_logic;
    d_adr_o   : out std_logic_vector(g_config.da_bits-1 downto 0);
    d_dat_o   : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    d_dat_i   : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    d_ack_i   : in  std_logic);
end opa_ldst;

architecture rtl of opa_ldst is
begin
end rtl;
