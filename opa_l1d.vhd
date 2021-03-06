--  opa: Open Processor Architecture
--  Copyright (C) 2014-2016  Wesley W. Terpstra
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  To apply the GPL to my VHDL, please follow these definitions:
--    Program        - The entire collection of VHDL in this project and any
--                     netlist or floorplan derived from it.
--    System Library - Any macro that translates directly to hardware
--                     e.g. registers, IO pins, or memory blocks
--    
--  My intent is that if you include OPA into your project, all of the HDL
--  and other design files that go into the same physical chip must also
--  be released under the GPL. If this does not cover your usage, then you
--  must consult me directly to receive the code under a different license.

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
    g_isa    : t_opa_isa;
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
    
    -- Share information about the addresses we are loading/storing
    issue_store_o : out std_logic;
    issue_load_o  : out std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    issue_addr_o  : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_alias_high(g_isa) downto f_opa_alias_low(g_config));
    issue_mask_o  : out t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)/8-1 downto 0);
    
    -- L1d requests action
    dbus_req_o    : out t_opa_dbus_request;
    dbus_radr_o   : out std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    dbus_way_o    : out std_logic_vector(f_opa_num_dway  (g_config)  -1 downto 0);
    dbus_wadr_o   : out std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    dbus_dirty_o  : out std_logic_vector(f_opa_dline_size(g_config)  -1 downto 0);
    dbus_data_o   : out std_logic_vector(f_opa_dline_size(g_config)*8-1 downto 0);
    
    dbus_busy_i   : in  std_logic; -- can accept a req_i
    dbus_we_i     : in  std_logic_vector(f_opa_num_dway  (g_config)  -1 downto 0);
    dbus_adr_i    : in  std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    dbus_valid_i  : in  std_logic_vector(f_opa_dline_size(g_config)  -1 downto 0);
    dbus_data_i   : in  std_logic_vector(f_opa_dline_size(g_config)*8-1 downto 0);
    
    pbus_stall_i  : in  std_logic;
    pbus_req_o    : out std_logic;
    pbus_we_o     : out std_logic;
    pbus_addr_o   : out std_logic_vector(f_opa_adr_wide(g_config)  -1 downto 0);
    pbus_sel_o    : out std_logic_vector(f_opa_reg_wide(g_config)/8-1 downto 0);
    pbus_dat_o    : out std_logic_vector(f_opa_reg_wide(g_config)  -1 downto 0);
    
    pbus_pop_o    : out std_logic;
    pbus_full_i   : in  std_logic;
    pbus_err_i    : in  std_logic;
    pbus_dat_i    : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0));
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
  --  [(dirty bit) (high-physical-bits) (valid mask) (line data)] * ways
  
  constant c_big_endian    : boolean := f_opa_big_endian(g_isa);
  constant c_num_slow      : natural := f_opa_num_slow(g_config);
  constant c_num_ways      : natural := f_opa_num_dway(g_config);
  constant c_reg_wide      : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide      : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide      : natural := f_opa_imm_wide(g_isa);
  constant c_page_size     : natural := f_opa_page_size(g_isa);
  constant c_dline_size    : natural := f_opa_dline_size(g_config);
  constant c_alias_low     : natural := f_opa_alias_low(g_config);
  constant c_alias_high    : natural := f_opa_alias_high(g_isa);
  constant c_reg_bytes     : natural := c_reg_wide/8;
  constant c_log_reg_wide  : natural := f_opa_log2(c_reg_wide);
  constant c_log_reg_bytes : natural := c_log_reg_wide - 3;
  constant c_line_bytes    : natural := c_dline_size;
  constant c_tag_high      : natural := c_adr_wide-1;
  constant c_tag_low       : natural := f_opa_log2(c_page_size); 
  constant c_idx_high      : natural := c_tag_low-1;
  constant c_idx_low       : natural := f_opa_log2(c_line_bytes);
  constant c_off_high      : natural := c_idx_low-1;
  constant c_off_low       : natural := c_log_reg_bytes;
  constant c_sub_high      : natural := c_log_reg_bytes-1;
  constant c_sub_low       : natural := 0;
  constant c_tag_wide      : natural := c_tag_high+1 - c_tag_low;
  constant c_idx_wide      : natural := c_idx_high+1 - c_idx_low;
  constant c_off_wide      : natural := c_off_high+1 - c_off_low;
  constant c_sub_wide      : natural := c_sub_high+1 - c_sub_low;
  constant c_off_high1     : natural := f_opa_choose(c_off_wide=0, c_off_low, c_off_high);
  constant c_sub_high1     : natural := f_opa_choose(c_sub_wide=0, c_sub_low, c_sub_high);
  constant c_ent_wide      : natural := 1 + c_tag_wide + c_line_bytes*9;

  constant c_way_ones  : std_logic_vector(c_num_ways-1 downto 0) := (others => '1');
  constant c_not_valid : std_logic_vector(c_line_bytes-1 downto 0) := (others => '0');
  
  type t_tag   is array(natural range <>) of std_logic_vector(c_tag_high downto c_tag_low);
  type t_idx   is array(natural range <>) of std_logic_vector(c_idx_high downto c_idx_low);
  type t_off   is array(natural range <>) of std_logic_vector(c_off_high1 downto c_off_low);
  type t_sub   is array(natural range <>) of std_logic_vector(c_sub_high1 downto c_sub_low);
  type t_ent   is array(natural range <>) of std_logic_vector(c_ent_wide-1 downto 0);
  type t_way   is array(natural range <>) of std_logic_vector(c_num_ways-1 downto 0);
  type t_sel   is array(natural range <>) of std_logic_vector(c_reg_bytes-1 downto 0);
  type t_reg   is array(natural range <>) of std_logic_vector(c_reg_wide -1 downto 0);
  type t_valid is array(natural range <>) of std_logic_vector(c_line_bytes  -1 downto 0);
  type t_line  is array(natural range <>) of std_logic_vector(c_line_bytes*8-1 downto 0);
  type t_mux   is array(natural range <>) of std_logic_vector(c_log_reg_bytes  downto 0);
  type t_size  is array(natural range <>) of std_logic_vector(1 downto 0);
  
  signal s_random : std_logic_vector(c_num_ways-1 downto 0);
  signal s_size   : t_size(c_num_slow-1 downto 0);
  signal s_vtag   : t_tag (c_num_slow-1 downto 0);
  signal s_vidx   : t_idx (c_num_slow-1 downto 0);
  signal s_voff   : t_off (c_num_slow-1 downto 0);
  signal s_wmask  : t_sel (c_num_slow-1 downto 0);
  signal s_bmask  : t_valid(c_num_slow-1 downto 0);
  signal s_shoff  : t_off (c_num_slow-1 downto 0);
  signal s_shsub  : t_sub (c_num_slow-1 downto 0);
  signal s_pbus   : std_logic_vector(c_num_slow-1 downto 0);
  signal s_adr    : t_opa_matrix(c_num_slow-1 downto 0, c_adr_wide-1 downto 0);
  signal s_rent   : t_ent (c_num_slow*c_num_ways-1 downto 0);
  signal s_rdirty : std_logic_vector(c_num_slow*c_num_ways-1 downto 0);
  signal s_rvalid : t_valid(c_num_slow*c_num_ways-1 downto 0);
  signal s_rtag   : t_tag (c_num_slow*c_num_ways-1 downto 0);
  signal s_rdat   : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal s_dirtyw : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_validw : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_matchw : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_donew  : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_victimw: t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal s_sel    : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal s_rot    : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_mux    : t_mux (c_num_slow*c_num_ways*c_reg_wide-1 downto 0);
  signal s_sext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_zext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_clear  : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal s_ways   : t_way (c_num_slow*c_reg_wide-1 downto 0);
  signal s_0dat   : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_wb_dat : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_0we    : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_we  : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_line : t_line (c_num_ways-1 downto 0);
  signal s_was_valid: t_valid(c_num_ways-1 downto 0);
  signal s_wb_valid: t_valid(c_num_ways-1 downto 0);
  signal s_widx   : std_logic_vector(c_idx_high downto c_idx_low);
  signal s_wdirty : std_logic_vector(0 downto 0);
  signal s_wtag   : std_logic_vector(c_tag_high downto c_tag_low);
  signal s_we     : std_logic_vector(c_num_ways -1 downto 0);
  signal s_wvalid : t_valid(c_num_ways-1 downto 0);
  signal s_wdat   : t_line(c_num_ways-1 downto 0);
  signal s_went   : t_ent (c_num_ways-1 downto 0);
  signal s_match  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_dirty  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_streq  : std_logic;
  signal s_ldreq  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_grant  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_st_req : t_opa_dbus_request;
  signal s_cl_req : t_opa_dbus_request;
  signal s_di_req : t_opa_dbus_request;
  signal s_ld_req : t_opa_dbus_request;
  signal s_grant_way : std_logic_vector(c_num_slow*c_num_ways-1 downto 0);
  signal s_rtag_m    : t_opa_matrix(c_tag_high downto c_tag_low, c_num_slow*c_num_ways-1 downto 0);
  signal s_rvalid_m  : t_opa_matrix(c_line_bytes  -1 downto 0, c_num_slow*c_num_ways-1 downto 0);
  signal s_rdat_m    : t_opa_matrix(c_line_bytes*8-1 downto 0, c_num_slow*c_num_ways-1 downto 0);
  signal s_alias  : std_logic_vector(c_num_slow-1 downto 0);
  signal s_dretry : std_logic_vector(c_num_slow-1 downto 0);
  signal s_pretry : std_logic_vector(c_num_slow-1 downto 0) := (others => '1');
  
  signal r_stb    : std_logic_vector(c_num_slow-1 downto 0) := (others => '0');
  signal r_we     : std_logic_vector(c_num_slow-1 downto 0) := (others => '0');
  signal r_re     : std_logic_vector(c_num_slow-1 downto 0) := (others => '0');
  signal r_vtag   : t_tag(c_num_slow-1 downto 0);
  signal r_vidx   : t_idx(c_num_slow-1 downto 0);
  signal r_voff   : t_off(c_num_slow-1 downto 0);
  signal r_wmask  : t_sel (c_num_slow-1 downto 0);
  signal r_bmask  : t_valid(c_num_slow-1 downto 0);
  signal r_size   : t_size(c_num_slow-1 downto 0);
  signal r_shoff  : t_off (c_num_slow-1 downto 0);
  signal r_shsub  : t_sub (c_num_slow-1 downto 0);
  signal r_clear  : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal r_wb_dat : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_vidx0  : std_logic_vector(c_idx_high downto c_idx_low);
  signal r_random : std_logic_vector(c_num_ways-1 downto 0);
  signal r_rtag   : t_tag (c_num_slow*c_num_ways-1 downto 0);
  signal r_rvalid : t_valid(c_num_slow*c_num_ways-1 downto 0);
  signal r_rdat   : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal r_matchw : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_victimw: t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_zext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal r_pbus   : std_logic_vector(c_num_slow-1 downto 0);
  signal r_pdata  : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_grant  : std_logic_vector(c_num_slow-1 downto 0);
  
  function f_idx(p, w    : natural) return natural is begin return w*c_num_slow+p; end f_idx;
  function f_idx(p, w, b : natural) return natural is begin return (f_idx(p,w)*c_reg_wide)+b; end f_idx;
  function f_pow(m : natural) return natural is begin return 8*2**m; end f_pow;
  function f_pow1(m : natural) return natural is begin return 8*(2**m/2); end f_pow1;
  
begin

  check : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      -- Validate input control
      assert (f_opa_safe(slow_stb_i)   = '1') report "opa_l1d: slow_stb_i has metavalue" severity failure;
      assert (f_opa_safe(slow_oldest_i)= '1') report "opa_l1d: slow_oldest_i has metavalue" severity failure;
      assert (f_opa_safe(dbus_busy_i)  = '1') report "opa_l1d: dbus_busy_i has metavalue" severity failure;
      -- pbus_stall_i depends on pbus_addr_o, so only valid if we are strobing
      assert (f_opa_safe(r_stb(0) and pbus_stall_i) = '1') report "opa_l1d: pbus_stall_i has metavalue" severity failure;
      assert (f_opa_safe(pbus_full_i)  = '1') report "opa_l1d: pbus_full_i has metavalue" severity failure;
      -- combinatorial control
      assert (f_opa_safe(s_ldreq) = '1') report "opa_l1d: s_ldreq has metavalue" severity failure;
      assert (f_opa_safe(s_streq) = '1') report "opa_l1d: s_streq has metavalue" severity failure;
      assert (f_opa_safe(s_grant) = '1') report "opa_l1d: s_grant has metavalue" severity failure;
      -- these two only have meaning when a ldreq occurs
      assert (f_opa_safe(s_ldreq and s_match) = '1') report "opa_l1d: s_match has metavalue" severity failure;
      assert (f_opa_safe(s_ldreq and s_dirty) = '1') report "opa_l1d: s_dirty has metavalue" severity failure;
    end if;
  end process;

  -- Arbitrate the ways if we have more than one to pick
  many_ways : if c_num_ways > 1 generate
    random : block is
      signal s_random_idx : std_logic_vector(f_opa_log2(c_num_ways)-1 downto 0);
    begin
      -- We use random way cache replacement policy
      -- LRU is not possible b/c it requires modification on every access
      lfsr : opa_lfsr
        generic map(
          g_bits   => f_opa_log2(c_num_ways))
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          random_o => s_random_idx);
      -- 1-hot decode the entropy to a way
      way : for w in 0 to c_num_ways-1 generate
        s_random(w) <= f_opa_eq(unsigned(s_random_idx), w);
      end generate;
    end block;
  end generate;
  
  -- If only one way, well, use it.
  one_way : if c_num_ways = 1 generate
    s_random(0) <= '1';
  end generate;

  rdports : for p in 0 to c_num_slow-1 generate
    -- Select the address lines
    s_size(p) <= f_opa_select_row(slow_size_i, p);
    s_vtag(p) <= f_opa_select_row(slow_addr_i, p)(c_tag_high downto c_tag_low);
    s_vidx(p) <= f_opa_select_row(slow_addr_i, p)(c_idx_high downto c_idx_low);
    
    -- Calculate the sub-word byte-mask and rotation
    sub : if c_sub_wide > 0 generate
      subs : block is
        signal s_vsub  : t_sub (c_num_slow-1 downto 0);
        signal s_sizes : t_sub (c_num_slow-1 downto 0);
      begin
        s_vsub(p) <= f_opa_select_row(slow_addr_i, p)(c_sub_high downto c_sub_low);
        
        -- 1-hot decode the size (note: 0 = full size)
        size : for s in c_sub_low to c_sub_high generate
          s_sizes(p)(s) <= f_opa_eq(unsigned(s_size(p)), s);
        end generate;
        
        little : if not c_big_endian generate
          -- Derive the word byte-select mask for the operation
          wmask : for b in 0 to c_reg_bytes-1 generate
            s_wmask(p)(b) <= not f_opa_lt(unsigned(s_sizes(p))-1, b - unsigned(s_vsub(p)));
          end generate;
          -- Derive the sub-word rotation
          s_shsub(p) <= s_vsub(p);
        end generate;
        
        big : if c_big_endian generate
          wmask : for b in 0 to c_reg_bytes-1 generate
            s_wmask(p)(c_reg_bytes-1-b) <= not f_opa_lt(unsigned(s_sizes(p))-1, b - unsigned(s_vsub(p)));
          end generate;
          s_shsub(p) <= std_logic_vector(unsigned(s_vsub(p)) + unsigned(s_sizes(p)));
        end generate;
      end block;
    end generate;
    nosub : if c_sub_wide = 0 generate
      s_shsub(p) <= (others => '0');
      s_wmask(p) <= (others => '1');
    end generate;
    
    off : if c_off_wide > 0 generate
      s_voff(p) <= f_opa_select_row(slow_addr_i, p)(c_off_high downto c_off_low);
      
      -- Which bytes of the line get accessed?
      little : if not c_big_endian generate
        s_shoff(p) <= s_voff(p);
      end generate;
      big : if c_big_endian generate
        s_shoff(p) <= std_logic_vector((c_line_bytes/c_reg_bytes-1)-unsigned(s_voff(p)));
      end generate;
      
      bmask : for b in 0 to c_line_bytes-1 generate
        s_bmask(p)(b) <= 
          s_wmask(p)(b mod c_reg_bytes) and f_opa_eq(unsigned(s_shoff(p)), b/c_reg_bytes);
      end generate;
    end generate;
    nooff : if c_off_wide = 0 generate
      s_voff (p) <= (others => '0');
      s_shoff(p) <= (others => '0');
      s_bmask(p) <= s_wmask(p);
    end generate;
    
    -- If we miss, which word to load first? (we wrap around within the line)
    tag_bits : for b in s_wtag'range generate -- !!! use physical address
      s_adr(p,b) <= r_vtag(p)(b);
    end generate;
    idx_bits : for b in s_widx'range generate
      s_adr(p,b) <= r_vidx(p)(b);
    end generate;
    aoff : if c_off_wide > 0 generate
      off_bits : for b in c_off_high downto c_off_low generate
        s_adr(p,b) <= r_voff(p)(b);
      end generate;
    end generate;
    asub : if c_sub_wide > 0 generate
      sub_bits : for b in c_sub_high downto c_sub_low generate
        s_adr(p,b) <= '0';
      end generate;
    end generate;
    
    -- Highest physical bit indicates if this is for dbus or pbus
    s_pbus(p) <= s_adr(p,c_adr_wide-1);
    
    -- The L1d ways
    -- Note: the OPA_NEW bypass is indeed necessary.
    -- If you have back-to-back writes to cache, you will lose data
    -- if the second write does not see the result of the first.
    ways : for w in 0 to c_num_ways-1 generate
      l1d : opa_dpram
        generic map(
          g_width  => c_ent_wide,
          g_size   => 2**c_idx_wide,
          g_equal  => OPA_NEW,
          g_regin  => true,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_addr_i => s_vidx(p),
          r_data_o => s_rent(f_idx(p,w)),
          w_en_i   => s_we(w),
          w_addr_i => s_widx,
          w_data_i => s_went(w));
      
      -- Split out the line contents (dirty, tag, valid, data)
      s_rdirty(f_idx(p,w)) <= s_rent(f_idx(p,w))(c_ent_wide-1);
      s_rtag  (f_idx(p,w)) <= s_rent(f_idx(p,w))(c_ent_wide-2 downto 9*c_line_bytes);
      s_rvalid(f_idx(p,w)) <= s_rent(f_idx(p,w))(9*c_line_bytes-1 downto 8*c_line_bytes);
      s_rdat  (f_idx(p,w)) <= s_rent(f_idx(p,w))(8*c_line_bytes-1 downto 0);
      
      -- A load is done if the tag matches and the valid bits cover the request
      s_dirtyw(p,w) <= s_rdirty(f_idx(p,w));
      s_validw(p,w) <= f_opa_and(not r_bmask(p) or s_rvalid(f_idx(p,w)));
      s_matchw(p,w) <= f_opa_eq(r_vtag(p), s_rtag(f_idx(p,w)));
      s_donew (p,w) <= s_matchw(p,w) and (r_we(p) or s_validw(p,w));
      
      -- Would this way be the victim on a refill?
      s_victimw(p,w) <= f_opa_mux(s_match(p), s_matchw(p,w), s_random(w));
      
      -- If there is more than one word in the line, pick the one we want
      s_sel(f_idx(p,w)) <= f_opa_rotate_right(s_rdat(f_idx(p,w)), unsigned(r_shoff(p)), c_reg_wide);
      
      -- Rotate read line data to align with requested load
      big_rotate : if c_big_endian generate
        s_rot(f_idx(p,w)) <= f_opa_rotate_left (s_sel(f_idx(p,w))(c_reg_wide-1 downto 0), unsigned(r_shsub(p)), 8);
      end generate;
      little_rotate : if not c_big_endian generate
        s_rot(f_idx(p,w)) <= f_opa_rotate_right(s_sel(f_idx(p,w))(c_reg_wide-1 downto 0), unsigned(r_shsub(p)), 8);
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
        s_sext(f_idx(p,w))(b) <= f_opa_index(s_mux(f_idx(p,w,b)), unsigned(r_size(p)));
      end generate;
      
      zext : for e in 0 to c_log_reg_bytes generate
        bits : for b in f_pow(e)-1 downto f_pow1(e) generate
          s_zext(f_idx(p,w))(b) <= s_sext(f_idx(p,w))(b) and not r_clear(p,e);
        end generate;
      end generate;
    end generate;
    zext : for b in 0 to c_log_reg_bytes generate
      s_clear(p,b) <= f_opa_lt(unsigned(s_size(p)), b) and not slow_sext_i(p);
    end generate;
  end generate;
  
  -- Pick the matching way for load result
  out_ports : for p in 0 to c_num_slow-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      ways : for w in 0 to c_num_ways-1 generate
        s_ways(f_idx(p,b))(w) <= r_zext(f_idx(p,w))(b);
      end generate;
      slow_data_o(p,b) <= f_opa_or(s_ways(f_idx(p,b)) and f_opa_select_row(r_matchw, p)) or
                          (r_pdata(b) and r_pbus(p));
    end generate;
  end generate;
  
  -- Share information about potential aliasing with the issue stage
  -- It does not matter if the write succeeds => restart aliased loads anyways
  issue_store_o <= r_we(0);
  issue_load_o  <= r_re;
  issue_aliases : for u in 0 to c_num_slow-1 generate
    -- Extract the bits which tell us if a store and load alias
    -- I would love to use a hash over the whole address, but then I would be screwed
    -- if someone maps two virtual pages to the same physical address. If I had the 
    -- physical address, I could certainly hash that, but it's too slow. Hrm.
    addr : for b in c_idx_high downto c_off_low generate
      issue_addr_o(u,b) <= s_adr(u,b);
    end generate;
    mask : for b in 0 to c_reg_bytes-1 generate
      issue_mask_o(u,b) <= r_wmask(u)(b);
    end generate;
  end generate;
  
  -- We will execute stores from port 0
  
  -- Rotate write data to put target byte at write mask location
  s_0dat <= f_opa_select_row(slow_data_i, 0);
  wb_big : if c_big_endian generate
    s_wb_dat <= f_opa_rotate_right(s_0dat, unsigned(s_shsub(0)), 8);
  end generate;
  wb_little : if not c_big_endian generate
    s_wb_dat <= f_opa_rotate_left (s_0dat, unsigned(s_shsub(0)), 8);
  end generate;
  
  -- Which way gets written by port 0?
  -- Note: s_wb_we is ignored if dbus_busy_i=1
  s_0we   <= (others => r_we(0) and slow_oldest_i(0) and not s_pbus(0)); -- only the oldest write is allowed
  s_wb_we <= s_0we and f_opa_select_row(s_victimw, 0);
  
  -- Construct the per-way data we would like to write
  wb_ways : for w in 0 to c_num_ways-1 generate
    wbytes : for b in 0 to c_line_bytes-1 generate
      s_wb_line(w)((b+1)*8-1 downto b*8) <= 
        f_opa_mux(r_bmask(0)(b),
          r_wb_dat(((b mod c_reg_bytes)+1)*8-1 downto (b mod c_reg_bytes)*8),
          s_rdat(f_idx(0,w))((b+1)*8-1 downto b*8));
    end generate;
    -- What is the new valid state?
    s_was_valid(w) <= f_opa_mux(s_matchw(0,w), s_rvalid(f_idx(0,w)), c_not_valid);
    s_wb_valid(w)  <= r_bmask(0) or s_was_valid(w);
  end generate;
  
  -- Decide what to write to L1; dbus has priority
  s_widx      <= dbus_adr_i(s_widx'range) when dbus_busy_i='1' else r_vidx(0);
  s_wdirty(0) <= '0'                      when dbus_busy_i='1' else '1';
  s_wtag      <= dbus_adr_i(s_wtag'range) when dbus_busy_i='1' else r_vtag(0);
  write_ways : for w in 0 to c_num_ways-1 generate
    s_we(w)    <= dbus_we_i(w)           when dbus_busy_i='1' else s_wb_we(w);
    s_wvalid(w)<= dbus_valid_i           when dbus_busy_i='1' else s_wb_valid(w);
    s_wdat(w)  <= dbus_data_i            when dbus_busy_i='1' else s_wb_line(w);
    s_went(w)  <= s_wdirty & s_wtag & s_wvalid(w) & s_wdat(w);
  end generate;
  
  -- Pick which port wins access to the dbus b/c no way satisfied its ldst
  -- Note: streq=1 => ldreq(0)=1 ... b/c load s_donew => s_matchw
  s_match <= f_opa_product(s_matchw, c_way_ones); -- a way tag matched?
  s_dirty <= f_opa_product(s_dirtyw and s_victimw, c_way_ones); -- dirty line?
  s_streq <= not s_pbus(0) and not s_match(0) and r_we(0); -- store0 has priority over all loads
  s_ldreq <= not s_pbus and r_stb and not f_opa_product(s_donew, c_way_ones); -- which port?
  s_grant <= f_opa_pick_small(s_ldreq); -- if streq=1 then grant(0)=1
  
  -- To prevent later stores starving the oldest store, only do it for oldest
  s_st_req   <= OPA_DBUS_WAIT_STORE      when (s_dirty(0) and slow_oldest_i(0))='1' else OPA_DBUS_IDLE;
  s_cl_req   <= OPA_DBUS_LOAD            when f_opa_or(s_grant)                ='1' else OPA_DBUS_IDLE;
  s_di_req   <= OPA_DBUS_WAIT_STORE_LOAD when f_opa_or(s_grant and s_match)    ='1' else OPA_DBUS_LOAD_STORE;
  s_ld_req   <= s_di_req                 when f_opa_or(s_grant and s_dirty)    ='1' else s_cl_req;
  dbus_req_o <= s_st_req                 when s_streq                          ='1' else s_ld_req; 

  -- Which line should the dbus refill and to which way
  dbus_radr_o <= f_opa_product(f_opa_transpose(s_adr),     s_grant);
  dbus_way_o  <= f_opa_product(f_opa_transpose(s_victimw), s_grant);
  
  -- Select line contents for writeback by the dbus
  wbports : for p in 0 to c_num_slow-1 generate
    ways : for w in 0 to c_num_ways-1 generate
      s_grant_way(f_idx(p,w)) <= r_grant(p) and r_victimw(p,w);
      tag : for b in c_tag_high downto c_tag_low generate
        s_rtag_m  (b,f_idx(p,w)) <= r_rtag  (f_idx(p,w))(b);
      end generate;
      valid : for b in 0 to c_line_bytes-1 generate
        s_rvalid_m(b,f_idx(p,w)) <= r_rvalid(f_idx(p,w))(b);
      end generate;
      dat : for b in 0 to c_line_bytes*8-1 generate
        s_rdat_m  (b,f_idx(p,w)) <= r_rdat  (f_idx(p,w))(b);
      end generate;
    end generate;
  end generate;
  
  dbus_wadr_o(c_tag_high downto c_idx_low) <= f_opa_product(s_rtag_m, s_grant_way) & r_vidx0;
  low_wadr : if c_idx_low > 0 generate
    dbus_wadr_o(c_idx_low-1 downto 0) <= (others => '0');
  end generate;
  
  dbus_dirty_o <= f_opa_product(s_rvalid_m, s_grant_way);
  dbus_data_o  <= f_opa_product(s_rdat_m,   s_grant_way);
  
  -- If this load aliased a store at port 0, retry it
  cross_aliases : for p in 0 to c_num_slow-1 generate
    s_alias(p) <= r_re(p) and r_we(0)
                  and f_opa_eq(r_vidx(p), r_vidx(0))
                  and f_opa_eq(r_voff(p), r_voff(0))
                  and f_opa_or(r_wmask(p) and r_wmask(0));
  end generate;
  
  -- Restart load if it aliases a concurrent store or misses cache
  -- Restart a store if it is not oldest or dbus had control of L1d write port
  retry : for p in 0 to c_num_slow-1 generate
    s_dretry(p) <= f_opa_mux(r_re(p), (s_alias(p) or s_ldreq(p)), (not slow_oldest_i(p) or dbus_busy_i));
  end generate;
  -- Both loads and stores to pbus must be oldest
  -- Loads must have result ready, while stores must have a non-busy pbus
  s_pretry(0) <= not slow_oldest_i(0) or f_opa_mux(r_re(0), not pbus_full_i, pbus_stall_i);
  slow_retry_o <= r_stb and f_opa_mux(s_pbus, s_pretry, s_dretry);
  
  -- Peripheral bus accesses are comparatievly easy. They come from port 0.
  pbus_req_o  <= slow_oldest_i(0) and r_stb(0) and s_pbus(0) and not (r_re(0) and pbus_full_i);
  pbus_we_o   <= r_we(0);
  pbus_addr_o <= f_opa_select_row(s_adr, 0);
  pbus_sel_o  <= r_wmask(0);
  pbus_dat_o  <= r_wb_dat;
  pbus_pop_o  <= slow_oldest_i(0) and r_re(0) and s_pbus(0);
  
  control : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_stb <= (others => '0');
      r_we  <= (others => '0');
      r_re  <= (others => '0');
    elsif rising_edge(clk_i) then
      r_stb <= slow_stb_i;
      r_we  <= slow_stb_i and     slow_we_i;
      r_re  <= slow_stb_i and not slow_we_i; -- future: re=0 & we=0 for prefetch
    end if;
  end process;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_vtag  <= s_vtag;
      r_vidx  <= s_vidx;
      r_voff  <= s_voff;
      r_wmask <= s_wmask;
      r_bmask <= s_bmask;
      r_size  <= s_size;
      r_shoff <= s_shoff;
      r_shsub <= s_shsub;
      r_clear <= s_clear;
      r_wb_dat<= s_wb_dat;
      --
      r_vidx0 <= r_vidx(0);
      r_rtag  <= s_rtag;
      r_rvalid<= s_rvalid;
      r_rdat  <= s_rdat;
      r_matchw<= s_matchw;
      r_victimw<= s_victimw;
      r_zext  <= s_zext;
      r_pbus  <= (others => '0');
      r_pbus(0) <= s_pbus(0);
      r_pdata <= pbus_dat_i;
      r_grant <= s_grant;
    end if;
  end process;
  
end rtl;
