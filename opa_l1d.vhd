library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
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
    slow_size_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, 1 downto 0);
    slow_addr_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
    slow_data_i   : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
    slow_oldest_i : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_retry_o  : out std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_data_o   : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)-1 downto 0);
    
    dbus_stb_i    : in  std_logic;
    dbus_adr_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    dbus_dat_i    : in  std_logic_vector(c_dline_size*8          -1 downto 0);
    dbus_stb_o    : out std_logic;
    dbus_adr_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0));
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
  
  constant c_num_slow      : natural := f_opa_num_slow(g_config);
  constant c_num_ways      : natural := 1; -- for now
  constant c_reg_wide      : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide      : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide      : natural := f_opa_imm_wide(g_config);
  constant c_log_reg_wide  : natural := f_opa_log2(c_reg_wide);
  constant c_log_reg_bytes : natural := c_log_reg_wide - 3;
  constant c_line_bytes    : natural := c_dline_size;
  constant c_idx_low       : natural := f_opa_log2(c_line_bytes);
  constant c_idx_high      : natural := f_opa_log2(c_page_size);
  constant c_idx_wide      : natural := c_idx_high - c_idx_low;
  constant c_tag_wide      : natural := c_adr_wide - c_idx_high;
  constant c_ent_wide      : natural := c_tag_wide + c_dline_size*8;

  constant c_way_ones : std_logic_vector(c_num_ways     -1 downto 0) := (others => '1');
  
  signal s_wtag : std_logic_vector(c_adr_wide -1 downto c_idx_high);
  signal s_widx : std_logic_vector(c_idx_high -1 downto c_idx_low);
  signal s_woff : std_logic_vector(c_idx_low  -1 downto 0);
  signal s_wdat : std_logic_vector(8*c_dline_size-1 downto 0);
  signal s_went : std_logic_vector(c_ent_wide -1 downto 0);
  
  type t_tag  is array(natural range <>) of std_logic_vector(c_adr_wide-1 downto c_idx_high);
  type t_idx  is array(natural range <>) of std_logic_vector(c_idx_high-1 downto c_idx_low);
  type t_off  is array(natural range <>) of std_logic_vector(c_idx_low -1 downto 0);
  type t_ent  is array(natural range <>) of std_logic_vector(c_ent_wide-1 downto 0);
  type t_reg  is array(natural range <>) of std_logic_vector(c_reg_wide-1 downto 0);
  type t_way  is array(natural range <>) of std_logic_vector(c_num_ways-1 downto 0);
  type t_line is array(natural range <>) of std_logic_vector(8*c_dline_size-1 downto 0);
  type t_mux  is array(natural range <>) of std_logic_vector(c_log_reg_bytes  downto 0);
  type t_size is array(natural range <>) of std_logic_vector(1 downto 0);
  
  signal s_size  : t_size(c_num_slow-1 downto 0);
  signal s_vtag  : t_tag (c_num_slow-1 downto 0);
  signal s_vidx  : t_idx (c_num_slow-1 downto 0);
  signal s_voff  : t_off (c_num_slow-1 downto 0);
  signal s_adr   : t_opa_matrix(c_num_slow-1 downto 0, c_adr_wide-1 downto 0) := (others => (others => '0'));
  signal s_sizes : t_off (c_num_slow-1 downto 0);
  signal s_shift : t_off (c_num_slow-1 downto 0);
  signal s_rent  : t_ent (c_num_slow*c_num_ways-1 downto 0);
  signal s_rtag  : t_tag (c_num_slow*c_num_ways-1 downto 0);
  signal s_rdat  : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal s_match : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_miss  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_pick  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_rot   : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal s_mux   : t_mux (c_num_slow*c_num_ways*c_reg_wide-1 downto 0);
  signal s_sext  : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_clear : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal s_zext  : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_ways  : t_way (c_num_slow*c_reg_wide-1 downto 0);
  
  signal r_stb   : std_logic_vector(c_num_slow-1 downto 0);
  signal r_size  : t_size(c_num_slow-1 downto 0);
  signal r_vtag  : t_tag(c_num_slow-1 downto 0);
  signal r_vidx  : t_idx(c_num_slow-1 downto 0);
  signal r_voff  : t_off(c_num_slow-1 downto 0);
  signal r_shift : t_off(c_num_slow-1 downto 0);
  signal r_match : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_clear : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal r_zext  : t_reg (c_num_slow*c_num_ways-1 downto 0);
  
  function f_idx(p, w    : natural) return natural is begin return w*c_num_slow+p; end f_idx;
  function f_idx(p, w, b : natural) return natural is begin return (f_idx(p,w)*c_reg_wide)+b; end f_idx;
  function f_pow(m : natural) return natural is begin return 8*2**m; end f_pow;
  
begin

  s_wtag <= dbus_adr_i(s_wtag'range);
  s_widx <= dbus_adr_i(s_widx'range);
  s_wdat <= dbus_dat_i;
  s_went <= (not s_wtag) & s_wdat;
  
  ports : for p in 0 to c_num_slow-1 generate
    -- Select the address lines
    s_size(p) <= f_opa_select_row(slow_size_i, p);
    s_vtag(p) <= f_opa_select_row(slow_addr_i, p)(s_wtag'range);
    s_vidx(p) <= f_opa_select_row(slow_addr_i, p)(s_widx'range);
    s_voff(p) <= f_opa_select_row(slow_addr_i, p)(s_woff'range);
    
    -- Compute the data shift
    big_shift : if c_big_endian generate
      -- 1-hot decode the size
      size : for s in 0 to c_idx_low-1 generate
        s_sizes(p)(s) <= f_opa_bit(unsigned(s_size(p)) = s);
      end generate;
    end generate;
    little_shift : if not c_big_endian generate
      s_sizes(p) <= (others => '0');
    end generate;
    s_shift(p) <= std_logic_vector(unsigned(s_voff(p)) + unsigned(s_sizes(p)));
    
    -- If we miss, what to load first?
    tag_bits : for b in s_wtag'range generate -- !!! use physical address
      s_adr(p,b) <= r_vtag(p)(b);
    end generate;
    idx_bits : for b in s_widx'range generate
      s_adr(p,b) <= r_vidx(p)(b);
    end generate;
    off_bits : for b in s_woff'range generate
      s_adr(p,b) <= r_voff(p)(b);
    end generate;
    
    -- The L1d ways
    ways : for w in 0 to c_num_ways-1 generate
      l1d : opa_dpram
        generic map(
          g_width  => c_ent_wide,
          g_size   => 2**c_idx_wide,
          g_equal  => OPA_OLD,
          g_regin  => true,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_addr_i => s_vidx(p),
          r_data_o => s_rent(f_idx(p,w)),
          w_en_i   => dbus_stb_i,
          w_addr_i => s_widx,
          w_data_i => s_went);
      
      -- Split out the line contents
      s_rtag(f_idx(p,w)) <= not s_rent(f_idx(p,w))(s_went'high downto s_wdat'high+1);
      s_rdat(f_idx(p,w)) <= s_rent(f_idx(p,w))(s_wdat'range);
      
      -- !!! use physical address
      s_match(p,w) <= f_opa_bit(r_vtag(p) = s_rtag(f_idx(p,w)));
      -- !!! compute s_valid
      
      -- Rotate line data to align with requested load
      big_rotate : if c_big_endian generate
        s_rot(f_idx(p,w)) <= std_logic_vector(rotate_left (unsigned(s_rdat(f_idx(p,w))), to_integer(unsigned(r_shift(p)))*8));
      end generate;
      little_rotate : if not c_big_endian generate
        s_rot(f_idx(p,w)) <= std_logic_vector(rotate_right(unsigned(s_rdat(f_idx(p,w))), to_integer(unsigned(r_shift(p)))*8));
      end generate;
      
      -- Create the muxes for sign extension
      sext : for m in 0 to c_log_reg_bytes generate
        ext : if m < c_log_reg_bytes generate
          bits : for b in c_reg_wide-1 downto f_pow(m) generate
            s_mux(f_idx(p,w,b))(m) <= s_rot(f_idx(p,w))(f_pow(m)-1);
          end generate;
        end generate;
        bits : for b in f_pow(m)-1 downto 0 generate
          s_mux(f_idx(p,w,b))(m) <= s_rot(f_idx(p,w))(b);
        end generate;
      end generate;
      
      -- Apply the sign extension mux
      bits : for b in 0 to c_reg_wide-1 generate
        s_sext(f_idx(p,w))(b) <= s_mux(f_idx(p,w,b))(to_integer(unsigned(r_size(p))));
      end generate;
      
      -- use 'when' instead of 'and' because it helps synthesis realize this can be sync clear
      zext : for b in 0 to c_log_reg_bytes generate
        s_clear(p,b) <= f_opa_bit(unsigned(s_size(p)) < b) and not slow_sext_i(p);
        s_zext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) <= 
          s_sext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) when r_clear(p,b)='0' else (others => '0');
      end generate;
    end generate;
  end generate;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_stb   <= slow_stb_i;
      r_size  <= s_size;
      r_vtag  <= s_vtag;
      r_vidx  <= s_vidx;
      r_voff  <= s_voff;
      r_size  <= s_size;
      r_shift <= s_shift;
      r_clear <= s_clear;
      --
      r_match <= s_match;
      r_zext  <= s_zext;
    end if;
  end process;
  
  -- Let the dbus know we need to load something
  s_miss <= r_stb and not f_opa_product(s_match, c_way_ones);
  s_pick <= f_opa_pick_small(s_miss);
  dbus_stb_o <= f_opa_or(s_miss);
  dbus_adr_o <= f_opa_product(f_opa_transpose(s_adr), s_pick);
  
  -- Pick the matching way
  slow_retry_o <= s_miss;
  out_ports : for p in 0 to c_num_slow-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      ways : for w in 0 to c_num_ways-1 generate
        s_ways(f_idx(p,b))(w) <= r_zext(f_idx(p,w))(b);
      end generate;
      slow_data_o(p,b) <= f_opa_or(s_ways(f_idx(p,b)) and f_opa_select_row(r_match, p));
    end generate;
  end generate;
    
end rtl;
