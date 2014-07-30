library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;

    -- Incoming data
    stb_i          : in  std_logic;
    stall_o        : out std_logic;
    data_i         : in  std_logic_vector(f_opa_decoders(g_config)*16-1 downto 0));
end opa;

architecture rtl of opa is

  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_back_num  : natural := f_opa_back_num (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  
  signal s_mispredict           : std_logic;
  signal fifo_commit_bakx       : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal fifo_commit_setx       : std_logic_vector(c_decoders-1 downto 0);
  signal fifo_commit_regx       : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal fifo_rename_bakx       : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal decode_rename_stb      : std_logic;
  signal decode_rename_setx     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_geta     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_getb     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_typ      : t_opa_matrix(c_decoders-1 downto 0, c_types-1           downto 0);
  signal decode_rename_regx     : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal decode_rename_rega     : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal decode_rename_regb     : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal rename_fifo_step       : std_logic;
  signal rename_fifo_setx       : std_logic_vector(c_decoders-1 downto 0);
  signal rename_fifo_regx       : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  signal rename_decode_stall    : std_logic;
  signal rename_issue_stb       : std_logic;
  signal rename_issue_stat      : std_logic_vector(c_stat_wide-1 downto 0);
  signal rename_issue_typ       : t_opa_matrix(c_decoders-1 downto 0, c_types-1     downto 0);
  signal rename_issue_regx      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_rega      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_regb      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal issue_eu_regx          : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_rega     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_regb     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_bypass_a : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal issue_regfile_bypass_b : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal issue_regfile_mux_a    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal issue_regfile_mux_b    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal issue_commit_regx      : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_commit_bak       : std_logic_vector(c_back_num-1 downto 0);
  signal commit_rename_map      : t_opa_matrix(2**g_config.log_arch-1 downto 0, c_back_wide-1 downto 0);
  signal commit_rename_stb      : std_logic;
  signal commit_issue_mask      : std_logic_vector(2*g_config.num_stat-1 downto 0);
  signal commit_fifo_step       : std_logic;
  signal commit_fifo_we         : std_logic;
  signal commit_fifo_bakx       : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal regfile_eu_data        : t_opa_matrix(c_executers-1 downto 0, 2**g_config.log_width-1 downto 0);
  signal regfile_eu_datb        : t_opa_matrix(c_executers-1 downto 0, 2**g_config.log_width-1 downto 0);
  signal eu_issue_regx          : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal eu_regfile_regx        : t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
  signal eu_regfile_datx        : t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0);
  
  type t_dat is array (c_executers-1 downto 0) of std_logic_vector(2**g_config.log_width-1 downto 0);
  type t_reg is array (c_executers-1 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  
  signal s_issue_eu_regx   : t_reg;
  signal s_eu_issue_regx   : t_reg;
  signal s_regfile_eu_data : t_dat;
  signal s_regfile_eu_datb : t_dat;
  signal s_eu_regfile_regx : t_reg;
  signal s_eu_regfile_datx : t_dat;

begin

  check_divisible : 
    assert (g_config.num_stat mod g_config.num_decode = 0) 
    report "num_stat must be divisible by num_decode"
    severity failure;
  
  check_decode :
    assert (g_config.num_decode >= 1)
    report "num_decode must be >= 1"
    severity failure;
  
  check_stat :
    assert (g_config.num_stat >= 1)
    report "num_stat must be >= 1"
    severity failure;

  check_ieu :
    assert (g_config.num_ieu >= 1)
    report "num_ieu must be >= 1"
    severity failure;

  check_mul :
    assert (g_config.num_mul >= 1)
    report "num_mul must be >= 1"
    severity failure;

  fifo : opa_fifo
    generic map(
      g_config => g_config)
    port map(
      clk_i         => clk_i,
      rst_n_i       => rst_n_i,
      mispredict_i  => s_mispredict,
      commit_step_i => commit_fifo_step,
      commit_bakx_o => fifo_commit_bakx,
      commit_setx_o => fifo_commit_setx,
      commit_regx_o => fifo_commit_regx,
      commit_we_i   => commit_fifo_we,
      commit_bakx_i => commit_fifo_bakx,
      rename_step_i => rename_fifo_step,
      rename_bakx_o => fifo_rename_bakx,
      rename_setx_i => rename_fifo_setx,
      rename_regx_i => rename_fifo_regx);
  
  decode : opa_decoder
    generic map(
      g_config => g_config)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      stb_i          => stb_i,
      stall_o        => stall_o,
      data_i         => data_i,
      rename_stall_i => rename_decode_stall,
      rename_setx_o  => decode_rename_setx,
      rename_geta_o  => decode_rename_geta,
      rename_getb_o  => decode_rename_getb,
      rename_typ_o   => decode_rename_typ,
      rename_regx_o  => decode_rename_regx,
      rename_rega_o  => decode_rename_rega,
      rename_regb_o  => decode_rename_regb);
      
  rename : opa_renamer
    generic map(
      g_config => g_config)
    port map(
      clk_i        => clk_i,
      rst_n_i      => rst_n_i,
      mispredict_i => s_mispredict,
      commit_map_i => commit_rename_map,
      commit_stb_i => commit_rename_stb,
      fifo_step_o  => rename_fifo_step,
      fifo_bak_i   => fifo_rename_bakx,
      fifo_setx_o  => rename_fifo_setx,
      fifo_regx_o  => rename_fifo_regx,
      dec_stall_o  => rename_decode_stall,
      dec_stb_i    => decode_rename_stb,
      dec_setx_i   => decode_rename_setx,
      dec_geta_i   => decode_rename_geta,
      dec_getb_i   => decode_rename_getb,
      dec_typ_i    => decode_rename_typ,
      dec_regx_i   => decode_rename_regx,
      dec_rega_i   => decode_rename_rega,
      dec_regb_i   => decode_rename_regb,
      iss_stb_o    => rename_issue_stb,
      iss_stat_o   => rename_issue_stat,
      iss_typ_o    => rename_issue_typ,
      iss_regx_o   => rename_issue_regx,
      iss_rega_o   => rename_issue_rega,
      iss_regb_o   => rename_issue_regb);
  
  issue : opa_issue
    generic map(
      g_config => g_config)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      mispredict_i   => s_mispredict,
      ren_stb_i      => rename_issue_stb,
      ren_stat_i     => rename_issue_stat,
      ren_typ_i      => rename_issue_typ,
      ren_regx_i     => rename_issue_regx,
      ren_rega_i     => rename_issue_rega,
      ren_regb_i     => rename_issue_regb,
      eu_next_regx_o => issue_eu_regx,
      eu_next_rega_o => issue_regfile_rega,
      eu_next_regb_o => issue_regfile_regb,
      eu_done_regx_i => eu_issue_regx,
      reg_bypass_a_o => issue_regfile_bypass_a,
      reg_bypass_b_o => issue_regfile_bypass_b,
      reg_mux_a_o    => issue_regfile_mux_a,
      reg_mux_b_o    => issue_regfile_mux_b,
      commit_mask_i  => commit_issue_mask,
      commit_regx_o  => issue_commit_regx,
      commit_bak_o   => issue_commit_bak);
  
  commit : opa_commit
    generic map(
      g_config => g_config)
    port map(
      clk_i        => clk_i,
      rst_n_i      => rst_n_i,
      mispredict_o => s_mispredict,
      rename_map_o => commit_rename_map,
      rename_stb_o => commit_rename_stb,
      issue_regx_i => issue_commit_regx,
      issue_bak_i  => issue_commit_bak,
      fifo_step_o  => commit_fifo_step,
      fifo_bakx_i  => fifo_commit_bakx,
      fifo_setx_i  => fifo_commit_setx,
      fifo_regx_i  => fifo_commit_regx,
      fifo_we_o    => commit_fifo_we,
      fifo_bakx_o  => commit_fifo_bakx);
  
  regfile : opa_regfile
    generic map(
      g_config => g_config)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      iss_rega_i     => issue_regfile_rega,
      iss_regb_i     => issue_regfile_regb,
      iss_bypass_a_i => issue_regfile_bypass_a,
      iss_bypass_b_i => issue_regfile_bypass_b,
      iss_mux_a_i    => issue_regfile_mux_a,
      iss_mux_b_i    => issue_regfile_mux_b,
      eu_data_o      => regfile_eu_data,
      eu_datb_o      => regfile_eu_datb,
      eu_regx_i      => eu_regfile_regx,
      eu_datx_i      => eu_regfile_datx);
  
  ieus : for i in 0 to g_config.num_ieu-1 generate
    ieu : opa_ieu
      generic map(
        g_config => g_config)
      port map(
        clk_i      => clk_i,
        rst_n_i    => rst_n_i,
        iss_regx_i => s_issue_eu_regx(f_opa_ieu_index(g_config, i)),
        iss_regx_o => s_eu_issue_regx(f_opa_ieu_index(g_config, i)),
        reg_data_i => s_regfile_eu_data(f_opa_ieu_index(g_config, i)),
        reg_datb_i => s_regfile_eu_datb(f_opa_ieu_index(g_config, i)),
        reg_regx_o => s_eu_regfile_regx(f_opa_ieu_index(g_config, i)),
        reg_datx_o => s_eu_regfile_datx(f_opa_ieu_index(g_config, i)));
  end generate;
  
  muls : for i in 0 to g_config.num_mul-1 generate
    mul : opa_mul
      generic map(
        g_config => g_config)
      port map(
        clk_i      => clk_i,
        rst_n_i    => rst_n_i,
        iss_regx_i => s_issue_eu_regx(f_opa_mul_index(g_config, i)),
        iss_regx_o => s_eu_issue_regx(f_opa_mul_index(g_config, i)),
        reg_data_i => s_regfile_eu_data(f_opa_mul_index(g_config, i)),
        reg_datb_i => s_regfile_eu_datb(f_opa_mul_index(g_config, i)),
        reg_regx_o => s_eu_regfile_regx(f_opa_mul_index(g_config, i)),
        reg_datx_o => s_eu_regfile_datx(f_opa_mul_index(g_config, i)));
  end generate;
  
  -- loadstore :
  
end rtl;
