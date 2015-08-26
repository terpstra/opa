library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_issue is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- Values the renamer provides us
    rename_stb_i   : in  std_logic;
    rename_stall_o : out std_logic;
    rename_fast_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_slow_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    rename_oldx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_baka_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakb_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_stata_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_statb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_oldx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Exceptions from the EUs
    eu_fault_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_pc_i        : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide  (g_config)-1 downto c_op_align);
    eu_pcf_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fetch_wide(g_config)-1 downto c_op_align);
    eu_pcn_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide  (g_config)-1 downto c_op_align);
     
    -- Regfile needs to fetch these for EU
    regfile_rstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_aux_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_aux_wide (g_config)-1 downto 0);
    regfile_dec_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_dec_wide(g_config)-1 downto 0);
    regfile_baka_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    regfile_bakb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Regfile should capture result from EU
    regfile_wstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_bakx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
end opa_issue;

architecture rtl of opa_issue is

  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_num_arch  : natural := f_opa_num_arch (g_config);
  constant c_num_fast  : natural := f_opa_num_fast (g_config);
  constant c_num_slow  : natural := f_opa_num_slow (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_aux_wide  : natural := f_opa_aux_wide (g_config);
  constant c_dec_wide  : natural := f_opa_dec_wide (g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders -1 downto 0) := (others => '0');
  constant c_stat_ones     : std_logic_vector(c_num_stat -1 downto 0) := (others => '1');

  -- Instructions have these flags:
  --   issued: was previously selected by arbitration and not stalled
  --   ready:  result is available (can issue dependants)    => issued
  --   final:  will not generate quash|kill                  => ready
  --   quash:  instruction needs to be reissued
  --   kill:   must reset the PC
  --
  -- Only final+!quash instructions are shifted out of the window.
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
  --   Stores are buffered until retired
  --   Quash clears ready. If final, it also clears: issued/final/kill.
  
  -- To keep r_schedule as easy to compute as possible, half of the reservation station
  -- is shifted early, and half is shifted late. r_schedule is late, as is anything fed
  -- to the regfile stage. Anything used to feed r_schedule is shifted early.
  
  -- These have 1 latency indexes
  signal r_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal r_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule      : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  
  signal s_schedule_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal r_schedule_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal s_schedule_slow_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal r_schedule_slow_issue : std_logic_vector(c_num_stat-1 downto 0);
  
  signal s_stall      : std_logic;
  signal s_shift      : std_logic;
  signal r_shift      : std_logic;
  
  -- These have 0 latency indexes (fed directly)
  signal r_fast       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_slow       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_bakx0      : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  -- These have 0 latency indexes, but 1 latency content
  signal s_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal s_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  -- These have 1 latency indexes (fed by skidpad)
  signal s_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_wait1      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_wait1      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_wait2      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_wait2      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_aux        : t_opa_matrix(c_num_stat-1 downto 0, c_aux_wide -1 downto 0);
  signal r_oldx       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakx1      : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_baka       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakb       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  
  type t_stat is array(c_num_stat-1 downto 0) of unsigned(c_stat_wide-1 downto 0);
  signal s_fast_need_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal s_slow_need_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_raw       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_shift     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_pad       : std_logic_vector(c_num_stat+c_decoders-1 downto 0);
  signal s_readya          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyb          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_fast    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_slow    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_fast      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_slow      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_stata_1         : t_stat;
  signal s_statb_1         : t_stat;
  signal s_stata_2         : t_stat;
  signal s_statb_2         : t_stat;
  
  -- Accept data from the renamer; use a skidpad to synchronize state
  signal r_sp_oldx : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_bakx : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_baka : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_bakb : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_aux  : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide -1 downto 0);
  
  signal s_new_stata  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_new_statb  : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal s_matchn_a   : t_opa_matrix(c_decoders-1 downto 0, c_num_stat -1 downto 0);
  signal s_matchn_b   : t_opa_matrix(c_decoders-1 downto 0, c_num_stat -1 downto 0);
  
  -- Scheduled writeback
  signal r_rf_wstb_fast1 : std_logic_vector(c_num_fast-1 downto 0);
  signal r_rf_wstb_slow1 : std_logic_vector(c_num_slow-1 downto 0);
  signal r_rf_wstb_slow2 : std_logic_vector(c_num_slow-1 downto 0);
  signal r_rf_wstb_slow3 : std_logic_vector(c_num_slow-1 downto 0);
  signal r_rf_bakx_fast1 : t_opa_matrix(c_num_fast-1 downto 0, c_back_wide-1 downto 0);
  signal r_rf_bakx_slow1 : t_opa_matrix(c_num_slow-1 downto 0, c_back_wide-1 downto 0);
  signal r_rf_bakx_slow2 : t_opa_matrix(c_num_slow-1 downto 0, c_back_wide-1 downto 0);
  signal r_rf_bakx_slow3 : t_opa_matrix(c_num_slow-1 downto 0, c_back_wide-1 downto 0);
  
  function f_pad(x : std_logic) return std_logic_vector is
    variable result : std_logic_vector(c_decoders-1 downto 0) := (others => '0');
  begin
    result(result'high) := x;
    return result;
  end f_pad;
  constant c_pad_high0 : std_logic_vector(c_decoders-1 downto 0) := f_pad('0');
  constant c_pad_high1 : std_logic_vector(c_decoders-1 downto 0) := f_pad('1');
  
  function f_decoder_labels(decoders : natural) return t_opa_matrix is
    variable result : t_opa_matrix(c_num_stat-1 downto 0, c_dec_wide-1 downto 0);
    variable value : unsigned(result'range(2));
  begin
    for s in result'range(1) loop
      value := to_unsigned(s mod c_decoders, value'length);
      for b in value'range loop
        result(s,b) := value(b);
      end loop;
    end loop;
    return result;
  end f_decoder_labels;
  constant c_decoder_labels : t_opa_matrix := f_decoder_labels(c_decoders);
  
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
  
  function f_shift(x : std_logic_vector; s : std_logic) return std_logic_vector is
    alias y : std_logic_vector(x'high downto x'low) is x;
    variable result : std_logic_vector(y'range) :=  y;
  begin
    if s = '1' then 
      result := c_decoder_zeros & y(y'high downto y'low+c_decoders);
    end if;
    return result;
  end f_shift;
  
begin

  -- Which stations are now issued?
  s_issued <= f_shift(r_schedule_fast_issue or r_schedule_slow_issue, r_shift) or r_issued;
  s_fast_need_issue <= not s_issued and r_fast;
  s_slow_need_issue <= not s_issued and r_slow;
    -- 1 level using extend lut mode (two 5 input functions, sharing 4 input, muxed)

  -- Which stations have ready operands?
  s_ready_pad <= c_pad_high1 & r_ready;
  s_readya <= f_opa_compose(s_ready_pad, r_stata);
  s_readyb <= f_opa_compose(s_ready_pad, r_statb);
     -- 2.5 levels with <= 32 stations
  
  -- Which stations are pending issue?
  s_pending_fast <= s_readya and s_readyb and s_fast_need_issue;
  s_pending_slow <= s_readya and s_readyb and s_slow_need_issue;
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
      total_o  => s_schedule_slow_issue);
   -- 6 levels for <= 28 num_stat
  
  s_ready_raw <= f_shift(r_wait1 or r_ready, r_shift);
  ready_shift : opa_lcell_vector generic map(g_wide => c_num_stat) port map(a_i => s_ready_raw, b_o => s_ready_shift);
  s_ready  <= (s_schedule_fast_issue and s_pending_fast) or s_ready_shift;
  
  s_wait1   <= f_shift(r_wait2, r_shift);
  s_wait2   <= s_schedule_slow_issue and s_pending_slow;
  
  -- Which registers does each EU need to use?
  -- r_bak[abx], r_aux shifted one cycle later, so s_stat has correct index
  s_schedule <= f_opa_transpose(f_opa_concat(f_opa_transpose(r_schedule_slow), f_opa_transpose(r_schedule_fast)));
  regfile_rstb_o <= f_opa_product(s_schedule, c_stat_ones);
  regfile_baka_o <= f_opa_product(s_schedule, r_baka);
  regfile_bakb_o <= f_opa_product(s_schedule, r_bakb);
  regfile_aux_o  <= f_opa_product(s_schedule, r_aux);
  regfile_dec_o  <= f_opa_product(s_schedule, c_decoder_labels);
    -- 2 levels with stations <= 18
  
  -- Report writeback to the regfile
  writeback : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rf_wstb_fast1 <= f_opa_product(r_schedule_fast, c_stat_ones);
      r_rf_wstb_slow1 <= f_opa_product(r_schedule_slow, c_stat_ones);
      r_rf_bakx_fast1 <= f_opa_product(r_schedule_fast, r_bakx1);
      r_rf_bakx_slow1 <= f_opa_product(r_schedule_slow, r_bakx1);
      r_rf_wstb_slow2 <= r_rf_wstb_slow1;
      r_rf_bakx_slow2 <= r_rf_bakx_slow1;
      r_rf_wstb_slow3 <= r_rf_wstb_slow2;
      r_rf_bakx_slow3 <= r_rf_bakx_slow2;
    end if;
  end process;
  
  regfile_wstb_o <= r_rf_wstb_slow3 & r_rf_wstb_fast1;
  regfile_bakx_o <= f_opa_transpose(f_opa_concat(f_opa_transpose(r_rf_bakx_slow3), f_opa_transpose(r_rf_bakx_fast1)));
  
  -- Determine if the execution window should be shifted
  s_final <= f_shift(r_final or r_ready, r_shift); -- !!! bogus; faults go here
  s_stall <= not f_opa_and(s_final(c_decoders-1 downto 0));
  s_shift <= rename_stb_i and not s_stall;
  rename_stall_o <= s_stall or not rst_n_i;
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
  
  -- !!! roll this into renamer cycle using an arch map
  -- Compare to the bakx in stations to find new station's 1hot dependency
  s_matchn_a  <= f_opa_match(rename_baka_i, r_bakx0);
  s_matchn_b  <= f_opa_match(rename_bakb_i, r_bakx0);
    -- 2 levels
  
  -- Decode to what the new station depends on
  s_new_stata <= f_opa_1hot_dec(s_matchn_a) or rename_stata_i;
  s_new_statb <= f_opa_1hot_dec(s_matchn_b) or rename_statb_i;
    -- 3 levels with <= 30 stations (5x3:1 decode of [(3=3) and (3=3)])
  
  -- Feed back unused registers to the renamer
  oldx : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      for b in 0 to c_back_wide-1 loop
        for i in 0 to c_decoders-1 loop
          rename_oldx_o(i,b) <= to_unsigned(c_num_arch+c_num_stat+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if s_shift = '1' then -- clock enable
        if r_shift = '1' then -- load enable
          for b in 0 to c_back_wide-1 loop
            for i in 0 to c_decoders-1 loop
              rename_oldx_o(i,b) <= r_oldx(i+c_decoders,b);
            end loop;
          end loop;
        else
          for b in 0 to c_back_wide-1 loop
            for i in 0 to c_decoders-1 loop
              rename_oldx_o(i,b) <= r_oldx(i,b);
            end loop;
          end loop;
        end if;
      end if;
    end if;
  end process;
  
  -- Register the inputs with reset, with clock enable
  skidpad : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then
        r_sp_oldx <= rename_oldx_i;
        r_sp_bakx <= rename_bakx_i;
        r_sp_baka <= rename_baka_i;
        r_sp_bakb <= rename_bakb_i;
        r_sp_aux  <= f_opa_dup_row(c_decoders, rename_aux_i);
      end if;
    end if;
  end process;
  
  -- Register the stations 0-latency without reset, with load enable
  stations_0l : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then -- load enable
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
        r_stata  <= s_stata;
        r_statb  <= s_statb;
      end if;
    end if;
  end process;
  
  stations_0rl : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_issued <= (others => '1');
    elsif rising_edge(clk_i) then
      if s_shift = '1' then -- load enable
        r_issued <= c_decoder_zeros & s_issued(c_num_stat-1 downto c_decoders);
      else
        r_issued <= s_issued;
      end if;
    end if;
  end process;

  -- Register the stations, 0-latency with reset, with clock enable
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
        r_fast <= rename_fast_i  & r_fast(c_num_stat-1 downto c_decoders);
        r_slow <= rename_slow_i  & r_slow(c_num_stat-1 downto c_decoders);
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx0(i,b) <= r_bakx0(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx0(i,b) <= rename_bakx_i(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset
  stations_1r : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_shift  <= '0';
      r_ready  <= (others => '1');
      r_wait1  <= (others => '0');
      r_wait2  <= (others => '0');
      r_final  <= (others => '1');
      r_schedule_fast <= (others => (others => '0'));
      r_schedule_slow <= (others => (others => '0'));
      r_schedule_fast_issue <= (others => '0');
      r_schedule_slow_issue <= (others => '0');
    elsif rising_edge(clk_i) then
      r_shift  <= s_shift;
      r_ready  <= s_ready;
      r_wait1  <= s_wait1;
      r_wait2  <= s_wait2;
      r_final  <= s_final;
      r_schedule_fast <= s_schedule_fast and f_opa_dup_row(c_num_fast, s_pending_fast);
      r_schedule_slow <= s_schedule_slow and f_opa_dup_row(c_num_slow, s_pending_slow);
      r_schedule_fast_issue <= s_schedule_fast_issue and s_pending_fast;
      r_schedule_slow_issue <= s_schedule_slow_issue and s_pending_slow;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset, with clock enable
  stations_1rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      for b in 0 to c_back_wide-1 loop
        for i in 0 to c_num_stat-1 loop
          r_oldx (i,b) <= to_unsigned(c_num_arch+i, c_back_wide)(b);
          r_bakx1(i,b) <= to_unsigned(c_num_arch+i, c_back_wide)(b);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_back_wide-1 loop
            r_oldx (i,b) <= r_oldx (i+c_decoders,b);
            r_bakx1(i,b) <= r_bakx1(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_oldx (i,b) <= r_sp_oldx(i-(c_num_stat-c_decoders),b);
            r_bakx1(i,b) <= r_sp_bakx(i-(c_num_stat-c_decoders),b);
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
          for b in 0 to c_aux_wide-1 loop
            r_aux(i,b)   <= r_aux  (i+c_decoders,b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b)  <= r_baka (i+c_decoders,b);
            r_bakb(i,b)  <= r_bakb (i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_aux_wide-1 loop
            r_aux  (i,b) <= r_sp_aux  (i-(c_num_stat-c_decoders),b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka (i,b) <= r_sp_baka (i-(c_num_stat-c_decoders),b);
            r_bakb (i,b) <= r_sp_bakb (i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
end rtl;
