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

package opa_components_pkg is

  type t_dpram_equal is (OPA_OLD, OPA_NEW, OPA_UNDEF);
  component opa_dpram is
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
  end component;
  
  -- Inputs are registered
  -- Read output from a port during a write is undefined
  -- Simultaneous write to the same address writes 'X's
  -- Data read from one port while written by another outputs 'X'
  component opa_tdpram is
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
  end component;
  
  -- Inhibit optimization between these points
  component opa_lcell is
    port(
      a_i : in  std_logic;
      b_o : out std_logic);
  end component;
  
  component opa_prim_ternary is
    generic(
      g_wide   : natural);
    port(
      a_i      : in  unsigned(g_wide-1 downto 0);
      b_i      : in  unsigned(g_wide-1 downto 0);
      c_i      : in  unsigned(g_wide-1 downto 0);
      x_o      : out unsigned(g_wide-1 downto 0));
  end component;
  
  component opa_prim_mul is
    generic(
      g_wide   : natural;
      g_regout : boolean;
      g_regwal : boolean;
      g_target : t_opa_target);
    port(
      clk_i    : in  std_logic;
      a_i      : in  std_logic_vector(  g_wide-1 downto 0);
      b_i      : in  std_logic_vector(  g_wide-1 downto 0);
      x_o      : out std_logic_vector(2*g_wide-1 downto 0));
  end component;
  
  component opa_prefixsum is
    generic(
      g_target  : t_opa_target;
      g_width   : natural;
      g_count   : natural);
    port(
      bits_i    : in  std_logic_vector(g_width-1 downto 0);
      count_o   : out t_opa_matrix(g_count-1 downto 0, g_width-1 downto 0);
      total_o   : out std_logic_vector(g_width-1 downto 0));
  end component;
  
  component opa_lfsr is
    generic(
      g_entropy : natural := 0;
      g_bits    : natural);
    port(
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      random_o : out std_logic_vector(g_bits-1 downto 0));
  end component;
  
  component opa_predict is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i           : in  std_logic;
      rst_n_i         : in  std_logic;
      
      -- Deliver our prediction
      icache_stall_i  : in  std_logic;
      icache_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      decode_hit_o    : out std_logic;
      decode_jump_o   : out std_logic_vector(f_opa_fetchers(g_config)-1 downto 0);
      
      -- Push a return stack entry
      decode_push_i   : in  std_logic;
      decode_ret_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      
      -- Fixup PC to new target
      decode_fault_i  : in  std_logic;
      decode_return_i : in  std_logic;
      decode_jump_i   : in  std_logic_vector(f_opa_fetchers(g_config)-1 downto 0);
      decode_source_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      decode_target_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align));
  end component;
  
  component opa_icache is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i           : in  std_logic;
      rst_n_i         : in  std_logic;
      
      predict_stall_o : out std_logic;
      predict_pc_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      
      decode_stb_o    : out std_logic;
      decode_stall_i  : in  std_logic;
      decode_fault_i  : in  std_logic;
      decode_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      decode_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      decode_dat_o    : out std_logic_vector(f_opa_fetch_bits(g_config)-1 downto 0);
      
      i_cyc_o         : out std_logic;
      i_stb_o         : out std_logic;
      i_stall_i       : in  std_logic;
      i_ack_i         : in  std_logic;
      i_err_i         : in  std_logic;
      i_addr_o        : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
      i_data_i        : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0));
  end component;
  
  component opa_decode is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;

      -- Predicted jumps?
      predict_hit_i    : in  std_logic;
      predict_jump_i   : in  std_logic_vector(f_opa_fetchers(g_config)-1 downto 0);
      
      -- Push a return stack entry
      predict_push_o   : out std_logic;
      predict_ret_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      
      -- Fixup PC to new target
      predict_fault_o  : out std_logic;
      predict_return_o : out std_logic;
      predict_jump_o   : out std_logic_vector(f_opa_fetchers(g_config)-1 downto 0);
      predict_source_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      predict_target_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);

      -- Instructions delivered from icache
      icache_stb_i     : in  std_logic;
      icache_stall_o   : out std_logic;
      icache_pc_i      : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      icache_pcn_i     : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
      icache_dat_i     : in  std_logic_vector(f_opa_fetch_bits(g_config)-1 downto 0);
      
      -- Feed data to the renamer
      rename_stb_o   : out std_logic;
      rename_stall_i : in  std_logic;
      rename_fast_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_slow_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_setx_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_geta_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_getb_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_aux_o   : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      rename_archx_o : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      rename_archa_o : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      rename_archb_o : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);

      -- Accept faults
      rename_fault_i : in  std_logic;
      rename_pc_i    : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      rename_pcf_i   : in  std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      rename_pcn_i   : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      
      -- Give the regfile the information EUs will need for these operations
      regfile_stb_o  : out std_logic;
      regfile_aux_o  : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      regfile_arg_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arg_wide(g_config)-1 downto 0);
      regfile_imm_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_imm_wide(g_config)-1 downto 0);
      regfile_pc_o   : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto c_op_align);
      regfile_pcf_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
      regfile_pcn_o  : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align));
  end component;
  
  component opa_rename is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      -- Values the decoder needs to provide us
      decode_stb_i   : in  std_logic;
      decode_stall_o : out std_logic;
      decode_fast_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      decode_slow_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      decode_setx_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      decode_geta_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      decode_getb_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      decode_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      decode_archx_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      decode_archa_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      decode_archb_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      
      -- Values we provide to the issuer
      issue_stb_o    : out std_logic;
      issue_stall_i  : in  std_logic;
      issue_fast_o   : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      issue_slow_o   : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      issue_geta_o   : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      issue_getb_o   : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      issue_aux_o    : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      issue_bakx_o   : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_baka_o   : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_bakb_o   : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_stata_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      issue_statb_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      issue_bakx_i   : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- Feed faults back up the pipeline
      issue_fault_i  : in  std_logic;
      issue_mask_i   : in  std_logic_vector(f_opa_renamers   (g_config)-1 downto 0);
      issue_pc_i     : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      issue_pcf_i    : in  std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      issue_pcn_i    : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      decode_fault_o : out std_logic;
      decode_pc_o    : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      decode_pcf_o   : out std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      decode_pcn_o   : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align));
  end component;

  component opa_issue is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      -- Values the renamer provides us
      rename_stb_i   : in  std_logic;
      rename_stall_o : out std_logic;
      rename_fast_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_slow_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_geta_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_getb_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
      rename_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      rename_bakx_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      rename_baka_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      rename_bakb_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      rename_stata_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      rename_statb_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      rename_bakx_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- Exceptions from the EUs
      eu_oldest_o    : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_retry_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_fault_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_pc_i        : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
      eu_pcf_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
      eu_pcn_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
      
      -- Selected fault fed back up pipeline
      rename_fault_o : out std_logic;
      rename_mask_o  : out std_logic_vector(f_opa_renamers   (g_config)-1 downto 0);
      rename_pc_o    : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      rename_pcf_o   : out std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      rename_pcn_o   : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      
      -- Regfile needs to fetch these for EU
      regfile_rstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      regfile_geta_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      regfile_getb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      regfile_aux_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_aux_wide (g_config)-1 downto 0);
      regfile_dec_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_ren_wide (g_config)-1 downto 0);
      regfile_baka_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      regfile_bakb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- Regfile should capture result from EU
      regfile_wstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      regfile_bakx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- Gather information from L1d about aliased loads
      l1d_store_i    : in  std_logic;
      l1d_load_i     : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      l1d_addr_i     : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_alias_high(g_config) downto f_opa_alias_low(g_config));
      l1d_mask_i     : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)/8-1 downto 0));
  end component;
  
  component opa_regfile is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i        : in  std_logic;
      rst_n_i      : in  std_logic;
      
      -- Record PC + immediate data
      decode_stb_i : in  std_logic;
      decode_aux_i : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
      decode_arg_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_arg_wide   (g_config)-1 downto 0);
      decode_imm_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_imm_wide   (g_config)-1 downto 0);
      decode_pc_i  : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
      decode_pcf_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
      decode_pcn_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);

      -- Issue has dispatched these instructions to us
      issue_rstb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      issue_geta_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      issue_getb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      issue_aux_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_aux_wide  (g_config)-1 downto 0);
      issue_dec_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_ren_wide  (g_config)-1 downto 0);
      issue_baka_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
      issue_bakb_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
      
      -- Feed the EUs one cycle later (they register this => result is two cycles later)
      eu_stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_rega_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide   (g_config)-1 downto 0);
      eu_regb_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide   (g_config)-1 downto 0);
      eu_arg_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_arg_wide   (g_config)-1 downto 0);
      eu_imm_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_imm_wide   (g_config)-1 downto 0);
      eu_pc_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
      eu_pcf_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
      eu_pcn_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
      
      -- Issue has indicated these EUs will write now
      issue_wstb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      issue_bakx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
      
      -- The results arrive two cycles after the issue said they would
      eu_regx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide  (g_config)-1 downto 0));
  end component;
  
  component opa_fast is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      regfile_stb_i  : in  std_logic;
      regfile_rega_i : in  std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      regfile_regb_i : in  std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      regfile_arg_i  : in  std_logic_vector(f_opa_arg_wide   (g_config)-1 downto 0);
      regfile_imm_i  : in  std_logic_vector(f_opa_imm_wide   (g_config)-1 downto 0);
      regfile_pc_i   : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      regfile_pcf_i  : in  std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      regfile_pcn_i  : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      regfile_regx_o : out std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      
      issue_oldest_i : in  std_logic;
      issue_retry_o  : out std_logic;
      issue_fault_o  : out std_logic;
      issue_pc_o     : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      issue_pcf_o    : out std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      issue_pcn_o    : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align));
  end component;

  component opa_slow is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      regfile_stb_i  : in  std_logic;
      regfile_rega_i : in  std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      regfile_regb_i : in  std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      regfile_arg_i  : in  std_logic_vector(f_opa_arg_wide   (g_config)-1 downto 0);
      regfile_imm_i  : in  std_logic_vector(f_opa_imm_wide   (g_config)-1 downto 0);
      regfile_pc_i   : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      regfile_pcf_i  : in  std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      regfile_pcn_i  : in  std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      regfile_regx_o : out std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      
      l1d_stb_o      : out std_logic;
      l1d_we_o       : out std_logic;
      l1d_sext_o     : out std_logic;
      l1d_size_o     : out std_logic_vector(1 downto 0);
      l1d_addr_o     : out std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      l1d_data_o     : out std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0);
      l1d_oldest_o   : out std_logic; -- delivered 1 cycle after stb
      l1d_retry_i    : in  std_logic; -- valid 1 cycle after stb_o 
      l1d_data_i     : in  std_logic_vector(f_opa_reg_wide   (g_config)-1 downto 0); -- 2 cycles
      
      issue_oldest_i : in  std_logic;
      issue_retry_o  : out std_logic;
      issue_fault_o  : out std_logic;
      issue_pc_o     : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align);
      issue_pcf_o    : out std_logic_vector(f_opa_fetch_align(g_config)-1 downto c_op_align);
      issue_pcn_o    : out std_logic_vector(f_opa_adr_wide   (g_config)-1 downto c_op_align));
  end component;

  type t_opa_dbus_request is (
    OPA_DBUS_WIPE,
    OPA_DBUS_IDLE,
    OPA_DBUS_WAIT_STORE_LOAD,
    OPA_DBUS_STORE_LOAD, -- request forbidden
    OPA_DBUS_LOAD_STORE,
    OPA_DBUS_WAIT_LOAD,
    OPA_DBUS_WAIT_STORE,
    OPA_DBUS_LOAD,
    OPA_DBUS_STORE);     -- request forbidden
  
  component opa_l1d is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      
      -- read/writes come from the slow EUs
      slow_stb_i    : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      slow_we_i     : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      slow_sext_i   : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      slow_size_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, 1 downto 0);
      slow_addr_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
      slow_data_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
      slow_oldest_i : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      slow_retry_o  : out std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      slow_data_o   : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
      
      -- Share information about the addresses we are loading/storing
      issue_store_o : out std_logic;
      issue_load_o  : out std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
      issue_addr_o  : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_alias_high(g_config) downto f_opa_alias_low(g_config));
      issue_mask_o  : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)/8-1 downto 0);
      
      -- L1d requests action
      dbus_req_o    : out t_opa_dbus_request;
      dbus_radr_o   : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      dbus_way_o    : out std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
      dbus_wadr_o   : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      dbus_dirty_o  : out std_logic_vector(c_dline_size            -1 downto 0);
      dbus_data_o   : out std_logic_vector(c_dline_size*8          -1 downto 0);
      
      dbus_busy_i   : in  std_logic; -- can accept a req_i
      dbus_we_i     : in  std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
      dbus_adr_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      dbus_valid_i  : in  std_logic_vector(c_dline_size            -1 downto 0);
      dbus_data_i   : in  std_logic_vector(c_dline_size*8          -1 downto 0));
  end component;

  component opa_dbus is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      
      d_cyc_o     : out std_logic;
      d_stb_o     : out std_logic;
      d_we_o      : out std_logic;
      d_stall_i   : in  std_logic;
      d_ack_i     : in  std_logic;
      d_err_i     : in  std_logic;
      d_addr_o    : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      d_sel_o     : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
      d_data_o    : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      d_data_i    : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
      
      -- L1d requests action
      l1d_req_i   : in  t_opa_dbus_request;
      l1d_radr_i  : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      l1d_way_i   : in  std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
      l1d_wadr_i  : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      l1d_dirty_i : in  std_logic_vector(c_dline_size            -1 downto 0);
      l1d_data_i  : in  std_logic_vector(c_dline_size*8          -1 downto 0);
      
      l1d_busy_o  : out std_logic; -- can accept a req_i
      l1d_we_o    : out std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
      l1d_adr_o   : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
      l1d_valid_o : out std_logic_vector(c_dline_size            -1 downto 0);
      l1d_data_o  : out std_logic_vector(c_dline_size*8          -1 downto 0));
  end component;
  
end package;
