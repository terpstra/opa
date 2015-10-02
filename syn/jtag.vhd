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

entity jtag is
  port(
    addr_o   : out std_logic_vector(31 downto 0);
    data_o   : out std_logic_vector(31 downto 0);
    data_i   : in  std_logic_vector(31 downto 0);
    gpio_o   : out std_logic_vector( 3 downto 0);
    we_xor_o : out std_logic;
    rstn_o   : out std_logic);
end jtag;

architecture rtl of jtag is

  constant c_ir_wide : natural := 2;
  
  constant c_IR_GPIO : std_logic_vector := "00";
  constant c_IR_ADDR : std_logic_vector := "10";
  constant c_IR_DATA : std_logic_vector := "11";

  -- Virtual JTAG pins
  signal s_tck               : std_logic;
  signal s_tdi               : std_logic;
  signal s_tdo               : std_logic;
  signal s_virtual_state_cdr : std_logic;
  signal s_virtual_state_sdr : std_logic;
  signal s_virtual_state_udr : std_logic;
  signal s_virtual_state_uir : std_logic;
  signal s_ir                : std_logic_vector(c_ir_wide-1 downto 0);
  signal r_ir                : std_logic_vector(c_ir_wide-1 downto 0);
  
  signal r_rstn : std_logic := '0';
  signal r_xor  : std_logic := '0';
  signal r_gpio : std_logic_vector( 5 downto 0) := (others => '0');
  signal r_addr : std_logic_vector(31 downto 0);
  signal r_data : std_logic_vector(31 downto 0);

begin

  vjtag : sld_virtual_jtag
    generic map(
      sld_instance_index => 99,
      sld_ir_width       => c_ir_wide)
    port map(
      ir_in              => s_ir,
      ir_out             => r_ir,
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
      virtual_state_uir  => s_virtual_state_uir);

   jtag : process(s_tck) is
   begin
     if rising_edge(s_tck) then
       if s_virtual_state_uir = '1' then
         r_ir <= s_ir;
       end if;
       
       if s_virtual_state_cdr = '1' then
         case r_ir is
           when c_IR_DATA => r_data <= data_i;
           when others    => null;
         end case;
       end if;
       
       if s_virtual_state_sdr = '1' then
         case r_ir is
           when c_IR_GPIO => r_gpio <= s_tdi & r_gpio(r_gpio'high downto r_gpio'low+1);
           when c_IR_ADDR => r_addr <= s_tdi & r_addr(r_addr'high downto r_addr'low+1);
           when c_IR_DATA => r_data <= s_tdi & r_data(r_data'high downto r_data'low+1);
           when others    => null;
         end case;
       end if;
       
       if s_virtual_state_udr = '1' then
         case r_ir is
           when c_IR_GPIO => r_rstn <= r_gpio(5); r_xor <= r_xor xor r_gpio(4);
           when others    => null;
         end case;
       end if;
     end if;
   end process;
   
   with r_ir select
   s_tdo <=
     r_gpio(r_gpio'low) when c_IR_GPIO,
     r_addr(r_addr'low) when c_IR_ADDR,
     r_data(r_data'low) when c_IR_DATA,
     '-'                when others;
   
   addr_o <= r_addr;
   data_o <= r_data;
   gpio_o <= r_gpio(gpio_o'range);
   we_xor_o <= r_xor;
   rstn_o   <= r_rstn;
   
end rtl;
