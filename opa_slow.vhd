library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_slow is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    issue_shift_i  : in  std_logic;
    issue_stat_i   : in  std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_ready_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_final_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_quash_o  : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_kill_o   : out std_logic_vector(f_opa_num_stat(g_config)-1 downto 0);
    issue_stall_o  : out std_logic;
    
    regfile_stb_i  : in  std_logic;
    regfile_rega_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_regb_i : in  std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0);
    regfile_bakx_i : in  std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_aux_i  : in  std_logic_vector(c_aux_wide-1 downto 0);
    
    regfile_stb_o  : out std_logic;
    regfile_bakx_o : out std_logic_vector(f_opa_back_wide(g_config)-1 downto 0);
    regfile_regx_o : out std_logic_vector(f_opa_reg_wide(g_config) -1 downto 0));
end opa_slow;

architecture rtl of opa_slow is

  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_num_stat  : natural := f_opa_num_stat(g_config);
  
  constant c_decoder_zeros : std_logic_vector(c_decoders-1 downto 0) := (others => '0');
  
  constant c_regout    : boolean := true;
  constant c_regwal    : boolean := c_reg_wide > 2*g_target.mul_width; -- needs wallace
  constant c_dsp_delay : natural := 2; -- registered input+output
  constant c_add_delay : natural := f_opa_choose(c_regout, c_dsp_delay+1, c_dsp_delay);
  constant c_wal_delay : natural := f_opa_choose(c_regwal, c_add_delay+1, c_add_delay);

  -- Control delay chain length should be delay-1
  type t_bak  is array(c_wal_delay-2 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  type t_stat is array(c_wal_delay-3 downto 0) of std_logic_vector(c_num_stat -1 downto 0);
  signal r_aux          : std_logic_vector(c_wal_delay-1 downto 0);
  signal r_regfile_stb  : std_logic_vector(c_wal_delay-2 downto 0);
  signal r_regfile_bakx : t_bak;
  signal r_issue_stat   : t_stat;
  
  signal s_product : std_logic_vector(2*c_reg_wide-1 downto 0);

  function f_shift(x : std_logic_vector; s : std_logic) return std_logic_vector is
    alias y : std_logic_vector(x'high downto x'low) is x;
    variable result : std_logic_vector(y'range) :=  y;
  begin
    if s = '1' then 
      result := c_decoder_zeros & y(y'high downto y'low+c_decoders);
    end if;
    return result;
  end f_shift;
  
begin

  issue_ready_o <= f_shift(r_issue_stat(r_issue_stat'low), issue_shift_i);
  issue_final_o <= f_shift(r_issue_stat(r_issue_stat'low), issue_shift_i);
  issue_quash_o <= (others => '0');
  issue_kill_o  <= (others => '0');
  issue_stall_o <= '0';

  delay : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_aux  <= regfile_aux_i(0) & r_aux(r_aux'high downto 1);
      
      r_regfile_stb(r_regfile_stb'high)   <= regfile_stb_i;
      r_regfile_bakx(r_regfile_bakx'high) <= regfile_bakx_i;
      
      if c_wal_delay > 2 then -- need the conditional to avoid null range warnings
        r_regfile_stb(r_regfile_stb'high-1 downto 0) <= r_regfile_stb(r_regfile_stb'high downto 1);
        for i in 0 to r_regfile_stb'high-1 loop
          r_regfile_bakx(i) <= r_regfile_bakx(i+1);
        end loop;
      end if;
      r_issue_stat(r_issue_stat'high) <= f_shift(issue_stat_i, issue_shift_i);
      if c_wal_delay > 3 then
        for i in 0 to c_wal_delay-4 loop
          r_issue_stat(i) <= f_shift(r_issue_stat(i+1), issue_shift_i);
        end loop;
      end if;
    end if;
  end process;
  
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
