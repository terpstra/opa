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

library altera_mf;
use altera_mf.altera_mf_components.all;

entity uart is
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
end uart;

architecture rtl of uart is

  -- Virtual JTAG pins
  signal s_tck               : std_logic;
  signal s_tdi               : std_logic;
  signal s_tdo               : std_logic;
  signal s_virtual_state_cdr : std_logic;
  signal s_virtual_state_sdr : std_logic;
  signal s_virtual_state_udr : std_logic;
  
  -- SYS to JTAG
  signal s_s2j_full   : std_logic;
  signal s_s2j_push   : std_logic;
  signal s_s2j_empty  : std_logic;
  signal s_s2j_pop    : std_logic;
  signal s_s2j_dat    : std_logic_vector(g_wide-1 downto 0);
  
  -- JTAG to SYS
  signal s_j2s_full   : std_logic;
  signal s_j2s_push   : std_logic;
  signal s_j2s_empty  : std_logic;
  signal s_j2s_pop    : std_logic;
  signal s_j2s_dat    : std_logic_vector(g_wide-1 downto 0);

  -- JTAG shift register
  signal r_jtag_valid : std_logic;
  signal r_jtag_dat   : std_logic_vector(g_wide-1 downto 0);

begin

  stall_o    <= s_s2j_full;
  s_s2j_push <= stb_i and not s_s2j_full;
  
  s_s2j_pop <= s_virtual_state_cdr and not s_s2j_empty;
  
  s2j : dcfifo
    generic map(
      lpm_width         => g_wide,
      lpm_widthu        => g_deep,
      lpm_numwords      => 2**g_deep,
      lpm_showahead     => "ON",
      overflow_checking => "OFF",
      underflow_checking=> "OFF",
      rdsync_delaypipe  => 4,
      wrsync_delaypipe  => 4)
    port map(
      aclr    => "not"(rst_n_i),
      wrclk   => clk_i,
      data    => dat_i,
      wrreq   => s_s2j_push,
      wrfull  => s_s2j_full,
      rdclk   => s_tck,
      q       => s_s2j_dat,
      rdreq   => s_s2j_pop,
      rdempty => s_s2j_empty);

  -- !!! no flow control on input from JTAG; we drop on overflow
  s_j2s_push <= r_jtag_valid and s_virtual_state_udr and not s_j2s_full;
  
  stb_o <= not s_j2s_empty;
  dat_o <= s_j2s_dat;
  s_j2s_pop <= not stall_i and not s_j2s_empty;
  
  j2s : dcfifo
    generic map(
      lpm_width         => g_wide,
      lpm_widthu        => g_deep,
      lpm_numwords      => 2**g_deep,
      lpm_showahead     => "ON",
      overflow_checking => "OFF",
      underflow_checking=> "OFF",
      rdsync_delaypipe  => 4,
      wrsync_delaypipe  => 4)
    port map(
      aclr    => "not"(rst_n_i),
      wrclk   => s_tck,
      data    => r_jtag_dat,
      wrreq   => s_j2s_push,
      wrfull  => s_j2s_full,
      rdclk   => clk_i,
      q       => s_j2s_dat,
      rdreq   => s_j2s_pop,
      rdempty => s_j2s_empty);

  vjtag : sld_virtual_jtag
    generic map(
      sld_instance_index => 98,
      sld_ir_width       => 1)
    port map(
      ir_in              => open,
      ir_out             => "0",
      jtag_state_cdr     => open,
      jtag_state_cir     => open,
      jtag_state_e1dr    => open,
      jtag_state_e1ir    => open,
      jtag_state_e2dr    => open,
      jtag_state_e2ir    => open,
      jtag_state_pdr     => open,
      jtag_state_pir     => open,
      jtag_state_rti     => open,
      jtag_state_sdr     => open,
      jtag_state_sdrs    => open,
      jtag_state_sir     => open,
      jtag_state_sirs    => open,
      jtag_state_tlr     => open,
      jtag_state_udr     => open,
      jtag_state_uir     => open,
      tck                => s_tck,
      tdi                => s_tdi,
      tdo                => s_tdo,
      tms                => open,
      virtual_state_cdr  => s_virtual_state_cdr,
      virtual_state_cir  => open,
      virtual_state_e1dr => open,
      virtual_state_e2dr => open,
      virtual_state_pdr  => open,
      virtual_state_sdr  => s_virtual_state_sdr,
      virtual_state_udr  => s_virtual_state_udr,
      virtual_state_uir  => open);

   jtag : process(s_tck) is
   begin
     if rising_edge(s_tck) then
       if s_virtual_state_cdr = '1' then
         r_jtag_valid <= not s_s2j_empty;
         r_jtag_dat   <= s_s2j_dat;
       end if;
       
       if s_virtual_state_sdr = '1' then
         r_jtag_valid <= s_tdi;
         r_jtag_dat   <= r_jtag_valid & r_jtag_dat(r_jtag_dat'high downto r_jtag_dat'low+1);
       end if;
     end if;
   end process;
   
   s_tdo <= r_jtag_dat(r_jtag_dat'low);
   
end rtl;
