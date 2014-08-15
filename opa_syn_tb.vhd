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

  constant c_config : t_opa_config := c_opa_mid;

  type t_ops is array(15 downto 0) of std_logic_vector(67 downto 0);
  signal r_op : t_ops :=
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
  
  signal r_we    : std_logic;
  signal r_addr  : std_logic_vector( 3 downto 0);
  signal r_data  : std_logic_vector(64 downto 0);
  
  signal s_out   : std_logic;
  signal r_out   : std_logic;
  
  signal s_stall : std_logic;
  signal s_stb   : std_logic;
  signal s_op    : std_logic_vector(2**c_config.log_width-1 downto 0);
  
  
begin

  test : process(clk_i, rstn_i) is
  begin
    if rstn_i = '0' then
      r_out <= '0';
      r_off <= (others => '0');
    elsif rising_edge(clk_i) then
      r_out <= s_out;
      if s_stall = '0' then
        r_off <= r_off + 1;
      end if;
    end if;
  end process;
  
  ram : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_we   <= we_i;
      r_addr <= addr_i;
      r_data <= data_i;
      if r_we = '1' then
        r_op(to_integer(unsigned(r_addr)))(r_data'range) <= r_data;
      end if;
    end if;
  end process;
  
  s_stb <= r_op(to_integer(r_off))(64);
  s_op  <= r_op(to_integer(r_off))(s_op'range);

  opa_core : opa
    generic map(
      g_config => c_config,
      g_target => c_opa_cyclone_v)
    port map(
      clk_i   => clk_i,
      rst_n_i => rstn_i,
      stb_i   => s_stb,
      stall_o => s_stall,
      data_i  => s_op,
      good_o  => s_out);

  good_o <= r_out;

end rtl;
    