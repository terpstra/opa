library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_ieu is
  generic(
    g_config   : t_opa_config);
  port(
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    
    iss_regx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    iss_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    
    aux_dat_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
    reg_data_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_datb_i : in  std_logic_vector(2**g_config.log_width-1 downto 0);
    reg_regx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    reg_datx_o : out std_logic_vector(2**g_config.log_width-1 downto 0));
end opa_ieu;

architecture rtl of opa_ieu is

  signal r_data : std_logic_vector(reg_data_i'range);
  signal r_datb : std_logic_vector(reg_datb_i'range);
  signal r_aux  : std_logic_vector(aux_dat_i'range);
  signal r_regx : std_logic_vector(iss_regx_i'range);
  signal r_regy : std_logic_vector(iss_regx_i'range);

  type t_logic is array(reg_data_i'range) of unsigned(1 downto 0);
  signal s_logic_in : t_logic;
  
  signal s_immediate  : std_logic_vector(reg_data_i'range);
  signal s_logic      : std_logic_vector(reg_data_i'range);
  signal s_nota       : std_logic_vector(reg_data_i'range);
  signal s_notb       : std_logic_vector(reg_data_i'range);
  signal s_widea      : std_logic_vector(reg_data_i'left+2 downto 0);
  signal s_wideb      : std_logic_vector(reg_data_i'left+2 downto 0);
  signal s_widex      : std_logic_vector(reg_data_i'left+2 downto 0);
  signal s_adder      : std_logic_vector(reg_data_i'range);
  signal s_comparison : std_logic_vector(reg_data_i'range);
begin

  iss_regx_o <= iss_regx_i; -- latency=1
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_data <= reg_data_i; -- OR immediate
      r_datb <= reg_datb_i;
      r_aux  <= aux_dat_i;
      r_regx <= iss_regx_i;
      r_regy <= r_regx;
    end if;
  end process;
  
  -- Result is a sign-extended immediate
  s_immediate(7 downto 0) <= r_aux(7 downto 0);
  s_immediate(s_immediate'left downto 8) <= (others => r_aux(7));
  
  -- Result is a logic function
  logic : for i in reg_data_i'range generate
    s_logic_in(i)(1) <= r_data(i);
    s_logic_in(i)(0) <= r_datb(i);
    s_logic(i) <= r_aux(to_integer(s_logic_in(i)));
  end generate;
  
  -- Result is an adder function
  s_nota <= (others => r_aux(0));
  s_notb <= (others => r_aux(1));
  s_widea(reg_data_i'left+2) <= '0';
  s_wideb(reg_data_i'left+2) <= '0';
  s_widea(reg_data_i'left+1 downto 1) <= r_data xor s_nota;
  s_wideb(reg_data_i'left+1 downto 1) <= r_data xor s_notb;
  s_widea(0) <= '1';
  s_wideb(0) <= r_aux(2);
  s_widex <= std_logic_vector(unsigned(s_widea) + unsigned(s_wideb));
  
  s_adder <= s_widex(reg_data_i'left+1 downto 1);
  s_comparison(0) <= s_widex(reg_data_i'left+2);
  s_comparison(reg_data_i'left downto 1) <= (others => '0');
  
  -- Send result to regfile
  reg_regx_o <= r_regy;
  with r_aux(r_aux'left downto r_aux'left-1) select
  reg_datx_o <= 
    s_immediate     when "00",
    s_logic         when "01",
    s_adder         when "10",
    s_comparison    when "11",
    (others => '-') when others;

end rtl;
