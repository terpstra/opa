library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_syn_tb is
  port(
    clk_i  : in  std_logic;
    rstn_i : in  std_logic;
    we_i   : in  std_logic;
    addr_i : in  std_logic_vector(3 downto 0);
    data_i : in  std_logic_vector(64 downto 0);
    good_o : out std_logic);
end opa_syn_tb;

architecture rtl of opa_syn_tb is

  constant c_config : t_opa_config := c_opa_large;

  type t_ops is array(15 downto 0) of std_logic_vector(67 downto 0);
  signal r_ops : t_ops :=
    (0      => x"02000200020002000",
     1      => x"12111211121112111",
     2      => x"12666266626662666",
     3      => x"12000200020002000",
     4      => x"12000200020002000",
     5      => x"12000200020002000",
     6      => x"12000200020002000",
     7      => x"12000200020002000",
     10     => x"11101110111011101",
     11     => x"11222133314441555",
     others => x"02000200020002000");

  signal r_off   : unsigned(3 downto 0);
  signal s_off   : unsigned(3 downto 0);
  
  signal r_we    : std_logic;
  signal r_addr  : std_logic_vector( 3 downto 0);
  signal r_data  : std_logic_vector(64 downto 0);
  
  signal s_stall : std_logic;
  signal r_stb   : std_logic;
  signal r_op    : std_logic_vector(c_config.num_decode*16-1 downto 0);
  
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
    if rstn_i = '0' then
      r_off <= (others => '0');
      good_o <= '0';
    elsif rising_edge(clk_i) then
      if s_stall = '0' then
        r_off <= s_off;
      end if;
      good_o <= d_data_o(31);
    end if;
  end process;
  s_off <= r_off + 1;
  
  ram : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_we   <= we_i;
      r_addr <= addr_i;
      r_data <= data_i;
      if r_we = '1' then
        r_ops(to_integer(unsigned(r_addr)))(r_data'range) <= r_data;
      end if;
      r_stb <= r_ops(to_integer(s_off))(64);
      r_op  <= r_ops(to_integer(s_off))(r_op'range);
    end if;
  end process;

  opa_core : opa
    generic map(
      g_config => c_config,
      g_target => c_opa_cyclone_v)
    port map(
      clk_i     => clk_i,
      rst_n_i   => rstn_i,
      stb_i     => r_stb,
      stall_o   => s_stall,
      data_i    => r_op,
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
  d_data_i <= d_data_o;
  
end rtl;
