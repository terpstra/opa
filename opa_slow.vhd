library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_slow is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    regfile_arg_i  : in  std_logic_vector(f_opa_arg_wide  (g_config)-1 downto 0);
    regfile_imm_i  : in  std_logic_vector(f_opa_imm_wide  (g_config)-1 downto 0);
    regfile_pc_i   : in  std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    regfile_pcf_i  : in  std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    regfile_pcn_i  : in  std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    
    dbus_stb_i     : in  std_logic;
    dbus_adr_i     : in  std_logic_vector(f_opa_adr_wide  (g_config)-1 downto 0);
    dbus_dat_i     : in  std_logic_vector(c_dline_size*8            -1 downto 0);
    dbus_stb_o     : out std_logic;
    dbus_adr_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto 0);
    
    issue_retry_o  : out std_logic;
    issue_fault_o  : out std_logic;
    issue_pc_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    issue_pcf_o    : out std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    issue_pcn_o    : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align));
end opa_slow;

architecture rtl of opa_slow is

  constant c_reg_wide      : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide      : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide      : natural := f_opa_imm_wide(g_config);
  constant c_log_reg_wide  : natural := f_opa_log2(c_reg_wide);
  constant c_log_reg_bytes : natural := c_log_reg_wide - 3;
  constant c_l1_line_bytes : natural := c_dline_size;
  constant c_l1_idx_low    : natural := f_opa_log2(c_l1_line_bytes);
  constant c_l1_idx_high   : natural := f_opa_log2(c_page_size);
  constant c_l1_idx_wide   : natural := c_l1_idx_high - c_l1_idx_low;
  constant c_l1_tag_wide   : natural := c_adr_wide - c_l1_idx_high;
  constant c_l1_ent_wide   : natural := c_l1_tag_wide + c_dline_size*8;
  
  constant c_zero_off : std_logic_vector(c_log_reg_bytes-1 downto 0) := (others => '0');
  
  signal s_slow  : t_opa_slow;
  signal s_mul   : t_opa_mul;
  signal s_shift : t_opa_shift;
  signal r_shift : t_opa_shift;
  signal s_ldst  : t_opa_ldst;
  signal r_ldst1 : t_opa_ldst;
  signal r_ldst2 : t_opa_ldst;
  
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);
  signal s_mul_out : std_logic_vector(  c_reg_wide-1 downto 0);
  
  signal r_stb1  : std_logic;
  signal r_mode1 : std_logic_vector(1 downto 0);
  signal r_mode2 : std_logic_vector(1 downto 0);
  signal r_mode3 : std_logic_vector(1 downto 0);
  signal r_high1 : std_logic;
  signal r_high2 : std_logic;
  signal r_high3 : std_logic;
  
  signal r_rega    : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_regb    : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_imm     : std_logic_vector(c_imm_wide-1 downto 0);
  signal s_virt_ad : std_logic_vector(c_reg_wide    -1 downto 0);
  signal s_l1_wtag : std_logic_vector(c_adr_wide    -1 downto c_l1_idx_high);
  signal s_l1_widx : std_logic_vector(c_l1_idx_high -1 downto c_l1_idx_low);
  signal s_l1_went : std_logic_vector(c_l1_ent_wide -1 downto 0);
  signal s_l1_vtag : std_logic_vector(c_adr_wide    -1 downto c_l1_idx_high);
  signal s_l1_vidx : std_logic_vector(c_l1_idx_high -1 downto c_l1_idx_low);
  signal s_l1_voff : std_logic_vector(c_l1_idx_low  -1 downto 0);
  signal r_l1_stb  : std_logic;
  signal r_l1_vtag : std_logic_vector(c_adr_wide    -1 downto c_l1_idx_high);
  signal r_l1_vidx : std_logic_vector(c_l1_idx_high -1 downto c_l1_idx_low);
  signal r_l1_voff : std_logic_vector(c_l1_idx_low  -1 downto 0);
  signal r_l1_shift: std_logic_vector(c_l1_idx_low  -1 downto 0);
  signal s_l1_rent : std_logic_vector(c_l1_ent_wide -1 downto 0);
  signal s_l1_rtag : std_logic_vector(c_adr_wide    -1 downto c_l1_idx_high);
  signal s_l1_rdat : std_logic_vector(8*c_dline_size-1 downto 0);
  signal s_sizes   : std_logic_vector(c_l1_idx_low  -1 downto 0);
  signal s_size_sh : std_logic_vector(c_l1_idx_low  -1 downto 0);
  signal s_l1_clear: std_logic_vector(c_log_reg_bytes  downto 0);
  signal r_l1_clear: std_logic_vector(c_log_reg_bytes  downto 0);
  signal s_l1_rot  : std_logic_vector(8*c_dline_size-1 downto 0);
  signal s_l1_sext : std_logic_vector(c_reg_wide    -1 downto 0);
  signal s_l1_zext : std_logic_vector(c_reg_wide    -1 downto 0);
  signal r_l1_dat  : std_logic_vector(c_reg_wide    -1 downto 0);
  signal s_load_out: std_logic_vector(c_reg_wide    -1 downto 0);
  
  type t_reg_mux is array(natural range <>) of std_logic_vector(c_reg_wide-1 downto 0);
  signal s_l1_mux : t_reg_mux(c_log_reg_bytes downto 0);
  
  signal s_miss    : std_logic;
  
  signal r_sexta   : std_logic_vector(2*c_reg_wide  -1 downto 0);
  signal r_shamt   : std_logic_vector(c_log_reg_wide   downto 0);
  signal s_shout   : std_logic_vector(2*c_reg_wide  -1 downto 0);
  signal r_shout   : std_logic_vector(c_reg_wide    -1 downto 0);

begin

  issue_retry_o   <= s_miss;
  issue_fault_o   <= '0';
  issue_pc_o      <= (others => '0');
  issue_pcf_o     <= (others => '0');
  issue_pcn_o     <= (others => '0');
  
  s_slow <= f_opa_slow_from_arg(regfile_arg_i);
  s_mul  <= f_opa_mul_from_slow(s_slow.raw);
  s_ldst <= f_opa_ldst_from_slow(s_slow.raw);
  s_shift<= f_opa_shift_from_slow(s_slow.raw);
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega     <= regfile_rega_i;
      r_regb     <= regfile_regb_i;
      r_stb1  <= regfile_stb_i;
      r_mode1 <= s_slow.mode;
      r_mode2 <= r_mode1;
      r_mode3 <= r_mode2;
      r_high1 <= s_mul.high;
      r_high2 <= r_high1;
      r_high3 <= r_high2;
    end if;
  end process;
  
  prim : opa_prim_mul
    generic map(
      g_wide   => c_reg_wide,
      g_regout => true,
      g_regwal => false,
      g_target => g_target)
    port map(
      clk_i    => clk_i,
      a_i      => regfile_rega_i,
      b_i      => regfile_regb_i,
      x_o      => s_product);

  s_mul_out <= 
    s_product(  c_reg_wide-1 downto          0) when r_high3='0' else
    s_product(2*c_reg_wide-1 downto c_reg_wide);
  
  s_virt_ad <= std_logic_vector(signed(r_rega) + signed(r_imm));
  
  s_l1_vtag <= s_virt_ad(s_l1_vtag'range);
  s_l1_vidx <= s_virt_ad(s_l1_vidx'range);
  s_l1_voff <= s_virt_ad(s_l1_voff'range);
  s_l1_wtag <= dbus_adr_i(s_l1_wtag'range);
  s_l1_widx <= dbus_adr_i(s_l1_widx'range);
  
  s_l1_went <= (not s_l1_wtag) & dbus_dat_i;
  l1d : opa_dpram
    generic map(
      g_width  => c_l1_ent_wide,
      g_size   => 2**c_l1_idx_wide,
      g_equal  => OPA_OLD,
      g_regin  => true,
      g_regout => false)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_addr_i => s_l1_vidx,
      r_data_o => s_l1_rent,
      w_en_i   => dbus_stb_i,
      w_addr_i => s_l1_widx,
      w_data_i => s_l1_went);
  
  s_l1_rtag <= not s_l1_rent(s_l1_rent'high downto s_l1_rdat'high+1);
  s_l1_rdat <= s_l1_rent(s_l1_rdat'range);
  
  -- !!! include valid bits; at the moment a partially loaded line can satisfy a load!
  s_miss <= f_opa_bit(r_l1_vtag /= s_l1_rtag) and r_l1_stb;
  
  -- Let the dbus know is we need to load something
  -- !!! replace r_l1_vtag with physical address
  dbus_stb_o <= s_miss;
  dbus_adr_o <= r_l1_vtag & r_l1_vidx & r_l1_voff(c_l1_idx_low-1 downto c_log_reg_bytes) & c_zero_off;
  
  -- 1-hot decode the size
  size : for i in 0 to c_l1_idx_low-1 generate
    s_sizes(i) <= f_opa_bit(unsigned(r_ldst1.size) = i);
  end generate;
  
  -- Rotate line data to align with requested load
  big_rotate : if c_big_endian generate
    s_size_sh <= s_sizes;
    s_l1_rot  <= std_logic_vector(rotate_left (unsigned(s_l1_rdat), to_integer(unsigned(r_l1_shift))*8));
  end generate;
  little_rotate : if not c_big_endian generate
    s_size_sh <= (others => '0');
    s_l1_rot  <= std_logic_vector(rotate_right(unsigned(s_l1_rdat), to_integer(unsigned(r_l1_shift))*8));
  end generate;
  
  -- Create the muxes for sign extension
  sext : for i in 0 to c_log_reg_bytes generate
    ext : if i < c_log_reg_bytes generate
      s_l1_mux(i)(c_reg_wide-1 downto 8*2**i) <= (others => s_l1_rot(8*2**i-1));
    end generate;
    s_l1_mux(i)(8*2**i-1 downto 0) <= s_l1_rot(8*2**i-1 downto 0);
  end generate;
  s_l1_sext <= s_l1_mux(to_integer(unsigned(r_ldst2.size)));
  
  -- use 'when' instead of 'and' because it helps synthesis realize this can be sync clear
  zext : for i in 0 to c_log_reg_bytes generate
    s_l1_clear(i) <= f_opa_bit(unsigned(r_ldst1.size) < i) and not r_ldst1.sext;
    s_l1_zext(8*2**i-1 downto 8*((2**i)/2)) <= 
      s_l1_sext(8*2**i-1 downto 8*((2**i)/2)) when r_l1_clear(i)='0' else (others => '0');
  end generate;
  
  l1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_imm      <= regfile_imm_i;
      r_ldst1    <= s_ldst;
      --
      r_l1_stb   <= r_stb1 and f_opa_bit(r_mode1 = c_opa_slow_load);
      r_l1_vtag  <= s_l1_vtag;
      r_l1_vidx  <= s_l1_vidx;
      r_l1_voff  <= s_l1_voff;
      r_l1_shift <= std_logic_vector(unsigned(s_l1_voff) + unsigned(s_size_sh));
      r_l1_clear <= s_l1_clear;
      r_ldst2    <= r_ldst1;
      --
      r_l1_dat  <= s_l1_zext;
    end if;
  end process;
  
  s_load_out <= r_l1_dat; -- !!! select the matching way
  
  -- Implement a shifter
  shifter : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_shift <= s_shift;
      -- sign extend the shifter
      if r_shift.sext = '0' then
        r_sexta <= (others => '0');
      else
        r_sexta <= (others => r_rega(r_rega'high));
      end if;
      r_sexta(r_rega'range) <= r_rega;
      -- calculate distance
      r_shamt <= (others => '0');
      if r_shift.right = '1' then
        r_shamt(c_log_reg_wide-1 downto 0) <= r_regb(c_log_reg_wide-1 downto 0);
      else
        if unsigned(r_regb(c_log_reg_wide-1 downto 0)) /= 0 then
          r_shamt <= std_logic_vector(0-unsigned(r_regb(r_shamt'range)));
        end if;
      end if;
      -- run the shifter
      r_shout <= s_shout(r_shout'range);
    end if;
  end process;
  s_shout <= std_logic_vector(rotate_right(unsigned(r_sexta), to_integer(unsigned(r_shamt))));
  
  -- pick the output
  with r_mode3 select
  regfile_regx_o <=
    s_mul_out       when c_opa_slow_mul,
    s_load_out      when c_opa_slow_load,
    r_shout         when c_opa_slow_shift,
    (others => '-') when others;

end rtl;
