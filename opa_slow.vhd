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
    dbus_dat_i     : in  std_logic_vector(f_opa_reg_wide  (g_config)-1 downto 0);
    dbus_stb_o     : out std_logic;
    dbus_adr_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto 0);
    
    issue_fault_o  : out std_logic;
    issue_pc_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    issue_pcf_o    : out std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    issue_pcn_o    : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align));
end opa_slow;

architecture rtl of opa_slow is

  constant c_reg_wide      : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide      : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide      : natural := f_opa_imm_wide(g_config);
  constant c_l1_line_bytes : natural := c_reg_wide/8;
  constant c_l1_line_low   : natural := f_opa_log2(c_l1_line_bytes);
  constant c_l1_line_high  : natural := f_opa_log2(c_page_size);
  constant c_l1_line_wide  : natural := c_l1_line_high - c_l1_line_low;
  constant c_l1_tag_wide   : natural := c_adr_wide - c_l1_line_high;
  constant c_l1_ent_wide   : natural := c_l1_tag_wide + c_reg_wide;
  
  constant c_zero_off : std_logic_vector(c_l1_line_low-1 downto 0) := (others => '0');
  
  signal s_slow : t_opa_slow;
  signal s_mul  : t_opa_mul;
  signal s_ldst : t_opa_ldst;
  
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);
  signal s_mul_out : std_logic_vector(  c_reg_wide-1 downto 0);
  
  signal r_mode1 : std_logic_vector(1 downto 0);
  signal r_mode2 : std_logic_vector(1 downto 0);
  signal r_mode3 : std_logic_vector(1 downto 0);
  signal r_high1 : std_logic;
  signal r_high2 : std_logic;
  signal r_high3 : std_logic;
  
  signal r_rega    : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_imm     : std_logic_vector(c_imm_wide-1 downto 0);
  signal s_virt_ad : std_logic_vector(c_reg_wide    -1 downto 0);
  signal s_l1_wtag : std_logic_vector(c_adr_wide    -1 downto c_l1_line_high);
  signal s_l1_widx : std_logic_vector(c_l1_line_high-1 downto c_l1_line_low);
  signal s_l1_went : std_logic_vector(c_l1_ent_wide -1 downto 0);
  signal s_l1_vtag : std_logic_vector(c_adr_wide    -1 downto c_l1_line_high);
  signal s_l1_vidx : std_logic_vector(c_l1_line_high-1 downto c_l1_line_low);
  signal s_l1_voff : std_logic_vector(c_l1_line_low -1 downto 0);
  signal r_l1_vtag : std_logic_vector(c_adr_wide    -1 downto c_l1_line_high);
  signal r_l1_vidx : std_logic_vector(c_l1_line_high-1 downto c_l1_line_low);
  signal r_l1_voff : std_logic_vector(c_l1_line_low -1 downto 0);
  signal s_l1_rent : std_logic_vector(c_l1_ent_wide -1 downto 0);
  signal s_l1_rtag : std_logic_vector(c_adr_wide    -1 downto c_l1_line_high);
  signal s_l1_rdat : std_logic_vector(c_reg_wide    -1 downto 0);
  signal r_l1_rdat : std_logic_vector(c_reg_wide    -1 downto 0);
  signal s_load_out: std_logic_vector(c_reg_wide    -1 downto 0);
  
  signal s_miss    : std_logic;

begin

  issue_fault_o <= '0';
  issue_pc_o    <= (others => '0');
  issue_pcf_o   <= (others => '0');
  issue_pcn_o   <= (others => '0');
  
  s_slow <= f_opa_slow_from_arg(regfile_arg_i);
  s_mul  <= f_opa_mul_from_slow(s_slow.raw);
  s_ldst <= f_opa_ldst_from_slow(s_slow.raw);
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
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
      g_width  => c_reg_wide + c_l1_tag_wide,
      g_size   => 2**c_l1_line_wide,
      g_bypass => false,
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
  
  s_l1_rtag <= not s_l1_rent(s_l1_rent'high downto c_reg_wide);
  s_l1_rdat <= s_l1_rent(s_l1_rdat'range);
  
  s_miss <= f_opa_bit(r_l1_vtag /= s_l1_rtag and r_mode1 = c_opa_slow_load);
  
  -- Let the dbus know is we need to load something
  dbus_stb_o <= s_miss;
  dbus_adr_o <= r_l1_vtag & r_l1_vidx & c_zero_off; -- !!! fill in with physical address
  
  l1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega    <= regfile_rega_i;
      r_imm     <= regfile_imm_i;
      r_l1_vtag <= s_l1_vtag;
      r_l1_vidx <= s_l1_vidx;
      r_l1_voff <= s_l1_voff;
      r_l1_rdat <= s_l1_rdat; -- !!! rotate and sign-extend before here
    end if;
  end process;
  
  s_load_out <= r_l1_rdat; -- !!! select the matching way
  
  -- !!! include a shifter
  with r_mode3 select
  regfile_regx_o <=
    s_mul_out       when c_opa_slow_mul,
    s_load_out      when c_opa_slow_load,
    (others => '-') when others;

end rtl;
