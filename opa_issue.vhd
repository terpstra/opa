library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_issue is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- We need to know if the fetch has something for us
    fetch_stb_i    : in  std_logic;
    fetch_stall_o  : out std_logic;
    
    -- Values the renamer provides us
    rename_shift_o : out std_logic;
    rename_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_geta_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_typ_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    rename_aux_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
    rename_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    rename_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_baka_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakb_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_confa_i : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0); -- conflict: use stata.
    rename_confb_i : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_stata_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_statb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    
    -- Completion timing feedback from EU; 1 + # registers between these = op latency
    eu_shift_o     : out std_logic;
    eu_stb_o       : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_stat_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    eu_stb_i       : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_kill_i      : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_stat_i      : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    
    -- Regfile needs to fetch these for EU
    regfile_stb_o  : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_bakx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    regfile_baka_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    regfile_bakb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    regfile_aux_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);
    
    -- Let the commit know which registers are retired
    commit_shift_o : out std_logic;
    commit_kill_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    commit_setx_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    commit_archx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    commit_bakx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
end opa_issue;

architecture rtl of opa_issue is

  constant c_num_issue : natural := f_opa_num_issue(g_config);
  constant c_num_wait  : natural := f_opa_num_wait (g_config);
  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_num_arch  : natural := f_opa_num_arch (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders -1 downto 0) := (others => '0');
  constant c_execute_ones  : std_logic_vector(c_executers-1 downto 0) := (others => '1');
  constant c_wait_zeros    : std_logic_vector(c_num_wait -1 downto 0) := (others => '0');
  constant c_stat_ones     : std_logic_vector(c_num_stat -1 downto c_num_wait) := (others => '1');
  constant c_stat_labels       : t_opa_matrix := f_opa_labels(c_num_stat);
  constant c_stat_shift_labels : t_opa_matrix := f_opa_labels(c_num_stat,  c_stat_wide, c_decoders);

  -- Instructions have these flags:
  --   issued: was previously selected by arbitration and not stalled
  --   ready:  result is available (can issue dependants)    => issued
  --   final:  will not generate quash|kill                  => ready
  --   commit: ready to be retired                           => final
  --   quash:  instruction needs to be reissued
  --   kill:   must reset the PC
  --
  -- Only committed instructions are shifted out of the window.
  --
  -- OPA makes heavy use of speculative execution; instructions run opportunistically.
  -- Thus, it can make these kinds of mistakes:
  --   A non-final branch can report kill                   (misprediction)
  --   A non-final ld/st  can report kill                   (page fault)
  --   A non-final load   can quash itself                  (cache miss)
  --   A non-final store  can quash following load/stores   (speculative read)
  -- 
  -- To maintain program-order, enforce these rules:
  --   To issue an instruction, all operands must be ready
  --   To issue a store, all prior branches must be committed
  --   To commit an instruction, must be final+!quash and all operands committed
  --   To commit a load/store, all prior stores must be committed
  --     ... this last rule means at more one write/cycle.
  --     ... "no prior squashes and all commits final" might work too
  --   Quash clears ready. If (!issued|final), it also clears: issue/final/quash/kill
  --
  -- To simplify these rules, we keep two additional flags:
  --   uncb: Uncommitted branch
  --   uncs: Uncommitted store
  
  signal s_stall      : std_logic;
  signal s_shift      : std_logic;
  signal r_shift      : std_logic;
  signal s_issued     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal r_issued     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal s_done       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_not_done   : std_logic_vector(c_num_stat-1 downto 0);
  signal r_done       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_killed     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_killed     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readya     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal r_readya     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal s_readyb     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal r_readyb     : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal s_stata      : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_stat_wide-1 downto 0);
  signal r_stata      : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_stat_wide-1 downto 0);
  signal s_statb      : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_stat_wide-1 downto 0);
  signal r_statb      : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_stat_wide-1 downto 0);
  signal r_typ        : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_types    -1 downto 0);
  signal r_setx       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_archx      : t_opa_matrix(c_num_stat-1 downto          0, c_arch_wide-1 downto 0);
  signal r_aux        : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_aux_wide -1 downto 0);
  signal r_baka       : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_back_wide-1 downto 0);
  signal r_bakb       : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_back_wide-1 downto 0);
  signal r_bakx0      : t_opa_matrix(c_num_stat-1 downto          0, c_back_wide-1 downto 0);
  signal r_bakx1      : t_opa_matrix(c_num_stat-1 downto          0, c_back_wide-1 downto 0);
  signal s_bakx1      : t_opa_matrix(c_num_stat-1 downto c_num_wait, c_back_wide-1 downto 0);
  
  type t_stat is array(c_num_stat-1 downto c_num_wait) of unsigned(c_stat_wide-1 downto 0);
  signal s_stata_1    : t_stat;
  signal s_statb_1    : t_stat;
  signal s_stata_2    : t_stat;
  signal s_statb_2    : t_stat;
  
  -- Need to eat data from the renamer with careful register staging
  -- This is tricky because half of window potentially 1-cycle ahead of the other
  signal r_sh1_setx   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh2_setx   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_geta   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_geta   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_getb   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_getb   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_typ    : t_opa_matrix(c_decoders-1 downto 0, c_types-1     downto 0);
  signal r_mux_typ    : t_opa_matrix(c_decoders-1 downto 0, c_types-1     downto 0);
  signal r_sh1_aux    : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide-1  downto 0);
  signal r_sh2_aux    : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide-1  downto 0);
  signal r_sh1_archx  : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal r_sh2_archx  : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal r_sh1_bakx   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh2_bakx   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_mux_bakx   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh1_baka   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh2_baka   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_mux_baka   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh1_bakb   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh2_bakb   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_mux_bakb   : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sh1_confa  : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_confa  : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_confb  : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_confb  : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_mux_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_sh1_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_mux_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  
  signal s_new_readya : std_logic_vector(c_decoders-1 downto 0);
  signal s_new_readyb : std_logic_vector(c_decoders-1 downto 0);
  signal s_new_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_new_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  
  -- Intermediate expressions
  signal s_now_issued : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal s_now_shift  : std_logic_vector(c_num_stat-1 downto c_num_wait);
  signal s_pending    : t_opa_matrix(c_num_stat -1 downto c_num_wait, c_types    -1 downto 0);
  signal s_matchd     : t_opa_matrix(c_num_stat -1 downto          0, c_executers-1 downto 0);
  signal s_matchn_a   : t_opa_matrix(c_decoders -1 downto 0, c_num_stat -1 downto 0);
  signal s_matchn_b   : t_opa_matrix(c_decoders -1 downto 0, c_num_stat -1 downto 0);
  signal r_now_issue  : t_opa_matrix(c_executers-1 downto 0, c_num_stat -1 downto c_num_wait);
  signal r_now_finish : std_logic_vector(c_num_stat-1 downto 0);
  signal s_now_finish : std_logic_vector(c_num_stat-1 downto 0);
  signal s_eu_finish  : std_logic_vector(c_num_stat-1 downto 0);
  signal s_was_readya : std_logic_vector(c_decoders-1 downto 0);
  signal s_was_readyb : std_logic_vector(c_decoders-1 downto 0);
  
begin
  
  -- Select stations to execute, given pending status.
  -- The input is registered by this component, a necessary evil to
  -- allow us to use large memory blocks in the FPGA.
  -- Ideally, it registers at output; non-M10k designs do this.
  arbitrate : opa_arbitrate
    generic map(
      g_config  => g_config,
      g_target  => g_target)
    port map(
      clk_i     => clk_i,
      rst_n_i   => rst_n_i,
      pending_i => s_pending,
      issue_o   => r_now_issue,
      finish_i  => s_eu_finish,
      finish_o  => r_now_finish);
   -- 5 levels for <= 12 num_issue (3 pending + 2 arbitrate)
  
  -- Which stations are now issued?
  -- r_now_issue has old numbering, so may decrement to match new indexes
  s_now_issued <= f_opa_product(f_opa_transpose(r_now_issue), c_execute_ones);
  s_now_shift  <= s_now_issued when r_shift='0' else (c_decoder_zeros & s_now_issued(c_num_stat-1 downto c_num_wait+c_decoders));
  s_issued     <= r_issued or s_now_shift;
    -- 2 levels with <= 12 EUs
    -- ... could be reduced to 1 by giving type-based issue info (in addition to unit based)
  
  -- Pass the stations we issue through the EU schedulers
  eu_shift_o <= r_shift;
  eu_stb_o   <= f_opa_product(r_now_issue, c_stat_ones);
  eu_stat_o  <= f_opa_1hot_dec(f_opa_concat(r_now_issue, f_opa_dup_row(c_executers, c_wait_zeros)));
    -- 2 levels for 36 stations

  -- Which stations are done or killed?
  -- eu_stat_i has old numbering, so may decrement to match new indexes
  s_matchd <= f_opa_match(c_stat_labels,       eu_stat_i) when r_shift='0' else
              f_opa_match(c_stat_shift_labels, eu_stat_i);
    -- 1 level with <= 16 stations (4stat+1shift)
  s_eu_finish <= f_opa_product(s_matchd, eu_stb_i);
    -- 2 levels with <= 5 EUs
    -- AND_EU [4 index 1 shift 1 stb/kill]
  s_now_finish <= r_now_finish when r_shift='0' else (c_decoder_zeros & r_now_finish(c_num_stat-1 downto c_decoders));
  s_done   <= r_done or s_now_finish;
    -- 1 level
  s_killed <= f_opa_product(s_matchd, eu_kill_i) or r_killed;
  
  -- Which stations become ready?
  -- r_stat[ab] references lag by 1-cycle (content-wise), but are accurate (index-wise)
  s_readya <= r_readya or f_opa_compose(r_now_finish, r_stata);
  s_readyb <= r_readyb or f_opa_compose(r_now_finish, r_statb);
     -- 2 levels with <= 16 stations
  
  -- Which stations are pending issue?
  pending : for t in 0 to c_types-1 generate
    stat : for s in c_num_wait to c_num_stat-1 generate
      s_pending(s,t) <=
        s_readya(s) and s_readyb(s) and
        not s_issued(s) and r_typ(s,t);
    end generate;
  end generate;
    -- 3 levels (s_issued and s_ready[ab] have 2 depth)
  
  -- Which registers does each EU need to use?
  -- r_bak[abx], r_aux shifted one cycle later, so s_stat has correct index
  regfile_stb_o  <= f_opa_product(r_now_issue, c_stat_ones);
  regfile_bakx_o <= f_opa_product(r_now_issue, s_bakx1);
  regfile_baka_o <= f_opa_product(r_now_issue, r_baka);
  regfile_bakb_o <= f_opa_product(r_now_issue, r_bakb);
  regfile_aux_o  <= f_opa_product(r_now_issue, r_aux);
    -- 2 levels with stations <= 18
  
  -- Submatrix for regfile product
  bakx1 : for i in c_num_wait to c_num_stat-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      s_bakx1(i,b) <= r_bakx1(i,b);
    end generate;
  end generate;

  -- Determine if the execution window should be shifted
  s_stall <= not
    (f_opa_and(s_done(c_decoders-1 downto 0)) and
     (f_opa_bit(c_num_wait = 0) or 
      f_opa_and(s_issued(c_decoders+c_num_wait-1 downto c_num_wait))));
  s_shift <= fetch_stb_i and not s_stall;
  fetch_stall_o <= s_stall or not rst_n_i;
    -- 2 levels with decoders <= 2
  
  -- Prepare decremented versions of the station references
  statrefs : for i in c_num_wait to c_num_stat-1 generate
    -- Need to remap the signals to get the effect we want
    bits : for b in 0 to c_stat_wide-1 generate
      s_stata_1(i)(b) <= r_stata(i, b);
      s_statb_1(i)(b) <= r_statb(i, b);
      s_stata(i, b) <= s_stata_2(i)(b);
      s_statb(i, b) <= s_statb_2(i)(b);
    end generate;
    s_stata_2(i) <= (s_stata_1(i) - c_decoders) when r_shift='1' else s_stata_1(i);
    s_statb_2(i) <= (s_statb_1(i) - c_decoders) when r_shift='1' else s_statb_1(i);
      -- 1 level with stations <= 32 (5 stat + 1 shift)
  end generate;
  
  -- Tell the committer about our data
  rename_shift_o <= r_shift;
  commit_shift_o <= r_shift;
  commit_kill_o  <= r_killed(c_decoders-1 downto 0); -- !!! timing?
  commit_setx_o  <= r_setx(c_decoders-1 downto 0);
  commit : for i in 0 to c_decoders-1 generate
    arch : for b in 0 to c_arch_wide-1 generate
      commit_archx_o(i, b) <= r_archx(i, b);
    end generate;
    back : for b in 0 to c_back_wide-1 generate
      commit_bakx_o(i, b) <= r_bakx1(i, b);
    end generate;
  end generate;
  
  -- Compare to the bakx in stations to find new station's 1hot dependency
  s_matchn_a  <= f_opa_match(r_mux_baka, r_bakx0);
  s_matchn_b  <= f_opa_match(r_mux_bakb, r_bakx0);
    -- 2 levels
  
  -- Decode to what the new station depends on
  s_new_stata <= f_opa_1hot_dec(s_matchn_a) or r_mux_stata;
  s_new_statb <= f_opa_1hot_dec(s_matchn_b) or r_mux_statb;
    -- 3 levels with <= 30 stations (5x3:1 decode of [(3=3) and (3=3)])
  
  -- The nots ensure no match = ready
  s_not_done <= not s_done; -- 1 level
  s_was_readya <= not f_opa_product(s_matchn_a, s_not_done);
  s_was_readyb <= not f_opa_product(s_matchn_b, s_not_done);
    -- 3 levels with <= 12 stations (6x2:1 OR of [(3=3) and (3=3) and stb])
  
  -- Consider mitigating factor for readiness
  s_new_readya <= not r_mux_geta or (not r_mux_confa and s_was_readya);
  s_new_readyb <= not r_mux_getb or (not r_mux_confb and s_was_readyb);
    -- 4 levels for 48 stations (4* OR from s_was_readya)
  
  -- Register the inputs with reset, with clock enable
  rename_in_rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      -- Load no-ops on power-on
      r_sh1_geta  <= (others => '0'); -- needed b/c new_ready is not issued
      r_sh1_getb  <= (others => '0');
      r_sh1_typ   <= (others => (1 => '1', others => '0'));
      r_sh1_setx  <= (others => '0');
      r_sh2_setx  <= (others => '0');
    elsif rising_edge(clk_i) then
      if r_shift = '1' then
        r_sh1_geta  <= rename_geta_i;
        r_sh1_getb  <= rename_geta_i;
        r_sh1_typ   <= rename_typ_i;
        r_sh1_setx  <= rename_setx_i;
        r_sh2_setx  <= r_sh1_setx;
      end if;
    end if;
  end process;
  
  -- Register the inputs without reset, with clock enable
  rename_in_c : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable
        r_sh1_aux   <= rename_aux_i;
        r_sh1_archx <= rename_archx_i;
        r_sh1_baka  <= rename_baka_i;
        r_sh1_bakb  <= rename_bakb_i;
        r_sh1_confa <= rename_confa_i;
        r_sh1_confb <= rename_confb_i;
        r_sh1_stata <= rename_stata_i;
        r_sh1_statb <= rename_statb_i;
        r_sh2_aux   <= r_sh1_aux;
        r_sh2_archx <= r_sh1_archx;
        r_sh2_baka  <= r_sh1_baka;
        r_sh2_bakb  <= r_sh1_bakb;
      end if;
    end if;
  end process;
  
  -- Mux inputs with reset, clock enable, load enable
  rename_mux_rcl : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_mux_geta  <= (others => '0');
      r_mux_getb  <= (others => '0');
      r_mux_typ   <= (others => (1 => '1', others => '0'));
    elsif rising_edge(clk_i) then
      if s_shift = '1' then   -- clock enable
        if r_shift = '1' then -- load enable
          r_mux_geta  <= rename_geta_i;
          r_mux_getb  <= rename_getb_i;
          r_mux_typ   <= rename_typ_i;
        else
          r_mux_geta  <= r_sh1_geta;
          r_mux_getb  <= r_sh1_getb;
          r_mux_typ   <= r_sh1_typ;
        end if;
      end if;
    end if;
  end process;
  
  -- Mux inputs without reset
  rename_mux_cl : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then   -- clock enable
        if r_shift = '1' then -- load enable
          r_mux_baka  <= rename_baka_i;
          r_mux_bakb  <= rename_bakb_i;
          r_mux_confa <= rename_confa_i;
          r_mux_confb <= rename_confb_i;
          r_mux_stata <= rename_stata_i;
          r_mux_statb <= rename_statb_i;
        else
          r_mux_baka  <= r_sh1_baka;
          r_mux_bakb  <= r_sh1_bakb;
          r_mux_confa <= r_sh1_confa;
          r_mux_confb <= r_sh1_confb;
          r_mux_stata <= r_sh1_stata;
          r_mux_statb <= r_sh1_statb;
        end if;
      end if;
    end if;
  end process;
  
  -- Register the stations, 0-latency with reset, with load enable
  stations_0rl : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_shift  <= '0';
      r_issued <= (others => '1');
      r_done   <= (others => '1');
      r_killed <= (others => '0');
    elsif rising_edge(clk_i) then
      r_shift  <= s_shift;
      if s_shift = '1' then -- load enable port
        r_issued <= c_decoder_zeros & s_issued(c_num_stat-1 downto c_decoders+c_num_wait);
        r_done   <= c_decoder_zeros & s_done  (c_num_stat-1 downto c_decoders);
        r_killed <= c_decoder_zeros & s_killed(c_num_stat-1 downto c_decoders);
      else
        r_issued <= s_issued;
        r_done   <= s_done;
        r_killed <= s_killed;
      end if;
    end if;
  end process;
  
  -- Register the stations 0-latency without reset, with load enable
  stations_0l : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then -- load enable
        r_readya <= s_new_readya & s_readya(c_num_stat-1 downto c_decoders+c_num_wait);
        r_readyb <= s_new_readyb & s_readyb(c_num_stat-1 downto c_decoders+c_num_wait);
        -- These two are sneaky; they are half lagged. Content lags thanks to s_stat[ab].
        for i in c_num_wait to c_num_stat-c_decoders-1 loop
          for b in 0 to c_stat_wide-1 loop
            r_stata(i,b) <= s_stata(i+c_decoders,b);
            r_statb(i,b) <= s_statb(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_stat_wide-1 loop
            r_stata(i,b) <= s_new_stata(i-(c_num_stat-c_decoders),b);
            r_statb(i,b) <= s_new_statb(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      else
        r_readya <= s_readya;
        r_readyb <= s_readyb;
        r_stata  <= s_stata;
        r_statb  <= s_statb;
      end if;
    end if;
  end process;

  -- Register the stations, 0-latency without reset, with clock enable
  stations_0c : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then -- clock enable port
        for i in c_num_wait to c_num_stat-c_decoders-1 loop
          for b in 0 to c_types-1 loop
            r_typ(i,b) <= r_typ(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_types-1 loop
            r_typ(i,b) <= r_mux_typ(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
  stations_0rc : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      for b in 0 to c_back_wide-1 loop
        for i in 0 to c_num_stat-1 loop
          r_bakx0(i,b)    <= to_unsigned(c_num_arch+i, c_back_wide)(b);
        end loop;
         for i in 0 to c_decoders-1 loop
          r_mux_bakx(i,b) <= to_unsigned(c_num_arch+c_num_stat+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if s_shift = '1' then
        if r_shift = '1' then
          r_mux_bakx <= rename_bakx_i;
        else
          r_mux_bakx <= r_sh1_bakx;
        end if;
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx0(i,b) <= r_bakx0(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx0(i,b) <= r_mux_bakx(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;

  -- Register the stations, 1-latency without reset, with clock enable
  stations_1c : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_arch_wide-1 loop
            r_archx(i,b) <= r_archx(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_wait to c_num_stat-c_decoders-1 loop
          for b in 0 to c_aux_wide-1 loop
            r_aux(i,b)   <= r_aux  (i+c_decoders,b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b)  <= r_baka (i+c_decoders,b);
            r_bakb(i,b)  <= r_bakb (i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_arch_wide-1 loop
            r_archx(i,b) <= r_sh2_archx(i-(c_num_stat-c_decoders),b);
          end loop;
          for b in 0 to c_aux_wide-1 loop
            r_aux  (i,b) <= r_sh2_aux  (i-(c_num_stat-c_decoders),b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka (i,b) <= r_sh2_baka (i-(c_num_stat-c_decoders),b);
            r_bakb (i,b) <= r_sh2_bakb (i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset, with clock enable
  stations_1rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_setx <= (others => '0');
      for b in 0 to c_back_wide-1 loop
        for i in 0 to c_num_stat-1 loop
          r_bakx1(i,b)    <= to_unsigned(c_num_arch+i, c_back_wide)(b);
        end loop;
        for i in 0 to c_decoders-1 loop
          r_sh1_bakx(i,b) <= to_unsigned(c_num_arch+c_num_stat+c_decoders+i, c_back_wide)(b);
          r_sh2_bakx(i,b) <= to_unsigned(c_num_arch+c_num_stat+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        r_setx <= r_sh2_setx & r_setx(c_num_stat-1 downto c_decoders);
        r_sh1_bakx <= rename_bakx_i;
        r_sh2_bakx <= r_sh1_bakx;
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx1(i,b) <= r_bakx1(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx1(i,b) <= r_sh2_bakx(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;

end rtl;
