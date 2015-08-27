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
    decode_fast_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_slow_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_geta_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_getb_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    decode_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    decode_archa_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    decode_archb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    
    -- Values we provide to the issuer
    issue_stb_o    : out std_logic;
    issue_stall_i  : in  std_logic;
    issue_fast_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_slow_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_geta_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_getb_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_aux_o    : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    issue_oldx_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bakx_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_baka_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bakb_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_stata_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    issue_statb_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    issue_oldx_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
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
  
  constant c_UR_triangle : t_opa_matrix := f_triangle(c_decoders, true);
  constant c_LL_triangle : t_opa_matrix := f_triangle(c_decoders, false);
  constant c_stat_labels : t_opa_matrix := f_opa_labels(c_decoders, c_stat_wide, c_num_stat);

  signal r_map         : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_map_writers : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_mux     : std_logic_vector(c_num_arch-1 downto 0);
  signal s_map_source  : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_value   : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_map         : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_old_baka    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_old_bakb    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_not_get_a   : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0) := (others => (others => '0'));
  signal s_not_get_b   : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0) := (others => (others => '0'));
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
  signal s_stata       : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_statb       : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);

  signal s_old_bakx    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_overwrites  : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_oldx        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_useless     : std_logic_vector(c_decoders-1 downto 0);
  signal s_progress    : std_logic;

begin

  -- Compute the new architectural state
  s_map_writers <= f_opa_match_index(c_num_arch, decode_archx_i) and f_opa_dup_row(c_num_arch, decode_setx_i);
  s_map_mux     <= f_opa_product(s_map_writers, c_decode_ones);
  s_map_source  <= f_opa_pick_big(s_map_writers);
  s_map_value   <= f_opa_product(s_map_source, issue_oldx_i);
  
  arch : for i in 0 to c_num_arch-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      s_map(i,b) <= s_map_value(i,b) when s_map_mux(i)='1' else r_map(i,b);
    end generate;
  end generate;
  
  s_progress <= decode_stb_i and not issue_stall_i;
  main : process(rst_n_i, clk_i) is
    variable value : std_logic_vector(r_map'range(2));
  begin
    if rst_n_i = '0' then
      for i in r_map'range(1) loop
        value := std_logic_vector(to_unsigned(i, r_map'length(2)));
        for j in r_map'range(2) loop
          r_map(i,j) <= value(j);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if s_progress = '1' then -- clock enable
        r_map <= s_map;
      end if;
    end if;
  end process;
  
  get_rows : for i in 0 to c_decoders-1 generate
    s_not_get_a(i,c_decoders-1) <= not decode_geta_i(i);
    s_not_get_b(i,c_decoders-1) <= not decode_getb_i(i);
    -- all other columns 0
  end generate;
  
  -- Rename the inputs, watching out for same-cycle dependencies
  s_old_baka <= f_opa_compose(r_map, decode_archa_i);
  s_old_bakb <= f_opa_compose(r_map, decode_archb_i);
  s_match_a  <= (f_opa_match(decode_archa_i, decode_archx_i) and f_opa_dup_row(c_decoders, decode_setx_i) and c_UR_triangle) or s_not_get_a;
  s_match_b  <= (f_opa_match(decode_archb_i, decode_archx_i) and f_opa_dup_row(c_decoders, decode_setx_i) and c_UR_triangle) or s_not_get_b;
  s_mux_a    <= f_opa_product(s_match_a, c_decode_ones);
  s_mux_b    <= f_opa_product(s_match_b, c_decode_ones);
  s_source_a <= f_opa_pick_big(s_match_a);
  s_source_b <= f_opa_pick_big(s_match_b);
  s_new_baka <= f_opa_product(s_source_a, issue_oldx_i);
  s_new_bakb <= f_opa_product(s_source_b, issue_oldx_i);
  
  -- Decode station dependencies between them (between rest are done with CAM in issue)
  s_stata    <= f_opa_product(s_source_a, c_stat_labels); -- 0 on no conflict
  s_statb    <= f_opa_product(s_source_b, c_stat_labels);
  
  -- Pick between old arch register or cross-dependency
  -- !!! decode !get bak to something big => r_map in regfile picks immediate
  rows : for i in s_baka'range(1) generate
    cols : for j in s_baka'range(2) generate
      s_baka(i,j) <= s_old_baka(i,j) when s_mux_a(i) = '0' else s_new_baka(i,j);
      s_bakb(i,j) <= s_old_bakb(i,j) when s_mux_b(i) = '0' else s_new_bakb(i,j);
    end generate;
  end generate;
  
  -- Calculate which backing registers are released upon commit
  s_old_bakx   <= f_opa_compose(r_map, decode_archx_i);
  s_overwrites <= f_opa_match(decode_archx_i, decode_archx_i) and c_LL_triangle;
  s_useless    <= f_opa_product(s_overwrites, decode_setx_i) or not decode_setx_i;
  
  free : for i in 0 to c_decoders-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      s_oldx(i,b) <= issue_oldx_i(i,b) when s_useless(i)='1' else s_old_bakx(i,b);
    end generate;
  end generate;
  
  -- Forward result to issue stage
  decode_stall_o <= issue_stall_i;
  issue_stb_o    <= decode_stb_i;
  issue_fast_o   <= decode_fast_i;
  issue_slow_o   <= decode_slow_i;
  issue_geta_o   <= decode_geta_i;
  issue_getb_o   <= decode_getb_i;
  issue_aux_o    <= decode_aux_i;
  issue_oldx_o   <= s_oldx;
  issue_bakx_o   <= issue_oldx_i;
  issue_baka_o   <= s_baka;
  issue_bakb_o   <= s_bakb;
  issue_stata_o  <= s_stata;
  issue_statb_o  <= s_statb;
  
end rtl;
