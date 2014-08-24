library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;

    -- Incoming data
    stb_i          : in  std_logic;
    stall_o        : out std_logic;
    data_i         : in  std_logic_vector(g_config.num_decode*c_op_wide-1 downto 0);
    
    -- Wishbone data bus
    d_stb_o   : out std_logic;
    d_we_o    : out std_logic;
    d_stall_i : in  std_logic;
    d_ack_i   : in  std_logic;
    d_err_i   : in  std_logic;
    d_addr_o  : out std_logic_vector(g_config.da_bits-1 downto 0);
    d_sel_o   : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    d_data_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_data_i  : out std_logic_vector(2**g_config.log_width  -1 downto 0));
end opa;

architecture rtl of opa is

  -- Quartus 11+ likes to replace my registers with a slow FIFO. Stop it.
  attribute altera_attribute : string; 
  attribute altera_attribute of rtl : architecture is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
  
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_num_fast  : natural := f_opa_num_fast (g_config);
  constant c_num_slow  : natural := f_opa_num_slow (g_config);
  constant c_num_back  : natural := f_opa_num_back (g_config);
  constant c_num_arch  : natural := f_opa_num_arch (g_config);
  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  
  constant c_executer_ones : std_logic_vector(c_executers-1 downto 0) := (others => '1');
  
  signal decode_rename_fast     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_slow     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_jump     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_load     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_store    : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_setx     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_geta     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_getb     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_aux      : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide-1  downto 0);
  signal decode_rename_archx    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal decode_rename_archa    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal decode_rename_archb    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal rename_issue_fast      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_slow      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_jump      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_load      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_store     : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_setx      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_aux       : t_opa_matrix(c_decoders-1 downto 0, c_aux_wide-1  downto 0);
  signal rename_issue_archx     : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal rename_issue_bakx      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_baka      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_bakb      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_stata     : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal rename_issue_statb     : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal issue_rename_shift     : std_logic;
  signal issue_eu_shift         : std_logic;
  signal issue_eu_stat          : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  signal issue_regfile_stb      : std_logic_vector(c_executers-1 downto 0);
  signal issue_regfile_bakx     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_baka     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_bakb     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_aux      : t_opa_matrix(c_executers-1 downto 0, c_aux_wide-1  downto 0);    
  signal issue_commit_shift     : std_logic;
  signal issue_commit_kill      : std_logic_vector(c_decoders-1 downto 0);
  signal issue_commit_setx      : std_logic_vector(c_decoders-1 downto 0);
  signal issue_commit_archx     : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1  downto 0);
  signal issue_commit_bakx      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1  downto 0);
  signal commit_rename_kill     : std_logic;
  signal commit_rename_map      : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1  downto 0);
  signal commit_rename_bakx     : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1  downto 0);
  signal regfile_eu_stb         : std_logic_vector(c_executers-1 downto 0);
  signal regfile_eu_rega        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1  downto 0);
  signal regfile_eu_regb        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1  downto 0);
  signal regfile_eu_bakx        : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal regfile_eu_aux         : t_opa_matrix(c_executers-1 downto 0, c_aux_wide-1  downto 0);
  signal eu_issue_ready         : std_logic_vector(c_num_stat-1 downto 0);
  signal eu_issue_final         : std_logic_vector(c_num_stat-1 downto 0);
  signal eu_issue_quash         : std_logic_vector(c_num_stat-1 downto 0);
  signal eu_issue_kill          : std_logic_vector(c_num_stat-1 downto 0);
  signal eu_issue_stall         : std_logic_vector(c_num_slow-1 downto 0);
  signal eu_regfile_stb         : std_logic_vector(c_executers-1 downto 0);
  signal eu_regfile_bakx        : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal eu_regfile_regx        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1 downto 0);
  
  type t_stat is array (c_executers-1 downto 0) of std_logic_vector(c_num_stat -1 downto 0);
  type t_reg  is array (c_executers-1 downto 0) of std_logic_vector(c_reg_wide -1 downto 0);
  type t_bak  is array (c_executers-1 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  type t_aux  is array (c_executers-1 downto 0) of std_logic_vector(c_aux_wide -1 downto 0);
  
  signal s_issue_eu_stat   : t_stat;
  signal s_eu_issue_ready  : t_stat;
  signal s_eu_issue_final  : t_stat;
  signal s_eu_issue_quash  : t_stat;
  signal s_eu_issue_kill   : t_stat;
  signal s_regfile_eu_rega : t_reg;
  signal s_regfile_eu_regb : t_reg;
  signal s_regfile_eu_bakx : t_bak;
  signal s_regfile_eu_aux  : t_aux;
  signal s_eu_regfile_bakx : t_bak;
  signal s_eu_regfile_regx : t_reg;
  
  signal s_eu_issue_ready_m : t_opa_matrix(c_num_stat-1 downto 0, c_executers-1 downto 0);
  signal s_eu_issue_final_m : t_opa_matrix(c_num_stat-1 downto 0, c_executers-1 downto 0);
  signal s_eu_issue_quash_m : t_opa_matrix(c_num_stat-1 downto 0, c_executers-1 downto 0);
  signal s_eu_issue_kill_m  : t_opa_matrix(c_num_stat-1 downto 0, c_executers-1 downto 0);

begin

  check_issue_divisible : 
    assert (g_config.num_stat mod g_config.num_decode = 0) 
    report "num_stat must be divisible by num_decode"
    severity failure;
  
  check_decode :
    assert (g_config.num_decode >= 1)
    report "num_decode must be >= 1"
    severity failure;
  
  check_stat :
    assert (g_config.num_fast >= 1)
    report "num_fast must be >= 1"
    severity failure;

  check_ieu :
    assert (g_config.num_slow >= 1)
    report "num_slow must be >= 1"
    severity failure;

  decode : opa_decode
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      fetch_dat_i    => data_i,
      rename_fast_o  => decode_rename_fast,
      rename_slow_o  => decode_rename_slow,
      rename_jump_o  => decode_rename_jump,
      rename_load_o  => decode_rename_load,
      rename_store_o => decode_rename_store,
      rename_setx_o  => decode_rename_setx,
      rename_geta_o  => decode_rename_geta,
      rename_getb_o  => decode_rename_getb,
      rename_aux_o   => decode_rename_aux,
      rename_archx_o => decode_rename_archx,
      rename_archa_o => decode_rename_archa,
      rename_archb_o => decode_rename_archb);
      
  rename : opa_rename
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      decode_fast_i  => decode_rename_fast,
      decode_slow_i  => decode_rename_slow,
      decode_jump_i  => decode_rename_jump,
      decode_load_i  => decode_rename_load,
      decode_store_i => decode_rename_store,
      decode_setx_i  => decode_rename_setx,
      decode_geta_i  => decode_rename_geta,
      decode_getb_i  => decode_rename_getb,
      decode_aux_i   => decode_rename_aux,
      decode_archx_i => decode_rename_archx,
      decode_archa_i => decode_rename_archa,
      decode_archb_i => decode_rename_archb,
      commit_kill_i  => commit_rename_kill,
      commit_map_i   => commit_rename_map,
      commit_bakx_i  => commit_rename_bakx,
      issue_shift_i  => issue_rename_shift,
      issue_fast_o   => rename_issue_fast,
      issue_slow_o   => rename_issue_slow,
      issue_jump_o   => rename_issue_jump,
      issue_load_o   => rename_issue_load,
      issue_store_o  => rename_issue_store,
      issue_setx_o   => rename_issue_setx,
      issue_aux_o    => rename_issue_aux,
      issue_archx_o  => rename_issue_archx,
      issue_bakx_o   => rename_issue_bakx,
      issue_baka_o   => rename_issue_baka,
      issue_bakb_o   => rename_issue_bakb,
      issue_stata_o  => rename_issue_stata,
      issue_statb_o  => rename_issue_statb);
  
  issue : opa_issue
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      fetch_stb_i    => stb_i,
      fetch_stall_o  => stall_o,
      rename_shift_o => issue_rename_shift,
      rename_fast_i  => rename_issue_fast,
      rename_slow_i  => rename_issue_slow,
      rename_jump_i  => rename_issue_jump,
      rename_load_i  => rename_issue_load,
      rename_store_i => rename_issue_store,
      rename_setx_i  => rename_issue_setx,
      rename_aux_i   => rename_issue_aux,
      rename_archx_i => rename_issue_archx,
      rename_bakx_i  => rename_issue_bakx,
      rename_baka_i  => rename_issue_baka,
      rename_bakb_i  => rename_issue_bakb,
      rename_stata_i => rename_issue_stata,
      rename_statb_i => rename_issue_statb,
      eu_shift_o     => issue_eu_shift,
      eu_stat_o      => issue_eu_stat,
      eu_ready_i     => eu_issue_ready,
      eu_final_i     => eu_issue_final,
      eu_quash_i     => eu_issue_quash,
      eu_kill_i      => eu_issue_kill,
      eu_stall_i     => eu_issue_stall,
      regfile_stb_o  => issue_regfile_stb,
      regfile_bakx_o => issue_regfile_bakx,
      regfile_baka_o => issue_regfile_baka,
      regfile_bakb_o => issue_regfile_bakb,
      regfile_aux_o  => issue_regfile_aux,
      commit_shift_o => issue_commit_shift,
      commit_kill_o  => issue_commit_kill,
      commit_setx_o  => issue_commit_setx,
      commit_archx_o => issue_commit_archx,
      commit_bakx_o  => issue_commit_bakx);
  
  commit : opa_commit
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i         => clk_i,
      rst_n_i       => rst_n_i,
      issue_shift_i => issue_commit_shift,
      issue_kill_i  => issue_commit_kill,
      issue_setx_i  => issue_commit_setx,
      issue_archx_i => issue_commit_archx,
      issue_bakx_i  => issue_commit_bakx,
      rename_kill_o => commit_rename_kill,
      rename_map_o  => commit_rename_map,
      rename_bakx_o => commit_rename_bakx);

  regfile : opa_regfile
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      issue_stb_i    => issue_regfile_stb,
      issue_bakx_i   => issue_regfile_bakx,
      issue_baka_i   => issue_regfile_baka,
      issue_bakb_i   => issue_regfile_bakb,
      issue_aux_i    => issue_regfile_aux,
      eu_stb_o       => regfile_eu_stb,
      eu_rega_o      => regfile_eu_rega,
      eu_regb_o      => regfile_eu_regb,
      eu_bakx_o      => regfile_eu_bakx,
      eu_aux_o       => regfile_eu_aux,
      eu_stb_i       => eu_regfile_stb,
      eu_bakx_i      => eu_regfile_bakx,
      eu_regx_i      => eu_regfile_regx);
  
  -- Relabel matrix between issue+regfile and EUs
  eus : for u in 0 to c_executers-1 generate
    dat : for b in 0 to c_reg_wide-1 generate
      s_regfile_eu_rega(u)(b) <= regfile_eu_rega(u,b);
      s_regfile_eu_regb(u)(b) <= regfile_eu_regb(u,b);
      eu_regfile_regx(u,b) <= s_eu_regfile_regx(u)(b);
    end generate;
    reg : for b in 0 to c_back_wide-1 generate
      s_regfile_eu_bakx(u)(b) <= regfile_eu_bakx(u,b);
      eu_regfile_bakx(u,b) <= s_eu_regfile_bakx(u)(b);
    end generate;
    aux : for b in 0 to c_aux_wide-1 generate
      s_regfile_eu_aux(u)(b) <= regfile_eu_aux(u,b);
    end generate;
    stat : for b in 0 to c_num_stat-1 generate
      s_issue_eu_stat(u)(b) <= issue_eu_stat(u,b);
      s_eu_issue_ready_m(b,u) <= s_eu_issue_ready(u)(b);
      s_eu_issue_final_m(b,u) <= s_eu_issue_final(u)(b);
      s_eu_issue_quash_m(b,u) <= s_eu_issue_quash(u)(b);
      s_eu_issue_kill_m (b,u) <= s_eu_issue_kill (u)(b);
    end generate;
  end generate;
  
  eu_issue_ready <= f_opa_product(s_eu_issue_ready_m, c_executer_ones);
  eu_issue_final <= f_opa_product(s_eu_issue_final_m, c_executer_ones);
  eu_issue_quash <= f_opa_product(s_eu_issue_quash_m, c_executer_ones);
  eu_issue_kill  <= f_opa_product(s_eu_issue_kill_m,  c_executer_ones);
  
  fastx : for i in 0 to c_num_fast-1 generate
    fast : opa_fast
      generic map(
        g_config => g_config,
        g_target => g_target)
      port map(
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        issue_shift_i  => issue_eu_shift,
        issue_stat_i   => s_issue_eu_stat(f_opa_fast_index(g_config, i)),
        issue_final_o  => s_eu_issue_final(f_opa_fast_index(g_config, i)),
        issue_kill_o   => s_eu_issue_kill(f_opa_fast_index(g_config, i)),
        regfile_stb_i  => regfile_eu_stb(f_opa_fast_index(g_config, i)),
        regfile_rega_i => s_regfile_eu_rega(f_opa_fast_index(g_config, i)),
        regfile_regb_i => s_regfile_eu_regb(f_opa_fast_index(g_config, i)),
        regfile_bakx_i => s_regfile_eu_bakx(f_opa_fast_index(g_config, i)),
        regfile_aux_i  => s_regfile_eu_aux(f_opa_fast_index(g_config, i)),
        regfile_stb_o  => eu_regfile_stb(f_opa_fast_index(g_config, i)),
        regfile_bakx_o => s_eu_regfile_bakx(f_opa_fast_index(g_config, i)),
        regfile_regx_o => s_eu_regfile_regx(f_opa_fast_index(g_config, i)));
    s_eu_issue_ready(f_opa_fast_index(g_config, i)) <= (others => '0');
    s_eu_issue_quash(f_opa_fast_index(g_config, i)) <= (others => '0');
  end generate;
  
  slowx : for i in 0 to c_num_slow-1 generate
    slow : opa_slow
      generic map(
        g_config => g_config,
        g_target => g_target)
      port map(
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        issue_shift_i  => issue_eu_shift,
        issue_stat_i   => s_issue_eu_stat(f_opa_slow_index(g_config, i)),
        issue_ready_o  => s_eu_issue_ready(f_opa_slow_index(g_config, i)),
        issue_final_o  => s_eu_issue_final(f_opa_slow_index(g_config, i)),
        issue_quash_o  => s_eu_issue_quash(f_opa_slow_index(g_config, i)),
        issue_kill_o   => s_eu_issue_kill(f_opa_slow_index(g_config, i)),
        issue_stall_o  => eu_issue_stall(i),
        regfile_stb_i  => regfile_eu_stb(f_opa_slow_index(g_config, i)),
        regfile_rega_i => s_regfile_eu_rega(f_opa_slow_index(g_config, i)),
        regfile_regb_i => s_regfile_eu_regb(f_opa_slow_index(g_config, i)),
        regfile_bakx_i => s_regfile_eu_bakx(f_opa_slow_index(g_config, i)),
        regfile_aux_i  => s_regfile_eu_aux(f_opa_slow_index(g_config, i)),
        regfile_stb_o  => eu_regfile_stb(f_opa_slow_index(g_config, i)),
        regfile_bakx_o => s_eu_regfile_bakx(f_opa_slow_index(g_config, i)),
        regfile_regx_o => s_eu_regfile_regx(f_opa_slow_index(g_config, i)));
  end generate;
  
end rtl;
