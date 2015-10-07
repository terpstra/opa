--  opa: Open Processor Architecture
--  Copyright (C) 2014-2016  Wesley W. Terpstra
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  To apply the GPL to my VHDL, please follow these definitions:
--    Program        - The entire collection of VHDL in this project and any
--                     netlist or floorplan derived from it.
--    System Library - Any macro that translates directly to hardware
--                     e.g. registers, IO pins, or memory blocks
--    
--  My intent is that if you include OPA into your project, all of the HDL
--  and other design files that go into the same physical chip must also
--  be released under the GPL. If this does not cover your usage, then you
--  must consult me directly to receive the code under a different license.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity opa_syn_tb is
  port(
    osc : in  std_logic;
    dip : in  std_logic_vector(1 to 3);
    but : in  std_logic_vector(1 to 2);
    led : out std_logic_vector(7 downto 0) := (others => 'Z'));
end opa_syn_tb;

architecture rtl of opa_syn_tb is

  -- A 'large' OPA does not fit into the bemicro. Use a two-way L1d to fit.
  constant c_opa_bemicro : t_opa_config := (
    reg_width  => 32, -- 32-bit CPU
    adr_width  => 32, -- 32-bit address space
    num_fetch  =>  4, -- fetch  4 instructions per clock
    num_rename =>  3, -- rename 3 instructions per clock
    num_stat   => 27, -- schedule 27 instructions at once
    num_fast   =>  2, -- execute 2 fast instructions per clock
    num_slow   =>  1, -- execute 1 slow instruction per clock
    ieee_fp    => false, -- hell no
    ic_ways    =>  2, -- keep the size down; only 2-way L1i
    iline_size => 16, -- 4 instructions per line
    dc_ways    =>  2, -- keep the size down; only 2-way L1d
    dline_size => 16, -- 4 words per line
    dtlb_ways  =>  1);-- direct mapped TLB
  
  constant c_config : t_opa_config := c_opa_bemicro;
  
  -- How many words to run it with?
  constant c_log_ram : natural := 14; -- 4*2^14 = 64kB of memory

  component pll is
    port(
      refclk   : in  std_logic := 'X'; -- clk
      rst      : in  std_logic := 'X'; -- reset
      outclk_0 : out std_logic;        -- clk
      locked   : out std_logic);       -- export
  end component pll;
  
  component jtag is
    port(
      addr_o   : out std_logic_vector(31 downto 0);
      data_o   : out std_logic_vector(31 downto 0);
      data_i   : in  std_logic_vector(31 downto 0);
      gpio_o   : out std_logic_vector( 3 downto 0);
      we_xor_o : out std_logic;
      rstn_o   : out std_logic);
  end component jtag;

  component uart is
    generic(
      g_wide : natural := 8;
      g_deep : natural := 10);
    port(
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      stb_i    : in  std_logic;
      stall_o  : out std_logic;
      dat_i    : in  std_logic_vector(g_wide-1 downto 0);
      stb_o    : out std_logic;
      stall_i  : in  std_logic;
      dat_o    : out std_logic_vector(g_wide-1 downto 0));
  end component uart;

  -- Reset
  signal clk_free : std_logic;
  signal locked   : std_logic;
  signal r_delock : std_logic := '1';
  signal s_rstin  : std_logic;
  signal r_rstin  : std_logic_vector(2 downto 0) := (others => '0');
  signal r_rsth   : std_logic_vector(2 downto 0) := (others => '0');
  signal r_rstc   : unsigned(19 downto 0) := (others => '1');
  signal r_rstn   : std_logic := '0';
  signal r_rsttg  : std_logic_vector(4 downto 0) := (others => '0');
  signal rstn     : std_logic;
  
  -- Clocking
  signal clk_100m : std_logic;
  signal r_dip2   : std_logic_vector(dip'range);
  signal r_dip1   : std_logic_vector(dip'range);
  signal r_dip    : std_logic_vector(dip'range);
  signal r_ena    : std_logic;
  signal r_div    : unsigned(27 downto 0);
  signal r_cnt    : unsigned(27 downto 0);
  signal r_gate   : std_logic;
  signal clk      : std_logic;
  signal r_clk    : std_logic; -- pretty clock output (1/2 clk)
  
  -- OPA signals
  signal i_cyc  : std_logic;
  signal i_stb  : std_logic;
  signal i_stall: std_logic;
  signal i_ack  : std_logic;
  signal i_addr : std_logic_vector(c_config.adr_width-1 downto 0);
  signal i_dat  : std_logic_vector(31 downto 0); 
  signal d_cyc  : std_logic;
  signal d_stb  : std_logic;
  signal d_stall: std_logic;
  signal d_we   : std_logic;
  signal d_ack  : std_logic;
  signal d_addr : std_logic_vector(c_config.adr_width-1 downto 0);
  signal d_sel  : std_logic_vector( 3 downto 0);
  signal d_dati : std_logic_vector(31 downto 0);
  signal d_dato : std_logic_vector(31 downto 0);
  signal p_cyc  : std_logic;
  signal p_stb  : std_logic;
  signal p_stall: std_logic;
  signal p_we   : std_logic;
  signal p_ack  : std_logic;
  signal p_addr : std_logic_vector(c_config.adr_width-1 downto 0);
  signal p_sel  : std_logic_vector( 3 downto 0);
  signal p_dati : std_logic_vector(31 downto 0);
  signal p_dato : std_logic_vector(31 downto 0);
  signal s_led  : std_logic_vector(c_config.num_fast+c_config.num_slow-1 downto 0);
  signal d_wem  : std_logic;
  
  -- JTAG connection
  signal jtag_addr : std_logic_vector(31 downto 0);
  signal jtag_data : std_logic_vector(31 downto 0);
  signal gpio      : std_logic_vector( 3 downto 0);
  signal s_we_xor  : std_logic;
  signal jtag_rstn : std_logic;
  signal s_a_addr  : std_logic_vector(c_config.adr_width-1 downto 0);
  
  signal r_we_xor2 : std_logic;
  signal r_we_xor1 : std_logic;
  signal r_we_xor0 : std_logic;
  signal r_we      : std_logic;
  
  -- UART flow control
  signal s_uart_we : std_logic;
  signal s_uart_re : std_logic;
  signal s_uart_stall : std_logic;
  
  -- User button presed?
  signal r_but2 : std_logic;
  signal r_but1 : std_logic;
  signal r_but0 : std_logic;

begin

  -- The free running external clock
  clk_free <= osc;

  -- Derive an on-chip clock
  clockpll : pll
    port map(
      refclk   => clk_free,
      rst      => r_delock,
      outclk_0 => clk_100m,
      locked   => locked);
  
  -- If we lose lock, assert r_delock
  delock : process(clk_free) is
  begin
    if rising_edge(clk_free) then
      r_delock <= not locked and r_rstn;
    end if;
  end process;
      
  -- Pulse extend any short/glitchy lock loss to at least one clock period
  s_rstin <= locked and but(1) and jtag_rstn;
  reset_in : process(clk_free, s_rstin) is
  begin
    if s_rstin = '0' then
      r_rstin <= (others => '0');
    elsif rising_edge(clk_free) then
      r_rstin <= '1' & r_rstin(r_rstin'high downto r_rstin'low+1);
    end if;
  end process;

  -- Safely transfer reset signal into free-running clock domain (meta-stable)
  reset_meta : process(clk_free) is
  begin
    if rising_edge(clk_free) then
      r_rsth <= r_rstin(r_rstin'low) & r_rsth(r_rsth'high downto r_rsth'low+1);
    end if;
  end process;
  
  -- Derive a reasonable duration reset (debounce)
  reset : process(clk_free, r_rsth(r_rsth'low)) is
  begin
    if r_rsth(r_rsth'low) = '0' then
      r_rstn <= '0';
      r_rstc <= (others => '1');
    elsif rising_edge(clk_free) then
      if r_rstc = 0 then
        r_rstn <= '1';
        r_rstc <= (others => '0');
      else
        r_rstn <= '0';
        r_rstc <= r_rstc - 1;
      end if;
    end if;
  end process;
  
  -- Select clock divider
  clocksel : process(clk_free) is
  begin
    if rising_edge(clk_free) then
      -- Eliminate any meta-stability (still bounces, but does not matter)
      r_dip2 <= dip;
      r_dip1 <= r_dip2;
      r_dip  <= r_dip1;
      
      -- Decode the target clock rate
      if    r_dip(1) = '0' then -- dip0 => 100MHz
        r_ena <= '1';
        r_div <= to_unsigned(1, r_div'length);
      elsif r_dip(2) = '0' then -- dip1 => 10kHz
        r_ena <= '1';
        r_div <= to_unsigned(10000, r_div'length);
      elsif r_dip(3) = '0' then -- dip2 => 1Hz
        r_ena <= '1';
        r_div <= to_unsigned(100000000, r_div'length);
      else                      -- no dip => clock disabled
        r_ena <= '0';
        r_div <= (others => '-');
      end if;
    end if;
  end process;
  
  -- Gate the clock
  gate : process(clk_100m) is
  begin
    if rising_edge(clk_100m) then
      if r_cnt >= r_div then
        r_gate <= r_ena;
        r_cnt  <= to_unsigned(1, r_cnt'length);
      else
        r_gate <= '0';
        r_cnt  <= r_cnt + 1;
      end if;
    end if;
  end process;

  -- Use a hardware clock gate at the clock network source
  clockmux : altclkctrl
    generic map(
      number_of_clocks => 1)
    port map(
      ena       => r_gate,
      inclk(0)  => clk_100m,
      outclk    => clk);
  
  -- Inject reset from free running clock to target domain (remove meta-stability)
  reset_target : process(clk) is
  begin
    if rising_edge(clk) then
      r_rsttg <= r_rstn & r_rsttg(r_rsttg'high downto r_rsttg'low+1);
    end if;
  end process;
  rstn <= r_rsttg(0);

  opa_core : opa
    generic map(
      g_isa    => T_OPA_LM32,
      g_config => c_config,
      g_target => c_opa_cyclone_v)
    port map(
      clk_i     => clk,
      rst_n_i   => rstn,
      i_cyc_o   => i_cyc,
      i_stb_o   => i_stb,
      i_stall_i => i_stall,
      i_ack_i   => i_ack,
      i_err_i   => '0',
      i_addr_o  => i_addr,
      i_data_i  => i_dat,
      d_cyc_o   => d_cyc,
      d_stb_o   => d_stb,
      d_we_o    => d_we,
      d_stall_i => d_stall,
      d_ack_i   => d_ack,
      d_err_i   => '0',
      d_addr_o  => d_addr,
      d_sel_o   => d_sel,
      d_data_o  => d_dato,
      d_data_i  => d_dati,
      p_cyc_o   => p_cyc,
      p_stb_o   => p_stb,
      p_we_o    => p_we,
      p_stall_i => p_stall,
      p_ack_i   => p_ack,
      p_err_i   => '0',
      p_addr_o  => p_addr,
      p_sel_o   => p_sel,
      p_data_o  => p_dato,
      p_data_i  => p_dati,
      status_o  => s_led);
  
  led(7) <= '0' when r_clk   ='1' else 'Z';
  led(6) <= '0' when gpio(3) ='1' else 'Z';
  led(5) <= '0' when gpio(2) ='1' else 'Z';
  led(4) <= '0' when gpio(1) ='1' else 'Z';
  led(3) <= '0' when gpio(0) ='1' else 'Z';
  activity : for i in s_led'range generate
    led(i) <= '0' when s_led(i)='1' else 'Z';
  end generate;
  d_wem <= d_cyc and d_stb and d_we;
  
  ext : jtag
    port map(
      addr_o   => jtag_addr,
      data_o   => jtag_data,
      data_i   => i_dat,
      gpio_o   => gpio,
      we_xor_o => s_we_xor,
      rstn_o   => jtag_rstn);
  
  a_we : process(clk) is
  begin
    if rising_edge(clk) then
      r_we_xor0 <= s_we_xor;
      r_we_xor1 <= r_we_xor0;
      r_we_xor2 <= r_we_xor1;
      r_we <= r_we_xor1 xor r_we_xor2;
    end if;
  end process;
  s_a_addr <= jtag_addr(s_a_addr'range) when jtag_rstn='0' else i_addr;
  
  i_stall <= '0';
  d_stall <= '0';
  
  ram : opa_tdpram
    generic map(
      g_width => 8,
      g_size  => 2**c_log_ram,
      g_hunks => 4)
    port map(
      clk_i    => clk,
      rst_n_i  => '1', -- run even while CPU reset
      a_wen_i  => r_we,
      a_sel_i  => (others => '1'),
      a_addr_i => s_a_addr(c_log_ram+1 downto 2),
      a_data_i => jtag_data,
      a_data_o => i_dat,
      b_wen_i  => d_wem,
      b_sel_i  => d_sel,
      b_addr_i => d_addr(c_log_ram+1 downto 2),
      b_data_i => d_dato,
      b_data_o => d_dati);

  idpbus : process(clk) is
  begin
    if rising_edge(clk) then
      i_ack <= i_cyc and i_stb and not i_stall;
      d_ack <= d_cyc and d_stb and not d_stall;
      p_ack <= p_cyc and p_stb and not p_stall;
      r_clk <= not r_clk;
    end if;
  end process;
  
  s_uart_we <= p_cyc and p_stb and p_we and p_sel(0);
  s_uart_re <= p_cyc and p_stb and not p_we;
  p_stall   <= s_uart_stall and p_we;
  
  io : uart
    port map(
      clk_i   => clk,
      rst_n_i => rstn,
      stb_i   => s_uart_we,
      stall_o => s_uart_stall,
      dat_i   => p_dato(7 downto 0),
      stb_o   => p_dati(8),
      stall_i => "not"(s_uart_re),
      dat_o   => p_dati(7 downto 0));
  
  p_dati(30 downto 9) <= (others => '0');
  
  button : process(clk) is
  begin
    if rising_edge(clk) then
      r_but2 <= but(2);
      r_but1 <= r_but2;
      r_but0 <= r_but1;
    end if;
  end process;
  p_dati(31) <= not r_but0;
  
end rtl;
