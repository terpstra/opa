library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_renamer is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    mispredict_i   : in  std_logic;
    
    -- What does the commiter have to say?
    commit_map_i   : in  t_opa_matrix(2**g_config.log_arch-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    commit_stb_i   : in  std_logic;

    -- FIFO feeds us backing registers
    fifo_step_o    : out std_logic;
    fifo_bak_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    fifo_setx_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    fifo_regx_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);

    -- Values the decoder needs to provide us
    dec_stall_o    : out std_logic; -- registered
    dec_stb_i      : in  std_logic;
    dec_setx_i     : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    dec_geta_i     : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    dec_getb_i     : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    dec_typ_i      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1           downto 0);
    dec_regx_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    dec_rega_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    dec_regb_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    
    -- Values we provide to the issuer
    iss_stb_o      : out std_logic;
    iss_stat_o     : out std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    iss_typ_o      : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    iss_regx_o     : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    iss_rega_o     : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    iss_regb_o     : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
end opa_renamer;

architecture rtl of opa_renamer is

  constant c_regs      : natural := 2**g_config.log_arch;
  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_one       : std_logic_vector(0 downto 0) := "1";
  
  -- Same-cycle dependencies
  function f_LL_triangle(n : natural) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(1) loop
        if i > j then
          result(i,j) := '1';
        else
          result(i,j) := '0';
        end if;
      end loop;
    end loop;
    return result;
  end f_LL_triangle;
  
  constant c_LL_triangle : t_opa_matrix := f_LL_triangle(c_decoders);

  signal r_map         : t_opa_matrix(c_regs-1 downto 0, c_back_wide-1 downto 0);
  signal s_map_writers : t_opa_matrix(c_regs-1 downto 0, c_decoders-1  downto 0);
  signal s_map_source  : t_opa_matrix(c_regs-1 downto 0, c_decoders    downto 0);
  signal s_map         : t_opa_matrix(c_regs-1 downto 0, c_back_wide-1 downto 0);
  
  signal r_push_at     : unsigned(c_stat_wide-1 downto 0);
  signal r_push_page   : std_logic;
  signal r_pop_at      : unsigned(c_stat_wide-1 downto 0);
  signal r_pop_page    : std_logic;
  signal s_pop_at1     : unsigned(c_stat_wide-1 downto 0);
  signal s_pop_page1   : std_logic;
  signal s_pop_at      : unsigned(c_stat_wide-1 downto 0);
  signal s_pop_page    : std_logic;
  signal s_pop_limit   : std_logic;
  signal r_commit      : std_logic;
    
  signal s_dec_jammed  : std_logic;
  signal r_dec_full    : std_logic;
  signal r_dec_setx    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_geta    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_getb    : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_typ     : t_opa_matrix(c_decoders-1 downto 0, c_types-1           downto 0);
  signal r_dec_regx    : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal r_dec_rega    : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal r_dec_regb    : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal r_bakx        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_old_baka    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_old_bakb    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_match_a     : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_match_b     : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_source_a    : t_opa_matrix(c_decoders-1 downto 0, c_decoders    downto 0);
  signal s_source_b    : t_opa_matrix(c_decoders-1 downto 0, c_decoders    downto 0);
  signal s_new_baka    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_new_bakb    : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_baka        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_bakb        : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);

  signal s_skid_stb    : std_logic;
  signal s_skid_stall  : std_logic;
  signal s_skid_stat   : std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
  signal s_skid_typ    : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
  signal s_skid_regx   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  signal s_skid_rega   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  signal s_skid_regb   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  
  signal r_skid_full   : std_logic;
  signal r_skid_stat   : std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
  signal r_skid_typ    : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
  signal r_skid_regx   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  signal r_skid_rega   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  signal r_skid_regb   : t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
begin

  --- Typical pipeline stage with stall=r_skid_full ----------------------------

  s_dec_jammed <= r_dec_full and r_skid_full;
  dec_stall_o <= s_dec_jammed;
  
  edge1r : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_dec_full <= '0';
    elsif rising_edge(clk_i) then
      r_dec_full <= dec_stb_i or s_dec_jammed;
    end if;
  end process;
  edge1a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_dec_jammed = '0' then
        r_dec_setx <= dec_setx_i;
        r_dec_geta <= dec_geta_i;
        r_dec_getb <= dec_geta_i;
        r_dec_typ  <= dec_typ_i;
        r_dec_rega <= dec_rega_i;
        r_dec_regb <= dec_regb_i;
        r_dec_regx <= dec_regx_i;
        r_bakx     <= fifo_bak_i;
      end if;
    end if;
  end process;
  
  -- Pump the FIFO
  fifo_step_o <= not s_dec_jammed;
  fifo_setx_o <= dec_setx_i;
  fifo_regx_o <= dec_regx_i;

  -- Compute the new architectural state
  s_map_writers <= f_opa_match_index(c_regs, r_dec_regx) and f_opa_dup_row(c_regs, r_dec_setx);
  s_map_source  <= f_opa_pick(f_opa_concat(f_opa_dup_row(c_regs, c_one), s_map_writers));
  s_map         <= f_opa_product(f_opa_split2(1, s_map_source), r_bakx);
  
  edge2r : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_push_at   <= (others => '0');
      r_push_page <= '0';
    elsif rising_edge(clk_i) then
      if r_dec_full = '1' and r_skid_full = '0' then
        if r_push_at = g_config.num_stat/c_decoders-1 then
          r_push_at   <= (others => '0');
          r_push_page <= not r_push_page;
        else
          r_push_at   <= r_push_at+1;
          r_push_page <= r_push_page;
        end if;
      end if;
    end if;
  end process;
  edge2a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if mispredict_i = '1' then -- cannot be a reset/clear as non-constant value used
        r_map <= commit_map_i;
      else
        -- Update the map, if it was changed
        for i in r_map'range(1) loop
          if (not s_dec_jammed and s_map_source(i, c_decoders)) = '1' then
            for j in r_map'range(2) loop
              r_map(i,j) <= s_map(i,j);
            end loop;
          end if;
        end loop;
      end if;
    end if;
  end process;
  
  -- Rename the inputs, watching out for same-cycle dependencies
  s_old_baka <= f_opa_compose(r_map, r_dec_rega);
  s_old_bakb <= f_opa_compose(r_map, r_dec_regb);
  s_match_a  <= f_opa_match(r_dec_rega, r_dec_regx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_LL_triangle;
  s_match_b  <= f_opa_match(r_dec_regb, r_dec_regx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_LL_triangle;
  s_source_a <= f_opa_pick(f_opa_concat(f_opa_dup_row(c_decoders, c_one), s_match_a));
  s_source_b <= f_opa_pick(f_opa_concat(f_opa_dup_row(c_decoders, c_one), s_match_b));
  s_new_baka <= f_opa_product(f_opa_split2(1, s_source_a), r_bakx);
  s_new_bakb <= f_opa_product(f_opa_split2(1, s_source_b), r_bakx);
  
  -- Pick between old arch register or cross-dependency
  rows : for i in s_baka'range(1) generate
    cols : for j in s_baka'range(2) generate
      s_baka(i,j) <= s_old_baka(i,j) when s_source_a(i, c_decoders) = '1' else s_new_baka(i,j);
      s_bakb(i,j) <= s_old_baka(i,j) when s_source_a(i, c_decoders) = '1' else s_new_baka(i,j);
    end generate;
  end generate;
  
  -- Forward the instruction to the skid pad
  s_skid_stb  <= r_dec_full;
  s_skid_stat <= std_logic_vector(r_push_at);
  s_skid_typ  <= r_dec_typ;
  s_skid_regx <= r_bakx;
  -- Backing register 0 is the unused "trash" register.
  s_skid_rega <= f_opa_transpose(f_opa_dup_row(c_back_wide, r_dec_geta)) and s_baka;
  s_skid_regb <= f_opa_transpose(f_opa_dup_row(c_back_wide, r_dec_getb)) and s_bakb;
  
  --- Implement back pressure for issuer ---------------------------------------
  
  backr : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_commit   <= '0';
      r_pop_at   <= (others => '0');
      r_pop_page <= '0';
    elsif rising_edge(clk_i) then
      r_commit   <= commit_stb_i;
      r_pop_at   <= s_pop_at;
      r_pop_page <= s_pop_page;
    end if;
  end process;
  
  s_pop_limit <= f_opa_bit(r_pop_at=g_config.num_stat/c_decoders-1);
  s_pop_at1   <= to_unsigned(0, c_stat_wide) when s_pop_limit='1' else (r_pop_at+1);
  s_pop_page1 <= r_pop_page xor s_pop_limit;
  s_pop_at    <= s_pop_at1   when r_commit='1' else r_pop_at;
  s_pop_page  <= s_pop_page1 when r_commit='1' else r_pop_page;
   
  s_skid_stall <= 
    not commit_stb_i and f_opa_bit(
      (r_push_at    = s_pop_at) and
      (r_push_page /= s_pop_page));
  
  --- Skid pad to cut commit_stb_i latency -------------------------------------
  
  skidr : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_skid_full <= '0';
    elsif rising_edge(clk_i) then
      r_skid_full <= (s_skid_stb or r_skid_full) and s_skid_stall;
    end if;
  end process;
  skida : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_skid_full = '0' then
        r_skid_stat <= s_skid_stat;
        r_skid_typ  <= s_skid_typ;
        r_skid_regx <= s_skid_regx;
        r_skid_rega <= s_skid_rega;
        r_skid_regb <= s_skid_regb;
      end if;
    end if;
  end process;
  
  iss_stb_o  <= (s_skid_stb or r_skid_full) and not s_skid_stall;
  iss_stat_o <= r_skid_stat when r_skid_full='1' else s_skid_stat;
  iss_typ_o  <= r_skid_typ  when r_skid_full='1' else s_skid_typ;
  iss_regx_o <= r_skid_regx when r_skid_full='1' else s_skid_regx;
  iss_rega_o <= r_skid_rega when r_skid_full='1' else s_skid_rega;
  iss_regb_o <= r_skid_regb when r_skid_full='1' else s_skid_regb;
  
end rtl;
