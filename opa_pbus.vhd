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
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_pbus is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i       : in  std_logic;
    rst_n_i     : in  std_logic;
    
    p_cyc_o     : out std_logic;
    p_stb_o     : out std_logic;
    p_we_o      : out std_logic;
    p_stall_i   : in  std_logic;
    p_ack_i     : in  std_logic;
    p_err_i     : in  std_logic;
    p_addr_o    : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    p_sel_o     : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    p_data_o    : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    p_data_i    : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
    
    -- L1d requests action
    l1d_stall_o : out std_logic; -- stall has an async dep on addr
    l1d_req_i   : in  std_logic;
    l1d_we_i    : in  std_logic;
    l1d_addr_i  : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    l1d_sel_i   : in  std_logic_vector(2**g_config.log_width/8 -1 downto 0);
    l1d_dat_i   : in  std_logic_vector(2**g_config.log_width   -1 downto 0);
    
    l1d_pop_i   : in  std_logic;
    l1d_full_o  : out std_logic;
    l1d_err_o   : out std_logic;
    l1d_dat_o   : out std_logic_vector(2**g_config.log_width-1 downto 0));
end opa_pbus;

architecture rtl of opa_pbus is

  constant c_adr_wide  : natural := f_opa_adr_wide(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_sel_wide  : natural := c_reg_wide/8;
  constant c_fifo_wide : natural := c_adr_wide + c_sel_wide + c_reg_wide;
  constant c_fifo_deep : natural := 4;
  constant c_device_align : natural := f_opa_log2(c_page_size);
  
  signal s_stall   : std_logic; -- We can accept the op on l1d_addr_i
  signal s_push    : std_logic; -- L1d delivers req into FIFO (and possibly reg)
  signal s_exist   : std_logic; -- There exists data to be sent
  signal s_full    : std_logic; -- full regs were not drained by pbus
  signal s_pop     : std_logic; -- regs have accepted data from L1d or FIFO
  signal s_fin     : std_logic; -- pbus completed IO
  
  signal s_widx    : unsigned(c_fifo_deep-1 downto 0);
  signal s_ridx    : unsigned(c_fifo_deep-1 downto 0);
  signal s_fidx    : unsigned(c_fifo_deep-1 downto 0);
  signal s_fifo_in : std_logic_vector(c_fifo_wide-1 downto 0);
  signal s_fifo_out: std_logic_vector(c_fifo_wide-1 downto 0);
  
  signal r_widx    : unsigned(c_fifo_deep-1 downto 0) := (others => '0');
  signal r_ridx    : unsigned(c_fifo_deep-1 downto 0) := (others => '0');
  signal r_fidx    : unsigned(c_fifo_deep-1 downto 0) := (others => '0');
  signal r_stall   : std_logic := '0';
  signal r_cyc     : std_logic := '0';
  signal r_stb     : std_logic := '0';
  
  -- This cannot go into FIFO because we must tap it twice
  signal r_we_q    : std_logic_vector(2**c_fifo_deep-1 downto 0);
  
  signal r_we      : std_logic;
  signal r_adr     : std_logic_vector(c_adr_wide  -1 downto 0);
  signal r_sel     : std_logic_vector(c_reg_wide/8-1 downto 0);
  signal r_dat     : std_logic_vector(c_reg_wide  -1 downto 0);
  
  signal r_lock    : std_logic := '0'; -- !!! set somewhere in a CSR or so
  
  signal r_full    : std_logic := '0';
  signal r_err     : std_logic;
  signal r_que     : std_logic_vector(c_reg_wide-1 downto 0);
  
begin

  -- We accept requests into the same wishbone cycle if they are within the same device
  -- OR the user has explicitly requested the cycle line stay up (r_lock).
  s_stall <= 
    r_stall or not
    (r_lock or f_opa_bit(r_adr(r_adr'high downto c_device_align) = l1d_addr_i(r_adr'high downto c_device_align)));
  
  s_push  <= l1d_req_i and not s_stall;
  s_full  <= r_stb and p_stall_i;
  s_exist <= f_opa_bit(r_widx /= r_ridx) or s_push;
  s_pop   <= not s_full and s_exist;
  s_fin   <= r_cyc and (p_ack_i or p_err_i);
  
  l1d_stall_o <= s_stall;
  p_cyc_o  <= r_cyc;
  p_stb_o  <= r_stb;
  p_we_o   <= r_we;
  p_sel_o  <= r_sel;
  p_data_o <= r_dat;
  
  p_addr_o(p_addr_o'high downto r_adr'high) <= (others => r_adr(r_adr'high));
  p_addr_o(r_adr'high-1 downto 0) <= std_logic_vector(r_adr(r_adr'high-1 downto 0));
  
  -- !!! Consider setting g_regin=false and r_addr_i to r_ridx; ie: async read memory
  fifo_out : opa_dpram
    generic map(
      g_width  => c_fifo_wide,
      g_size   => 2**c_fifo_deep,
      g_equal  => OPA_NEW,
      g_regin  => true,
      g_regout => false)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_addr_i => std_logic_vector(s_ridx),
      r_data_o => s_fifo_out,
      w_en_i   => '1',
      w_addr_i => std_logic_vector(r_widx),
      w_data_i => s_fifo_in);

  s_widx <= r_widx + ("" & s_push);
  s_ridx <= r_ridx + ("" & s_pop);
  s_fidx <= r_fidx + ("" & s_fin);
  s_fifo_in <= l1d_addr_i & l1d_sel_i & l1d_dat_i;

  main : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_ridx  <= (others => '0');
      r_widx  <= (others => '0');
      r_fidx  <= (others => '0');
      r_stall <= '0';
      r_cyc   <= '0';
      r_stb   <= '0';
    elsif rising_edge(clk_i) then
      r_ridx  <= s_ridx;
      r_widx  <= s_widx;
      r_fidx  <= s_fidx;
      r_stall <= f_opa_bit(r_widx - r_fidx >= 2**c_fifo_deep-2);
      r_cyc   <= f_opa_bit(s_widx /= s_fidx) or r_lock;
      r_stb   <= s_exist or s_full;
    end if;
  end process;
  
  we : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_we_q(to_integer(unsigned(r_widx))) <= l1d_we_i;
    end if;
  end process;
  
  pbus : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if p_stall_i = '0' then
        if r_ridx = r_widx then
          r_we  <= l1d_we_i;
          r_adr <= l1d_addr_i;
          r_sel <= l1d_sel_i;
          r_dat <= l1d_dat_i;
        else
          r_we  <= r_we_q(to_integer(unsigned(r_ridx)));
          r_adr <= s_fifo_out(s_fifo_out'high downto s_fifo_out'high-c_adr_wide+1);
          r_sel <= s_fifo_out(c_reg_wide/8*9-1 downto c_reg_wide);
          r_dat <= s_fifo_out(c_reg_wide-1 downto 0);
        end if;
      end if;
    end if;
  end process;
  
  -- !!! add a FIFO just like the above once we have prefetch => high throughput loads
  
  l1d_full_o <= r_full;
  l1d_err_o  <= r_err;
  l1d_dat_o  <= r_que;
  
  qmain : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_full <= '0';
    elsif rising_edge(clk_i) then
      r_full <= (r_full and not l1d_pop_i) or (s_fin and not r_we_q(to_integer(unsigned(r_fidx))));
    end if;
  end process;
  
  qbus : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_full = '0' then
        r_que  <= p_data_i;
        r_err  <= p_err_i;
      end if;
    end if;
  end process;

end rtl;
