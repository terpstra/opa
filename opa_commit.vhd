library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_commit is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    
    -- Instructions to commit from the issue stage
    issue_shift_i : in  std_logic;
    issue_kill_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    issue_archx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    issue_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Let the renamer see our map for rollback and tell it when commiting
    rename_kill_o : out std_logic;
    rename_map_o  : out t_opa_matrix(f_opa_num_arch(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_bakx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
end opa_commit;

architecture rtl of opa_commit is

  constant c_num_arch  : natural := f_opa_num_arch(g_config);
  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);

  constant c_ones : std_logic_vector(c_decoders-1 downto 0) := (others => '1');
  
  function f_LL_triangle(n : natural) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i,j) := f_opa_bit(i < j);
      end loop;
    end loop;
    return result;
  end f_LL_triangle;
  
  constant c_LL_triangle : t_opa_matrix := f_LL_triangle(c_decoders);
  
  signal s_map_writers  : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_source   : t_opa_matrix(c_num_arch-1 downto 0, c_decoders-1  downto 0);
  signal s_map_mux      : std_logic_vector(c_num_arch-1 downto 0);
  signal s_map_value    : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal s_map          : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);
  signal r_map          : t_opa_matrix(c_num_arch-1 downto 0, c_back_wide-1 downto 0);

  signal s_old_map      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_overwrites   : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_useless      : std_logic_vector(c_decoders-1 downto 0);

begin

  -- Calculate update to the architectural state
  s_map_writers <= f_opa_match_index(c_num_arch, issue_archx_i) and 
                   f_opa_dup_row(c_num_arch, issue_setx_i);
  s_map_mux     <= f_opa_product(s_map_writers, c_ones);
  s_map_source  <= f_opa_pick_big(s_map_writers);
  s_map_value   <= f_opa_product(s_map_source, issue_bakx_i);
  
  arch : for i in 0 to c_num_arch-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      s_map(i,b) <= s_map_value(i,b) when s_map_mux(i)='1' else r_map(i,b);
    end generate;
  end generate;
  
  -- Write the new architectural state
  edge2r : process(rst_n_i, clk_i) is
    variable value : std_logic_vector(r_map'range(2));
  begin
    if rst_n_i = '0' then
      for i in r_map'range(1) loop
        value := std_logic_vector(to_unsigned(i, r_map'length(2)));
        for j in r_map'range(2) loop
          r_map(i,j) <= value(j);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      if issue_shift_i = '1' then
        r_map <= s_map;
      end if;
    end if;
  end process;
  
  rename_kill_o <= not rst_n_i; -- !!! fix me.
  rename_map_o <= r_map;
  
  -- Calculate which backing registers are released upon commit
  s_overwrites <= f_opa_match(issue_archx_i, issue_archx_i) and c_LL_triangle;
  s_useless   <= f_opa_product(s_overwrites, issue_setx_i) or not issue_setx_i;
  s_old_map   <= f_opa_compose(r_map, issue_archx_i);
   
  free : for i in 0 to c_decoders-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      rename_bakx_o(i,b) <= issue_bakx_i(i,b) when s_useless(i)='1' else s_old_map(i,b);
    end generate;
  end generate;

end rtl;
