library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_regfile is
  generic(
    g_config       : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- Which registers to read for each EU
    iss_rega_i     : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    iss_regb_i     : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    -- Hints that can be used to implement multiported RAM
    iss_bypass_a_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
    iss_bypass_b_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
    iss_mux_a_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);
    iss_mux_b_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_executers(g_config)-1 downto 0);

    -- The resulting register data
    eu_data_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0);
    eu_datb_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0);
    -- The results to record
    eu_regx_i      : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_datx_i      : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, 2**g_config.log_width-1 downto 0)); 
end opa_regfile;

architecture rtl of opa_regfile is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_logsize   : natural := f_opa_back_wide(g_config);
  constant c_width     : natural := 2**g_config.log_width;
  
  -- Need to map the matrix to something we can curry in a port mapping
  type t_address  is array(c_executers-1 downto 0) of std_logic_vector(c_logsize-1 downto 0);
  type t_data_in  is array(c_executers-1 downto 0) of std_logic_vector(c_width-1   downto 0);
  type t_data_out is array(c_executers-1 downto 0, c_executers-1 downto 0) of std_logic_vector(c_width-1 downto 0);
  
  signal s_ra_addr  : t_address;
  signal s_rb_addr  : t_address;
  signal s_w_addr   : t_address;
  signal s_ra_data  : t_data_out;
  signal s_rb_data  : t_data_out;
  signal s_w_data   : t_data_in;
  
  signal r_bypass_a : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal r_bypass_b : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal r_mux_a    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal r_mux_b    : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  
  signal s_ram_a    : t_opa_matrix(c_executers-1 downto 0, 2**c_width-1 downto 0);
  signal s_ram_b    : t_opa_matrix(c_executers-1 downto 0, 2**c_width-1 downto 0);
  
  signal s_bypass_a : t_opa_matrix(c_executers-1 downto 0, 2**c_width-1 downto 0);
  signal s_bypass_b : t_opa_matrix(c_executers-1 downto 0, 2**c_width-1 downto 0);
  
  function f_my_dot(d : t_data_out; m : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0)) 
    return t_opa_matrix is
    variable result : t_opa_matrix(c_executers-1 downto 0, 2**c_width-1 downto 0);
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

  remap : for u in 0 to c_executers-1 generate
    s_ra_addr(u) <= f_opa_select_row(iss_rega_i, u);
    s_rb_addr(u) <= f_opa_select_row(iss_rega_i, u);
    s_w_addr(u)  <= f_opa_select_row(eu_regx_i, u);
    s_w_data(u)  <= f_opa_select_row(eu_datx_i, u);
  end generate;

  ramsw : for w in 0 to c_executers-1 generate
    ramsr : for r in 0 to c_executers-1 generate
      rama : opa_dpram
        generic map(
          g_width => c_width,
          g_size  => 2**f_opa_back_wide(g_config))-- NOT back_num
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => '1', -- !!! optimize
          r_addr_i => s_ra_addr(r),
          r_data_o => s_ra_data(r, w),
          w_en_i   => '1', 
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
      ramb : opa_dpram
        generic map(
          g_width => c_width,
          g_size  => 2**f_opa_back_wide(g_config))
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => '1',
          r_addr_i => s_rb_addr(r),
          r_data_o => s_rb_data(r, w),
          w_en_i   => '1', 
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
    end generate;
  end generate;
  
  -- Register our hints
  hint : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_bypass_a <= iss_bypass_a_i;
      r_bypass_b <= iss_bypass_b_i;
      r_mux_a <= iss_mux_a_i;
      r_mux_b <= iss_mux_b_i;
    end if;
  end process;
  
  -- Alternative: register reg[abx]_i and then decode them
  
  s_ram_a <= f_my_dot(s_ra_data, r_mux_a);
  s_ram_b <= f_my_dot(s_rb_data, r_mux_b);
  
  s_bypass_a <= f_opa_product(r_bypass_a, eu_datx_i);
  s_bypass_b <= f_opa_product(r_bypass_b, eu_datx_i);
  
  eu_data_o <= s_bypass_a or s_ram_a;
  eu_datb_o <= s_bypass_b or s_ram_b;
  
end rtl;
