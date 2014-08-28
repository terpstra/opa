library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_dbus is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    -- Wishbone data bus to L2
    d_stall_i     : in  std_logic;
    d_stb_o       : out std_logic;
    d_we_o        : out std_logic;
    d_adr_o       : out std_logic_vector(f_opa_dadr_wide(g_config)-1 downto 0);
    d_dat_o       : out std_logic_vector(f_opa_reg_wide (g_config)-1 downto 0);
    d_dat_i       : in  std_logic_vector(f_opa_reg_wide (g_config)-1 downto 0);
    d_ack_i       : in  std_logic;
    -- When low, the dbus has room for >= slow*2 additional operations
    issue_shift_i : in  std_logic;
    issue_stall_o : out std_logic;
    issue_quash_o : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0); -- !!! make sure holding this does not cause reissue loop
    -- L1d issues reads when both LSB and L1d missed
    -- L1d issues writes on cache eviction (only caused by L1d writes => no miss => no hazard)
    l1d_stb_i     : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    l1d_we_i      : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0); -- ignored when we_i=1
    l1d_stat_i    : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    l1d_adr_i     : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_dadr_wide(g_config)-1 downto 0);
    l1d_dat_i     : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0);
    -- Upon receiving a bus read result, it is forwarded to the LSB
    lsb_stb_o     : out std_logic;
    lsb_stat_o    : out std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    lsb_adr_o     : out std_logic_vector(f_opa_dadr_wide(g_config)-1 downto 0);
    lsb_dat_o     : out std_logic_vector(f_opa_reg_wide (g_config)-1 downto 0));
end opa_dbus;

architecture rtl of opa_dbus is
begin
end rtl;
