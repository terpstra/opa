library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_dbus is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    
    d_cyc_o    : out std_logic;
    d_stb_o    : out std_logic;
    d_we_o     : out std_logic;
    d_stall_i  : in  std_logic;
    d_ack_i    : in  std_logic;
    d_err_i    : in  std_logic;
    d_addr_o   : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_sel_o    : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    d_data_o   : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_data_i   : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
    
    slow_stb_o : out std_logic;
    slow_adr_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    slow_dat_o : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    slow_stb_i : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_adr_i : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto 0));
end opa_dbus;

architecture rtl of opa_dbus is

  constant c_reg_wide : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide : natural := f_opa_adr_wide(g_config);

  signal r_cyc : std_logic;
  signal r_stb : std_logic;
  signal r_adr : std_logic_vector(c_reg_wide-1 downto 0) := (others => '0');

begin

  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_cyc = '0' then
        r_cyc <= f_opa_or(slow_stb_i);
        r_stb <= f_opa_or(slow_stb_i);
        r_adr(c_adr_wide-1 downto 0) <= f_opa_select_row(slow_adr_i, 0);
        -- !!! wrap the address around to load a whole cache line
      else
        if d_stall_i = '0' then
          r_stb <= '0';
        end if;
        if d_ack_i = '1' then
          r_cyc <= '0';
        end if;
      end if;
    end if;
  end process;
  
  d_cyc_o  <= r_cyc;
  d_stb_o  <= r_stb;
  d_we_o   <= '0';
  d_addr_o <= r_adr;
  d_sel_o  <= (others => '1');
  d_data_o <= (others => '0');
  
  slow_stb_o <= d_ack_i;
  slow_adr_o <= r_adr(c_adr_wide-1 downto 0);
  slow_dat_o <= d_data_i;

end rtl;
