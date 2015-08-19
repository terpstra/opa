library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_regfile is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i        : in  std_logic;
    rst_n_i      : in  std_logic;
    
    -- Which registers to read for each EU
    issue_stb_i  : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_bakx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_baka_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_bakb_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    issue_aux_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);

    -- The resulting register data
    eu_stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_rega_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    eu_regb_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0);
    eu_bakx_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_aux_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, c_aux_wide-1 downto 0);
    
    -- The results to record; bakx must arrive 1-cycle before regx
    eu_stb_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_bakx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    eu_regx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide(g_config) -1 downto 0));
end opa_regfile;

architecture rtl of opa_regfile is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_num_back  : natural := f_opa_num_back(g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  
  constant c_labels : t_opa_matrix := f_opa_labels(c_executers);
  constant c_ones : std_logic_vector(c_executers-1 downto 0) := (others => '1');
      
  -- Bypass logic. We combine:
  --   EU outputs (fast+slow)
  --   reg of last cycle
  --   memory block fetch
  --   immediate
  --
  -- For x EUs, that means 3*x + 1 inputs to each register.
  -- This fits perfectly into a 4:1 mux tree! (4, 7, 10, 13, ...)
  -- 
  -- We would like to arrange the tree to ensure two things:
  --   1- Common inputs are in the same position on the deepest level.
  --      This achieves the most possible sharing at bottom (only indexes differ)
  --   2- When some leaves can be higher in the tree, they are EUs (fast then slow)
  --
  -- With 2 EU (1 fast 1 slow):
  --  (fast0 fast0 fast0 fast0) \               this becomes a single leaf
  --  (slow0 slow0 slow0 slow0) |               ditto
  --  (reg0  reg0  reg0  reg0 ) +-- output      ditto
  --  (reg1  mem0  mem1  imm  ) /               only this requires a nested mux
  --
  -- For example, with 3 EU (2 fast, 1 slow):
  --  (fast0 fast0 fast0 fast0)  \              this becomes a single leaf
  --  (fast1 fast1 fast1 fast1)  |              ditto
  --  (slow0 reg0  reg1  reg2 )  +-- output     these are common to all EUs, so can be shared
  --  (mem0  mem1  mem2  imm  )  /              mem are specific to each EU, so no sharing possible
  -- 
  -- Another example, with 5 EU (3 fast, 2 slow):
  --  (fast0 fast1 fast2 slow0) \               common, so can be shared
  --  (slow1 reg0  reg1  reg2 ) |               ditto
  --  (reg3  reg4  mem0  mem1 ) +-- output      cannot be shared
  --  (mem2  mem3  mem4  imm  ) /               ditto
  --
  -- The approach is to list the items first by their natural indexes:
  --   0:fast0, 1:fast1, 2:slow0, 3:reg0, 4:reg1, 5:reg2, 6:mem0, 7:mem1, 8:mem2, 9:imm
  -- And then expand the lowest by 3 until the last touches the maximum value
  --   0=>0, 1=>4, 2=>8, 3=>9, 4=>10, 5=>11, 6=>12, 7=>13, 8=>14, 9=>15
  
  constant c_num_natural  : natural := c_executers*3 + 1;
  constant c_natural_wide : natural := f_opa_log2(c_num_natural);
  constant c_mux_wide     : natural := ((c_natural_wide+1)/2)*2; -- round-up to even
  constant c_num_mux      : natural := 2**c_mux_wide; -- is a power of 4, so (c_num_mux-1)%3=0
  constant c_num_short    : natural := (c_num_mux-c_num_natural) / 3;
  
  -- Calculate positions for terms in the mux tree
  function f_nat2mux(x : natural) return natural is
  begin
    if x < c_num_short then
      return x*4;
    else
      return x+c_num_short*3;
    end if;
  end f_nat2mux;
  
  function f_indexes(x : natural) return t_opa_matrix is
    variable result : t_opa_matrix(c_executers-1 downto 0, c_mux_wide-1 downto 0);
    variable row : unsigned(result'range(2));
  begin
    for i in result'range(1) loop
      row := to_unsigned(f_nat2mux(x+i), row'length);
      for j in result'range(2) loop
        result(i,j) := row(j);
      end loop;
    end loop;
    return result;
  end f_indexes;
  
  constant c_eu_indexes  : t_opa_matrix := f_indexes(c_executers*0);
  constant c_reg_indexes : t_opa_matrix := f_indexes(c_executers*1);
  constant c_mem_indexes : t_opa_matrix := f_indexes(c_executers*2);
  
  function f_eu (x : natural) return natural is begin return f_nat2mux(x+c_executers*0); end f_eu;
  function f_reg(x : natural) return natural is begin return f_nat2mux(x+c_executers*1); end f_reg;
  function f_mem(x : natural) return natural is begin return f_nat2mux(x+c_executers*2); end f_mem;
  constant c_imm : natural := c_num_mux-1;
  
  -- To keep the calculation as simple as possible, r_map will encode the MUX choice
  -- to take for values not accessed via bypass. Bypass if matches last or current EU
  -- wrote to the target address.
   
  signal r_stb         : std_logic_vector(c_executers-1 downto 0);
  signal r_bakx        : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_regx        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide -1 downto 0);
  
  signal s_map_set     : std_logic_vector(c_num_back-1 downto 0);
  signal s_map_match   : t_opa_matrix(c_num_back-1 downto 0, c_executers-1 downto 0);
  signal s_map_value   : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0);
  signal s_map         : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0);
  signal r_map         : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0) := (others => (others => '1'));
  
  signal s_eu_match_a  : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal s_eu_match_b  : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal s_reg_match_a : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal s_reg_match_b : t_opa_matrix(c_executers-1 downto 0, c_executers-1 downto 0);
  signal s_value_a     : t_opa_matrix(c_executers-1 downto 0, c_mux_wide -1 downto 0);
  signal s_value_b     : t_opa_matrix(c_executers-1 downto 0, c_mux_wide -1 downto 0);
  signal s_regfile_a   : t_opa_matrix(c_executers-1 downto 0, c_mux_wide -1 downto 0);
  signal s_regfile_b   : t_opa_matrix(c_executers-1 downto 0, c_mux_wide -1 downto 0);
  signal s_bypass_a    : std_logic_vector(c_executers-1 downto 0);
  signal s_bypass_b    : std_logic_vector(c_executers-1 downto 0);
  
  -- Synthesis tools bitch and moan if I use a 3D array, so use a quick-n-dirty hack function
  function f_idx(x : natural; y : natural) return natural is
  begin
    return y*c_executers+x;
  end f_idx;
  
  -- Need to map the matrix to something we can curry in a port mapping
  type t_address  is array(c_executers-1 downto 0) of std_logic_vector(c_back_wide-1 downto 0);
  type t_data_in  is array(c_executers-1 downto 0) of std_logic_vector(c_reg_wide-1 downto 0);
  type t_data_out is array(c_executers*c_executers-1 downto 0) of std_logic_vector(c_reg_wide-1 downto 0);
  
  signal s_ra_addr  : t_address;
  signal s_rb_addr  : t_address;
  signal s_ra_data  : t_data_out;
  signal s_rb_data  : t_data_out;
  signal s_w_addr   : t_address;
  signal s_w_data   : t_data_in;
  
  type t_mux is array(c_executers*c_reg_wide-1 downto 0) of std_logic_vector(c_num_mux-1 downto 0);
  signal s_mux_a     : t_mux;
  signal s_mux_b     : t_mux;
  signal r_mux_idx_a : t_opa_matrix(c_executers-1 downto 0, c_mux_wide-1 downto 0);
  signal r_mux_idx_b : t_opa_matrix(c_executers-1 downto 0, c_mux_wide-1 downto 0);
  
begin

  input : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      eu_stb_o  <= issue_stb_i;
      eu_bakx_o <= issue_bakx_i;
      eu_aux_o  <= issue_aux_i;
      r_stb  <= eu_stb_i;
      r_bakx <= eu_bakx_i;
      r_regx <= eu_regx_i;
    end if;
  end process;
  
  -- Calculate the new mapping from back registers to units
  s_map_match <= f_opa_match_index(c_num_back, eu_bakx_i) and f_opa_dup_row(c_num_back, eu_stb_i);
  s_map_set   <= f_opa_product(s_map_match, c_ones);
  s_map_value <= f_opa_product(s_map_match, c_mem_indexes);
  
  back_reg : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      for i in 0 to c_num_back-1 loop
        if s_map_set(i) = '1' then
          for b in 0 to c_mux_wide-1 loop
            r_map(i,b) <= s_map_value(i,b);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  -- Detect if we will need a bypass
  -- Note: it is impossible for a backing register to be writen in two consequetive cycles
  s_eu_match_a  <= f_opa_match(issue_baka_i, eu_bakx_i) and f_opa_dup_row(c_executers, eu_stb_i);
  s_eu_match_b  <= f_opa_match(issue_bakb_i, eu_bakx_i) and f_opa_dup_row(c_executers, eu_stb_i);
  s_reg_match_a <= f_opa_match(issue_baka_i, r_bakx)    and f_opa_dup_row(c_executers, r_stb);
  s_reg_match_b <= f_opa_match(issue_bakb_i, r_bakx)    and f_opa_dup_row(c_executers, r_stb);
  s_value_a     <= f_opa_product(s_eu_match_a, c_eu_indexes) or f_opa_product(s_reg_match_a, c_reg_indexes);
  s_value_b     <= f_opa_product(s_eu_match_b, c_eu_indexes) or f_opa_product(s_reg_match_b, c_reg_indexes);
  s_bypass_a    <= f_opa_product(s_eu_match_a, c_ones) or f_opa_product(s_reg_match_a, c_ones);
  s_bypass_b    <= f_opa_product(s_eu_match_b, c_ones) or f_opa_product(s_reg_match_b, c_ones);
  s_regfile_a   <= f_opa_compose(r_map, issue_baka_i);
  s_regfile_b   <= f_opa_compose(r_map, issue_bakb_i);
  
  mux_idx_a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      for u in 0 to c_executers-1 loop
        if s_bypass_a(u) = '1' then
          for b in 0 to c_mux_wide-1 loop
            r_mux_idx_a(u,b) <= s_value_a(u,b);
          end loop;
        else
          for b in 0 to c_mux_wide-1 loop
            r_mux_idx_a(u,b) <= s_regfile_a(u,b);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  mux_idx_b : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      for u in 0 to c_executers-1 loop
        if s_bypass_b(u) = '1' then
          for b in 0 to c_mux_wide-1 loop
            r_mux_idx_b(u,b) <= s_value_b(u,b);
          end loop;
        else
          for b in 0 to c_mux_wide-1 loop
            r_mux_idx_b(u,b) <= s_regfile_b(u,b);
          end loop;
        end if;
      end loop;
    end if;
  end process;
  
  remap_rf_in : for u in 0 to c_executers-1 generate
    s_ra_addr(u) <= f_opa_select_row(issue_baka_i, u);
    s_rb_addr(u) <= f_opa_select_row(issue_bakb_i, u);
    s_w_addr(u)  <= f_opa_select_row(r_bakx, u);
    s_w_data(u)  <= f_opa_select_row(eu_regx_i, u);
  end generate;

  ramsw : for w in 0 to c_executers-1 generate
    ramsr : for r in 0 to c_executers-1 generate
      rama : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_bypass => false,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => issue_stb_i(r),
          r_addr_i => s_ra_addr(r),
          r_data_o => s_ra_data(f_idx(r, w)),
          w_en_i   => r_stb(w),
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
      ramb : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_bypass => false,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_en_i   => issue_stb_i(r),
          r_addr_i => s_rb_addr(r),
          r_data_o => s_rb_data(f_idx(r, w)),
          w_en_i   => r_stb(w),
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
    end generate;
  end generate;
  
  -- Create the mux and demux it
  bypass : for u in 0 to c_executers-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      
      -- Select from dpram outputs
      regfile : for v in 0 to c_executers-1 generate
        s_mux_a(f_idx(u,b))(f_mem(v+1)-1 downto f_mem(v)) <= (others => s_ra_data(f_idx(u,v))(b));
        s_mux_b(f_idx(u,b))(f_mem(v+1)-1 downto f_mem(v)) <= (others => s_rb_data(f_idx(u,v))(b));
      end generate;
      
      -- Select from the registered outputs
      reg : for v in 0 to c_executers-1 generate
        s_mux_a(f_idx(u,b))(f_reg(v+1)-1 downto f_reg(v)) <= (others => r_regx(v,b));
        s_mux_b(f_idx(u,b))(f_reg(v+1)-1 downto f_reg(v)) <= (others => r_regx(v,b));
      end generate;
      
      -- Select from other EUs
      eu : for v in 0 to c_executers-1 generate
        s_mux_a(f_idx(u,b))(f_eu(v+1)-1 downto f_eu(v)) <= (others => eu_regx_i(v,b));
        s_mux_b(f_idx(u,b))(f_eu(v+1)-1 downto f_eu(v)) <= (others => eu_regx_i(v,b));
      end generate;
      
      -- Select from immediate !!!
      s_mux_a(f_idx(u,b))(c_imm) <= '1'; -- aux(b);
      s_mux_b(f_idx(u,b))(c_imm) <= '1'; -- aux(b);
      
      -- Execute the mux
      eu_rega_o(u,b) <= s_mux_a(f_idx(u,b))(to_integer(unsigned(f_opa_select_row(r_mux_idx_a,u))));
      eu_regb_o(u,b) <= s_mux_b(f_idx(u,b))(to_integer(unsigned(f_opa_select_row(r_mux_idx_b,u))));
    end generate;
  end generate;
  
end rtl;
