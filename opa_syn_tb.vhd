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

entity opa_syn_tb is
  port(
    clk_i     : in  std_logic;
    rstn_i    : in  std_logic;
    i_cyc_o   : out std_logic;
    i_stb_o   : out std_logic;
    i_stall_i : in  std_logic;
    i_ack_i   : in  std_logic;
    i_data_i  : in  std_logic_vector(31 downto 0);
    d_cyc_o   : out std_logic; 
    d_stb_o   : out std_logic;
    d_we_o    : out std_logic;
    d_stall_i : in  std_logic;
    d_ack_i   : in  std_logic;
    d_sel_o   : out std_logic_vector(3 downto 0);
    d_data_o  : out std_logic_vector(31 downto 0);
    x_addr_o  : out std_logic_vector(31 downto 0));
end opa_syn_tb;

architecture rtl of opa_syn_tb is

  -- not enough pins to hook these up
  signal i_addr_o : std_logic_vector(31 downto 0);
  signal d_data_i : std_logic_vector(31 downto 0);
  signal d_addr_o : std_logic_vector(31 downto 0);
  
begin

  opa_core : opa
    generic map(
      g_config => c_opa_large,
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
      d_cyc_o   => d_cyc_o,
      d_stb_o   => d_stb_o,
      d_we_o    => d_we_o,
      d_stall_i => d_stall_i,
      d_ack_i   => d_ack_i,
      d_err_i   => '0',
      d_addr_o  => d_addr_o,
      d_sel_o   => d_sel_o,
      d_data_o  => d_data_o,
      d_data_i  => d_data_i);

  -- pin reduction hack
  d_data_i <= i_data_i;
  x_addr_o <= i_addr_o xor d_addr_o;
  
end rtl;
