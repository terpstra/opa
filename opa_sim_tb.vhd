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
use std.textio.all;

library work;
use work.opa_pkg.all;

-- Users do not need these packages:
use work.demo_pkg.all;           -- for demo program
use work.opa_isa_base_pkg.all;   -- for f_opa_log2
use work.opa_functions_pkg.all;  -- for f_opa_safe
use work.opa_components_pkg.all; -- for opa_lfsr

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
  signal i_addr   : std_logic_vector(c_config.adr_width  -1 downto 0);
  signal i_data   : std_logic_vector(c_config.reg_width  -1 downto 0);

  signal d_cyc    : std_logic;
  signal d_stb    : std_logic;
  signal d_we     : std_logic;
  signal d_stall  : std_logic;
  signal d_ack    : std_logic;
  signal d_err    : std_logic;
  signal d_addr   : std_logic_vector(c_config.adr_width  -1 downto 0);
  signal d_sel    : std_logic_vector(c_config.reg_width/8-1 downto 0);
  signal d_data_o : std_logic_vector(c_config.reg_width  -1 downto 0);
  signal d_data_i : std_logic_vector(c_config.reg_width  -1 downto 0);
  
  signal p_cyc    : std_logic;
  signal p_stb    : std_logic;
  signal p_we     : std_logic;
  signal p_stall  : std_logic;
  signal p_ack    : std_logic;
  signal p_err    : std_logic;
  signal p_addr   : std_logic_vector(c_config.adr_width  -1 downto 0);
  signal p_sel    : std_logic_vector(c_config.reg_width/8-1 downto 0);
  signal p_data_o : std_logic_vector(c_config.reg_width  -1 downto 0);
  signal p_data_i : std_logic_vector(c_config.reg_width  -1 downto 0);
  
  signal ram : t_word_array(c_demo_ram'range) := c_demo_ram;
  
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
      g_isa    => c_demo_isa,
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
      d_data_i  => d_data_i,
      
      p_cyc_o   => p_cyc,
      p_stb_o   => p_stb,
      p_we_o    => p_we,
      p_stall_i => p_stall,
      p_ack_i   => p_ack,
      p_err_i   => p_err,
      p_addr_o  => p_addr,
      p_sel_o   => p_sel,
      p_data_o  => p_data_o,
      p_data_i  => p_data_i);
  
  memory : process(clk, rstn) is
    variable da, ia : integer;
  begin
    if rstn = '0' then
      i_ack    <= '0';
      i_data   <= (others => '0');
      d_ack    <= '0';
      d_data_i <= (others => '0');
    elsif rising_edge(clk) then
      i_ack    <= i_cyc and i_stb and not i_stall;
      d_ack    <= d_cyc and d_stb and not d_stall;
      
      i_data   <= (others => 'X');
      d_data_i <= (others => 'X');
      
      assert (f_opa_safe(i_cyc) = '1') report "Meta-value on i_cyc" severity failure;
      assert (f_opa_safe(i_stb) = '1') report "Meta-value on i_stb" severity failure;
      if (i_cyc and i_stb) = '1' then
        assert (f_opa_safe(i_addr) = '1') report "Meta-value on instruction bus address" severity failure;
        ia := to_integer(unsigned(i_addr(i_addr'left downto f_opa_log2(c_config.reg_width)-3)));
        if ia > ram'high or ia < ram'low then
          assert (ia >= ram'low and ia <= ram'high)
          report "Instruction bus read out-of-bounds"
          severity warning;
        else
          i_data <= ram(ia);
        end if;
      end if;
      
      assert (f_opa_safe(d_cyc) = '1') report "Meta-value on d_cyc" severity failure;
      assert (f_opa_safe(d_stb) = '1') report "Meta-value on d_stb" severity failure;
      if (d_cyc and d_stb) = '1' then
        assert (f_opa_safe(d_we)     = '1') report "Meta-value on d_we"     severity failure;
        assert (f_opa_safe(d_addr)   = '1') report "Meta-value on d_addr"   severity failure;
        assert (f_opa_safe(d_sel)    = '1') report "Meta-value on d_sel"    severity failure;
        assert (f_opa_safe(d_data_o) = '1') report "Meta-value on d_data_o" severity failure;
        da := to_integer(unsigned(d_addr(d_addr'left downto f_opa_log2(c_config.reg_width)-3)));
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
  
  pbus : process(clk) is
    variable buf : line;
    variable ch : integer;
  begin
    if rising_edge(clk) then
      assert (f_opa_safe(p_cyc) = '1') report "Meta-value on p_cyc" severity failure;
      assert (f_opa_safe(p_stb) = '1') report "Meta-value on p_stb" severity failure;
      if (p_cyc and p_stb) = '1' then
        assert (f_opa_safe(p_we)     = '1') report "Meta-value on p_we"     severity failure;
        assert (f_opa_safe(p_addr)   = '1') report "Meta-value on p_addr"   severity failure;
        assert (f_opa_safe(p_sel)    = '1') report "Meta-value on p_sel"    severity failure;
        assert (f_opa_safe(p_data_o) = '1') report "Meta-value on p_data_o" severity failure;
        if (not p_stall and p_we) = '1' then
          ch := to_integer(unsigned(p_data_o(7 downto 0)));
          if ch = 10 then
            writeline(output, buf);
          else
            write(buf, character'val(ch));
          end if;
        end if;
      end if;
      p_ack <= p_cyc and p_stb and not p_stall;
      p_data_i <= (others => '0'); -- read from console?
    end if;
  end process;
  
  lsfr : opa_lfsr
    generic map(g_bits => 3)
    port map(
      clk_i       => clk,
      rst_n_i     => rstn,
      random_o(0) => i_stall,
      random_o(1) => d_stall,
      random_o(2) => p_stall);
  
  -- for now:
  i_err   <= '0';
  d_err   <= '0';
  p_err   <= '0';

end rtl;
