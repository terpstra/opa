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

entity opa_icache is
  generic(
    g_isa    : t_opa_isa;
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;
    
    predict_stall_o : out std_logic;
    predict_pc_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    
    decode_stb_o    : out std_logic;
    decode_stall_i  : in  std_logic;
    decode_fault_i  : in  std_logic;
    decode_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    decode_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    decode_dat_o    : out std_logic_vector(f_opa_fetch_bits(g_isa,g_config)-1 downto 0);
    
    i_cyc_o         : out std_logic;
    i_stb_o         : out std_logic;
    i_stall_i       : in  std_logic;
    i_ack_i         : in  std_logic;
    i_err_i         : in  std_logic;
    i_addr_o        : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    i_data_i        : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0));
end opa_icache;

architecture rtl of opa_icache is

  constant c_big_endian: boolean := f_opa_big_endian(g_isa);
  constant c_op_align  : natural := f_opa_op_align(g_isa);
  constant c_page_size : natural := f_opa_page_size(g_isa);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide  : natural := f_opa_adr_wide(g_config);
  constant c_fetch_bits: natural := f_opa_fetch_bits(g_isa,g_config);
  constant c_num_load  : natural := c_fetch_bits/c_reg_wide;
  constant c_reg_align : natural := f_opa_log2(c_reg_wide/8);
  constant c_load_wide : natural := f_opa_log2(c_num_load);
  constant c_page_wide : natural := f_opa_log2(c_page_size);
  constant c_fetch_align: natural := f_opa_fetch_align(g_isa,g_config);
  constant c_fetch_bytes: natural := f_opa_fetch_bytes(g_isa,g_config);
  constant c_tag_wide  : natural := c_adr_wide - c_page_wide;
  constant c_size      : natural := c_page_size/c_fetch_bytes;
  
  constant c_fetch_adr : unsigned(c_adr_wide-1 downto 0) := to_unsigned(c_fetch_bytes, c_adr_wide);
  constant c_increment : unsigned(c_adr_wide-1 downto c_op_align) := c_fetch_adr(c_adr_wide-1 downto c_op_align);
  
  signal r_wipe  : std_logic := '1';
  signal r_hit   : std_logic := '0';
  signal s_stall : std_logic;
  signal s_dstb  : std_logic;
  signal s_repeat: std_logic;
  signal s_wen   : std_logic;
  signal r_wen   : std_logic := '0';
  signal r_icyc  : std_logic := '0';
  signal r_istb  : std_logic := '0';
  signal s_pc1   : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal s_rtag  : std_logic_vector(c_adr_wide-1 downto c_page_wide);
  signal s_rdata : std_logic_vector(c_fetch_bits-1 downto 0);
  signal r_rdata : std_logic_vector(c_fetch_bits-1 downto 0);
  signal s_wdata : std_logic_vector(c_fetch_bits-1 downto 0);
  signal s_rraw  : std_logic_vector(c_tag_wide+c_fetch_bits-1 downto 0);
  signal s_wraw  : std_logic_vector(c_tag_wide+c_fetch_bits-1 downto 0);
  signal r_pc1   : std_logic_vector(c_adr_wide-1 downto c_op_align) := std_logic_vector(c_increment);
  signal r_pc2   : std_logic_vector(c_adr_wide-1 downto c_op_align) := (others => '0');
  
  signal s_last_load : std_logic;
  signal s_last_get  : std_logic;
  
begin

  s_pc1 <= predict_pc_i when (s_stall = '0' or decode_fault_i = '1') else r_pc1;
  
  -- !!! increase number of ways
  cache : opa_dpram
    generic map(
      g_width  => s_rtag'length + s_rdata'length,
      g_size   => c_size,
      g_equal  => OPA_OLD,
      g_regin  => true,
      g_regout => false)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_addr_i => s_pc1(c_page_wide-1 downto c_fetch_align),
      r_data_o => s_rraw,
      w_en_i   => s_wen,
      w_addr_i => r_pc2 (c_page_wide-1 downto c_fetch_align),
      w_data_i => s_wraw);
  
  s_rtag  <= s_rraw(s_rraw'left downto s_rdata'length);
  s_rdata <= s_rraw(s_rdata'range);
  s_wraw(s_wraw'left downto s_wdata'length) <= r_pc2(s_rtag'range);
  s_wraw(s_wdata'range) <= s_wdata;

  -- The r_pc[12] comparison optimizes the case where we just wrote to the
  -- cache, and there were two back-to-back fetches of the same address.
  --
  -- If s_repeat were ALWAYS 0, we would get the old data from icache and
  -- conclude that there is no hit and then reload the same line again.
  -- Slow, but safe. This is why the memory cannot be OPA_UNDEF.
  -- 
  -- However, in the case that the r_pc1 and r_pc2 really refer to the same
  -- PHYSICAL address lines, we can use this optimization to avoid a cache 
  -- refill without the need for OPA_NEW.
  s_repeat <= f_opa_eq(r_pc1(r_pc1'high downto c_fetch_align),
                       r_pc2(r_pc2'high downto c_fetch_align));
  
  pc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_wipe <= '1';
      r_hit  <= '0';
      r_pc1  <= std_logic_vector(c_increment);
      r_pc2  <= (others => '0');
    elsif rising_edge(clk_i) then
      r_pc1 <= s_pc1;
      if r_wipe = '1' then
        if r_wen ='1' then
          r_pc2(c_page_wide-1 downto c_fetch_align) <= 
            std_logic_vector(unsigned(r_pc2(c_page_wide-1 downto c_fetch_align)) + 1);
          r_wipe <= not f_opa_and(r_pc2(c_page_wide-1 downto c_fetch_align));
        end if;
      else
        if s_stall = '0' then
          r_hit <= f_opa_eq(r_pc1(s_rtag'range), s_rtag) or s_repeat;
          r_pc2 <= r_pc1;
        end if;
      end if;
    end if;
  end process;
  
  rdata : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_stall = '0' and s_repeat = '0' then
        r_rdata <= s_rdata;
      end if;
      if s_wen = '1' then
        r_rdata <= s_wdata;
      end if;
    end if;
  end process;
  
  s_stall <= decode_stall_i or not s_dstb;
  s_dstb <= (r_hit or r_wen) and not r_wipe;
  
  predict_stall_o <= s_stall;
  
  decode_stb_o  <= s_dstb;
  decode_pc_o   <= r_pc2;
  decode_pcn_o  <= r_pc1;
  decode_dat_o  <= r_rdata;
  
  -- When accepting data into the line, endian matters
  dat1p : if c_num_load > 1 generate
    data : block is
      signal r_wdata : std_logic_vector(c_fetch_bits-1 downto 0);
    begin
      refill : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          if (r_icyc and i_ack_i) = '1' then
            r_wdata <= s_wdata;
          end if;
        end if;
      end process;
      
      big : if c_big_endian generate
        s_wdata <= r_wdata(c_fetch_bits-c_reg_wide-1 downto 0) & i_data_i;
      end generate;
      
      small : if not c_big_endian generate
        s_wdata <= i_data_i & r_wdata(c_fetch_bits-1 downto c_reg_wide);
      end generate;
    end block;
  end generate;
  dat1 : if c_num_load = 1 generate
    s_wdata <= i_data_i;
  end generate;
  
  -- !!! think about what to do on i_err_i
  -- probably easiest is to fill cache with instructions which generate a fault
  
  i_cyc_o <= r_icyc;
  i_stb_o <= r_istb;
  
  i_addr_o(c_adr_wide-1 downto c_fetch_align) <= r_pc2(c_adr_wide-1 downto c_fetch_align);
  i_addr_o(c_reg_align-1 downto 0)            <= (others => '0');
  
  fill : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_wen  <= '0';
      r_icyc <= '0';
      r_istb <= '0';
    elsif rising_edge(clk_i) then
      if s_wen = '1' then
        r_wen <= '1';
      elsif decode_stall_i = '0' then
        r_wen <= '0';
      end if;
      if (not s_dstb and not r_icyc) = '1' then
        r_istb <= '1';
        r_icyc <= '1';
      else
        if (r_istb and not i_stall_i) = '1' then
          r_istb <= not s_last_load;
        end if;
        if (r_icyc and i_ack_i) = '1' then
          r_icyc <= not s_last_get;
        end if;
      end if;
    end if;
  end process;
  
  count1 : if c_num_load = 1 generate
    s_last_load <= '1';
    s_last_get  <= '1';
    s_wen       <= i_ack_i;
  end generate;
  count1p : if c_num_load > 1 generate
    sigs : block is
      signal r_load : unsigned(c_load_wide-1 downto 0) := (others => '0');
      signal r_got  : unsigned(c_load_wide-1 downto 0) := (others => '0');
    begin
      counters : process(clk_i, rst_n_i) is
      begin
        if rst_n_i = '0' then
          r_load <= (others => '0');
          r_got  <= (others => '0');
        elsif rising_edge(clk_i) then
          if r_icyc = '0' then
            r_load <= (others => '0');
            r_got  <= (others => '0');
          else
            r_load <= r_load + ("" & (r_istb and not i_stall_i));
            r_got  <= r_got  + ("" & i_ack_i);
          end if;
        end if;
      end process;
      
      s_last_load <= f_opa_eq(r_load, c_num_load-1);
      s_last_get  <= f_opa_eq(r_got,  c_num_load-1);
      s_wen       <= i_ack_i and s_last_get;
      
      i_addr_o(c_fetch_align-1 downto c_reg_align) <= std_logic_vector(r_load);
    end block;
  end generate;

end rtl;
