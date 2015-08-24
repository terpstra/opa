library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_fast is
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
end opa_fast;

architecture rtl of opa_fast is

  signal s_fast  : t_opa_fast;
  signal s_adder : t_opa_adder;

  signal r_rega : std_logic_vector(regfile_rega_i'range);
  signal r_regb : std_logic_vector(regfile_regb_i'range);
  signal r_imm  : std_logic_vector(regfile_imm_i'range);
  signal r_pc   : std_logic_vector(regfile_pc_i'range);
  signal r_pcf  : std_logic_vector(regfile_pcf_i'range);
  signal r_pcn  : std_logic_vector(regfile_pcn_i'range);
  
  signal r_lut  : std_logic_vector(3 downto 0);
  signal r_nota : std_logic;
  signal r_notb : std_logic;
  signal r_cin  : std_logic;
  signal r_sign : std_logic;
  signal r_mode : std_logic_vector(1 downto 0);

  type t_logic is array(natural range <>) of unsigned(1 downto 0);
  signal s_logic_in : t_logic(r_rega'range);
  
  signal s_logic      : std_logic_vector(r_rega'range);
  signal s_nota       : std_logic_vector(r_rega'range);
  signal s_notb       : std_logic_vector(r_rega'range);
  signal s_widea      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_wideb      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_widex      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_sum_low    : std_logic_vector(r_rega'range);
  signal s_comparison : std_logic_vector(r_rega'range);

  attribute dont_merge : boolean;
  attribute maxfan     : natural;
  
  -- Do not merge these registers; they are used in different places!
  attribute dont_merge of r_imm  : signal is true;
  attribute dont_merge of r_lut  : signal is true;
  attribute dont_merge of r_nota : signal is true;
  attribute dont_merge of r_notb : signal is true;
  attribute dont_merge of r_cin  : signal is true;
  attribute dont_merge of r_mode : signal is true;
  
  -- These are fanned out to 64 bits; make it easier to fit
  -- attribute maxfan of r_lut  : signal is 8;
  -- attribute maxfan of r_mode : signal is 8;
begin

  issue_fault_o <= '0';
  issue_pc_o    <= r_pc;
  issue_pcf_o   <= r_pcf;
  issue_pcn_o   <= r_pcn;
  
  s_fast  <= f_opa_fast_from_arg(regfile_arg_i);
  s_adder <= f_opa_adder_from_fast(s_fast.table);
  
  -- Register our inputs
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega <= regfile_rega_i;
      r_regb <= regfile_regb_i;
      r_imm  <= regfile_imm_i;
      r_pc   <= regfile_pc_i;
      r_pcf  <= regfile_pcf_i;
      r_pcn  <= regfile_pcn_i;
      
      r_mode <= s_fast.mode;
      r_lut  <= s_fast.table;
      r_nota <= s_adder.nota;
      r_notb <= s_adder.notb;
      r_cin  <= s_adder.cin;
      r_sign <= s_adder.sign;
    end if;
  end process;
  
  -- Result is a logic function
  logic : for i in r_rega'range generate
    s_logic_in(i)(1) <= r_rega(i);
    s_logic_in(i)(0) <= r_regb(i);
    s_logic(i) <= r_lut(to_integer(s_logic_in(i)));
  end generate;
  
  -- Result is an adder function
  s_nota <= (others => r_nota);
  s_notb <= (others => r_notb);
  s_widea(r_rega'left+2) <= '0';
  s_wideb(r_rega'left+2) <= '0';
  s_widea(r_rega'left+1 downto 1) <= r_rega xor s_nota;
  s_wideb(r_rega'left+1 downto 1) <= r_regb xor s_notb;
  s_widea(0) <= '1';
  s_wideb(0) <= r_cin;
  s_widex <= std_logic_vector(unsigned(s_widea) + unsigned(s_wideb));
  
  s_sum_low <= s_widex(r_rega'left+1 downto 1);
  s_comparison(0) <= s_widex(r_rega'left+2) xor ((r_rega(31) xor r_regb(31)) and r_sign);
  s_comparison(r_rega'left downto 1) <= (others => '0');
  
  -- Send result to regfile
  with r_mode select
  regfile_regx_o <= 
    s_logic         when c_opa_fast_lut,
    s_sum_low       when c_opa_fast_addl,
    s_comparison    when c_opa_fast_addh,
    (others => '-') when others;
  
  -- !!! test pcn
  
end rtl;
