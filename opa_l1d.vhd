library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_l1d is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    
    -- read/writes come from the slow EUs
    slow_stb_i    : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_we_i     : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_sext_i   : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_size_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, 2 downto 0);
    slow_adr_i    : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
    slow_dat_o    : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0)
    
    -- issue says when to finalize a write
    );   
end opa_l1d;

architecture rtl of opa_l1d is
  -- These memory layouts correspond to the RISC-V Sv32/39/48 format
  
  -- 16-bit memory layout is as follows:
  --  15:12 TLB   4KB pages
  --  11:4  cache line select
  --   3:0  cache line offset

  -- 32-bit memory layout is as follows:
  --  31:22 TLB   4MB pages
  --  21:12 TLB   4KB pages
  --  11:4  cache line select
  --   3:0  cache line offset

  -- 39-bit memory layout is as follows:
  --  38:30 TLB   1GB pages
  --  29:21 TLB   2MB pages
  --  20:12 TLB   4KB pages
  --  11:4  cache line select
  --   3:0  cache line offset
  
  -- 48-bit memory layout is as follows:
  --  49:39 TLB 512GB pages
  --  38:30 TLB   1GB pages
  --  29:21 TLB   2MB pages
  --  20:12 TLB   4KB pages
  --  11:4  cache line select
  --   3:0  cache line offset
  
  -- Each cache entry is laid out as follows:
  --  [(physical-bits) (valid mask) (dirty mask) (line)] * ways
  --  age for LRU is done using registers
  
  constant c_num_slow    : natural := f_opa_num_slow(g_config);
  constant c_reg_wide    : natural := f_opa_reg_wide(g_config);
  constant c_line_bytes  : natural := 16;  -- bytes
  constant c_line_depth  : natural := 256; -- 256*16 = page size
  constant c_phys_wide   : natural := g_config.dtlb_wide - 12;
  constant c_valid_wide  : natural := c_line_bytes;
  constant c_dirty_wide  : natural := c_line_bytes;
  constant c_line_wide   : natural := c_line_bytes*8;
  constant c_way_wide    : natural := c_phys_wide + c_valid_wide + c_dirty_wide + c_line_wide;
  constant c_dat_ways    : natural := g_config.dc_ways;
  constant c_cache_wide  : natural := c_dat_ways * c_way_wide;

  type t_valid_way  is array(natural range <>) of std_logic_vector(c_valid_wide-1 downto 0);
  type t_dirty_way  is array(natural range <>) of std_logic_vector(c_valid_wide-1 downto 0);
  type t_phys_way   is array(natural range <>) of std_logic_vector(c_phys_wide -1 downto 0);
  type t_line_way   is array(natural range <>) of std_logic_vector(c_line_wide -1 downto 0);
  type t_word_way   is array(natural range <>) of std_logic_vector(c_reg_wide  -1 downto 0);
  type t_valid_ways is array(natural range <>) of t_valid_way(c_dat_ways-1 downto 0);
  type t_dirty_ways is array(natural range <>) of t_dirty_way(c_dat_ways-1 downto 0);
  type t_phys_ways  is array(natural range <>) of t_phys_way (c_dat_ways-1 downto 0);
  type t_line_ways  is array(natural range <>) of t_line_way (c_dat_ways-1 downto 0);
  type t_word_ways  is array(natural range <>) of t_word_way (c_dat_ways-1 downto 0);
  
  signal s_valid_ways : t_valid_ways(c_num_slow-1 downto 0);
  signal s_dirty_ways : t_dirty_ways(c_num_slow-1 downto 0);
  signal s_phys_ways  : t_phys_ways (c_num_slow-1 downto 0);
  signal s_line_ways  : t_line_ways (c_num_slow-1 downto 0);
  signal s_line_shift : t_line_ways (c_num_slow-1 downto 0);
  signal r_word_ways  : t_word_ways (c_num_slow-1 downto 0);

  type t_cache     is array(natural range <>) of std_logic_vector(c_cache_wide-1 downto 0);
  type t_adr_shift is array(natural range <>) of std_logic_vector( 3 downto  0);
  type t_adr_line  is array(natural range <>) of std_logic_vector(12 downto  4);
  type t_adr_tlb0  is array(natural range <>) of std_logic_vector(22 downto 13);
  signal s_cache     : t_cache    (c_num_slow-1 downto 0);
  signal r_adr_shift : t_adr_shift(c_num_slow-1 downto 0);
  signal s_adr_line  : t_adr_line (c_num_slow-1 downto 0);
  signal s_adr_tlb0  : t_adr_tlb0 (c_num_slow-1 downto 0);
  
begin

  check_vspace :
    assert (4 <= g_config.log_width and g_config.log_width <= 6)
    report "low_width must be between 4 and 6 (16-bit to 64-bit) CPU"
    severity failure;
  
  check_vspace16 :
    assert (g_config.log_width /= 4 or g_config.dtlb_wide = 16)
    report "16-bit processors must use 16-bit dtlb_wide layout"
    severity failure;
  
  check_vspace32 :
    assert (g_config.log_width /= 5 or g_config.dtlb_wide = 32)
    report "32-bit processors must use 32-bit dtlb_wide layout"
    severity failure;

  check_vspace64 :
    assert (g_config.log_width /= 6 or g_config.dtlb_wide = 39 or g_config.dtlb_wide = 48)
    report "64-bit processors must use 39-bit or 48-bit dtlb_wide layout"
    severity failure;

  -- We duplicate L1 cache once per slow unit
  caches : for slow in 0 to c_num_slow-1 generate
    s_adr_line(slow) <= f_opa_select_row(slow_adr_i, slow)(12 downto 4);
    stage0 : process(clk_i) is
    begin
      if rising_edge(clk_i) then
        r_adr_shift(slow) <= f_opa_select_row(slow_adr_i, slow)(3 downto 0);
      end if;
    end process;
    
    cache : opa_dpram
      generic map(
        g_width  => c_cache_wide,
        g_size   => 256,
        g_bypass => false,
        g_regout => false)
      port map(
        clk_i    => clk_i,
        rst_n_i  => rst_n_i,
        r_addr_i => s_adr_line(slow),
        r_data_o => s_cache(slow),
        w_en_i   => '0',
        w_addr_i => (others => '0'),
        w_data_i => (others => '0'));
   
    ways : for way in 0 to c_dat_ways-1 generate
      s_phys_ways (slow)(way) <= s_cache(slow)(c_way_wide-1 downto c_valid_wide+c_dirty_wide+c_line_wide);
      s_valid_ways(slow)(way) <= s_cache(slow)(c_way_wide-c_phys_wide-1 downto c_dirty_wide+c_line_wide);
      s_dirty_ways(slow)(way) <= s_cache(slow)(c_way_wide-c_phys_wide-c_valid_wide downto c_line_wide);
      s_line_ways (slow)(way) <= s_cache(slow)(c_way_wide-c_phys_wide-c_valid_wide-c_dirty_wide downto 0);
      
      s_line_shift(slow)(way) <= 
        std_logic_vector(shift_left(
          unsigned(s_line_ways(slow)(way)),
          8*to_integer(unsigned(r_adr_shift(slow)))));
      
      stage1 : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          r_word_ways(slow)(way) <= s_line_shift(slow)(way)(c_line_wide-1 downto c_line_wide-c_reg_wide);
        end if;
      end process;
    end generate;
  end generate;
  
  -- 1: compare high bits to TLB phy tags, compare TLB tags to line tags, rotate lines
  -- 2: product of matches, sext lines, mux ways
  

end rtl;
