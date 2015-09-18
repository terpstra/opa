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

entity opa_slow is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    regfile_arg_i  : in  std_logic_vector(f_opa_arg_wide  (g_config)-1 downto 0);
    regfile_imm_i  : in  std_logic_vector(f_opa_imm_wide  (g_config)-1 downto 0);
    regfile_pc_i   : in  std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    regfile_pcf_i  : in  std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    regfile_pcn_i  : in  std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    
    l1d_stb_o      : out std_logic;
    l1d_we_o       : out std_logic;
    l1d_sext_o     : out std_logic;
    l1d_size_o     : out std_logic_vector(1 downto 0);
    l1d_addr_o     : out std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    l1d_data_o     : out std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    l1d_oldest_o   : out std_logic; -- delivered 1 cycle after stb
    l1d_retry_i    : in  std_logic; -- valid 1 cycle after stb_o 
    l1d_data_i     : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0); -- 2 cycles
    
    issue_oldest_i : in  std_logic;
    issue_retry_o  : out std_logic;
    issue_fault_o  : out std_logic;
    issue_pc_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    issue_pcf_o    : out std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    issue_pcn_o    : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align));
end opa_slow;

architecture rtl of opa_slow is

  constant c_reg_wide     : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide     : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide     : natural := f_opa_imm_wide(g_config);
  constant c_log_reg_wide : natural := f_opa_log2(c_reg_wide);
  
  signal s_slow    : t_opa_slow;
  signal r_stb     : std_logic;
  signal r_rega    : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_regb    : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_imm     : std_logic_vector(c_imm_wide-1 downto 0);
  signal r_mode1   : std_logic_vector(1 downto 0);
  signal r_mode2   : std_logic_vector(1 downto 0);
  signal r_mode3   : std_logic_vector(1 downto 0);
  
  signal s_mul     : t_opa_mul;
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);
  signal s_mul_out : std_logic_vector(  c_reg_wide-1 downto 0);
  signal r_high1   : std_logic;
  signal r_high2   : std_logic;
  signal r_high3   : std_logic;

  signal s_ldst    : t_opa_ldst;
  signal r_ldst    : t_opa_ldst;
  
  signal s_shift   : t_opa_shift;
  signal r_shift   : t_opa_shift;
  signal r_sexta   : std_logic_vector(2*c_reg_wide  -1 downto 0);
  signal r_shamt   : std_logic_vector(c_log_reg_wide   downto 0);
  signal s_shout   : std_logic_vector(2*c_reg_wide  -1 downto 0);
  signal r_shout   : std_logic_vector(c_reg_wide    -1 downto 0);

begin

  issue_retry_o   <= l1d_retry_i;
  issue_fault_o   <= '0';
  issue_pc_o      <= (others => '0');
  issue_pcf_o     <= (others => '0');
  issue_pcn_o     <= (others => '0');
  
  s_slow <= f_opa_slow_from_arg(regfile_arg_i);
  s_mul  <= f_opa_mul_from_slow(s_slow.raw);
  s_ldst <= f_opa_ldst_from_slow(s_slow.raw);
  s_shift<= f_opa_shift_from_slow(s_slow.raw);
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_stb   <= regfile_stb_i;
      r_rega  <= regfile_rega_i;
      r_regb  <= regfile_regb_i;
      r_imm   <= regfile_imm_i;
      r_ldst  <= s_ldst;
      r_mode1 <= s_slow.mode;
      r_mode2 <= r_mode1;
      r_mode3 <= r_mode2;
      r_high1 <= s_mul.high;
      r_high2 <= r_high1;
      r_high3 <= r_high2;
    end if;
  end process;
  
  prim : opa_prim_mul
    generic map(
      g_wide   => c_reg_wide,
      g_regout => true,
      g_regwal => false,
      g_target => g_target)
    port map(
      clk_i    => clk_i,
      a_i      => regfile_rega_i,
      b_i      => regfile_regb_i,
      x_o      => s_product);

  s_mul_out <= 
    s_product(  c_reg_wide-1 downto          0) when r_high3='0' else
    s_product(2*c_reg_wide-1 downto c_reg_wide);
  
  -- Hand over memory accesses to the L1d
  with r_mode1 select
  l1d_stb_o <= 
    r_stb when c_opa_slow_load,
    r_stb when c_opa_slow_store,
    '0'   when others;
  
  with r_mode1 select
  l1d_we_o <=
    '1' when c_opa_slow_store,
    '0' when c_opa_slow_load,
    '-' when others;
  
  l1d_sext_o   <= r_ldst.sext;
  l1d_size_o   <= r_ldst.size;
  l1d_addr_o   <= std_logic_vector(signed(r_rega) + signed(r_imm));
  l1d_data_o   <= r_regb;
  l1d_oldest_o <= issue_oldest_i;
  
  -- Implement a shifter
  shifter : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_shift <= s_shift;
      -- sign extend the shifter
      if r_shift.sext = '0' then
        r_sexta <= (others => '0');
      else
        r_sexta <= (others => r_rega(r_rega'high));
      end if;
      r_sexta(r_rega'range) <= r_rega;
      -- calculate distance
      r_shamt <= (others => '0');
      if r_shift.right = '1' then
        r_shamt(c_log_reg_wide-1 downto 0) <= r_regb(c_log_reg_wide-1 downto 0);
      else
        if unsigned(r_regb(c_log_reg_wide-1 downto 0)) /= 0 then
          r_shamt <= std_logic_vector(0-unsigned(r_regb(r_shamt'range)));
        end if;
      end if;
      -- run the shifter
      r_shout <= s_shout(r_shout'range);
    end if;
  end process;
  s_shout <= std_logic_vector(rotate_right(unsigned(r_sexta), to_integer(unsigned(r_shamt))));
  
  -- pick the output
  with r_mode3 select
  regfile_regx_o <=
    s_mul_out       when c_opa_slow_mul,
    l1d_data_i      when c_opa_slow_load,
    r_shout         when c_opa_slow_shift,
    (others => '-') when others;

end rtl;
