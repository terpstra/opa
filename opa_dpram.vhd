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

entity opa_dpram is
  generic(
    g_width  : natural;
    g_size   : natural;
    g_equal  : t_dpram_equal;
    g_regin  : boolean;
    g_regout : boolean);
  port(
    clk_i    : in  std_logic;
    rst_n_i  : in  std_logic;
    r_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    r_data_o : out std_logic_vector(g_width-1 downto 0);
    w_en_i   : in  std_logic;
    w_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    w_data_i : in  std_logic_vector(g_width-1 downto 0));
end opa_dpram;

architecture rtl of opa_dpram is
  type t_memory is array(g_size-1 downto 0) of std_logic_vector(g_width-1 downto 0);
  signal r_memory : t_memory := (others => (others => '0'));
  
  signal s_bypass       : std_logic;
  signal r_bypass       : std_logic;
  signal sr_bypass      : std_logic;
  signal s_data_memory  : std_logic_vector(g_width-1 downto 0);
  signal r_data_memory  : std_logic_vector(g_width-1 downto 0);
  signal sr_data_memory : std_logic_vector(g_width-1 downto 0);
  signal s_data_bypass  : std_logic_vector(g_width-1 downto 0);
  signal r_data_bypass  : std_logic_vector(g_width-1 downto 0);
  signal sr_data_bypass : std_logic_vector(g_width-1 downto 0);
  signal sr_data        : std_logic_vector(g_width-1 downto 0);
  signal srr_data       : std_logic_vector(g_width-1 downto 0);
begin

  nohw : 
    assert (g_equal /= OPA_OLD or g_regin)
    report "opa_dpram cannot be used in OPA_OLD mode without a registered input"
    severity failure;

  s_data_bypass <= w_data_i;
  s_data_memory <= r_memory(to_integer(unsigned(r_addr_i))) when f_opa_safe(r_addr_i)='1' else (others => 'X');
  s_bypass      <= f_opa_bit(r_addr_i = w_addr_i) and w_en_i;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if w_en_i = '1' then
        assert (f_opa_safe(w_addr_i) = '1') report "Attempt to write to a meta-valued address" severity failure;
        r_memory(to_integer(unsigned(w_addr_i))) <= w_data_i;
      end if;
      
      r_data_bypass <= s_data_bypass;
      r_data_memory <= s_data_memory;
      r_bypass      <= s_bypass;
      srr_data      <= sr_data;
    end if;
  end process;
  
  sr_data_bypass <= r_data_bypass when g_regin else s_data_bypass;
  sr_data_memory <= r_data_memory when g_regin else s_data_memory;
  sr_bypass      <= r_bypass      when g_regin else s_bypass;
  
  sr_data <= 
    sr_data_memory when sr_bypass = '0' or g_equal = OPA_OLD else
    sr_data_bypass when                    g_equal = OPA_NEW else
    (others => 'X');
  
  r_data_o <= srr_data when g_regout else sr_data;

end rtl;
