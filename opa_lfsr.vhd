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

entity opa_lfsr is
  generic(
    g_entropy : natural := 0;
    g_bits    : natural);
  port(
    clk_i    : in  std_logic;
    rst_n_i  : in  std_logic;
    random_o : out std_logic_vector(g_bits-1 downto 0));
end opa_lfsr;

architecture rtl of opa_lfsr is

  -- We only want to work with trinomial irreducible polynomials
  -- They build-up less xor chains when we do multiple shifts at once

  constant c_size : natural := 18; -- Has a nice trionmial irreducible polynomial
  constant c_tap  : natural := 11; -- x^18 + x^11 + 1 is irreducible
  
  signal r_reg : std_logic_vector(c_size-1 downto 0);

begin

  main : process(clk_i, rst_n_i) is
    variable result : std_logic_vector(r_reg'range);
  begin
    if rst_n_i = '0' then
      r_reg <= (others => '1');
    elsif rising_edge(clk_i) then
      result := r_reg;
      for i in 0 to g_bits-1 loop
        result := result(result'high-1 downto result'low) & result(result'high);
        result(c_tap) := result(c_tap) xor result(result'low);
      end loop;
      r_reg <= result;
    end if;
  end process;

  random_o <= r_reg(random_o'range);

end rtl;
