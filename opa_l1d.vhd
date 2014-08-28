library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_l1d is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    -- Receive requests from LSB(we_i=1) or issue(we_i=0)
    ldst_stall_o  : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_stb_i    : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_we_i     : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_adr_i    : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_dadr_wide(g_config)-1 downto 0);
    ldst_dat_i    : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0);
    ldst_dat_o    : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0);
    ldst_miss_o   : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    -- Request for data bus [stb computed in ldst = we_o or (l1d_miss and lsb_miss)]
    dbus_we_o     : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    dbus_adr_o    : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_dadr_wide(g_config)-1 downto 0);
    dbus_dat_o    : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0));
end opa_l1d;

architecture rtl of opa_l1d is
begin
end rtl;
