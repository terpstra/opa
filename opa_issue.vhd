library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_issue is
  generic(
    g_config       : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- Values the decoder needs to provide us
    dec_stb_i      : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    dec_typ_i      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    dec_stat_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    dec_regx_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); -- -1 on no-op
    dec_rega_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    dec_regb_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- EU should execute this next
    eu_next_regx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); -- -1 on no-op
    eu_next_rega_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_next_regb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    -- EU is committed to completion in 2 cycles (after stb_o) [ latency1: connect regx_i=regx_o ]
    eu_done_regx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Connections to/from the committer
    commit_mask_i  : in  std_logic_vector(2*g_config.num_stat-1 downto 0); -- must be a register
    commit_done_o  : out std_logic_vector(  g_config.num_stat-1 downto 0));
end opa_issue;

architecture rtl of opa_issue is

  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_back_num  : natural := f_opa_back_num (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_stations  : natural := g_config.num_stat;
  constant c_unit_wide : natural := f_opa_log2(f_opa_max_typ(g_config));
  
  constant c_ones : std_logic_vector(c_executers-1 downto 0) := (others => '1');

  signal r_dec_stb       : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_typ       : t_opa_matrix(c_decoders -1 downto 0, c_types    -1 downto 0);
  signal r_dec_stat      : t_opa_matrix(c_decoders -1 downto 0, c_stat_wide-1 downto 0);
  signal r_dec_regx      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_dec_rega      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_dec_regb      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_done_regx     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal s_dec_done_a    : std_logic_vector(c_decoders-1 downto 0);
  signal s_dec_done_b    : std_logic_vector(c_decoders-1 downto 0);
  
  signal r_back_ready    : std_logic_vector(c_back_num-1 downto 0) := (others => '1');
  signal s_back_now_done : std_logic_vector(c_back_num-1 downto 0);
  signal s_back_cleared  : std_logic_vector(c_back_num-1 downto 0);
  
  signal r_stat_issued   : std_logic_vector(c_stations-1 downto 0) := (others => '1');
  signal r_stat_readya   : std_logic_vector(c_stations-1 downto 0);
  signal r_stat_readyb   : std_logic_vector(c_stations-1 downto 0);
  signal r_stat_typ      : t_opa_matrix(c_stations-1 downto 0, c_types    -1 downto 0);
  signal r_stat_rega     : t_opa_matrix(c_stations-1 downto 0, c_back_wide-1 downto 0);
  signal r_stat_regb     : t_opa_matrix(c_stations-1 downto 0, c_back_wide-1 downto 0);
  signal r_stat_regx     : t_opa_matrix(c_stations-1 downto 0, c_back_wide-1 downto 0);
  signal s_stat_readya   : std_logic_vector(c_stations-1 downto 0);
  signal s_stat_readyb   : std_logic_vector(c_stations-1 downto 0);
  signal s_stat_pending  : std_logic_vector(c_stations-1 downto 0);
  
  -- Need to curry this matrix when passed to opa_satadd
  type t_pending_typ  is array (c_types-1 downto 0) of std_logic_vector(  c_stations-1 downto 0);
  type t_pending_prio is array (c_types-1 downto 0) of std_logic_vector(2*c_stations-1 downto 0);
  type t_sums         is array (c_types-1 downto 0) of t_opa_matrix(2*c_stations-1 downto 0, c_unit_wide-1 downto 0);
  type t_pick_index   is array (c_executers-1 downto 0) of std_logic_vector(2*c_stations-1 downto 0);
  type t_pick_one     is array (c_executers-1 downto 0) of std_logic_vector(2*c_stations   downto 0);
  signal s_stat_pending_typ  : t_pending_typ;
  signal s_stat_pending_prio : t_pending_prio;
  signal s_stat_sums         : t_sums;
  signal s_pick_index        : t_pick_index;
  signal s_pick_one          : t_pick_one;
  signal s_schedule          : t_opa_matrix(c_executers-1 downto 0,   c_stations-1 downto 0);
  
begin

  -- Edge 1: register decoded instructions and just-finished registers
  edge1a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_dec_stb  <= dec_stb_i;
      r_dec_typ  <= dec_typ_i;
      r_dec_stat <= dec_stat_i;
      r_dec_regx <= dec_regx_i;
      r_dec_rega <= dec_rega_i;
      r_dec_regb <= dec_regb_i;
      r_done_regx <= eu_done_regx_i; -- fans out like crazy -- duplicate it !!!
    end if;
  end process;
  
  -- Calculate what the just-completed registers affect
  s_stat_readya   <= f_opa_match(r_stat_rega, r_done_regx) or r_stat_readya;
  s_stat_readyb   <= f_opa_match(r_stat_regb, r_done_regx) or r_stat_readyb;
  s_back_now_done <= f_opa_match_index(c_back_num, r_done_regx);
  s_back_cleared  <= f_opa_match_index(c_back_num, r_dec_regx);
  
  -- Are the inputs for newly decoded instructions ready?
  --   They were already ready (careful of new op cross-dependencies)
  --   They are about to be made ready by completing operations
  s_dec_done_a <= f_opa_compose(r_back_ready and not s_back_cleared, r_dec_rega) or f_opa_match(r_dec_rega, r_done_regx);
  s_dec_done_b <= f_opa_compose(r_back_ready and not s_back_cleared, r_dec_regb) or f_opa_match(r_dec_regb, r_done_regx);
  
  -- Edge 2: Update reservation stations and backing readiness
  edge2r : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_back_ready  <= (others => '1'); -- reseting just these suffices
      r_stat_issued <= (others => '1');
    elsif rising_edge(clk_i) then
      r_back_ready  <= (s_back_now_done or r_back_ready) and not s_back_cleared;
      r_stat_issued <= r_stat_issued or f_opa_product(f_opa_transpose(s_schedule), c_ones);
    end if;
  end process;
  edge2a : process(clk_i) is
    variable index : integer;
  begin
    if rising_edge(clk_i) then
      r_stat_readya <= s_stat_readya;
      r_stat_readyb <= s_stat_readyb;
      
      -- Each station has only one decoder source
      for i in 0 to c_decoders-1 loop
        index := to_integer(unsigned(f_opa_select_row(r_dec_stat, i)))*c_decoders + i;
        
        if r_dec_stb(i) = '1' then
          r_stat_issued(index) <= '0';
          r_stat_readya(index) <= s_dec_done_a(i);
          r_stat_readyb(index) <= s_dec_done_b(i);
          for b in r_stat_typ'range(2) loop
            r_stat_typ (index, b) <= r_dec_typ (i, b);
            r_stat_rega(index, b) <= r_dec_rega(i, b);
            r_stat_regb(index, b) <= r_dec_regb(i, b);
            r_stat_regx(index, b) <= r_dec_regx(i, b);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  -------------------------------------------------------------------------------------------------
  -- Instruction selection begins here                                                           --
  -------------------------------------------------------------------------------------------------
  
  -- Which stations are pending execution?
  s_stat_pending <= s_stat_readya and s_stat_readyb and not r_stat_issued;
  
  -- Split pending instructions to unit types and count the incidence
  types : for t in 0 to c_types-1 generate
    s_stat_pending_typ(t)  <= s_stat_pending and f_opa_select_col(r_stat_typ, t);
    s_stat_pending_prio(t) <= (s_stat_pending_typ(t) & s_stat_pending_typ(t)) and commit_mask_i;
    
    satadd : opa_satadd
      generic map(
        g_state => c_unit_wide,
        g_size  => c_stations*2)
      port map(
        bits_i  => s_stat_pending_prio(t),
        sums_o  => s_stat_sums(t));
  end generate;
  
  -- Assign one reservation station to each unit
  executers : for u in 0 to c_executers-1 generate
    prio_stations : for r in 0 to 2*c_stations-1 generate
      s_pick_index(u)(r) <= 
        f_opa_bit(
          f_opa_select_row(s_stat_sums(f_opa_unit_type(g_config, u)), r) = 
          std_logic_vector(to_unsigned(f_opa_unit_index(g_config, u), c_unit_wide)));
    end generate;
    
    s_pick_one(u) <= (s_pick_index(u) & '0') and not ('0' & s_pick_index(u));
    
    real_stations : for r in 0 to c_stations-1 generate
      s_schedule(u,r) <= s_pick_one(u)(r) or s_pick_one(u)(r+c_stations);
    end generate;
  end generate;
  
  -- Compute the result via matrix product
  -- We use inverted logic so the result is -1 when s_schedule assigns nothing
  eu_next_regx_o <= not f_opa_product(s_schedule, not r_stat_regx);
  eu_next_rega_o <= not f_opa_product(s_schedule, not r_stat_rega);
  eu_next_regb_o <= not f_opa_product(s_schedule, not r_stat_regb);

end rtl;
