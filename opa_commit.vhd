library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_commit is
  generic(
    g_config : t_opa_config);
  port(
    clk_i        : in  std_logic;
    rst_n_i      : in  std_logic;
    mispredict_o : out std_logic;
    
    -- Let the renamer see our map for rollback and tell it when commiting
    rename_map_o : out t_opa_matrix(2**g_config.log_arch-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_stb_o : out std_logic;
    
    -- Snoop on the issuer state to make commit decisions
    issue_regx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bak_i  : in  std_logic_vector(f_opa_back_num(g_config)-1 downto 0);
    issue_mask_o : out std_logic_vector(2*g_config.num_stat-1 downto 0);
    
    -- FIFO feeds us registers for permuting into arch map
    fifo_step_o  : out std_logic;
    fifo_bakx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    fifo_setx_i  : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    fifo_regx_i  : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    
    -- We pump out to the FIFO
    fifo_we_o    : out std_logic;
    fifo_bakx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0));
end opa_commit;

architecture rtl of opa_commit is

  constant c_regs      : natural := 2**g_config.log_arch;
  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  
  constant c_ones1 : std_logic_vector(c_decoders-1  downto 0) := (others => '1');
  constant c_ones2 : std_logic_vector(c_executers-1 downto 0) := (others => '1');
  constant c_one   : std_logic_vector(0 downto 0)             := "1";
  
  function f_LL_triangle(n : natural) return t_opa_matrix is
    variable result : t_opa_matrix(n-1 downto 0, n-1 downto 0);
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i,j) := f_opa_bit(i > j);
      end loop;
    end loop;
    return result;
  end f_LL_triangle;
  
  constant c_LL_triangle : t_opa_matrix := f_LL_triangle(c_decoders);
  
  signal s_already_done : std_logic_vector(c_decoders-1 downto 0);
  signal s_now_done     : std_logic_vector(c_decoders-1 downto 0);
  signal s_done         : std_logic;
  
  signal r_we           : std_logic;
  signal r_bakx         : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal r_setx         : std_logic_vector(c_decoders-1 downto 0);
  signal r_regx         : t_opa_matrix(c_decoders-1 downto 0, g_config.log_arch-1 downto 0);
  
  signal r_map          : t_opa_matrix(c_regs-1     downto 0, c_back_wide-1 downto 0);
  signal s_map_writers  : t_opa_matrix(c_regs-1     downto 0, c_decoders-1  downto 0);
  signal s_map_source   : t_opa_matrix(c_regs-1     downto 0, c_decoders    downto 0);
  signal s_map          : t_opa_matrix(c_regs-1     downto 0, c_back_wide-1 downto 0);
  signal s_old_map      : t_opa_matrix(c_decoders-1 downto 0, c_back_wide-1 downto 0);
  signal s_match        : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_overwrites   : t_opa_matrix(c_decoders-1 downto 0, c_decoders-1  downto 0);
  signal s_useless      : std_logic_vector(c_decoders-1 downto 0);
  
  signal r_mask         : std_logic_vector(2*g_config.num_stat-1 downto 0);
  signal r_mispredict   : std_logic;

begin

  -- Calculate if we can commit.
  s_already_done <= f_opa_compose(issue_bak_i, fifo_bakx_i);
  s_now_done <= f_opa_product(f_opa_match(fifo_bakx_i, issue_regx_i), c_ones2);
  s_done <= f_opa_bit((s_already_done or s_now_done) = c_ones1);
  
  -- Let the renamer see the committed state
  rename_map_o <= r_map;
  rename_stb_o <= s_done;

  -- Pump the FIFO, with some delay for timing
  fifo_step_o <= s_done;
  edge1 : process(clk_i) is 
  begin
    if rising_edge(clk_i) then
      r_we   <= s_done;
      r_bakx <= fifo_bakx_i;
      r_setx <= fifo_setx_i;
      r_regx <= fifo_regx_i;
    end if;
  end process;
  
  -- Calculate update to the architectural state
  s_map_writers <= f_opa_match_index(c_regs, r_regx) and f_opa_dup_row(c_regs, r_setx);
  s_map_source  <= f_opa_pick(f_opa_concat(f_opa_dup_row(c_regs, c_one), s_map_writers));
  s_map         <= f_opa_product(f_opa_split2(1, s_map_source), r_bakx);
  
  -- Calculate which backing registers are released upon commit
  s_old_map    <= f_opa_compose(r_map, r_regx);
  s_match      <= f_opa_match(r_regx, r_regx);
  s_overwrites <= s_match and f_opa_dup_row(c_decoders, r_setx) and c_LL_triangle;
  s_useless    <= f_opa_product(s_overwrites, c_ones1) or not r_setx;
  
  -- Feed the FIFO
  fifo_we_o <= r_we;
  free : for i in 0 to c_decoders-1 generate
    bits : for b in 0 to c_back_wide-1 generate
      fifo_bakx_o(i,b) <= r_bakx(i,b) when s_useless(i)='1' else s_old_map(i,b);
    end generate;
  end generate;
  
  -- Write the new architectural state
  edge2r : process(rst_n_i, clk_i) is
    variable value : std_logic_vector(r_map'range(2));
  begin
    if rst_n_i = '0' then
      for i in r_map'range(1) loop
        -- backing register 0 = the garbage register
        value := std_logic_vector(to_unsigned(i+1, r_map'length(2)));
        for j in r_map'range(2) loop
          r_map(i,j) <= value(j);
        end loop;
      end loop;
    elsif rising_edge(clk_i) then
      for i in r_map'range(1) loop
        if (r_we and not s_map_source(i, c_decoders)) = '1' then
          for j in r_map'range(2) loop
            r_map(i,j) <= s_map(i,j);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  -- Advance the priority mask
  edge2m : process(r_mispredict, clk_i) is
  begin
    if r_mispredict = '1' then
      r_mask <= (others => '0');
      for i in 0 to g_config.num_stat-1 loop
        r_mask(i) <= '1';
      end loop;
    elsif rising_edge(clk_i) then
      if r_we = '1' then
        if r_mask(2*g_config.num_stat-c_decoders-1) = '1' then
          r_mask <= (others => '0');
          for i in 0 to g_config.num_stat-1 loop
            r_mask(i) <= '1';
          end loop;
        else
          r_mask <= std_logic_vector(unsigned(r_mask) rol c_decoders);
        end if;
      end if;
    end if;
  end process;
  issue_mask_o <= r_mask;
  
  -- Pulse mispredict for one cycle once reset ends
  mispredict_o <= r_mispredict and rst_n_i;
  mispredict : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_mispredict <= '1';
    elsif rising_edge(clk_i) then
      r_mispredict <= '0';
    end if;
  end process;
  
end rtl;
