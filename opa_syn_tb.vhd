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
    i_addr_o  : out std_logic_vector(31 downto 0);
    i_data_i  : in  std_logic_vector(31 downto 0);
    good_o    : out std_logic);
end opa_syn_tb;

architecture rtl of opa_syn_tb is

  constant c_config : t_opa_config := c_opa_large;

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
