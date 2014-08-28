library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

-- Unified Load/Store Buffer
entity opa_lsb is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    -- The issue stage shift is what retires writes
    -- It is only allowed to shift if we have room!
    issue_stall_o : out std_logic; 
    issue_shift_i : in  std_logic;
    issue_quash_o : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    -- Accept bus accesses; reads=>load forwarding check, writes=>quash check
    ldst_stb_i    : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_we_i     : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_stat_i   : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    ldst_adr_i    : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_dadr_wide(g_config)-1 downto 0);
    ldst_dat_i    : in  t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0);
    ldst_miss_o   : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    ldst_dat_o    : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0);
    -- Receive cache miss results from the dbus (always a write)
    dbus_stb_i    : in  std_logic;
    dbus_stat_i   : in  std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    dbus_adr_i    : in  std_logic_vector(f_opa_dadr_wide(g_config)-1 downto 0);
    dbus_dat_i    : in  std_logic_vector(f_opa_reg_wide (g_config)-1 downto 0);
    -- l1d is filled when we retire stuff (refill or write)
    l1d_stall_i   : in  std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    l1d_stb_o     : out std_logic_vector(f_opa_num_ldst(g_config)-1 downto 0);
    l1d_adr_o     : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_dadr_wide(g_config)-1 downto 0);
    l1d_dat_o     : out t_opa_matrix(f_opa_num_ldst(g_config)-1 downto 0, f_opa_reg_wide (g_config)-1 downto 0));
end opa_lsb;

architecture rtl of opa_lsb is
begin

  -- Put highest priority write into highest offset of l1d_*_o

end rtl;
