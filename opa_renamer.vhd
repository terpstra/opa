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
    fifo_ready_i   : in  std_logic;
    fifo_bak_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Values the decoder needs to provide us
    dec_stall_o    : out std_logic; -- warning: a VERY slow signal; register it and use a skid pad
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
  function f_LR_triangle(n : natural) return t_opa_matrix is
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
  end f_LR_triangle;
  
  constant c_LR_triangle : t_opa_matrix := f_LR_triangle(c_decoders);

  signal r_map         : t_opa_matrix(c_regs-1 downto 0, c_back_wide-1 downto 0);
  signal s_map_writers : t_opa_matrix(c_regs-1 downto 0, c_decoders-1  downto 0);
  signal s_map_source  : t_opa_matrix(c_regs-1 downto 0, c_decoders    downto 0);
  signal s_map         : t_opa_matrix(c_regs-1 downto 0, c_back_wide-1 downto 0);
  
  signal r_dec_stb     : std_logic;
  signal r_count       : unsigned(c_stat_wide-1 downto 0);
  signal s_count       : unsigned(c_stat_wide-1 downto 0);
  
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

begin

  -- We cannot accept new instructions when there are no free backing registers
  dec_stall_o <= not fifo_ready_i;

  edge1r : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_dec_stb <= '0';
    elsif rising_edge(clk_i) then
      r_dec_stb <= dec_stb_i and fifo_ready_i;
    end if;
  end process;
  edge1a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_dec_setx <= dec_setx_i;
      r_dec_geta <= dec_geta_i;
      r_dec_getb <= dec_geta_i;
      r_dec_typ  <= dec_typ_i;
      r_dec_rega <= dec_rega_i;
      r_dec_regb <= dec_regb_i;
      r_dec_regx <= dec_regx_i;
      r_bakx     <= fifo_bak_i;
    end if;
  end process;

  -- Compute the new architectural state
  s_map_writers <= f_opa_match_index(c_regs, r_dec_regx) and f_opa_dup_row(c_regs, r_dec_setx);
  s_map_source  <= f_opa_pick(f_opa_concat(f_opa_dup_row(c_regs, c_one), s_map_writers));
  s_map         <= f_opa_product(f_opa_split2(1, s_map_source), r_bakx);
  s_count       <= to_unsigned(0, c_stat_wide) when r_count = (g_config.num_stat/c_decoders-1) else (r_count+1);
  
  edge2r : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_count <= (others => '1');
    elsif rising_edge(clk_i) then
      if r_dec_stb = '1' then
        r_count <= s_count;
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
          if (r_dec_stb and s_map_source(i, c_decoders)) = '1' then
            for j in r_map'range(2) loop
              r_map(i,j) <= s_map(i,j);
            end loop;
          end if;
        end loop;
      end if;
    end if;
  end process;
  
  -- Forward the instruction
  iss_stb_o  <= r_dec_stb;
  iss_typ_o  <= r_dec_typ;
  iss_stat_o <= std_logic_vector(s_count);
  iss_regx_o <= r_bakx;
  
  -- Rename the inputs, watching out for same-cycle dependencies
  s_old_baka <= f_opa_compose(r_map, r_dec_rega);
  s_old_bakb <= f_opa_compose(r_map, r_dec_regb);
  s_match_a  <= f_opa_match(r_dec_rega, r_dec_regx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_LR_triangle;
  s_match_b  <= f_opa_match(r_dec_regb, r_dec_regx) and f_opa_dup_row(c_decoders, r_dec_setx) and c_LR_triangle;
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
  
  -- Backing register 0 is the "trash" register.
  -- It is never used by real instructions.
  iss_rega_o <= f_opa_dup_row(c_back_wide, r_dec_geta) and s_baka;
  iss_regb_o <= f_opa_dup_row(c_back_wide, r_dec_getb) and s_bakb;
  
end rtl;
