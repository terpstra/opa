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

  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  
  constant c_regout    : boolean := c_reg_wide >   g_target.mul_width; -- needs an adder
  constant c_regwal    : boolean := c_reg_wide > 2*g_target.mul_width; -- needs wallace
  constant c_dsp_delay : natural := 2; -- registered input+output
  constant c_add_delay : natural := f_opa_choose(c_regout, c_dsp_delay+1, c_dsp_delay);
  constant c_wal_delay : natural := f_opa_choose(c_regwal, c_add_delay+1, c_add_delay);

  -- Control delay chain length should be delay-1
  type t_stat is array(c_wal_delay-2 downto 0) of unsigned(c_stat_wide-1 downto 0);
  type t_bak  is array(c_wal_delay-2 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  signal r_issue_stb    : std_logic_vector(c_wal_delay-2 downto 0);
  signal r_issue_stat   : t_stat;
  signal r_regfile_stb  : std_logic_vector(c_wal_delay-2 downto 0);
  signal r_regfile_bakx : t_bak;
  signal r_aux          : std_logic_vector(c_wal_delay-1 downto 0);
  
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);

begin

  delay : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_regfile_stb <= regfile_stb_i    & r_regfile_stb(r_regfile_stb'high downto 1);
      r_issue_stb   <= issue_stb_i      & r_issue_stb  (r_issue_stb'high   downto 1);
      r_aux         <= regfile_aux_i(0) & r_aux        (r_aux'high         downto 1);
      
      r_regfile_bakx(r_regfile_bakx'high) <= regfile_bakx_i;
      for i in 0 to r_regfile_bakx'high-1 loop
        r_regfile_bakx(i) <= r_regfile_bakx(i+1);
      end loop;
      
      if issue_shift_i = '1' then
        r_issue_stat(r_issue_stat'high) <= unsigned(issue_stat_i) - c_decoders;
      else
        r_issue_stat(r_issue_stat'high) <= unsigned(issue_stat_i);
      end if;
      
      for i in 0 to r_issue_stat'high-1 loop
        if issue_shift_i = '1' then
          r_issue_stat(i) <= r_issue_stat(i+1) - c_decoders;
        else
          r_issue_stat(i) <= r_issue_stat(i+1);
        end if;
      end loop;
    end if;
  end process;
  
  issue_kill_o <= '0';
  issue_stb_o  <= r_issue_stb(0);
  issue_stat_o <= std_logic_vector(r_issue_stat(0));
  
  regfile_stb_o  <= r_regfile_stb(0);
  regfile_bakx_o <= r_regfile_bakx(0);
  
  prim : opa_prim_mul
    generic map(
      g_wide   => c_reg_wide,
      g_regout => c_regout,
      g_regwal => c_regwal,
      g_target => g_target)
    port map(
      clk_i    => clk_i,
      a_i      => regfile_rega_i,
      b_i      => regfile_regb_i,
      x_o      => s_product);

  regfile_regx_o <= 
    s_product(  c_reg_wide-1 downto          0) when r_aux(0)='0' else
    s_product(2*c_reg_wide-1 downto c_reg_wide);

end rtl;
