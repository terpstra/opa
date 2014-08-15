library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_regfile is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i        : in  std_logic;
    rst_n_i      : in  std_logic;
    
    -- Which registers to read for each EU
    issue_stb_i  : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_bakx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_baka_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bakb_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_aux_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);

    -- The resulting register data
    eu_stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_rega_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    eu_regb_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    eu_bakx_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_aux_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);
    
    -- The results to record; bakx must arrive 1-cycle before regx
    eu_stb_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_bakx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_regx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0));
end opa_regfile;

architecture rtl of opa_regfile is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_num_back  : natural := f_opa_num_back(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_mux1_wide : natural := f_opa_log2(c_executers);
  constant c_mux2_wide : natural := f_opa_log2(c_executers+1);
  
  constant c_labels : t_opa_matrix := f_opa_labels(c_executers);
  constant c_ones : std_logic_vector(c_executers-1 downto 0) := (others => '1');
  constant c_zero : t_opa_matrix(c_executers-1 downto 0, 0 downto 0) := (others => (others => '0'));
    
  signal r_baka      : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakb      : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakx      : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_stb       : std_logic_vector(c_executers-1 downto 0);
  
  signal s_map_set   : std_logic_vector(c_num_back-1 downto 0);
  signal s_map_match : t_opa_matrix(c_num_back-1 downto 0, c_executers-1 downto 0);
  signal s_map_value : t_opa_matrix(c_num_back-1 downto 0, c_mux1_wide-1 downto 0);
  signal r_map       : t_opa_matrix(c_num_back-1 downto 0, c_mux1_wide-1 downto 0);
  
  signal s_mux1_idx_a : t_opa_matrix(c_executers-1 downto 0, c_mux1_wide-1 downto 0);
  signal s_mux1_idx_b : t_opa_matrix(c_executers-1 downto 0, c_mux1_wide-1 downto 0);
  
  signal s_match_a    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal s_match_b    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal r_mux2_idx_a : t_opa_matrix(c_executers-1 downto 0, c_mux2_wide-1 downto 0);
  signal r_mux2_idx_b : t_opa_matrix(c_executers-1 downto 0, c_mux2_wide-1 downto 0);
  
  -- Need to map the matrix to something we can curry in a port mapping
  type t_address  is array(c_executers-1 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  type t_data_in  is array(c_executers-1 downto 0) of std_logic_vector(c_reg_wide-1 downto 0);
  -- !!! use manual mapping (tools don't like 3D arrays)
  type t_mux1     is array(c_executers-1 downto 0, c_executers-1 downto 0) of std_logic_vector(c_reg_wide-1 downto 0);
  type t_mux2     is array(c_executers-1 downto 0, c_executers   downto 0) of std_logic_vector(c_reg_wide-1 downto 0);
  
  signal s_ra_addr : t_address;
  signal s_rb_addr : t_address;
  signal s_w_addr  : t_address;
  signal s_w_data  : t_data_in;
  signal s_mux1_a  : t_mux1;
  signal s_mux1_b  : t_mux1;
  signal s_mux2_a  : t_mux2;
  signal s_mux2_b  : t_mux2;
  
begin

  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      eu_stb_o  <= issue_stb_i;
      eu_bakx_o <= issue_bakx_i;
      eu_aux_o  <= issue_aux_i;
      r_baka <= issue_baka_i;
      r_bakb <= issue_bakb_i;
      r_stb  <= eu_stb_i;
      r_bakx <= eu_bakx_i;
    end if;
  end process;
  
  -- Calculate the new mapping from back registers to units
  s_map_match <= f_opa_match_index(c_num_back, eu_bakx_i) and f_opa_dup_row(c_num_back, eu_stb_i);
  s_map_set   <= f_opa_product(s_map_match, c_ones);
  s_map_value <= f_opa_product(s_map_match, c_labels);
  
  -- Update the map of who owns what
  back_map : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      for i in 0 to c_num_back-1 loop
        if s_map_set(i)='1' then
          for b in 0 to c_mux1_wide-1 loop
            r_map(i,b) <= s_map_value(i,b);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  -- Detect if we will need a bypass
  s_match_a <= f_opa_match(issue_baka_i, eu_bakx_i) and f_opa_dup_row(c_executers, eu_stb_i);
  s_match_b <= f_opa_match(issue_bakb_i, eu_bakx_i) and f_opa_dup_row(c_executers, eu_stb_i);
    -- 2+2+M
  
  bypass : process(clk_i) is
  begin
    if rising_edge(clk_i) then
       -- leave bit 0 as 0 => decoding to 0 when no matches is good
      r_mux2_idx_a <= f_opa_1hot_dec(f_opa_concat(s_match_a, c_zero));
      r_mux2_idx_b <= f_opa_1hot_dec(f_opa_concat(s_match_b, c_zero));
      -- 2+2+M ... decoding can fit inside the slack from s_match_a
    end if;
  end process;
  
  remap : for u in 0 to c_executers-1 generate
    s_ra_addr(u) <= f_opa_select_row(issue_baka_i, u);
    s_rb_addr(u) <= f_opa_select_row(issue_bakb_i, u);
    s_w_addr(u)  <= f_opa_select_row(r_bakx, u);
    s_w_data(u)  <= f_opa_select_row(eu_regx_i, u);
  end generate;

  ramsw : for w in 0 to c_executers-1 generate
    ramsr : for r in 0 to c_executers-1 generate
      rama : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_bypass => true)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => issue_stb_i(r),
          r_addr_i => s_ra_addr(r),
          r_data_o => s_mux1_a(r, w),
          w_en_i   => r_stb(w),
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
      ramb : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_bypass => true)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => issue_stb_i(r),
          r_addr_i => s_rb_addr(r),
          r_data_o => s_mux1_b(r, w),
          w_en_i   => r_stb(w),
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
    end generate;
  end generate;
  
  -- !!! make this a register
  s_mux1_idx_a <= f_opa_compose(r_map, r_baka);
  s_mux1_idx_b <= f_opa_compose(r_map, r_bakb);
  
  regout : for u in 0 to c_executers-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      -- Mux #1: select memory
      s_mux2_a(u,0)(b) <= s_mux1_a(u, to_integer(unsigned(f_opa_select_row(s_mux1_idx_a,u))))(b);
      s_mux2_b(u,0)(b) <= s_mux1_b(u, to_integer(unsigned(f_opa_select_row(s_mux1_idx_b,u))))(b);
      regin : for v in 0 to c_executers-1 generate
        s_mux2_a(u,v+1)(b) <= eu_regx_i(v,b);
        s_mux2_b(u,v+1)(b) <= eu_regx_i(v,b);
      end generate;
      -- Mux #2: add EU bypass
      eu_rega_o(u,b) <= s_mux2_a(u, to_integer(unsigned(f_opa_select_row(r_mux2_idx_a, u))))(b);
      eu_regb_o(u,b) <= s_mux2_b(u, to_integer(unsigned(f_opa_select_row(r_mux2_idx_b, u))))(b);
    end generate;
  end generate;
  
end rtl;
