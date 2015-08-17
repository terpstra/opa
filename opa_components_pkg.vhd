library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;

package opa_components_pkg is

  component opa_dpram is
    generic(
      g_width  : natural;
      g_size   : natural;
      g_bypass : boolean;
      g_regout : boolean);
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
  
  -- Inhibit optimization between these points
  component opa_lcell is
    port(
      a_i : in  std_logic;
      b_o : out std_logic);
  end component;
  component opa_lcell_vector is
    generic(
      g_wide : natural);
    port(
      a_i : in  std_logic_vector(g_wide-1 downto 0);
      b_o : out std_logic_vector(g_wide-1 downto 0));
  end component;
  component opa_lcell_matrix is
    generic(
      g_rows : natural;
      g_cols : natural);
    port(
      a_i : in  t_opa_matrix(g_rows-1 downto 0, g_cols-1 downto 0);
      b_o : out t_opa_matrix(g_rows-1 downto 0, g_cols-1 downto 0));
  end component;
  
  component opa_prim_ternary is
    generic(
      g_wide   : natural);
    port(
      a_i      : in  unsigned(g_wide-1 downto 0);
      b_i      : in  unsigned(g_wide-1 downto 0);
      c_i      : in  unsigned(g_wide-1 downto 0);
      x_o      : out unsigned(g_wide-1 downto 0));
  end component;
  
  component opa_prim_mul is
    generic(
      g_wide   : natural;
      g_regout : boolean;
      g_regwal : boolean;
      g_target : t_opa_target);
    port(
      clk_i    : in  std_logic;
      a_i      : in  std_logic_vector(  g_wide-1 downto 0);
      b_i      : in  std_logic_vector(  g_wide-1 downto 0);
      x_o      : out std_logic_vector(2*g_wide-1 downto 0));
  end component;
  
  component opa_prefixsum is
    generic(
      g_target  : t_opa_target;
      g_width   : natural;
      g_count   : natural);
    port(
      bits_i    : in  std_logic_vector(g_width-1 downto 0);
      count_o   : out t_opa_matrix(g_count-1 downto 0, g_width-1 downto 0);
      total_o   : out std_logic_vector(g_width-1 downto 0));
  end component;
  
  component opa_decode is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;

      fetch_dat_i    : in  std_logic_vector(f_opa_decoders(g_config)*c_op_wide-1 downto 0);
      rename_fast_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      rename_slow_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      rename_setx_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      rename_geta_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      rename_getb_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      rename_aux_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1        downto 0);
      rename_archx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
      rename_archa_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
      rename_archb_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
  end component;
  
  component opa_rename is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      -- Values the decoder needs to provide us
      decode_fast_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      decode_slow_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      decode_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      decode_geta_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      decode_getb_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      decode_aux_i   : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
      decode_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      decode_archa_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      decode_archb_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      
      -- What does the commiter have to say?
      commit_kill_i  : in  std_logic;
      commit_map_i   : in  t_opa_matrix(f_opa_num_arch(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      commit_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);

      -- Values we provide to the issuer
      issue_shift_i  : in  std_logic;
      issue_fast_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      issue_slow_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      issue_setx_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      issue_aux_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1                downto 0);
      issue_archx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      issue_bakx_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_baka_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_bakb_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_stata_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
      issue_statb_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0));
  end component;

  component opa_issue is
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
      eu_final_i     : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      eu_quash_i     : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      eu_kill_i      : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      
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
  end component;
  
  component opa_commit is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      
      -- Instructions to commit from the issue stage
      issue_shift_i : in  std_logic;
      issue_kill_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      issue_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
      issue_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
      issue_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      
      -- Let the renamer see our map for rollback and tell it when commiting
      rename_kill_o : out std_logic;
      rename_map_o  : out t_opa_matrix(f_opa_num_arch(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      rename_bakx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
  end component;
  
  component opa_regfile is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i        : in  std_logic;
      rst_n_i      : in  std_logic;
      
      -- Which registers to read for each EU
      issue_stb_i  : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      issue_bakx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_baka_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_bakb_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      issue_aux_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);

      -- The resulting register data
      eu_stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_rega_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
      eu_regb_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
      eu_bakx_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      eu_aux_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);
      
      -- The results to record; bakx must arrive 1-cycle before regx
      eu_stb_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
      eu_bakx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
      eu_regx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0));
  end component;
  
  component opa_fast is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      issue_shift_i  : in  std_logic;
      issue_stat_i   : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_final_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_kill_o   : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      
      regfile_stb_i  : in  std_logic;
      regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      regfile_bakx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      regfile_aux_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
      
      regfile_stb_o  : out std_logic;
      regfile_bakx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0));
  end component;

  component opa_slow is
    generic(
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
      
      issue_shift_i  : in  std_logic;
      issue_stat_i   : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_ready_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_final_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_quash_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_kill_o   : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
      issue_stall_o  : out std_logic;
      
      regfile_stb_i  : in  std_logic;
      regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      regfile_bakx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      regfile_aux_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
      
      l1d_stb_o      : out std_logic;
      l1d_sext_o     : out std_logic;
      l1d_size_o     : out std_logic_vector(1 downto 0); -- quad,word,nibble,byte
      l1d_adr_o      : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      l1d_dat_i      : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
      
      regfile_stb_o  : out std_logic;
      regfile_bakx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
      regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0));
  end component;

  component opa_core_tb is
    port(
      clk_i  : in std_logic;
      rstn_i : in std_logic;
      good_o : out std_logic);
  end component;
  
end package;
