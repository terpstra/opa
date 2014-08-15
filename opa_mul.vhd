library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_mul is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    issue_shift_i  : in  std_logic;
    issue_stb_i    : in  std_logic;
    issue_stat_i   : in  std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    issue_stb_o    : out std_logic;
    issue_kill_o   : out std_logic;
    issue_stat_o   : out std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_bakx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_aux_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
    
    regfile_stb_o  : out std_logic;
    regfile_bakx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0));
end opa_mul;

architecture rtl of opa_mul is

  constant c_decoders : natural := f_opa_decoders(g_config);

  signal r_rega : std_logic_vector(regfile_rega_i'range);
  signal r_regb : std_logic_vector(regfile_regb_i'range);
  signal r_regx  : std_logic_vector(regfile_rega_i'length*2-1 downto 0);
  signal r_aux1  : std_logic;
  signal r_aux2  : std_logic;

begin

  -- Everything we do has latency=2
  delay : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      issue_stb_o  <= issue_stb_i;
      issue_kill_o <= '0';
      if issue_shift_i = '1' then
        issue_stat_o <= std_logic_vector(unsigned(issue_stat_i) - c_decoders);
      else
        issue_stat_o <= issue_stat_i;
      end if;
    
      regfile_stb_o  <= regfile_stb_i;
      regfile_bakx_o <= regfile_bakx_i;
    end if;
  end process;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_rega <= regfile_rega_i;
      r_regb <= regfile_regb_i;
      r_aux1 <= regfile_aux_i(0);
      r_aux2 <= r_aux1;
      
      r_regx <= std_logic_vector(unsigned(r_rega) * unsigned(r_regb));
    end if;
  end process;
  
  regfile_regx_o <= 
    r_regx(r_rega'range) when r_aux2='0' else
    r_regx(r_rega'length*2-1 downto r_rega'length);

end rtl;
