library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
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
    decode_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_geta_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_getb_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_aux_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
    decode_typ_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    decode_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    decode_archa_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    decode_archb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    
    -- What does the commiter have to say?
    commit_kill_i  : in  std_logic;
    commit_map_i   : in  t_opa_matrix(f_opa_num_arch(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    commit_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);

    -- Values we provide to the issuer
    issue_shift_i  : in  std_logic;
    issue_setx_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_geta_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_getb_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_typ_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    issue_aux_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
    issue_archx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    issue_bakx_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_baka_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bakb_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_confa_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0); -- conflict: use stata.
    issue_confb_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_stata_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    issue_statb_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0));
end opa_rename;

architecture rtl of opa_rename is

  constant c_num_arch  : natural := f_opa_num_arch(g_config);
  constant c_num_stat  : natural := f_opa_num_stat(g_config);
  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  
  constant c_arch_ones   : std_logic_vector(c_num_arch-1 downto 0) := (others => '1');
  constant c_decode_ones : std_logic_vector(c_decoders-1 downto 0) := (others => '1');  
  
  -- Same-cycle dependencies
  function f_UR_triangle(n : natural) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(1) loop
        result(i,j) := f_opa_bit(i > j);
      end loop;
    end loop;
    return result;
  end f_UR_triangle;
  
  constant c_UR_triangle : t_opa_matrix := f_UR_triangle(c_decoders);
  constant c_stat_labels : t_opa_matrix := f_opa_labels(c_decoders, c_stat_wide, c_num_stat);

  signal r_map         : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_map_writers : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_mux     : std_logic_vector(c_num_arch-1 downto 0);
  signal s_map_source  : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_value   : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_map         : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  
  signal r_dec_setx    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_geta    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_getb    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_aux     : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide-1  downto 0);
  signal r_dec_typ     : t_opa_matrix(c_decoders-1 downto 0, c_types-1     downto 0);
  signal r_dec_archx   : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal r_dec_archa   : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal r_dec_archb   : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal r_commit_bakx : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_old_baka    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_old_bakb    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_match_a     : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_match_b     : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_mux_a       : std_logic_vector(c_decoders-1 downto 0);
  signal s_mux_b       : std_logic_vector(c_decoders-1 downto 0);
  signal s_source_a    : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_source_b    : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_new_baka    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_new_bakb    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_baka        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_bakb        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);

begin

  edge1a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      -- No clock enable b/c:
      --   if we pull from fetch, then NEXT cycle these are read
      --   otherwise, our results are ignored
      --   Thus, it's simplly a 1-cycle delay
      r_dec_setx  <= decode_setx_i;
      r_dec_geta  <= decode_geta_i;
      r_dec_getb  <= decode_getb_i;
      r_dec_aux   <= decode_aux_i;
      r_dec_typ   <= decode_typ_i;
      r_dec_archa <= decode_archa_i;
      r_dec_archb <= decode_archb_i;
      r_dec_archx <= decode_archx_i;
    end if;
  end process;
  
  back : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      for i in 0 to c_decoders-1 loop
        for b in 0 to c_back_wide-1 loop
          r_commit_bakx(i,b) <= to_unsigned(c_num_arch+c_num_stat+c_decoders*2+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if issue_shift_i = '1' then -- clock enable
        r_commit_bakx <= commit_bakx_i;
      end if;
    end if;
  end process;
  
  -- Compute the new architectural state
  s_map_writers <= f_opa_match_index(c_num_arch, r_dec_archx) and f_opa_dup_row(c_num_arch, r_dec_setx);
  s_map_mux     <= f_opa_product(s_map_writers, c_decode_ones);
  s_map_source  <= f_opa_pick_big(s_map_writers);
  s_map_value   <= f_opa_product(s_map_source, r_commit_bakx);
  
  arch : for i in 0 to c_num_arch-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      s_map(i,b) <= s_map_value(i,b) when s_map_mux(i)='1' else r_map(i,b);
    end generate;
  end generate;
  
  edge2a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if issue_shift_i = '1' then -- clock enable
        if commit_kill_i = '1' then -- load enable
          r_map <= commit_map_i;
        else
          r_map <= s_map;
        end if;
      end if;
    end if;
  end process;
  
  -- Rename the inputs, watching out for same-cycle dependencies
  s_old_baka <= f_opa_compose(r_map, r_dec_archa);
  s_old_bakb <= f_opa_compose(r_map, r_dec_archb);
  s_match_a  <= f_opa_match(r_dec_archa, r_dec_archx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_UR_triangle;
  s_match_b  <= f_opa_match(r_dec_archb, r_dec_archx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_UR_triangle;
  s_mux_a    <= f_opa_product(s_match_a, c_decode_ones);
  s_mux_b    <= f_opa_product(s_match_b, c_decode_ones);
  s_source_a <= f_opa_pick_big(s_match_a);
  s_source_b <= f_opa_pick_big(s_match_b);
  s_new_baka <= f_opa_product(s_source_a, r_commit_bakx);
  s_new_bakb <= f_opa_product(s_source_b, r_commit_bakx);
  
  -- Pick between old arch register or cross-dependency
  rows : for i in s_baka'range(1) generate
    cols : for j in s_baka'range(2) generate
      s_baka(i,j) <= s_old_baka(i,j) when s_mux_a(i) = '0' else s_new_baka(i,j);
      s_bakb(i,j) <= s_old_bakb(i,j) when s_mux_b(i) = '0' else s_new_bakb(i,j);
    end generate;
  end generate;
  
  -- Forward result to issue stage
  issue_setx_o  <= r_dec_setx;
  issue_geta_o  <= r_dec_geta;
  issue_getb_o  <= r_dec_getb;
  issue_typ_o   <= r_dec_typ;
  issue_aux_o   <= r_dec_aux;
  issue_archx_o <= r_dec_archx;
  issue_bakx_o  <= r_commit_bakx;
  issue_baka_o  <= s_baka;
  issue_bakb_o  <= s_bakb;
  issue_confa_o <= s_mux_a;
  issue_confb_o <= s_mux_b;
  issue_stata_o <= f_opa_product(s_source_a, c_stat_labels); -- 0 on no conflict
  issue_statb_o <= f_opa_product(s_source_b, c_stat_labels);
  
end rtl;
