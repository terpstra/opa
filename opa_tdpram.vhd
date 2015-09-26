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

-- Inputs are registered
-- Read output from a port during a write is undefined
-- Simultaneous write to the same address writes 'X's
-- Data read from one port while written by another outputs 'X'
entity opa_tdpram is
  generic(
    g_width  : natural;
    g_size   : natural;
    g_hunks  : natural := 1);
  port(
    clk_i    : in  std_logic;
    rst_n_i  : in  std_logic;
    a_wen_i  : in  std_logic;
    a_sel_i  : in  std_logic_vector(g_hunks-1 downto 0) := (others => '1');
    a_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    a_data_i : in  std_logic_vector(g_hunks*g_width-1 downto 0);
    a_data_o : out std_logic_vector(g_hunks*g_width-1 downto 0);
    b_wen_i  : in  std_logic;
    b_sel_i  : in  std_logic_vector(g_hunks-1 downto 0) := (others => '1');
    b_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    b_data_i : in  std_logic_vector(g_hunks*g_width-1 downto 0);
    b_data_o : out std_logic_vector(g_hunks*g_width-1 downto 0));
end opa_tdpram;

architecture rtl of opa_tdpram is
begin

  nobe : if g_hunks = 1 generate
    simple : block is
      type t_memory is array(g_size-1 downto 0) of std_logic_vector(g_width-1 downto 0);
      shared variable v_memory : t_memory;
      
      signal a_idx : integer;
      signal b_idx : integer;
    begin

      a_idx <= to_integer(unsigned(a_addr_i));
      b_idx <= to_integer(unsigned(b_addr_i));
      
      a : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          if (a_wen_i and a_sel_i(0)) = '1' then
            v_memory(a_idx) := a_data_i;
          end if;
          a_data_o <= v_memory(a_idx);
          
          -- Output undefined during write
          if a_wen_i = '1' or (b_wen_i = '1' and a_idx = b_idx) then
            a_data_o <= (others => 'X');
          end if;
        end if;
      end process;
      
      b : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          if (b_wen_i and b_sel_i(0)) = '1' then
            v_memory(b_idx) := b_data_i;
          end if;
          b_data_o <= v_memory(b_idx);
          
          -- Output undefined during write
          if b_wen_i = '1' or (a_wen_i = '1' and a_idx = b_idx) then
            b_data_o <= (others => 'X');
          end if;
        end if;
      end process;
      
      fatal : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          assert (a_idx /= b_idx or a_wen_i = '0' or b_wen_i = '0')
          report "Two writes to the same address in opa_tdpram"
          severity failure;
        end if;
      end process;
    end block;
  end generate;
  
  -- Reduce the dpram to multiple dprams per byte enable
  be : if g_hunks > 1 generate
    recurse : block is
      signal s_clk_i    : std_logic;
      signal s_rst_n_i  : std_logic;
      signal s_a_wen_i  : std_logic;
      signal s_a_sel_i  : std_logic_vector(g_hunks-1 downto 0) := (others => '1');
      signal s_a_addr_i : std_logic_vector(f_opa_log2(g_size)-1 downto 0);
      signal s_a_data_i : std_logic_vector(g_hunks*g_width-1 downto 0);
      signal s_a_data_o : std_logic_vector(g_hunks*g_width-1 downto 0);
      signal s_b_wen_i  : std_logic;
      signal s_b_sel_i  : std_logic_vector(g_hunks-1 downto 0) := (others => '1');
      signal s_b_addr_i : std_logic_vector(f_opa_log2(g_size)-1 downto 0);
      signal s_b_data_i : std_logic_vector(g_hunks*g_width-1 downto 0);
      signal s_b_data_o : std_logic_vector(g_hunks*g_width-1 downto 0);
    begin
      -- We have to rename so they don't conflict in recursive component
      s_clk_i    <= clk_i;
      s_rst_n_i  <= rst_n_i;
      s_a_wen_i  <= a_wen_i;
      s_a_sel_i  <= a_sel_i;
      s_a_addr_i <= a_addr_i;
      s_a_data_i <= a_data_i;
      a_data_o <= s_a_data_o;
      s_b_wen_i  <= b_wen_i;
      s_b_sel_i  <= b_sel_i;
      s_b_addr_i <= b_addr_i;
      s_b_data_i <= b_data_i;
      b_data_o <= s_b_data_o;
      
      bex : for i in 0 to g_hunks-1 generate
        ram : entity opa_tdpram
          generic map(
            g_width => g_width,
            g_size  => g_size)
          port map(
            clk_i    => s_clk_i,
            rst_n_i  => s_rst_n_i,
            a_wen_i  => s_a_wen_i,
            a_sel_i  => s_a_sel_i(i downto i),
            a_addr_i => s_a_addr_i,
            a_data_i => s_a_data_i((i+1)*g_width-1 downto i*g_width),
            a_data_o => s_a_data_o((i+1)*g_width-1 downto i*g_width),
            b_wen_i  => s_b_wen_i,
            b_sel_i  => s_b_sel_i(i downto i),
            b_addr_i => s_b_addr_i,
            b_data_i => s_b_data_i((i+1)*g_width-1 downto i*g_width),
            b_data_o => s_b_data_o((i+1)*g_width-1 downto i*g_width));
      end generate;
    end block;
  end generate;

end rtl;
