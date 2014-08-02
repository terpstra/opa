library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_aux is
  generic(
    g_config       : t_opa_config);
  port(
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    
    -- What auxiliary data to record
    ren_stb_i  : in  std_logic;
    ren_stat_i : in  std_logic_vector(f_opa_stat_wide(g_config)-1 downto 0);
    ren_aux_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1 downto 0);
    
    -- Which registers to read for each EU
    iss_stat_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    iss_dec_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_decoders(g_config)-1 downto 0);
    -- The resulting register data
    eu_aux_o   : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0));
end opa_aux;

architecture rtl of opa_aux is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_decoders  : natural := f_opa_decoders (g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  
  -- Need to map the matrix to something we can curry in a port mapping
  type t_address  is array(c_executers-1 downto 0) of std_logic_vector(c_stat_wide-1 downto 0);
  type t_data_in  is array(c_decoders -1 downto 0) of std_logic_vector(c_aux_wide-1  downto 0);
  type t_data_out is array(c_executers-1 downto 0, c_decoders-1 downto 0) of std_logic_vector(c_aux_wide-1 downto 0);
  
  signal s_r_addr : t_address;
  signal s_r_data : t_data_out;
  signal s_w_data : t_data_in;
  
  signal r_mux    : t_opa_matrix(c_executers-1 downto 0, c_decoders-1 downto 0);
  
  function f_my_dot(d : t_data_out; m : t_opa_matrix(c_executers-1 downto 0, c_decoders-1 downto 0)) 
    return t_opa_matrix is
    variable result : t_opa_matrix(c_executers-1 downto 0, c_aux_wide-1 downto 0);
  begin
    for u in result'range(1) loop
      for b in result'range(2) loop
        result(u, b) := '0';
        for s in m'range(2) loop
          result(u, b) := result(u, b) or (d(u,s)(b) and m(u,s));
        end loop;
      end loop;
    end loop;
    return result;
  end f_my_dot;

begin

  remap_u : for u in 0 to c_executers-1 generate
    s_r_addr(u) <= f_opa_select_row(iss_stat_i, u);
  end generate;

  remap_d : for d in 0 to c_decoders-1 generate
    s_w_data(d) <= f_opa_select_row(ren_aux_i, d);
  end generate;

  rams_d : for d in 0 to c_decoders-1 generate
    rams_u : for u in 0 to c_executers-1 generate
      ramb : opa_dpram
        generic map(
          g_width => c_aux_wide,
          g_size  => 2**c_stat_wide)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => '1',
          r_addr_i => s_r_addr(u),
          r_data_o => s_r_data(u, d),
          w_en_i   => ren_stb_i, 
          w_addr_i => ren_stat_i,
          w_data_i => s_w_data(d));
    end generate;
  end generate;
  
  mux : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_mux <= iss_dec_i;
    end if;
  end process;
  
  eu_aux_o <= f_my_dot(s_r_data, r_mux);
  
end rtl;
