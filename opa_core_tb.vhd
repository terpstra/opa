library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;

entity opa_core_tb is
  port(
    clk_i  : in std_logic;
    rstn_i : in std_logic;
    good_o : out std_logic);
end opa_core_tb;

architecture rtl of opa_core_tb is

  constant c_config : t_opa_config := c_opa_large;

  type t_ops is array(15 downto 0) of std_logic_vector(67 downto 0);
  constant c_op : t_ops := 
    (0      => x"02099209920992099",
     1      => x"1411141110aa70bb8",
     2      => x"12666266620782078",
     3      => x"12000200020782078",
     4      => x"12000200000202000",
     5      => x"12000200040004000",
     6      => x"12000200040002000",
     7      => x"12000200020002000",
     10     => x"11101110141014101",
     11     => x"11222133344444555",
     others => x"02000200020002000");

  signal r_off : unsigned(3 downto 0);
  
  signal s_stall : std_logic;
  signal s_stb   : std_logic;
  signal s_op    : std_logic_vector(c_config.num_decode*16-1 downto 0);
  
  signal d_stb    : std_logic;
  signal d_we     : std_logic;
  signal d_stall  : std_logic;
  signal d_ack    : std_logic;
  signal d_err    : std_logic;
  signal d_addr   : std_logic_vector(c_config.da_bits       -1 downto 0);
  signal d_sel    : std_logic_vector(2**c_config.log_width/8-1 downto 0);
  signal d_data_o : std_logic_vector(2**c_config.log_width  -1 downto 0);
  signal d_data_i : std_logic_vector(2**c_config.log_width  -1 downto 0);
  
begin

  test : process(clk_i, rstn_i) is
  begin
    if rstn_i = '0' then
      r_off <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_stall = '0' then
        r_off <= r_off + 1;
      end if;
    end if;
  end process;
  
  s_stb <= c_op(to_integer(r_off))(64);
  s_op  <= c_op(to_integer(r_off))(s_op'range);

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

  good_o <= '1';

end rtl;
