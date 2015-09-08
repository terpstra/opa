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
    rename_geta_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    rename_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_baka_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakb_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_stata_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_statb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    rename_bakx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Exceptions from the EUs
    eu_commit_i    : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_reissue_i   : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_fault_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_pc_i        : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide  (g_config)-1 downto c_op_align);
    eu_pcf_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fetch_wide(g_config)-1 downto c_op_align);
    eu_pcn_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide  (g_config)-1 downto c_op_align);
     
    -- Selected fault fed back up pipeline
    rename_fault_o : out std_logic;
    rename_mask_o  : out std_logic_vector(f_opa_decoders  (g_config)-1 downto 0);
    rename_pc_o    : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    rename_pcf_o   : out std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    rename_pcn_o   : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    
    -- Regfile needs to fetch these for EU
    regfile_rstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_geta_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_getb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
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
  constant c_adr_wide  : natural := f_opa_adr_wide (g_config);
  constant c_fetch_wide: natural := f_opa_fetch_wide(g_config);
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders -1 downto 0) := (others => '0');
  constant c_stat_ones     : std_logic_vector(c_num_stat -1 downto 0) := (others => '1');
  constant c_fast_zeros    : std_logic_vector(c_num_fast -1 downto 0) := (others => '0');
  constant c_slow_ones     : std_logic_vector(c_num_slow -1 downto 0) := (others => '1');
  constant c_slow_only     : std_logic_vector(c_executers-1 downto 0) := c_slow_ones & c_fast_zeros;
  
  constant c_init_bak : t_opa_matrix := f_opa_labels(c_num_stat, c_back_wide, c_num_arch);

  -- Instructions have these flags:
  --   issued: already sent to the execution units
  --   ready:  result will be available for dependants    => issued
  --   final:  will not generate miss/fault               => ready
  --
  -- Only final instructions are shifted out of the window
  -- A non-final instruction can remove issue/ready/final from any later instruction.
  --
  -- OPA makes heavy use of speculative execution; instructions run opportunistically.
  -- Thus, it can make these kinds of mistakes:
  --   A non-final branch can report fault                  (misprediction)
  --   A non-final ld/st  can report fault                  (page fault)
  --   A non-final load   can report reissue                (cache miss)
  --   A non-final store  can reissue following loads       (speculative read)
  -- 
  -- To maintain program-order, enforce these rules:
  --   To issue an instruction, all operands must be ready
  --   Non-ready dependencies clear issued+ready+final
  --   Stores are finalized in order
  
  -- To keep r_schedule0 as easy to compute as possible, half of the reservation station
  -- is shifted early, and half is shifted late. r_schedule0 is late, as is anything fed
  -- to the regfile stage. Anything used to feed r_schedule0 is shifted early.
  
  -- These have 1 latency indexes
  signal s_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal r_schedule0     : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule1s    : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule2     : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule3     : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule4s    : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal s_schedule_wb   : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  
  signal s_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal r_fast_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal s_slow_issue : std_logic_vector(c_num_stat-1 downto 0);
  signal r_slow_issue : std_logic_vector(c_num_stat-1 downto 0);
  
  -- These have 0 latency indexes (fed directly)
  signal r_fast       : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal r_slow       : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal s_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_new_issued : std_logic_vector(c_num_stat-1 downto 0);
  signal r_issued     : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  signal s_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_new_final  : std_logic_vector(c_num_stat-1 downto 0);
  signal r_final      : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  -- These have 0 latency indexes, but 1 latency content
  signal s_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0) := (others => (others => '1'));
  signal s_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0) := (others => (others => '1'));
  -- These have 1 latency indexes (fed by skidpad)
  signal s_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_ready      : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  signal r_geta       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_getb       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_aux        : t_opa_matrix(c_num_stat-1 downto 0, c_aux_wide -1 downto 0);
  signal r_bakx       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0) := c_init_bak;
  signal r_baka       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakb       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  
  signal s_was_ready       : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_pad       : std_logic_vector(2**c_stat_wide-1 downto 0) := (others => '0');
  signal s_readya          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyb          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyab         : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_fast    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_slow    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_reissue         : std_logic_vector(c_num_stat-1 downto 0);
  
  -- Accept data from the renamer; use a skidpad to synchronize state
  signal r_sp_geta : std_logic_vector(c_decoders-1 downto 0);
  signal r_sp_getb : std_logic_vector(c_decoders-1 downto 0);
  signal r_sp_bakx : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_baka : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_bakb : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_aux  : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide -1 downto 0);
  
  -- Faults inhibit commit and shift
  signal r_reissue       : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal r_commit        : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_stall         : std_logic;
  signal s_shift         : std_logic;
  signal r_shift         : std_logic := '0';
  
  -- Faults are resolved to the oldest and executed when all preceding ops are final
  signal r_fault_in      : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_all_faults    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_oldest_fault  : std_logic_vector(c_num_stat-1 downto 0);
  signal r_oldest_fault  : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal s_fault_victor  : std_logic_vector(c_executers-1 downto 0);
  signal r_fault_victor  : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_fault_same    : std_logic;
  signal r_fault_same    : std_logic := '0';
  signal s_fault_same_pc : std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal s_fault_same_pcf: std_logic_vector(c_fetch_wide-1 downto c_op_align);
  signal s_fault_same_pcn: std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal r_fault_pc0     : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1   downto c_op_align);
  signal r_fault_pcf0    : t_opa_matrix(c_executers-1 downto 0, c_fetch_wide-1 downto c_op_align);
  signal r_fault_pcn0    : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1   downto c_op_align);
  signal r_fault_pc1     : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1   downto c_op_align);
  signal r_fault_pcf1    : t_opa_matrix(c_executers-1 downto 0, c_fetch_wide-1 downto c_op_align);
  signal r_fault_pcn1    : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1   downto c_op_align);
  signal r_fault_pc      : std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal s_fault_pc      : std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal r_fault_pcf     : std_logic_vector(c_fetch_wide-1 downto c_op_align);
  signal s_fault_pcf     : std_logic_vector(c_fetch_wide-1 downto c_op_align);
  signal r_fault_pcn     : std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal s_fault_pcn     : std_logic_vector(c_adr_wide  -1 downto c_op_align);
  signal s_fault_tail    : std_logic_vector(c_decoders-1 downto 0);
  signal s_fault_deps    : std_logic_vector(c_decoders-1 downto 0);
  signal s_fault_out     : std_logic;
  signal r_fault_out     : std_logic := '0';
  signal r_fault_mask    : std_logic_vector(c_decoders-1 downto 0) := (others => '1');
  signal r_wipe_pipe     : std_logic := '0'; -- lasts two cycles
  
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
  
  function f_shift(x : std_logic_vector; s : std_logic) return std_logic_vector is
    alias y : std_logic_vector(x'high downto x'low) is x;
    variable result : std_logic_vector(y'range) :=  y;
  begin
    if s = '1' then 
      result := c_decoder_zeros & y(y'high downto y'low+c_decoders);
    end if;
    return result;
  end f_shift;
  
  function f_shift(x : t_opa_matrix; s : std_logic) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2)) := x;
  begin
    if s = '1' then
      result := (others => (others => '0'));
      for i in x'range(1) loop
        for j in x'high(2)-c_decoders downto x'low(2) loop
          result(i,j) := x(i,j+c_decoders);
        end loop;
      end loop;
    end if;
    return result;
  end f_shift;
  
begin

  -- Which stations are now issued?
  s_issued <= f_shift(r_fast_issue or r_slow_issue, r_shift) or r_issued;

  -- Which stations have ready operands?
  -- !!! use a sparse version of s_ready_pad to save half the muxes
  s_ready_pad(s_ready_pad'high) <= '1';
  s_ready_pad(r_ready'range) <= r_ready;
  s_readya <= f_opa_compose(s_ready_pad, r_stata);
  s_readyb <= f_opa_compose(s_ready_pad, r_statb);
  
  -- Which stations are pending issue?
  s_readyab <= s_readya and s_readyb; -- 3 levels (for stat_wide <= 5)
  s_pending_fast <= s_readyab and not s_issued and r_fast;
  s_pending_slow <= s_readyab and not s_issued and r_slow;
  
  -- We need to reissue anything the failed in EU or had a failed dependant.
  s_reissue    <= f_opa_product(f_opa_transpose(r_schedule4s), r_reissue);
  s_new_issued <= s_issued and not s_reissue and s_readyab;
  
  fast : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_fast)
    port map(
      bits_i   => s_pending_fast,
      count_o  => s_schedule_fast,
      total_o  => s_fast_issue);
  
  slow : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_slow)
    port map(
      bits_i   => s_pending_slow,
      count_o  => s_schedule_slow,
      total_o  => s_slow_issue);
   -- 6 levels for <= 28 num_stat
  
  s_was_ready <= s_readyab and not s_reissue and
    (f_opa_product(f_opa_transpose(r_schedule1s), c_slow_only) 
     or f_shift(r_ready, r_shift));
  s_ready <= (s_fast_issue and s_pending_fast) or s_was_ready;
  
  -- Which registers does each EU need to use?
  -- r_bak[abx], r_aux shifted one cycle later, so s_stat has correct index
  regfile_rstb_o <= f_opa_product(r_schedule0, c_stat_ones);
  regfile_geta_o <= f_opa_product(r_schedule0, r_geta);
  regfile_getb_o <= f_opa_product(r_schedule0, r_getb);
  regfile_baka_o <= f_opa_product(r_schedule0, r_baka);
  regfile_bakb_o <= f_opa_product(r_schedule0, r_bakb);
  regfile_aux_o  <= f_opa_product(r_schedule0, r_aux);
  regfile_dec_o  <= f_opa_product(r_schedule0, c_decoder_labels);
    -- 2 levels with stations <= 18
  
  wb_stat : for j in 0 to c_num_stat-1 generate
    fast : for i in 0 to c_num_fast-1 generate
      s_schedule_wb(i,j) <= r_schedule0(i,j);
    end generate;
    slow : for i in c_num_fast to c_executers-1 generate
      s_schedule_wb(i,j) <= r_schedule2(i,j);
    end generate;
  end generate;
  
  -- Report writeback to the regfile
  writeback : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      regfile_wstb_o <= f_opa_product(s_schedule_wb, c_stat_ones);
      regfile_bakx_o <= f_opa_product(s_schedule_wb, r_bakx);
    end if;
  end process;
  
  -- Determine if the execution window should be shifted
  s_final  <= r_final or f_opa_product(f_opa_transpose(r_schedule4s), r_commit);
  s_stall  <= not f_opa_and(s_final(c_decoders-1 downto 0));
  s_shift  <= (rename_stb_i and not s_stall) or r_fault_out;
  rename_stall_o <= s_stall;
    
  -- We can get away with r_ready instead of s_readyab, because all reissues
  -- start with a load, which will stop everything older than it shifting out
  -- for long enough that the 1-cycle propogation of 0s in r_ready is faster.
  s_new_final <= s_final and f_shift(r_ready, r_shift);
  
  -- Resolve faults to determine which fault wins
  s_all_faults    <= f_opa_product(f_opa_transpose(r_schedule4s), r_fault_in) or r_oldest_fault;
  s_oldest_fault  <= s_all_faults and std_logic_vector(0-unsigned(s_all_faults));
  s_fault_victor  <= f_opa_product(r_schedule4s, s_oldest_fault);
  s_fault_same    <= f_opa_or(r_oldest_fault and s_oldest_fault);
  
  -- Select fault addresses
  s_fault_same_pc  <= (others => r_fault_same);
  s_fault_same_pcf <= (others => r_fault_same);
  s_fault_same_pcn <= (others => r_fault_same);
  s_fault_pc  <= f_opa_product(f_opa_transpose(r_fault_pc1),  r_fault_victor) or (r_fault_pc  and s_fault_same_pc);
  s_fault_pcf <= f_opa_product(f_opa_transpose(r_fault_pcf1), r_fault_victor) or (r_fault_pcf and s_fault_same_pcf);
  s_fault_pcn <= f_opa_product(f_opa_transpose(r_fault_pcn1), r_fault_victor) or (r_fault_pcn and s_fault_same_pcn);
  
  -- Fault out if in last position and all prior ops are r_final
  s_fault_tail <= r_oldest_fault(c_decoders-1 downto 0);
  s_fault_deps <= std_logic_vector(unsigned(s_fault_tail) - 1);
  s_fault_out <= f_opa_and(s_final(c_decoders-1 downto 0) or not s_fault_deps) and f_opa_or(s_fault_tail);
  
  -- !!! currently we have to wait until the op reaches the oldest position
  -- ... this can take quite some time if the fetch is slow. if we alreday know
  -- there is a fault, why not just advance the pipeline quickly? fill with garbage
  
  -- Forward the fault up the pipeline
  rename_fault_o <= r_fault_out;
  rename_mask_o  <= r_fault_mask;
  rename_pc_o    <= r_fault_pc;
  rename_pcf_o   <= r_fault_pcf;
  rename_pcn_o   <= r_fault_pcn;
  -- May only fault on a shift
  
  fault_ctl : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_fault_in     <= (others => '0');
      r_fault_out    <= '0';
      r_fault_mask   <= (others => '1');
      r_oldest_fault <= (others => '0');
      r_fault_victor <= (others => '0');
      r_fault_same   <= '0';
      r_wipe_pipe    <= '0';
    elsif rising_edge(clk_i) then
      if r_fault_out = '1' then
        r_fault_in     <= (others => '0');
        r_fault_out    <= '0';
        r_fault_mask   <= (others => '1');
        r_oldest_fault <= (others => '0');
      else
        r_fault_in     <= eu_fault_i;
        r_fault_out    <= s_fault_out;
        r_fault_mask   <= s_fault_deps or s_fault_tail;
        r_oldest_fault <= f_shift(s_oldest_fault, s_shift);
      end if;
      if r_fault_out = '0' then
        r_wipe_pipe <= '0';
      else
        r_wipe_pipe <= s_fault_out;
      end if;
      r_fault_victor  <= s_fault_victor;
      r_fault_same    <= s_fault_same;
    end if;
  end process;
  
  fault_adr : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_fault_pc0  <= eu_pc_i;
      r_fault_pcf0 <= eu_pcf_i;
      r_fault_pcn0 <= eu_pcn_i;
      r_fault_pc1  <= r_fault_pc0;
      r_fault_pcf1 <= r_fault_pcf0;
      r_fault_pcn1 <= r_fault_pcn0;
      r_fault_pc   <= s_fault_pc;
      r_fault_pcf  <= s_fault_pcf;
      r_fault_pcn  <= s_fault_pcn;
    end if;
  end process;
  
  -- Prepare decremented versions of the station references
  s_stata <= f_opa_decrement(r_stata, c_decoders) when r_shift='1' else r_stata;
  s_statb <= f_opa_decrement(r_statb, c_decoders) when r_shift='1' else r_statb;
  
  -- Feed back unused registers back to the renamer
  bakx_o : for b in 0 to c_back_wide-1 generate
    dec : for i in 0 to c_decoders-1 generate
      rename_bakx_o(i,b) <= r_bakx(i+c_decoders,b) when r_shift='1' else r_bakx(i,b);
    end generate;
  end generate;
  
  -- Register the inputs with reset, with clock enable
  skidpad : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then
        r_sp_geta <= rename_geta_i;
        r_sp_getb <= rename_getb_i;
        r_sp_bakx <= rename_bakx_i;
        r_sp_baka <= rename_baka_i;
        r_sp_bakb <= rename_bakb_i;
        r_sp_aux  <= f_opa_dup_row(c_decoders, rename_aux_i);
      end if;
    end if;
  end process;
  
  -- Register the stations 0-latency with reset, with load enable
  stations_0rs : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then -- asynchronous clear
      r_issued <= (others => '1');
      r_final  <= (others => '1');
    elsif rising_edge(clk_i) then
      if r_wipe_pipe = '1' then -- synchronous clear
        r_issued <= (others => '1');
        r_final  <= (others => '1');
      else
        r_issued <= f_shift(s_new_issued, s_shift);
        r_final  <= f_shift(s_new_final,  s_shift);
      end if;
    end if;
  end process;
  
  stations_0rl : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then -- asynchronous clear
      r_stata  <= (others => (others => '1'));
      r_statb  <= (others => (others => '1'));
    elsif rising_edge(clk_i) then
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
            r_stata(i,b) <= rename_stata_i(i-(c_num_stat-c_decoders),b);
            r_statb(i,b) <= rename_statb_i(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      else
        r_stata <= s_stata;
        r_statb <= s_statb;
      end if;
    end if;
  end process;

  -- Register the stations, 0-latency with reset, with clock enable
  stations_0rc : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_fast <= (others => '0');
      r_slow <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_shift = '1' then
        r_fast <= rename_fast_i & r_fast(c_num_stat-1 downto c_decoders);
        r_slow <= rename_slow_i & r_slow(c_num_stat-1 downto c_decoders);
      end if;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset
  stations_1rs : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_commit  <= (others => '0');
      r_reissue <= (others => '0');
      r_ready      <= (others => '1');
      r_schedule0  <= (others => (others => '0'));
      r_schedule1s <= (others => (others => '0'));
      r_schedule2  <= (others => (others => '0'));
      r_schedule3  <= (others => (others => '0'));
      r_schedule4s <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      if r_wipe_pipe = '1' then
        r_commit  <= (others => '0');
        r_reissue <= (others => '0');
        r_ready      <= (others => '1');
        r_schedule0  <= (others => (others => '0'));
        r_schedule1s <= (others => (others => '0'));
        r_schedule2  <= (others => (others => '0'));
        r_schedule3  <= (others => (others => '0'));
        r_schedule4s <= (others => (others => '0'));
      else
        r_commit  <= eu_commit_i;
        r_reissue <= eu_reissue_i;
        r_ready      <= s_ready;
        r_schedule0  <= f_opa_transpose(f_opa_concat(
          f_opa_transpose(s_schedule_slow and f_opa_dup_row(c_num_slow, s_pending_slow)), 
          f_opa_transpose(s_schedule_fast and f_opa_dup_row(c_num_fast, s_pending_fast))));
        r_schedule1s <= f_shift(f_shift(r_schedule0, r_shift), s_shift);
        r_schedule2  <= r_schedule1s;
        r_schedule3  <= f_shift(r_schedule2, r_shift);
        r_schedule4s <= f_shift(f_shift(r_schedule3, r_shift), s_shift);
      end if;
    end if;
  end process;
  
  stations_1r : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_shift <= '0';
    elsif rising_edge(clk_i) then
      r_shift <= s_shift;
    end if;
  end process;
  
  -- Registers the stations, 1-latency without reset
  stations_1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_fast_issue <= s_fast_issue and s_pending_fast;
      r_slow_issue <= s_slow_issue and s_pending_slow;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset, with clock enable
  stations_1rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_bakx <= c_init_bak;
    elsif rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        for i in 0 to c_num_stat-c_decoders-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx(i,b) <= r_bakx(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx(i,b) <= r_sp_bakx(i-(c_num_stat-c_decoders),b);
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
          r_geta(i) <= r_geta(i+c_decoders);
          r_getb(i) <= r_getb(i+c_decoders);
          for b in 0 to c_aux_wide-1 loop
            r_aux (i,b) <= r_aux (i+c_decoders,b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b) <= r_baka(i+c_decoders,b);
            r_bakb(i,b) <= r_bakb(i+c_decoders,b);
          end loop;
        end loop;
        for i in c_num_stat-c_decoders to c_num_stat-1 loop
          r_geta(i) <= r_sp_geta(i-(c_num_stat-c_decoders));
          r_getb(i) <= r_sp_getb(i-(c_num_stat-c_decoders));
          for b in 0 to c_aux_wide-1 loop
            r_aux (i,b) <= r_sp_aux (i-(c_num_stat-c_decoders),b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b) <= r_sp_baka(i-(c_num_stat-c_decoders),b);
            r_bakb(i,b) <= r_sp_bakb(i-(c_num_stat-c_decoders),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
end rtl;
