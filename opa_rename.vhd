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

entity opa_rename is
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
    decode_order_i : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
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
    issue_order_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
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
end opa_rename;

architecture rtl of opa_rename is

  constant c_num_arch  : natural := f_opa_num_arch(g_config);
  constant c_num_stat  : natural := f_opa_num_stat(g_config);
  constant c_renamers  : natural := f_opa_renamers(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_data_wide : natural := (c_arch_wide + c_back_wide) * c_renamers;
  
  constant c_arch_ones   : std_logic_vector(c_num_arch-1 downto 0) := (others => '1');
  constant c_decode_ones : std_logic_vector(c_renamers-1 downto 0) := (others => '1');  
  
  -- Same-cycle dependencies
  function f_triangle(n : natural; UR : boolean) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(1) loop
        if UR then
          result(i,j) := f_opa_bit(i > j);
        else
          result(i,j) := f_opa_bit(i < j);
        end if;
      end loop;
    end loop;
    return result;
  end f_triangle;
  
  function f_fill_top_row(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    result := x;
    for i in x'range(2) loop
      result(x'high(1), i) := '1';
    end loop;
    return result;
  end f_fill_top_row;
  
  constant c_UR_triangle : t_opa_matrix := f_triangle(c_renamers, true);
  constant c_LL_triangle : t_opa_matrix := f_triangle(c_renamers, false);
  
  constant c_pre_stat_labels : t_opa_matrix := f_opa_labels(c_renamers, c_stat_wide, c_num_stat);
  constant c_dec_stat_labels : t_opa_matrix := f_opa_labels(c_renamers, c_stat_wide, c_num_stat-c_renamers);
  constant c_stat_labels     : t_opa_matrix := f_fill_top_row(c_pre_stat_labels);
  
  constant c_arch_init : t_opa_matrix := f_opa_labels(c_num_arch, c_back_wide, 0);
  constant c_free_init : t_opa_matrix := f_opa_labels(c_renamers, c_back_wide, c_num_arch+c_num_stat);

  signal r_pre_stat    : t_opa_matrix(c_num_arch-1 downto 0, c_stat_wide-1 downto 0) := (others => (others => '1'));
  signal r_pre_bak     : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0) := c_arch_init;
  signal r_com_bak     : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0) := c_arch_init;
  signal r_free_bak    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0) := c_free_init;
  signal r_q_setx      : std_logic_vector(c_num_stat-1 downto 0)                     := (others => '0');
  signal r_q_archx     : t_opa_matrix(c_num_stat-1 downto 0, c_arch_wide-1 downto 0);
  
  signal s_pre_writers : t_opa_matrix(c_num_arch-1 downto 0, c_renamers-1  downto 0);
  signal s_pre_mux     : std_logic_vector(c_num_arch-1 downto 0);
  signal s_pre_source  : t_opa_matrix(c_num_arch-1 downto 0, c_renamers-1  downto 0);
  signal s_pre_dec_stat: t_opa_matrix(c_num_arch-1 downto 0, c_stat_wide-1 downto 0);
  signal s_pre_new_stat: t_opa_matrix(c_num_arch-1 downto 0, c_stat_wide-1 downto 0);
  signal s_pre_new_bak : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_pre_mux_stat: t_opa_matrix(c_num_arch-1 downto 0, c_stat_wide-1 downto 0);
  signal s_pre_mux_bak : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_com_setx    : std_logic_vector(c_renamers-1 downto 0);
  signal s_com_archx   : t_opa_matrix(c_renamers-1 downto 0, c_arch_wide-1 downto 0);       
  signal s_com_writers : t_opa_matrix(c_num_arch-1 downto 0, c_renamers-1  downto 0);
  signal s_com_mux     : std_logic_vector(c_num_arch-1 downto 0);
  signal s_com_source  : t_opa_matrix(c_num_arch-1 downto 0, c_renamers-1  downto 0);
  signal s_com_new_bak : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_com_mux_bak : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_old_bakx    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_overwrites  : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0);
  signal s_useless     : std_logic_vector(c_renamers-1 downto 0);
  signal s_free_bak    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);

  signal s_progress    : std_logic;
  
  signal s_not_get_a   : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0) := (others => (others => '0'));
  signal s_not_get_b   : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0) := (others => (others => '0'));
  
  signal s_old_baka    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_old_bakb    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_old_stata   : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);
  signal s_old_statb   : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);
  signal s_match_a     : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0);
  signal s_match_b     : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0);
  signal s_mux_a       : std_logic_vector(c_renamers-1 downto 0);
  signal s_mux_b       : std_logic_vector(c_renamers-1 downto 0);
  signal s_source_a    : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0);
  signal s_source_b    : t_opa_matrix(c_renamers-1 downto 0, c_renamers-1  downto 0);
  signal s_new_baka    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_new_bakb    : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_new_stata   : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);
  signal s_new_statb   : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);
  signal s_baka        : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_bakb        : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal s_stata       : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);
  signal s_statb       : t_opa_matrix(c_renamers-1 downto 0, c_stat_wide-1 downto 0);

begin

  check : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      assert (f_opa_safe(decode_stb_i)  = '1') report "rename: decode_stb_i has metavalue" severity failure;
      assert (f_opa_safe(issue_stall_i) = '1') report "rename: issue_stall_i has metavalue" severity failure;
      assert (f_opa_safe(issue_fault_i) = '1') report "rename: issue_fault_i has metavalue" severity failure;
      assert (f_opa_safe(s_progress)    = '1') report "rename: s_progress has metavalue" severity failure;
    end if;
  end process;

  -- Compute the new architectural state, predicting these operations run
  s_pre_writers <= f_opa_match_index(c_num_arch, decode_archx_i) and f_opa_dup_row(c_num_arch, decode_setx_i);
  s_pre_mux     <= f_opa_product(s_pre_writers, c_decode_ones);
  s_pre_source  <= f_opa_pick_big(s_pre_writers);
  s_pre_dec_stat<= f_opa_decrement(r_pre_stat, c_renamers);
  s_pre_new_stat<= f_opa_product(s_pre_source, c_dec_stat_labels);
  s_pre_new_bak <= f_opa_product(s_pre_source, r_free_bak);
  s_pre_mux_stat<= f_opa_mux(s_pre_mux, s_pre_new_stat, s_pre_dec_stat);
  s_pre_mux_bak <= f_opa_mux(s_pre_mux, s_pre_new_bak,  r_pre_bak);
  
  s_com_setx <= r_q_setx(c_renamers-1 downto 0) and issue_mask_i;
  archx : for i in 0 to c_renamers-1 generate
    bits : for b in 0 to c_arch_wide-1 generate
      s_com_archx(i,b) <= r_q_archx(i,b);
    end generate;
  end generate;

  -- Compute the new architectural state, knowing which operations commit
  s_com_writers <= f_opa_match_index(c_num_arch, s_com_archx) and f_opa_dup_row(c_num_arch, s_com_setx);
  s_com_mux     <= f_opa_product(s_com_writers, c_decode_ones);
  s_com_source  <= f_opa_pick_big(s_com_writers);
  s_com_new_bak <= f_opa_product(s_com_source, issue_bakx_i);
  s_com_mux_bak <= f_opa_mux(s_com_mux, s_com_new_bak, r_com_bak);

  -- Calculate which backing registers are freed by commit
  s_old_bakx   <= f_opa_compose(r_com_bak, s_com_archx);
  s_overwrites <= f_opa_match(s_com_archx, s_com_archx) and c_LL_triangle;
  s_useless    <= f_opa_product(s_overwrites, s_com_setx) or not s_com_setx;
  s_free_bak   <= f_opa_mux(s_useless, issue_bakx_i, s_old_bakx);
  
  s_progress <= (decode_stb_i and not issue_stall_i) or issue_fault_i;
  main : process(rst_n_i, clk_i) is
    variable value : std_logic_vector(r_pre_bak'range(2));
  begin
    if rst_n_i = '0' then
      r_pre_stat <= (others => (others => '1'));
      r_pre_bak  <= c_arch_init;
      r_com_bak  <= c_arch_init;
      r_free_bak <= c_free_init;
      r_q_setx   <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_progress = '1' then -- clock enable
        if issue_fault_i = '1' then -- load enable
          r_q_setx     <= (others => '0');
          r_pre_bak    <= s_com_mux_bak;
        else
          r_q_setx     <= decode_setx_i & r_q_setx(c_num_stat-1 downto c_renamers);
          r_pre_bak    <= s_pre_mux_bak;
        end if;
        r_pre_stat   <= s_pre_mux_stat;
        r_com_bak    <= s_com_mux_bak;
        r_free_bak   <= s_free_bak;
      end if;
    end if;
  end process;
  
  -- Hopefully inferred into something compact
  shifter : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_progress = '1' then
        for b in 0 to c_arch_wide-1 loop
          for i in 0 to c_num_stat-c_renamers-1 loop
            r_q_archx(i,b) <= r_q_archx(i+c_renamers,b);
          end loop;
          for i in c_num_stat-c_renamers to c_num_stat-1 loop
            r_q_archx(i,b) <= decode_archx_i(i-(c_num_stat-c_renamers),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
  get_rows : for i in 0 to c_renamers-1 generate
    s_not_get_a(i,c_renamers-1) <= not decode_geta_i(i);
    s_not_get_b(i,c_renamers-1) <= not decode_getb_i(i);
    -- all other columns 0
  end generate;
  
  -- Rename the inputs, watching out for same-cycle dependencies
  s_old_baka <= f_opa_compose(r_pre_bak, decode_archa_i);
  s_old_bakb <= f_opa_compose(r_pre_bak, decode_archb_i);
  s_old_stata<= f_opa_compose(r_pre_stat,decode_archa_i);
  s_old_statb<= f_opa_compose(r_pre_stat,decode_archb_i);
  s_match_a  <= (f_opa_match(decode_archa_i, decode_archx_i) and f_opa_dup_row(c_renamers, decode_setx_i) and c_UR_triangle) or s_not_get_a;
  s_match_b  <= (f_opa_match(decode_archb_i, decode_archx_i) and f_opa_dup_row(c_renamers, decode_setx_i) and c_UR_triangle) or s_not_get_b;
  s_mux_a    <= f_opa_product(s_match_a, c_decode_ones);
  s_mux_b    <= f_opa_product(s_match_b, c_decode_ones);
  s_source_a <= f_opa_pick_big(s_match_a);
  s_source_b <= f_opa_pick_big(s_match_b);
  s_new_baka <= f_opa_product(s_source_a, r_free_bak);
  s_new_bakb <= f_opa_product(s_source_b, r_free_bak);
  s_new_stata<= f_opa_product(s_source_a, c_stat_labels);
  s_new_statb<= f_opa_product(s_source_b, c_stat_labels);
  s_baka     <= f_opa_mux(s_mux_a, s_new_baka,  s_old_baka);
  s_bakb     <= f_opa_mux(s_mux_b, s_new_bakb,  s_old_bakb);
  s_stata    <= f_opa_mux(s_mux_a, s_new_stata, s_old_stata);
  s_statb    <= f_opa_mux(s_mux_b, s_new_statb, s_old_statb);
  
  -- Forward result to issue stage
  decode_stall_o <= issue_stall_i;
  issue_stb_o    <= decode_stb_i;
  issue_fast_o   <= decode_fast_i;
  issue_slow_o   <= decode_slow_i;
  issue_order_o  <= decode_order_i;
  issue_geta_o   <= decode_geta_i;
  issue_getb_o   <= decode_getb_i;
  issue_aux_o    <= decode_aux_i;
  issue_bakx_o   <= r_free_bak;
  issue_baka_o   <= s_baka;
  issue_bakb_o   <= s_bakb;
  issue_stata_o  <= s_stata;
  issue_statb_o  <= s_statb;
  
  decode_fault_o <= issue_fault_i;
  decode_pc_o    <= issue_pc_i;
  decode_pcf_o   <= issue_pcf_i;
  decode_pcn_o   <= issue_pcn_i;
  
end rtl;
