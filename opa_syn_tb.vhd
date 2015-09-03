library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_syn_tb is
  port(
    clk_i     : in  std_logic;
    rstn_i    : in  std_logic;
    i_cyc_o   : out std_logic;
    i_stb_o   : out std_logic;
    i_stall_i : in  std_logic;
    i_ack_i   : in  std_logic;
    i_addr_o  : out std_logic_vector(31 downto 0);
    i_data_i  : in  std_logic_vector(31 downto 0);
    good_o    : out std_logic);
end opa_syn_tb;

architecture rtl of opa_syn_tb is

  constant c_config : t_opa_config := c_opa_mid;

  signal d_cyc    : std_logic;
  signal d_stb    : std_logic;
  signal d_we     : std_logic;
  signal d_stall  : std_logic;
  signal d_ack    : std_logic;
  signal d_err    : std_logic;
  signal d_addr   : std_logic_vector(2**c_config.log_width  -1 downto 0);
  signal d_sel    : std_logic_vector(2**c_config.log_width/8-1 downto 0);
  signal d_data_o : std_logic_vector(2**c_config.log_width  -1 downto 0);
  signal d_data_i : std_logic_vector(2**c_config.log_width  -1 downto 0);
  
begin

  test : process(clk_i, rstn_i) is
  begin
    if rising_edge(clk_i) then
      good_o <= d_data_o(31);
    end if;
  end process;
  
  opa_core : opa
    generic map(
      g_config => c_config,
      g_target => c_opa_cyclone_v)
    port map(
      clk_i     => clk_i,
      rst_n_i   => rstn_i,
      i_cyc_o   => i_cyc_o,
      i_stb_o   => i_stb_o,
      i_stall_i => i_stall_i,
      i_ack_i   => i_ack_i,
      i_err_i   => '0',
      i_addr_o  => i_addr_o,
      i_data_i  => i_data_i,
      d_cyc_o   => d_cyc,
      d_stb_o   => d_stb,
      d_we_o    => d_we,
      d_stall_i => d_stall,
      d_ack_i   => d_ack,
      d_err_i   => d_err,
      d_addr_o  => d_addr,
      d_sel_o   => d_sel,
      d_data_o  => d_data_o,
      d_data_i  => d_data_i);

  -- for now:
  d_stall  <= '0';
  d_ack    <= d_stb;
  d_err    <= '0';
  d_data_i <= i_data_i;
  
end rtl;
