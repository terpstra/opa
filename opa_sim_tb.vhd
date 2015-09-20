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
use work.demo_pkg.all;

entity opa_sim_tb is
end opa_sim_tb;

architecture rtl of opa_sim_tb is

  constant period : time := 5 ns; -- 100MHz has 5ns high
  signal clk, rstn : std_logic;

  constant c_config : t_opa_config := c_opa_large;
  
  signal i_cyc    : std_logic;
  signal i_stb    : std_logic;
  signal i_stall  : std_logic;
  signal i_ack    : std_logic;
  signal i_err    : std_logic;
  signal i_addr   : std_logic_vector(2**c_config.log_width  -1 downto 0);
  signal i_data   : std_logic_vector(2**c_config.log_width  -1 downto 0);

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
  
  signal ram : t_word_array(demo'range) := demo;
  
begin

  clock : process
  begin
    clk <= '1';
    wait for period;
    clk <= '0';
    wait for period;
  end process;

  reset : process
  begin
    rstn <= '0';
    wait for period*8;
    rstn <= '1';
    wait until rstn = '0';
  end process;
  
  opa_core : opa
    generic map(
      g_config => c_config,
      g_target => c_opa_cyclone_v)
    port map(
      clk_i     => clk,
      rst_n_i   => rstn,
      
      i_cyc_o   => i_cyc,
      i_stb_o   => i_stb,
      i_stall_i => i_stall,
      i_ack_i   => i_ack,
      i_err_i   => i_err,
      i_addr_o  => i_addr,
      i_data_i  => i_data,
      
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
  
  test : process(clk, rstn) is
    variable da, ia : integer;
  begin
    if rstn = '0' then
      i_ack    <= '0';
      i_data   <= (others => '0');
      d_ack    <= '0';
      d_data_i <= (others => '0');
    elsif rising_edge(clk) then
      i_ack    <= i_cyc and i_stb;
      d_ack    <= d_cyc and d_stb;
      
      ia := to_integer(unsigned(i_addr(i_addr'left downto (c_config.log_width-3))));
      da := to_integer(unsigned(d_addr(d_addr'left downto (c_config.log_width-3))));
      
      i_data   <= (others => 'X');
      d_data_i <= (others => 'X');
      
      if (i_cyc and i_stb) = '1' then
        if ia > ram'high or ia < ram'low then
          assert (ia >= ram'low and ia <= ram'high)
          report "Instruction bus read out-of-bounds"
          severity warning;
        else
          i_data <= ram(ia);
        end if;
      end if;
      
      if (d_cyc and d_stb) = '1' then
        if da > ram'high or da < ram'low then
          assert (da >= ram'low and da <= ram'high)
          report "Data bus access out-of-bounds"
          severity warning;
        else
          if d_we = '0' then
            d_data_i <= ram(da);
          else
            for b in d_sel'range loop
              if d_sel(b) = '1' then
                ram(da)((b+1)*8-1 downto b*8) <= d_data_o((b+1)*8-1 downto b*8);
              end if;
            end loop;
          end if;
        end if;
      end if;
    end if;
  end process;
  
  -- for now:
  i_stall <= '0';
  d_stall <= '0';
  i_err   <= '0';
  d_err   <= '0';

end rtl;
