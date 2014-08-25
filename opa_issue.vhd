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
    rename_fast_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_slow_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_jump_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_load_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_store_i : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
    rename_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    rename_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_baka_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakb_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_stata_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_statb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    
    -- Exceptions from the EUs
    eu_shift_o     : out std_logic;
    eu_stat_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_num_stat(g_config)-1 downto 0);
    eu_ready_i     : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0); -- these can be slow
    eu_final_i     : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    eu_quash_i     : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    eu_kill_i      : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    eu_stall_i     : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0); -- must be fast
    
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

  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_num_arch  : natural := f_opa_num_arch (g_config);
  constant c_num_fast  : natural := f_opa_num_fast (g_config);
  constant c_num_slow  : natural := f_opa_num_slow (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders -1 downto 0) := (others => '0');
  constant c_stat_ones     : std_logic_vector(c_num_stat -1 downto 0) := (others => '1');

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
  --     ... this last rule means at most one write/cycle.
  --     ... "no prior squashes and all commits final" might work too
  --   Quash clears ready. If final, it also clears: issued/final/kill.
  --
  -- To simplify these rules, we keep two additional flags:
  --   uncb: Uncommitted branch
  --   uncs: Uncommitted store
  
  -- To keep r_schedule as easy to compute as possible, half of the reservation station
  -- is shifted early, and half is shifted late. r_schedule is late, as is anything fed
  -- to the regfile stage. Anything used to feed r_schedule is shifted early.
  
  signal r_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal r_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule      : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  signal s_schedule_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal r_schedule_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  
  signal s_stall      : std_logic;
  signal s_shift      : std_logic;
  signal r_shift      : std_logic;
  
  signal s_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_kill       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_kill       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_quash      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_quash      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_commit     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_commit     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_uncb       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_uncb       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_uncs       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_uncs       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_ldst       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_fast       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_slow       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal s_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_setx       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_archx      : t_opa_matrix(c_num_stat-1 downto 0, c_arch_wide-1 downto 0);
  signal r_aux        : t_opa_matrix(c_num_stat-1 downto 0, c_aux_wide -1 downto 0);
  signal r_baka       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakb       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakx0      : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakx1      : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  
  type t_stat is array(c_num_stat-1 downto 0) of unsigned(c_stat_wide-1 downto 0);
  signal s_uncb_sum     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_uncs_sum     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_store_issue  : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ldst_commit  : std_logic_vector(c_num_stat-1 downto 0);
  signal s_quash1       : std_logic_vector(c_num_stat+c_decoders-1 downto 0);
  signal s_quasha       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_quashb       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_commit1      : std_logic_vector(c_num_stat+c_decoders-1 downto 0);
  signal s_commita      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_commitb      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready1       : std_logic_vector(c_num_stat+c_decoders-1 downto 0);
  signal s_readya       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyb       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_eu_notstall  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_eu_issued    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_now_issued   : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_fast : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_slow : std_logic_vector(c_num_stat-1 downto 0);
  signal s_stata_1      : t_stat;
  signal s_statb_1      : t_stat;
  signal s_stata_2      : t_stat;
  signal s_statb_2      : t_stat;
  
  -- Need to eat data from the renamer with careful register staging
  -- This is tricky because half of window potentially 1-cycle ahead of the other
  signal r_sh1_fast   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_fast   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_slow   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_slow   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_jump   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_jump   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_store  : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_store  : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_ldst   : std_logic_vector(c_decoders-1 downto 0);
  signal r_mux_ldst   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh1_setx   : std_logic_vector(c_decoders-1 downto 0);
  signal r_sh2_setx   : std_logic_vector(c_decoders-1 downto 0);
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
  signal r_sh1_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_mux_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_sh1_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal r_mux_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  
  signal s_new_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_new_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_matchn_a   : t_opa_matrix(c_decoders -1 downto 0, c_num_stat -1 downto 0);
  signal s_matchn_b   : t_opa_matrix(c_decoders -1 downto 0, c_num_stat -1 downto 0);
  
  function f_pad(x : std_logic) return std_logic_vector is
    variable result : std_logic_vector(c_decoders-1 downto 0) := (others => '0');
  begin
    result(result'high) := x;
    return result;
  end f_pad;
  constant c_pad_high0 : std_logic_vector(c_decoders-1 downto 0) := f_pad('0');
  constant c_pad_high1 : std_logic_vector(c_decoders-1 downto 0) := f_pad('1');
  
  function f_decrement(x : unsigned(c_stat_wide-1 downto 0)) return unsigned is
    constant cu_num_stat : unsigned(x'range) := to_unsigned(c_num_stat+c_decoders-1, x'length);
    constant cu_decoders : unsigned(x'range) := to_unsigned(c_decoders,              x'length);
  begin
    if x = cu_num_stat or x < cu_decoders then
      return cu_num_stat;
    else
      return x - c_decoders;
    end if;
  end f_decrement;
  
begin

  -- Status from EUs
  -- !!! it feels to me like there's a race between issue and quash
  s_final <= eu_final_i or (r_final and not r_quash);
  s_kill  <= eu_kill_i  or (r_kill  and not r_quash);
  s_ready <= ((eu_ready_i or r_ready) and not r_quash) or (s_schedule_fast_issue and s_pending_fast);
  
  -- Is it safe to issue this station? (store-branch conflict)
  uncb : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => 1)
    port map(
      bits_i  => r_uncb,
      total_o => s_uncb_sum);
  s_store_issue <= not (r_uncs and s_uncb_sum);
    -- 2 inputs to level 3 with <= 36 stations
  
  -- Is it safe to commit this load/store? (speculative read/write)
  uncs : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => 1)
    port map(
      bits_i  => r_uncs,
      total_o => s_uncs_sum);
  s_ldst_commit <= not (r_ldst and s_uncs_sum);

  -- Propagate instruction quashing
  s_quash1 <= c_pad_high0 & r_quash;
  s_quasha <= f_opa_compose(s_quash1, r_stata);
  s_quashb <= f_opa_compose(s_quash1, r_statb);
  s_quash  <= eu_quash_i or s_quasha or s_quashb or (r_quash and r_issued and not r_final);
    -- 3 levels with <= 16 stations
  
  -- Propagate commits !!! peek ahead for r_final (and r_quash?)
  s_commit1 <= c_pad_high1 & r_commit;
  s_commita <= f_opa_compose(s_commit1, r_stata);
  s_commitb <= f_opa_compose(s_commit1, r_statb);
  s_commit  <= r_commit or (s_commita and s_commitb and r_final and not r_quash and s_ldst_commit);
  s_uncs    <= r_uncs and not s_commit;
  s_uncb    <= r_uncb and not s_commit;
    -- 3 levels with <= 16 stations
  
  -- Which stations have ready operands?
  s_ready1 <= c_pad_high1 & r_ready;
  s_readya <= f_opa_compose(s_ready1, r_stata);
  s_readyb <= f_opa_compose(s_ready1, r_statb);
     -- 2 levels with <= 16 stations
  
  -- Which stations are now issued?
  -- r_now_issue has old numbering, so may decrement to match new indexes
  s_eu_notstall <= not eu_stall_i;
  s_eu_issued  <= r_schedule_fast_issue or f_opa_product(f_opa_transpose(r_schedule_slow), s_eu_notstall);
  s_now_issued <= s_eu_issued when r_shift='0' else (c_decoder_zeros & s_eu_issued(c_num_stat-1 downto c_decoders));
  s_issued     <= s_now_issued or (r_issued and not (r_quash and r_final));
    -- 2 levels with slow <= 2

  -- Which stations are pending issue?
  s_pending_fast <= s_readya and s_readyb and not s_now_issued and r_fast;
  s_pending_slow <= s_readya and s_readyb and not s_now_issued and r_slow and s_store_issue;
    -- 3 levels
  
  fast : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_fast)
    port map(
      bits_i   => s_pending_fast,
      count_o  => s_schedule_fast,
      total_o  => s_schedule_fast_issue);
  
  slow : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_slow)
    port map(
      bits_i   => s_pending_slow,
      count_o  => s_schedule_slow,
      total_o  => open);
   -- 5 levels for <= 12 num_stat (3 pending + 2 arbitrate)
  
  s_schedule <= f_opa_transpose(f_opa_concat(f_opa_transpose(r_schedule_fast), f_opa_transpose(r_schedule_slow)));
  
  -- Forward plan to the register file and EUs
  eu_shift_o <= r_shift;
  eu_stat_o  <= s_schedule;

  -- Which registers does each EU need to use?
  -- r_bak[abx], r_aux shifted one cycle later, so s_stat has correct index
  regfile_stb_o  <= f_opa_product(s_schedule, c_stat_ones);
  regfile_bakx_o <= f_opa_product(s_schedule, r_bakx1);
  regfile_baka_o <= f_opa_product(s_schedule, r_baka);
  regfile_bakb_o <= f_opa_product(s_schedule, r_bakb);
  regfile_aux_o  <= f_opa_product(s_schedule, r_aux);
    -- 2 levels with stations <= 18
  
  -- Determine if the execution window should be shifted
  s_stall <= not f_opa_and(s_commit(c_decoders-1 downto 0));
  s_shift <= fetch_stb_i and not s_stall;
  fetch_stall_o <= s_stall or not rst_n_i;
    -- 2 levels with decoders <= 2
  
  -- Prepare decremented versions of the station references
  statrefs : for i in 0 to c_num_stat-1 generate
    -- Need to remap the signals to get the effect we want
    bits : for b in 0 to c_stat_wide-1 generate
      s_stata_1(i)(b) <= r_stata(i, b);
      s_statb_1(i)(b) <= r_statb(i, b);
      s_stata(i, b) <= s_stata_2(i)(b);
      s_statb(i, b) <= s_statb_2(i)(b);
    end generate;
    s_stata_2(i) <= f_decrement(s_stata_1(i)) when r_shift='1' else s_stata_1(i);
    s_statb_2(i) <= f_decrement(s_statb_1(i)) when r_shift='1' else s_statb_1(i);
      -- 1 level with stations <= 32 (5 stat + 1 shift)
  end generate;
  
  -- Tell the committer about our data
  rename_shift_o <= r_shift;
  commit_shift_o <= r_shift;
  commit_kill_o  <= r_kill(c_decoders-1 downto 0);
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
  
  -- Register the inputs with reset, with clock enable
  rename_in_rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      -- Load no-ops on power-on
      r_sh1_setx  <= (others => '0');
      r_sh2_setx  <= (others => '0');
      r_sh1_fast  <= (others => '1');
      r_sh1_slow  <= (others => '0');
      r_sh1_jump  <= (others => '0');
      r_sh1_store <= (others => '0');
      r_sh1_ldst  <= (others => '0');
    elsif rising_edge(clk_i) then
      if r_shift = '1' then
        r_sh1_setx  <= rename_setx_i;
        r_sh2_setx  <= r_sh1_setx;
        r_sh1_fast  <= rename_fast_i;
        r_sh1_slow  <= rename_slow_i;
        r_sh1_jump  <= rename_jump_i;
        r_sh1_store <= rename_store_i;
        r_sh1_ldst  <= rename_load_i or rename_store_i;
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
      r_mux_fast  <= (others => '1');
      r_mux_slow  <= (others => '0');
      r_mux_jump  <= (others => '0');
      r_mux_store <= (others => '0');
      r_mux_ldst  <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_shift = '1' then   -- clock enable
        if r_shift = '1' then -- load enable
          r_mux_fast  <= rename_fast_i;
          r_mux_slow  <= rename_slow_i;
          r_mux_jump  <= rename_jump_i;
          r_mux_store <= rename_store_i;
          r_mux_ldst  <= rename_load_i or rename_store_i;
        else
          r_mux_fast  <= r_sh1_fast;
          r_mux_slow  <= r_sh1_slow;
          r_mux_jump  <= r_sh1_jump;
          r_mux_store <= r_sh1_store;
          r_mux_ldst  <= r_sh1_ldst;
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
          r_mux_stata <= rename_stata_i;
          r_mux_statb <= rename_statb_i;
        else
          r_mux_baka  <= r_sh1_baka;
          r_mux_bakb  <= r_sh1_bakb;
          r_mux_stata <= r_sh1_stata;
          r_mux_statb <= r_sh1_statb;
        end if;
      end if;
    end if;
  end process;
  
  stations_0r : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_shift  <= '0';
      r_schedule_fast <= (others => (others => '0'));
      r_schedule_slow <= (others => (others => '0'));
      r_schedule_fast_issue <= (others => '0');
    elsif rising_edge(clk_i) then
      r_shift  <= s_shift;
      r_schedule_fast <= s_schedule_fast and f_opa_dup_row(c_num_fast, s_pending_fast);
      r_schedule_slow <= s_schedule_slow and f_opa_dup_row(c_num_slow, s_pending_slow);
      r_schedule_fast_issue <= s_schedule_fast_issue and s_pending_fast;
    end if;
  end process;
  
  -- Register the stations, 0-latency with reset, with load enable
  stations_0rl : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_issued <= (others => '1');
      r_ready  <= (others => '1');
      r_final  <= (others => '1');
      r_kill   <= (others => '0');
      r_quash  <= (others => '0');
      r_commit <= (others => '1');
    elsif rising_edge(clk_i) then
      if s_shift = '1' then -- load enable port
        r_issued <= c_decoder_zeros & s_issued(c_num_stat-1 downto c_decoders);
        r_ready  <= c_decoder_zeros & s_ready (c_num_stat-1 downto c_decoders);
        r_final  <= c_decoder_zeros & s_final (c_num_stat-1 downto c_decoders);
        r_kill   <= c_decoder_zeros & s_kill  (c_num_stat-1 downto c_decoders);
        r_quash  <= c_decoder_zeros & s_quash (c_num_stat-1 downto c_decoders);
        r_commit <= c_decoder_zeros & s_commit(c_num_stat-1 downto c_decoders);
      else
        r_issued <= s_issued;
        r_ready  <= s_ready;
        r_final  <= s_final;
        r_kill   <= s_kill;
        r_quash  <= s_quash;
        r_commit <= s_commit;
      end if;
    end if;
  end process;
  
  -- Register the stations 0-latency without reset, with load enable
  stations_0l : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then -- load enable
        r_uncb <= r_mux_jump  & s_uncb(c_num_stat-1 downto c_decoders);
        r_uncs <= r_mux_store & s_uncs(c_num_stat-1 downto c_decoders);
        -- These two are sneaky; they are half lagged. Content lags thanks to s_stat[ab].
        for i in 0 to c_num_stat-c_decoders-1 loop
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
        r_uncb   <= s_uncb;
        r_uncs   <= s_uncs;
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
        r_ldst <= r_mux_ldst & r_ldst(c_num_stat-1 downto c_decoders);
      end if;
    end if;
  end process;
  
  stations_0rcl : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      for b in 0 to c_back_wide-1 loop
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
      end if;
    end if;
  end process;
  
  stations_0rc : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_fast <= (others => '0');
      r_slow <= (others => '0');
      for b in 0 to c_back_wide-1 loop
        for i in 0 to c_num_stat-1 loop
          r_bakx0(i,b) <= to_unsigned(c_num_arch+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if s_shift = '1' then
        r_fast <= r_mux_fast  & r_fast(c_num_stat-1 downto c_decoders);
        r_slow <= r_mux_slow  & r_slow(c_num_stat-1 downto c_decoders);
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
        for i in 0 to c_num_stat-c_decoders-1 loop
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
