library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;

package opa_components_pkg is
  -- Policy:    inputs always registered INSIDE core
  --            outputs always left unregistered
  -- Exception: top-level core registers its bus outputs
  
  component opa_dpram is
    generic(
      g_width : natural;
      g_size  : natural);
    port(
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      r_en_i   : in  std_logic;
      r_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
      r_data_o : out std_logic_vector(g_width-1 downto 0);
      w_en_i   : in  std_logic;
      w_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
      w_data_i : in  std_logic_vector(g_width-1 downto 0));
  end component;
  
  component opa_satadd_ks is
    generic(
      g_state : natural;  -- bits in the adder
      g_size  : natural); -- elements in the array
    port(
      states_i : in  t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0);
      states_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
  end component;

  component opa_satadd is
    generic(
      g_state : natural;  -- bits in the adder
      g_size  : natural); -- elements in the array
    port(
      bits_i : in  std_logic_vector(g_size-1 downto 0);
      sums_o : out t_opa_matrix(g_size-1 downto 0, g_state-1 downto 0));
  end component;
  
  component opa_satadd_tb is
    port(
      clk_i  : in std_logic;
      rstn_i : in  std_logic;
      good_o : out std_logic);
  end component;

  component opa_issue is
    generic(
      g_config       : t_opa_config);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      -- Values the renamer needs to provide us
      ren_stb_i      : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      ren_typ_i      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
      ren_stat_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      ren_regx_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); -- -1 on no-op
      ren_rega_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      ren_regb_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- EU should execute this next
      eu_next_regx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); -- -1 on no-op
      eu_next_rega_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      eu_next_regb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      -- EU is committed to completion in 2 cycles (after stb_o) [ latency1: connect regx_i=regx_o ]
      eu_done_regx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- The ports can be used by the register file to select sources
      -- Alternatively, the register file can operate solely using eu_next_reg[abx]_o
      reg_bypass_a_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      reg_bypass_b_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      reg_mux_a_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      reg_mux_b_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      
      -- Connections to/from the committer
      commit_mask_i  : in  std_logic_vector(2*g_config.num_stat-1 downto 0); -- must be a register
      commit_done_o  : out std_logic_vector(  g_config.num_stat-1 downto 0));
  end component;
  
  component opa_regfile is
    generic(
      g_config       : t_opa_config);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      -- Which registers to read for each EU
      iss_rega_i     : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      iss_regb_i     : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      -- Hints that can be used to implement multiported RAM
      iss_bypass_a_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      iss_bypass_b_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      iss_mux_a_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
      iss_mux_b_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);

      -- The resulting register data
      eu_data_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0);
      eu_datb_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0);
      -- The results to record
      eu_regx_i      : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      eu_datx_i      : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0)); 
  end component;
  
  component opa_ieu is
    generic(
      g_config   : t_opa_config);
    port(
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic;
      
      iss_regx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      iss_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      
      reg_data_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
      reg_datb_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
      reg_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      reg_datx_o : out std_logic_vector(2**g_config.log_width-1 downto 0));
  end component;

  component opa_mul is
    generic(
      g_config   : t_opa_config);
    port(
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic;
      
      iss_regx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      iss_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      
      reg_data_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
      reg_datb_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
      reg_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      reg_datx_o : out std_logic_vector(2**g_config.log_width-1 downto 0));
  end component;

  -- TODO (then can run it!):
  -- renamer (move optimization)
  -- commiter

  -- Then (for real programs):
  -- fetcher
  -- decoder (constants, op decode)
  -- MMU + cache miss core

end package;
