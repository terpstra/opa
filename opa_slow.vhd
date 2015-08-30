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
    
    issue_fault_o  : out std_logic;
    issue_pc_o     : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align);
    issue_pcf_o    : out std_logic_vector(f_opa_fetch_wide(g_config)-1 downto c_op_align);
    issue_pcn_o    : out std_logic_vector(f_opa_adr_wide  (g_config)-1 downto c_op_align));
end opa_slow;

architecture rtl of opa_slow is

  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  
  signal s_slow : t_opa_slow;
  signal s_mul  : t_opa_mul;
  
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);
  
  signal r_mode1 : std_logic_vector(1 downto 0);
  signal r_mode2 : std_logic_vector(1 downto 0);
  signal r_mode3 : std_logic_vector(1 downto 0);
  signal r_high1 : std_logic;
  signal r_high2 : std_logic;
  signal r_high3 : std_logic;

begin

  issue_fault_o <= '0';
  issue_pc_o    <= (others => '0');
  issue_pcf_o   <= (others => '0');
  issue_pcn_o   <= (others => '0');
  
  s_slow <= f_opa_slow_from_arg(regfile_arg_i);
  s_mul  <= f_opa_mul_from_slow(s_slow.raw);
  
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

  regfile_regx_o <= 
    s_product(  c_reg_wide-1 downto          0) when r_high3='0' else
    s_product(2*c_reg_wide-1 downto c_reg_wide);
  
  -- !!! include a shifter and ldst

end rtl;
