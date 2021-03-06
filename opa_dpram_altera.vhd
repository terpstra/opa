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

library altera_mf;
use altera_mf.altera_mf_components.all;

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

architecture syn of opa_dpram is

  constant c_m10k      : boolean := g_regin; -- (g_regin and g_size > 32) or (g_equal = OPA_OLD);
  constant c_mlab_cin  : string  := f_opa_choose(g_regin,  "OUTCLOCK", "UNREGISTERED");
  constant c_mlab_cout : string  := f_opa_choose(g_regout, "OUTCLOCK", "UNREGISTERED");
  constant c_m10k_cout : string  := f_opa_choose(g_regout, "CLOCK0",   "UNREGISTERED");

  signal s_rdata      : std_logic_vector(g_width-1 downto 0);
  signal s_bypass     : std_logic;
  signal r_bypass1    : std_logic;
  signal r_bypass2    : std_logic;
  signal s_mux_bypass : std_logic;
  signal s_wdata      : std_logic_vector(g_width-1 downto 0);
  signal r_wdata1     : std_logic_vector(g_width-1 downto 0);
  signal r_wdata2     : std_logic_vector(g_width-1 downto 0);
  signal s_mux_wdata  : std_logic_vector(g_width-1 downto 0);

begin

  nohw : 
    assert (g_equal /= OPA_OLD or g_regin)
    report "opa_dpram cannot be used in OPA_OLD mode without a registered input"
    severity failure;

  regout : if not c_m10k generate
    ram : altdpram
      generic map(
        intended_device_family             => "Arria V",
        indata_aclr                        => "OFF",
        indata_reg                         => "INCLOCK",
        lpm_type                           => "altdpram",
        outdata_aclr                       => "OFF",
        outdata_reg                        => c_mlab_cout,
        ram_block_type                     => "MLAB",
        rdaddress_aclr                     => "OFF",
        rdaddress_reg                      => c_mlab_cin,
        rdcontrol_aclr                     => "OFF",
        rdcontrol_reg                      => "UNREGISTERED",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        width                              => g_width,
        widthad                            => f_opa_log2(g_size),
        width_byteena                      => 1,
        wraddress_aclr                     => "OFF",
        wraddress_reg                      => "INCLOCK",
        wrcontrol_aclr                     => "OFF",
        wrcontrol_reg                      => "INCLOCK")
      port map(
        outclock  => clk_i,
        wren      => w_en_i,
        wraddress => w_addr_i,
        data      => w_data_i,
        inclock   => clk_i,
        rdaddress => r_addr_i,
        q         => s_rdata);
  end generate;
  
  regin : if c_m10k generate
    ram : altsyncram
      generic map(
        intended_device_family             => "Arria V",
        address_aclr_b                     => "NONE",
        address_reg_b                      => "CLOCK0", -- always registered
        clock_enable_input_a               => "BYPASS",
        clock_enable_input_b               => "BYPASS",
        clock_enable_output_b              => "BYPASS",
        lpm_type                           => "altsyncram",
        numwords_a                         => g_size,
        numwords_b                         => g_size,
        operation_mode                     => "DUAL_PORT",
        outdata_aclr_b                     => "NONE",
        outdata_reg_b                      => c_m10k_cout,
        power_up_uninitialized             => "FALSE",
        ram_block_type                     => "M10K",
        read_during_write_mode_mixed_ports => "OLD_DATA",
        widthad_a                          => f_opa_log2(g_size),
        widthad_b                          => f_opa_log2(g_size),
        width_a                            => g_width,
        width_b                            => g_width,
        width_byteena_a                    => 1)
      port map(
        clock0    => clk_i,
        wren_a    => w_en_i,
        address_a => w_addr_i,
        data_a    => w_data_i,
        address_b => r_addr_i,
        q_b       => s_rdata);
  end generate;
  
  s_wdata   <= w_data_i;
  s_bypass <= f_opa_bit(r_addr_i = w_addr_i) and w_en_i;
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_wdata1  <= s_wdata;
      r_wdata2  <= r_wdata1;
      r_bypass1 <= s_bypass;
      r_bypass2 <= r_bypass1;
    end if;
  end process;
  
  s_mux_bypass <= 
    s_bypass  when (not g_regin and not g_regout) else
    r_bypass2 when (    g_regin and     g_regout) else
    r_bypass1;
  
  s_mux_wdata <= 
    s_wdata  when (not g_regin and not g_regout) else
    r_wdata2 when (    g_regin and     g_regout) else
    r_wdata1;
  
  r_data_o <= s_mux_wdata when (g_equal = OPA_NEW and s_mux_bypass = '1') else s_rdata;

end syn;
