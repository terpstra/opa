library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
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
    i_cyc_o   : out std_logic;
    i_stb_o   : out std_logic;
    i_stall_i : in  std_logic;
    i_ack_i   : in  std_logic;
    i_err_i   : in  std_logic;
    i_addr_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    i_data_i  : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
    
    -- Wishbone data bus
    d_cyc_o   : out std_logic;
    d_stb_o   : out std_logic;
    d_we_o    : out std_logic;
    d_stall_i : in  std_logic;
    d_ack_i   : in  std_logic;
    d_err_i   : in  std_logic;
    d_addr_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_sel_o   : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    d_data_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_data_i  : in  std_logic_vector(2**g_config.log_width  -1 downto 0));
end opa;

architecture rtl of opa is

  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_num_fast  : natural := f_opa_num_fast (g_config);
  constant c_num_slow  : natural := f_opa_num_slow (g_config);
  constant c_num_back  : natural := f_opa_num_back (g_config);
  constant c_num_arch  : natural := f_opa_num_arch (g_config);
  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_num_fetch : natural := f_opa_num_fetch(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_arch_wide : natural := f_opa_arch_wide(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide  : natural := f_opa_adr_wide(g_config);
  constant c_arg_wide  : natural := f_opa_arg_wide(g_config);
  constant c_imm_wide  : natural := f_opa_imm_wide(g_config);
  constant c_aux_wide  : natural := f_opa_aux_wide(g_config);
  constant c_dec_wide  : natural := f_opa_dec_wide(g_config);
  constant c_fetch_wide  : natural := f_opa_fetch_wide(g_config);
  
  signal predict_icache_pc      : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal predict_decode_hit     : std_logic;
  signal predict_decode_jump    : std_logic_vector(c_decoders-1 downto 0);

  signal icache_predict_stall   : std_logic;
  signal icache_decode_stb      : std_logic;
  signal icache_decode_pc       : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal icache_decode_pcn      : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal icache_decode_dat      : std_logic_vector(c_num_fetch*8-1 downto 0);
  
  signal decode_predict_push    : std_logic;
  signal decode_predict_ret     : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal decode_predict_fault   : std_logic;
  signal decode_predict_return  : std_logic;
  signal decode_predict_jump    : std_logic_vector(c_decoders-1 downto 0);
  signal decode_predict_source  : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal decode_predict_target  : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal decode_icache_stall    : std_logic;
  signal decode_rename_stb      : std_logic;
  signal decode_rename_fast     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_slow     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_setx     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_geta     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_getb     : std_logic_vector(c_decoders-1 downto 0);
  signal decode_rename_aux      : std_logic_vector(c_aux_wide-1 downto 0);
  signal decode_rename_archx    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal decode_rename_archa    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal decode_rename_archb    : t_opa_matrix(c_decoders-1 downto 0, c_arch_wide-1 downto 0);
  signal decode_regfile_stb     : std_logic;
  signal decode_regfile_aux     : std_logic_vector(c_aux_wide-1 downto 0);
  signal decode_regfile_arg     : t_opa_matrix(c_decoders-1 downto 0, c_arg_wide-1 downto 0);
  signal decode_regfile_imm     : t_opa_matrix(c_decoders-1 downto 0, c_imm_wide-1 downto 0);
  signal decode_regfile_pc      : t_opa_matrix(c_decoders-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal decode_regfile_pcf     : t_opa_matrix(c_decoders-1 downto 0, c_fetch_wide-1 downto c_op_align);
  signal decode_regfile_pcn     : std_logic_vector(c_adr_wide-1 downto c_op_align);
  
  signal rename_decode_stall    : std_logic;
  signal rename_decode_fault    : std_logic;
  signal rename_decode_pc       : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal rename_decode_pcf      : std_logic_vector(c_fetch_wide-1 downto c_op_align);
  signal rename_decode_pcn      : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal rename_issue_stb       : std_logic;
  signal rename_issue_fast      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_slow      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_geta      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_getb      : std_logic_vector(c_decoders-1 downto 0);
  signal rename_issue_aux       : std_logic_vector(c_aux_wide-1 downto 0);
  signal rename_issue_bakx      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_baka      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_bakb      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal rename_issue_stata     : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  signal rename_issue_statb     : t_opa_matrix(c_decoders-1 downto 0, c_stat_wide-1 downto 0);
  
  signal issue_rename_stall     : std_logic;
  signal issue_rename_bakx      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal issue_rename_fault     : std_logic;
  signal issue_rename_mask      : std_logic_vector(c_decoders-1 downto 0);
  signal issue_rename_pc        : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal issue_rename_pcf       : std_logic_vector(c_fetch_wide-1 downto c_op_align);
  signal issue_rename_pcn       : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal issue_regfile_rstb     : std_logic_vector(c_executers-1 downto 0);
  signal issue_regfile_geta     : std_logic_vector(c_executers-1 downto 0);
  signal issue_regfile_getb     : std_logic_vector(c_executers-1 downto 0);
  signal issue_regfile_aux      : t_opa_matrix(c_executers-1 downto 0, c_aux_wide-1 downto 0);
  signal issue_regfile_dec      : t_opa_matrix(c_executers-1 downto 0, c_dec_wide-1 downto 0);
  signal issue_regfile_baka     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_bakb     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal issue_regfile_wstb     : std_logic_vector(c_executers-1 downto 0);
  signal issue_regfile_bakx     : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  
  signal regfile_eu_stb         : std_logic_vector(c_executers-1 downto 0);
  signal regfile_eu_rega        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1  downto 0);
  signal regfile_eu_regb        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1  downto 0);
  signal regfile_eu_arg         : t_opa_matrix(c_executers-1 downto 0, c_arg_wide-1  downto 0);
  signal regfile_eu_imm         : t_opa_matrix(c_executers-1 downto 0, c_imm_wide-1  downto 0);
  signal regfile_eu_pc          : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal regfile_eu_pcf         : t_opa_matrix(c_executers-1 downto 0, c_fetch_wide-1 downto c_op_align);
  signal regfile_eu_pcn         : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  
  signal eu_regfile_regx        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1 downto 0);
  signal eu_issue_retry         : std_logic_vector(c_executers-1 downto 0);
  signal eu_issue_fault         : std_logic_vector(c_executers-1 downto 0);
  signal eu_issue_pc            : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal eu_issue_pcf           : t_opa_matrix(c_executers-1 downto 0, c_fetch_wide-1 downto c_op_align);
  signal eu_issue_pcn           : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal slow_dbus_stb          : std_logic_vector(c_num_slow-1 downto 0);
  signal slow_dbus_adr          : t_opa_matrix(c_num_slow-1 downto 0, c_adr_wide-1 downto 0);
  
  signal dbus_slow_stb          : std_logic;
  signal dbus_slow_adr          : std_logic_vector(c_adr_wide    -1 downto 0);
  signal dbus_slow_dat          : std_logic_vector(c_dline_size*8-1 downto 0);
  
  type t_reg  is array (c_executers-1 downto 0) of std_logic_vector(c_reg_wide -1 downto 0);
  type t_arg  is array (c_executers-1 downto 0) of std_logic_vector(c_arg_wide -1 downto 0);
  type t_imm  is array (c_executers-1 downto 0) of std_logic_vector(c_imm_wide -1 downto 0);
  type t_pc   is array (c_executers-1 downto 0) of std_logic_vector(c_adr_wide -1 downto c_op_align);
  type t_pcf  is array (c_executers-1 downto 0) of std_logic_vector(c_fetch_wide -1 downto c_op_align);
  type t_adr  is array (c_num_slow -1 downto 0) of std_logic_vector(c_adr_wide -1 downto 0);
  
  signal s_regfile_eu_rega : t_reg;
  signal s_regfile_eu_regb : t_reg;
  signal s_regfile_eu_arg  : t_arg;
  signal s_regfile_eu_imm  : t_imm;
  signal s_regfile_eu_pc   : t_pc;
  signal s_regfile_eu_pcf  : t_pcf;
  signal s_regfile_eu_pcn  : t_pc;
  signal s_eu_regfile_regx : t_reg;
  signal s_eu_issue_pc     : t_pc;
  signal s_eu_issue_pcf    : t_pcf;
  signal s_eu_issue_pcn    : t_pc;
  signal s_slow_dbus_adr   : t_adr;
  
begin

  check_issue_divisible : 
    assert (g_config.num_stat mod g_config.num_decode = 0) 
    report "num_stat must be divisible by num_decode"
    severity failure;
  
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
  
  check_reg :
    assert (8 <= 2**g_config.log_width)
    report "registers must be larger than a byte"
    severity failure;
    
  check_imm :
    assert (c_imm_wide <= 2**g_config.log_width)
    report "registers must be larger than ISA immediates"
    severity failure;
    
  check_adr :
    assert (g_config.adr_width <= 2**g_config.log_width)
    report "registers must be larger than virtual address space"
    severity failure;
    
  check_page :
    assert (g_config.adr_width >= f_opa_log2(c_page_size))
    report "virtual address space must exceed one page"
    severity failure;
  
  check_dline :
    assert (2**g_config.log_width <= c_dline_size*8)
    report "registers can not exceed the size of an L1d line"
    severity failure;

  check_iline :
    assert (2**g_config.log_width <= c_iline_size*8)
    report "registers can not exceed the size of an L1i line"
    severity failure;

  -- !!! include our own reset extender

  predict : opa_predict
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map (
      clk_i           => clk_i,
      rst_n_i         => rst_n_i,
      icache_stall_i  => icache_predict_stall,
      icache_pc_o     => predict_icache_pc,
      decode_hit_o    => predict_decode_hit,
      decode_jump_o   => predict_decode_jump,
      decode_push_i   => decode_predict_push,
      decode_ret_i    => decode_predict_ret,
      decode_fault_i  => decode_predict_fault,
      decode_return_i => decode_predict_return,
      decode_jump_i   => decode_predict_jump,
      decode_source_i => decode_predict_source,
      decode_target_i => decode_predict_target);
  
  icache : opa_icache
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i           => clk_i,
      rst_n_i         => rst_n_i,
      predict_stall_o => icache_predict_stall,
      predict_pc_i    => predict_icache_pc,
      decode_stb_o    => icache_decode_stb,
      decode_stall_i  => decode_icache_stall,
      decode_pc_o     => icache_decode_pc,
      decode_pcn_o    => icache_decode_pcn,
      decode_dat_o    => icache_decode_dat,
      i_cyc_o         => i_cyc_o,
      i_stb_o         => i_stb_o,
      i_stall_i       => i_stall_i,
      i_ack_i         => i_ack_i,
      i_err_i         => i_err_i,
      i_addr_o        => i_addr_o,
      i_data_i        => i_data_i);
  
  decode : opa_decode
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i            => clk_i,
      rst_n_i          => rst_n_i,
      predict_hit_i    => predict_decode_hit,
      predict_jump_i   => predict_decode_jump,
      predict_push_o   => decode_predict_push,
      predict_ret_o    => decode_predict_ret,
      predict_fault_o  => decode_predict_fault,
      predict_return_o => decode_predict_return,
      predict_jump_o   => decode_predict_jump,
      predict_source_o => decode_predict_source,
      predict_target_o => decode_predict_target,
      icache_stb_i     => icache_decode_stb,
      icache_stall_o   => decode_icache_stall,
      icache_pc_i      => icache_decode_pc,
      icache_pcn_i     => icache_decode_pcn,
      icache_dat_i     => icache_decode_dat,
      rename_stb_o     => decode_rename_stb,
      rename_stall_i   => rename_decode_stall,
      rename_fast_o    => decode_rename_fast,
      rename_slow_o    => decode_rename_slow,
      rename_setx_o    => decode_rename_setx,
      rename_geta_o    => decode_rename_geta,
      rename_getb_o    => decode_rename_getb,
      rename_aux_o     => decode_rename_aux,
      rename_archx_o   => decode_rename_archx,
      rename_archa_o   => decode_rename_archa,
      rename_archb_o   => decode_rename_archb,
      rename_fault_i   => rename_decode_fault,
      rename_pc_i      => rename_decode_pc,
      rename_pcf_i     => rename_decode_pcf,
      rename_pcn_i     => rename_decode_pcn,
      regfile_stb_o    => decode_regfile_stb,
      regfile_aux_o    => decode_regfile_aux,
      regfile_arg_o    => decode_regfile_arg,
      regfile_imm_o    => decode_regfile_imm,
      regfile_pc_o     => decode_regfile_pc,
      regfile_pcf_o    => decode_regfile_pcf,
      regfile_pcn_o    => decode_regfile_pcn);
      
  rename : opa_rename
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      decode_stb_i   => decode_rename_stb,
      decode_stall_o => rename_decode_stall,
      decode_fast_i  => decode_rename_fast,
      decode_slow_i  => decode_rename_slow,
      decode_setx_i  => decode_rename_setx,
      decode_geta_i  => decode_rename_geta,
      decode_getb_i  => decode_rename_getb,
      decode_aux_i   => decode_rename_aux,
      decode_archx_i => decode_rename_archx,
      decode_archa_i => decode_rename_archa,
      decode_archb_i => decode_rename_archb,
      issue_stb_o    => rename_issue_stb,
      issue_stall_i  => issue_rename_stall,
      issue_fast_o   => rename_issue_fast,
      issue_slow_o   => rename_issue_slow,
      issue_geta_o   => rename_issue_geta,
      issue_getb_o   => rename_issue_getb,
      issue_aux_o    => rename_issue_aux,
      issue_bakx_o   => rename_issue_bakx,
      issue_baka_o   => rename_issue_baka,
      issue_bakb_o   => rename_issue_bakb,
      issue_stata_o  => rename_issue_stata,
      issue_statb_o  => rename_issue_statb,
      issue_bakx_i   => issue_rename_bakx,
      issue_fault_i  => issue_rename_fault,
      issue_mask_i   => issue_rename_mask,
      issue_pc_i     => issue_rename_pc,
      issue_pcf_i    => issue_rename_pcf,
      issue_pcn_i    => issue_rename_pcn,
      decode_fault_o => rename_decode_fault,
      decode_pc_o    => rename_decode_pc,
      decode_pcf_o   => rename_decode_pcf,
      decode_pcn_o   => rename_decode_pcn);
  
  issue : opa_issue
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i          => clk_i,
      rst_n_i        => rst_n_i,
      rename_stb_i   => rename_issue_stb,
      rename_stall_o => issue_rename_stall,
      rename_fast_i  => rename_issue_fast,
      rename_slow_i  => rename_issue_slow,
      rename_geta_i  => rename_issue_geta,
      rename_getb_i  => rename_issue_getb,
      rename_aux_i   => rename_issue_aux,
      rename_bakx_i  => rename_issue_bakx,
      rename_baka_i  => rename_issue_baka,
      rename_bakb_i  => rename_issue_bakb,
      rename_stata_i => rename_issue_stata,
      rename_statb_i => rename_issue_statb,
      rename_bakx_o  => issue_rename_bakx,
      eu_retry_i     => eu_issue_retry,
      eu_fault_i     => eu_issue_fault,
      eu_pc_i        => eu_issue_pc,
      eu_pcf_i       => eu_issue_pcf,
      eu_pcn_i       => eu_issue_pcn,
      rename_fault_o => issue_rename_fault,
      rename_mask_o  => issue_rename_mask,
      rename_pc_o    => issue_rename_pc,
      rename_pcf_o   => issue_rename_pcf,
      rename_pcn_o   => issue_rename_pcn,
      regfile_rstb_o => issue_regfile_rstb,
      regfile_geta_o => issue_regfile_geta,
      regfile_getb_o => issue_regfile_getb,
      regfile_aux_o  => issue_regfile_aux,
      regfile_dec_o  => issue_regfile_dec,
      regfile_baka_o => issue_regfile_baka,
      regfile_bakb_o => issue_regfile_bakb,
      regfile_wstb_o => issue_regfile_wstb,
      regfile_bakx_o => issue_regfile_bakx);
  
  regfile : opa_regfile
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i        => clk_i,
      rst_n_i      => rst_n_i,
      decode_stb_i => decode_regfile_stb,
      decode_aux_i => decode_regfile_aux,
      decode_arg_i => decode_regfile_arg,
      decode_imm_i => decode_regfile_imm,
      decode_pc_i  => decode_regfile_pc,
      decode_pcf_i => decode_regfile_pcf,
      decode_pcn_i => decode_regfile_pcn,
      issue_rstb_i => issue_regfile_rstb,
      issue_geta_i => issue_regfile_geta,
      issue_getb_i => issue_regfile_getb,
      issue_aux_i  => issue_regfile_aux,
      issue_dec_i  => issue_regfile_dec,
      issue_baka_i => issue_regfile_baka,
      issue_bakb_i => issue_regfile_bakb,
      eu_stb_o     => regfile_eu_stb,
      eu_rega_o    => regfile_eu_rega,
      eu_regb_o    => regfile_eu_regb,
      eu_arg_o     => regfile_eu_arg,
      eu_imm_o     => regfile_eu_imm,
      eu_pc_o      => regfile_eu_pc,
      eu_pcf_o     => regfile_eu_pcf,
      eu_pcn_o     => regfile_eu_pcn,
      issue_wstb_i => issue_regfile_wstb,
      issue_bakx_i => issue_regfile_bakx,
      eu_regx_i    => eu_regfile_regx);
  
  -- Relabel matrix between issue+regfile and EUs
  eus : for u in 0 to c_executers-1 generate
    dat : for b in 0 to c_reg_wide-1 generate
      s_regfile_eu_rega(u)(b) <= regfile_eu_rega(u,b);
      s_regfile_eu_regb(u)(b) <= regfile_eu_regb(u,b);
      eu_regfile_regx(u,b) <= s_eu_regfile_regx(u)(b);
    end generate;
    arg : for b in 0 to c_arg_wide-1 generate
      s_regfile_eu_arg(u)(b) <= regfile_eu_arg(u,b);
    end generate;
    imm : for b in 0 to c_imm_wide-1 generate
      s_regfile_eu_imm(u)(b) <= regfile_eu_imm(u,b);
    end generate;
    pc : for b in c_op_align to c_adr_wide-1 generate
      s_regfile_eu_pc (u)(b) <= regfile_eu_pc (u,b);
      s_regfile_eu_pcn(u)(b) <= regfile_eu_pcn(u,b);
      eu_issue_pc (u,b) <= s_eu_issue_pc (u)(b);
      eu_issue_pcn(u,b) <= s_eu_issue_pcn(u)(b);
    end generate;
    pcf : for b in c_op_align to c_fetch_wide-1 generate
      s_regfile_eu_pcf(u)(b) <= regfile_eu_pcf(u,b);
      eu_issue_pcf(u,b) <= s_eu_issue_pcf(u)(b);
    end generate;
  end generate;
  
  slows : for u in 0 to c_num_slow-1 generate
    adr : for b in 0 to c_adr_wide-1 generate
      slow_dbus_adr(u,b) <= s_slow_dbus_adr(u)(b);
    end generate;
  end generate;
  
  fastx : for i in 0 to c_num_fast-1 generate
    fast : opa_fast
      generic map(
        g_config => g_config,
        g_target => g_target)
      port map(
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        regfile_stb_i  => regfile_eu_stb   (f_opa_fast_index(g_config, i)), 
        regfile_rega_i => s_regfile_eu_rega(f_opa_fast_index(g_config, i)),
        regfile_regb_i => s_regfile_eu_regb(f_opa_fast_index(g_config, i)),
        regfile_arg_i  => s_regfile_eu_arg (f_opa_fast_index(g_config, i)),
        regfile_imm_i  => s_regfile_eu_imm (f_opa_fast_index(g_config, i)),
        regfile_pc_i   => s_regfile_eu_pc  (f_opa_fast_index(g_config, i)),
        regfile_pcf_i  => s_regfile_eu_pcf (f_opa_fast_index(g_config, i)),
        regfile_pcn_i  => s_regfile_eu_pcn (f_opa_fast_index(g_config, i)),
        regfile_regx_o => s_eu_regfile_regx(f_opa_fast_index(g_config, i)),
        issue_retry_o  => eu_issue_retry   (f_opa_fast_index(g_config, i)),
        issue_fault_o  => eu_issue_fault   (f_opa_fast_index(g_config, i)),
        issue_pc_o     => s_eu_issue_pc    (f_opa_fast_index(g_config, i)),
        issue_pcf_o    => s_eu_issue_pcf   (f_opa_fast_index(g_config, i)),
        issue_pcn_o    => s_eu_issue_pcn   (f_opa_fast_index(g_config, i)));
  end generate;
  
  slowx : for i in 0 to c_num_slow-1 generate
    slow : opa_slow
      generic map(
        g_config => g_config,
        g_target => g_target)
      port map(
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        regfile_stb_i  => regfile_eu_stb   (f_opa_slow_index(g_config, i)), 
        regfile_rega_i => s_regfile_eu_rega(f_opa_slow_index(g_config, i)),
        regfile_regb_i => s_regfile_eu_regb(f_opa_slow_index(g_config, i)),
        regfile_arg_i  => s_regfile_eu_arg (f_opa_slow_index(g_config, i)),
        regfile_imm_i  => s_regfile_eu_imm (f_opa_slow_index(g_config, i)),
        regfile_pc_i   => s_regfile_eu_pc  (f_opa_slow_index(g_config, i)),
        regfile_pcf_i  => s_regfile_eu_pcf (f_opa_slow_index(g_config, i)),
        regfile_pcn_i  => s_regfile_eu_pcn (f_opa_slow_index(g_config, i)),
        regfile_regx_o => s_eu_regfile_regx(f_opa_slow_index(g_config, i)),
        dbus_stb_i     => dbus_slow_stb,
        dbus_adr_i     => dbus_slow_adr,
        dbus_dat_i     => dbus_slow_dat,
        dbus_stb_o     => slow_dbus_stb(i),
        dbus_adr_o     => s_slow_dbus_adr(i),
        issue_retry_o  => eu_issue_retry   (f_opa_slow_index(g_config, i)),
        issue_fault_o  => eu_issue_fault   (f_opa_slow_index(g_config, i)),
        issue_pc_o     => s_eu_issue_pc    (f_opa_slow_index(g_config, i)),
        issue_pcf_o    => s_eu_issue_pcf   (f_opa_slow_index(g_config, i)),
        issue_pcn_o    => s_eu_issue_pcn   (f_opa_slow_index(g_config, i)));
  end generate;
  
  dbus : opa_dbus
    generic map(
      g_config => g_config,
      g_target => g_target)
    port map(
      clk_i      => clk_i,
      rst_n_i    => rst_n_i,
      d_cyc_o    => d_cyc_o,
      d_stb_o    => d_stb_o,
      d_we_o     => d_we_o,
      d_stall_i  => d_stall_i,
      d_ack_i    => d_ack_i,
      d_err_i    => d_err_i,
      d_addr_o   => d_addr_o,
      d_sel_o    => d_sel_o,
      d_data_o   => d_data_o,
      d_data_i   => d_data_i,
      slow_stb_o => dbus_slow_stb,
      slow_adr_o => dbus_slow_adr,
      slow_dat_o => dbus_slow_dat,
      slow_stb_i => slow_dbus_stb,
      slow_adr_i => slow_dbus_adr);
  
end rtl;
