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
    dec_typ_i      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_log_types-1               downto 0);
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

  signal r_dec_stb       : std_logic_vector(c_decoders-1 downto 0);
  signal r_dec_typ       : t_opa_matrix(c_decoders -1 downto 0, c_log_types-1 downto 0);
  signal r_dec_stat      : t_opa_matrix(c_decoders -1 downto 0, c_stat_wide-1 downto 0);
  signal r_dec_regx      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_dec_rega      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_dec_regb      : t_opa_matrix(c_decoders -1 downto 0, c_back_wide-1 downto 0);
  signal r_done_regx     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal s_dec_done_a    : std_logic_vector(c_decoders-1 downto 0);
  signal s_dec_done_b    : std_logic_vector(c_decoders-1 downto 0);
  
  signal r_back_ready    : std_logic_vector(c_back_num-1 downto 0);
  signal s_back_now_done : std_logic_vector(c_back_num-1 downto 0);
  signal s_back_cleared  : std_logic_vector(c_back_num-1 downto 0);
  
  signal r_stat_issued   : std_logic_vector(c_stations-1 downto 0);
  signal r_stat_readya   : std_logic_vector(c_stations-1 downto 0);
  signal r_stat_readyb   : std_logic_vector(c_stations-1 downto 0);
  signal r_stat_typ      : t_opa_matrix(c_stations -1 downto 0, c_log_types-1 downto 0);
  signal r_stat_rega     : t_opa_matrix(c_stations -1 downto 0, c_back_wide-1 downto 0);
  signal r_stat_regb     : t_opa_matrix(c_stations -1 downto 0, c_back_wide-1 downto 0);
  signal r_stat_regx     : t_opa_matrix(c_stations -1 downto 0, c_back_wide-1 downto 0);
  signal s_stat_readya   : std_logic_vector(c_stations-1 downto 0);
  signal s_stat_readyb   : std_logic_vector(c_stations-1 downto 0);
  
begin

  -- Edge 1: register decoded instructions and just-finished registers
  edge1 : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      r_dec_stb  <= dec_stb_i;
      r_dec_typ  <= dec_typ_i;
      r_dec_stat <= dec_stat_i;
      r_dec_regx <= dec_regx_i;
      r_dec_rega <= dec_rega_i;
      r_dec_regb <= dec_regb_i;
      r_done_regx <= eu_done_regx_i; -- fans out like crazy -- duplicate it!!!
    end if;
  end process;
  
  -- Calculate what the just-completed registers affect (fan-out = W+B ... fuck!)
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
  edge2 : process(clk_i, rst_n_i) is
    variable index : integer;
  begin
    if rising_edge(clk_i) then
      r_back_ready  <= (s_back_now_done or r_back_ready) and not s_back_cleared;
      r_stat_readya <= s_stat_readya;
      r_stat_readyb <= s_stat_readyb;
      
      -- !!! issued
      
      -- Each station has only one decoder source
      for i in 0 to c_decoders-1 loop
        index := to_integer(unsigned(f_opa_select(i, r_dec_stat)))*c_decoders + i;
        
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
  
  -- Calculate instruction to execute
  -- This may be concurrent 
  
end rtl;
