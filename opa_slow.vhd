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
    g_isa    : t_opa_isa;
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    regfile_arg_i  : in  std_logic_vector(f_opa_arg_wide(g_config)-1 downto 0);
    regfile_imm_i  : in  std_logic_vector(f_opa_imm_wide(g_isa)   -1 downto 0);
    regfile_pc_i   : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    regfile_pcf_i  : in  std_logic_vector(f_opa_fet_wide(g_config)-1 downto 0);
    regfile_pcn_i  : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    
    l1d_stb_o      : out std_logic;
    l1d_we_o       : out std_logic;
    l1d_sext_o     : out std_logic;
    l1d_size_o     : out std_logic_vector(1 downto 0);
    l1d_addr_o     : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    l1d_data_o     : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    l1d_oldest_o   : out std_logic; -- delivered 1 cycle after stb
    l1d_retry_i    : in  std_logic; -- valid 1 cycle after stb_o 
    l1d_data_i     : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0); -- 2 cycles
    
    issue_oldest_i : in  std_logic;
    issue_retry_o  : out std_logic;
    issue_fault_o  : out std_logic;
    issue_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    issue_pcf_o    : out std_logic_vector(f_opa_fet_wide(g_config)-1 downto 0);
    issue_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa)));
end opa_slow;

architecture rtl of opa_slow is

  constant c_reg_wide     : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide     : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide     : natural := f_opa_imm_wide(g_isa);
  constant c_log_reg_wide : natural := f_opa_log2(c_reg_wide);
  constant c_log_reg_bytes: natural := c_log_reg_wide - 3;
  
  function f_pow(m : natural) return natural is begin return 8*2**m; end f_pow;
  
  signal s_arg     : t_opa_arg;
  signal r_stb     : std_logic := '0';
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
  
  type t_reg is array(natural range <>) of std_logic_vector(c_reg_wide-1 downto 0);
  signal s_sext    : t_opa_sext;
  signal r_sext    : t_opa_sext;
  signal s_sext_mux: t_reg(c_log_reg_bytes-1 downto 0);
  signal s_sext_a  : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_sext_a  : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_sext_o  : std_logic_vector(c_reg_wide-1 downto 0);

begin

  issue_retry_o   <= l1d_retry_i;
  issue_fault_o   <= '0';
  issue_pc_o      <= (others => '0');
  issue_pcf_o     <= (others => '0');
  issue_pcn_o     <= (others => '0');
  
  s_arg  <= f_opa_arg_from_vec(regfile_arg_i);
  s_mul  <= s_arg.mul;
  s_ldst <= s_arg.ldst;
  s_shift<= s_arg.shift;
  s_sext <= s_arg.sext;
  
  control : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_stb <= '0';
    elsif rising_edge(clk_i) then
      r_stb <= regfile_stb_i;
    end if;
  end process;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega  <= regfile_rega_i;
      r_regb  <= regfile_regb_i;
      r_imm   <= regfile_imm_i;
      r_ldst  <= s_ldst;
      r_mode1 <= s_arg.smode;
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

  with r_high3 select
  s_mul_out <= 
    s_product(  c_reg_wide-1 downto          0) when '0',
    s_product(2*c_reg_wide-1 downto c_reg_wide) when '1',
    (others => 'X') when others;
  
  -- Hand over memory accesses to the L1d
  l1d_stb_o    <= r_stb and f_opa_eq(r_mode1, c_opa_slow_ldst);
  l1d_we_o     <= r_ldst.store;
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
      case r_shift.sext is
        when '0' => r_sexta <= (others => '0');
        when '1' => r_sexta <= (others => r_rega(r_rega'high));
        when others => r_sexta <= (others => 'X');
      end case;
      r_sexta(r_rega'range) <= r_rega;
      -- calculate distance
      case r_shift.right is
        when '1' => r_shamt <= '0' & r_regb(c_log_reg_wide-1 downto 0);
        when '0' =>
          case f_opa_or(r_regb(c_log_reg_wide-1 downto 0)) is
            when '1' => r_shamt <= '1' & std_logic_vector(0-unsigned(r_regb(c_log_reg_wide-1 downto 0)));
            when '0' => r_shamt <= (others => '0');
            when others => r_shamt <= (others => 'X');
          end case;
        when others => r_shamt <= (others => 'X');
      end case;
      -- run the shifter
      r_shout <= s_shout(r_shout'range);
    end if;
  end process;
  s_shout <= f_opa_rotate_right(r_sexta, unsigned(r_shamt));
  
  -- Implement sign extension
  sextmux : for i in s_sext_mux'range generate
    s_sext_mux(i)(c_reg_wide-1 downto f_pow(i)) <= (others => r_rega(f_pow(i)-1));
    s_sext_mux(i)(f_pow(i)-1 downto 0) <= r_rega(f_pow(i)-1 downto 0);
  end generate;
  s_sext_a <= s_sext_mux(to_integer(unsigned(r_sext.size))) when f_opa_safe(r_sext.size)='1' else (others => 'X');
  sext : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_sext   <= s_sext;
      r_sext_a <= s_sext_a;
      r_sext_o <= r_sext_a;
    end if;
  end process;
  
  -- pick the output
  with r_mode3 select
  regfile_regx_o <=
    s_mul_out       when c_opa_slow_mul,
    l1d_data_i      when c_opa_slow_ldst,
    r_shout         when c_opa_slow_shift,
    r_sext_o        when c_opa_slow_sext,
    (others => 'X') when others;

end rtl;
