library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_fast is
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
end opa_fast;

architecture rtl of opa_fast is

  constant c_num_stat : natural := f_opa_num_stat(g_config);
  constant c_decoders : natural := f_opa_decoders(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders-1 downto 0) := (others => '0');

  signal r_rega : std_logic_vector(regfile_rega_i'range);
  signal r_regb : std_logic_vector(regfile_regb_i'range);
  signal r_aux  : std_logic_vector(regfile_aux_i'range);

  type t_logic is array(natural range <>) of unsigned(1 downto 0);
  signal s_logic_in : t_logic(r_rega'range);
  
  signal s_immediate  : std_logic_vector(r_rega'range);
  signal s_logic      : std_logic_vector(r_rega'range);
  signal s_nota       : std_logic_vector(r_rega'range);
  signal s_notb       : std_logic_vector(r_rega'range);
  signal s_widea      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_wideb      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_widex      : std_logic_vector(r_rega'left+2 downto 0);
  signal s_adder      : std_logic_vector(r_rega'range);
  signal s_comparison : std_logic_vector(r_rega'range);
begin

  issue_final_o <= issue_stat_i when issue_shift_i='0' else (c_decoder_zeros & issue_stat_i(c_num_stat-1 downto c_decoders));
  issue_kill_o  <= (others => '0');
  
  regfile_stb_o  <= regfile_stb_i;
  regfile_bakx_o <= regfile_bakx_i;
  
  -- Register our inputs
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega <= regfile_rega_i;
      r_regb <= regfile_regb_i;
      r_aux  <= regfile_aux_i;
    end if;
  end process;
  
  -- Result is a sign-extended immediate
  s_immediate(7 downto 0) <= r_aux(7 downto 0);
  s_immediate(s_immediate'left downto 8) <= (others => r_aux(7));
  
  -- Result is a logic function
  logic : for i in r_rega'range generate
    s_logic_in(i)(1) <= r_rega(i);
    s_logic_in(i)(0) <= r_regb(i);
    s_logic(i) <= r_aux(to_integer(s_logic_in(i)));
  end generate;
  
  -- Result is an adder function
  s_nota <= (others => r_aux(0));
  s_notb <= (others => r_aux(1));
  s_widea(r_rega'left+2) <= '0';
  s_wideb(r_rega'left+2) <= '0';
  s_widea(r_rega'left+1 downto 1) <= r_rega xor s_nota;
  s_wideb(r_rega'left+1 downto 1) <= r_regb xor s_notb;
  s_widea(0) <= '1';
  s_wideb(0) <= r_aux(2);
  s_widex <= std_logic_vector(unsigned(s_widea) + unsigned(s_wideb));
  
  s_adder <= s_widex(r_rega'left+1 downto 1);
  s_comparison(0) <= s_widex(r_rega'left+2);
  s_comparison(r_rega'left downto 1) <= (others => '0');
  
  -- Send result to regfile
  with r_aux(r_aux'left downto r_aux'left-1) select
  regfile_regx_o <= 
    s_immediate     when "00",
    s_logic         when "01",
    s_adder         when "10",
    s_comparison    when "11",
    (others => '-') when others;

end rtl;
