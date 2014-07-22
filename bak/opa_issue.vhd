library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

-- Two cycles pipeline depth (schedule and fetch)
entity opa_issue is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- Values the decoder needs to provide us
    dec_stb_i      : in  t_opa_map(1 to 2**g_config.log_decode);
    dec_typ_i      : in  t_opa_map(1 to 2**g_config.log_decode*c_log_types);
    dec_statx_i    : in  t_opa_map(1 to 2**g_config.log_decode*(g_config.log_stat-g_config.log_decode));
    dec_regx_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    dec_rega_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    dec_regb_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    
    -- EU should execute this next
    eu_next_regx_o : out t_opa_map(1 to g_config.num_units*g_config.log_back); -- -1 on no-op
    eu_next_rega_o : out t_opa_map(1 to g_config.num_units*g_config.log_back);
    eu_next_regb_o : out t_opa_map(1 to g_config.num_units*g_config.log_back);
    -- EU is committed to completion in 2 cycles (after stb_o) [ latency1: connect regx_i=regx_o ]
    eu_done_regx_i : in  t_opa_map(1 to g_config.num_units*g_config.log_back);
    
    -- Connections to/from the committer
    commit_mask_i  : in  t_opa_map(1 to 2*2**g_config.log_stat); -- must be a register
    commit_done_o  : out t_opa_map(1 to   2**g_config.log_stat));
end opa_issue;

architecture rtl of opa_issue is

  constant c_stat   : natural := 2**g_config.log_stat;
  constant c_back   : natural := 2**g_config.log_back;
  constant c_decode : natural := 2**g_config.log_decode;
  constant c_unit   : natural := g_config.num_units;
  
  constant c_log_units1 : natural := f_opa_log2(g_config.max_units+1);
  
  -- Backing register is ready?
  signal r_back_ready  : t_opa_map(1 to c_back);
  signal s_back_sets   : t_opa_map(1 to c_unit*c_back);
  signal s_back_set    : t_opa_map(1 to c_back);
  signal s_back_clears : t_opa_map(1 to c_decode*c_back);
  signal s_back_ready  : t_opa_map(1 to c_back);
  
  -- Reservation data structure
  signal r_res_rega   : t_opa_map(1 to c_stat*g_config.log_back);
  signal r_res_regb   : t_opa_map(1 to c_stat*g_config.log_back);
  signal r_res_regx   : t_opa_map(1 to c_stat*g_config.log_back);
  signal r_res_typ    : t_opa_map(1 to c_stat*c_log_types);
  signal r_res_readya : t_opa_map(1 to c_stat);
  signal r_res_readyb : t_opa_map(1 to c_stat);
  signal r_res_issued : t_opa_map(1 to c_stat);
  
  signal s_matcha   : t_opa_map(1 to c_unit*c_stat);
  signal s_matchb   : t_opa_map(1 to c_unit*c_stat);
  signal s_readya   : t_opa_map(1 to c_stat);
  signal s_readyb   : t_opa_map(1 to c_stat);
  signal s_pending  : t_opa_map(1 to c_types*2*c_stat);
  signal s_count    : t_opa_map(1 to c_types*2*c_stat*c_log_units1);
  signal s_schedule : t_opa_map(1 to c_unit*c_stat);
  signal s_regx     : t_opa_map(1 to c_stat*c_unit*g_config.log_back);
  signal s_rega     : t_opa_map(1 to c_stat*c_unit*g_config.log_back);
  signal s_regb     : t_opa_map(1 to c_stat*c_unit*g_config.log_back);
  
  -- Decision of what was executed last
  signal r_done_regx : t_opa_map(1 to c_unit*g_config.log_back); -- !!! force register duplication
  signal s_next_regx : t_opa_map(1 to c_unit*g_config.log_back);
  
begin

  -- Determine which registers are ready
  back_sets : for u in 1 to c_unit generate
    backs : for b in 1 to c_back generate
      s_back_sets(f_opa_index_matrix(u, b, c_unit, c_back)) <=
        '1' when f_opa_select_vector(u, c_unit, g_config.log_back, r_done_regx) = 
                 std_logic_vector(to_unsigned(b-1, g_config.log_back)) else '0';
    end generate;
  end generate;
  
  s_back_sets <= r_back_ready or f_opa_or_matrix(c_unit, c_back, s_back_sets);
  
  -- Determine which registers get cleared
  back_clears : for d in 1 to c_decode generate
    backs : for b in 1 to c_back generate
      s_back_clears(f_opa_index_matrix(d, b, c_decode, c_back)) <=  
        r_dec_stb when f_opa_select_vector(d, c_decode, g_config.log_back, r_dec_regx) =
                       std_logic_vector(to_unsigned(b-1, g_config.log_back)) else '0';
    end generate;
  end generate;
  
  s_back_ready <= s_back_sets and not f_opa_or_matrix(c_decode, c_back, s_back_clears);

  -- Accept input from the decoder; (statx<<log_decode)|i is index
  -- Don't bother with a pre-register stage; these ARE registers
  
  -- We need to be careful about a race condition !!!
  --  don't miss a cycle in checking ready status of back and finishing cycle => ready
  --  worry about two concurrent dependant ops
  stations : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '1' then
      r_back_ready <= (others => '1');
    elsif rising_edge(clk_i) then
      r_back_ready <= s_back_ready;
      
    end if;
  end process;
  
  r_res_rega
  r_res_regb
  r_res_regx
  r_res_typ
  r_dec_regx
  r_dec_stb
  
  -- Determine which reservation stations are ready
  match_stations: for u in 1 to c_unit generate
    stations : for r in 1 to c_stat generate
      s_matcha(f_opa_index_matrix(u, r, c_unit, c_stat)) <=
        '1' when f_opa_select_vector(u, c_unit, g_config.log_back, r_done_regx) =
                 f_opa_select_vector(r, c_stat, g_config.log_back, r_res_rega) else '0';
      s_matchb(f_opa_index_matrix(u, r, c_unit, c_stat)) <=
        '1' when f_opa_select_vector(u, c_unit, g_config.log_back, r_done_regx) =
                 f_opa_select_vector(r, c_stat, g_config.log_back, r_res_regb) else '0';
    end generate;
  end generate;
  
  s_readya <= r_readya or f_opa_or_matrix(c_unit, c_stat, s_matcha);
  s_readyb <= r_readyb or f_opa_or_matrix(c_unit, c_stat, s_matchb);
    
  -- Count, by EU-type, how may ops are pending
  types : for t in 1 to c_types generate
    stations: for r in 1 to c_stat generate
      s_pending(f_opa_index_matrix(r, t, 2*c_stat, c_types)) <=
        s_readya(r) and s_readyb(r) and not r_res_issued(r) and commit_mask_i(r) and
        f_opa_select_vector(r, c_stat, c_log_types, r_res_typ) =
          std_logic_vector(to_unsigned(t-1, c_log_types));
      s_pending(f_opa_index_matrix(c_stat+r, t, 2*c_stat, c_types)) <=
        s_readya(r) and s_readyb(r) and not r_res_issued(r) and commit_mask_i(c_stat+r) and
        f_opa_select_vector(r, c_stat, c_log_types, r_res_typ) =
          std_logic_vector(to_unsigned(t-1, c_log_types));
    end generate;
    
    satadd : opa_satadd
      generic map(
        g_state => c_log_units1,
        g_width => c_stat*2)
      port map(
        state_i => f_opa_cube_select(s_pending),
        state_o => f_opa_cube_select(s_count));
  end generate;
  
  -- For each unit, decide if it is for us.
  schedule_ieu : for u in 1 to g_config.num_ieu generate
    stat : for r in 1 to c_stat generate
      s_schedule(u,r) <= (s_count() = 1 and s_count() = 0) OR
                         (s_count() = 1 and s_count() = 0);
    end generate;
  end generate;
  
  -- One-hot select registers (using negative logic)
  regs : for u in 1 to c_unit generate
    stat : for r in 1 to c_stat generate
      bits : for b in 1 to g_config.log_back generate
        s_regx(f_opa_cube_index(r, u, b, c_stat, c_unit, g_config.log_back)) <=
          (s_schedule(f_opa_matrix_index(u, r, c_unit, c_stat)) and
           not r_res_regx(f_opa_matrix_index(r, b, c_stat, g_config.log_back)));
        s_rega(f_opa_cube_index(r, u, b, c_stat, c_unit, g_config.log_back)) <=
          (s_schedule(f_opa_matrix_index(u, r, c_unit, c_stat)) and
           not r_res_rega(f_opa_matrix_index(r, b, c_stat, g_config.log_back)));
        s_regb(f_opa_cube_index(r, u, b, c_stat, c_unit, g_config.log_back)) <=
          (s_schedule(f_opa_matrix_index(u, r, c_unit, c_stat)) and
           not r_res_regb(f_opa_matrix_index(r, b, c_stat, g_config.log_back)));
    end generate;
  end generate;
  
  -- Fan-in the decoded reservation stations (-1 if none selected)
  eu_next_regx_o <= not f_opa_or_cube(s_regx, c_stat, c_unit, g_config.log_back);
  eu_next_rega_o <= not f_opa_or_cube(s_rega, c_stat, c_unit, g_config.log_back);
  eu_next_regb_o <= not f_opa_or_cube(s_regb, c_stat, c_unit, g_config.log_back);
  
  -- Record what to do next
  step : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      r_done_regx <= eu_done_regx_i;
    end if;
  end process;
  
end rtl;
