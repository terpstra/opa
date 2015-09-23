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
    
    -- L1d requests action
    dbus_req_o   : out t_opa_dbus_request;
    dbus_radr_o  : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    dbus_way_o   : out std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
    dbus_wadr_o  : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    dbus_dirty_o : out std_logic_vector(c_dline_size            -1 downto 0);
    dbus_data_o  : out std_logic_vector(c_dline_size*8          -1 downto 0);
    
    dbus_busy_i  : in  std_logic; -- can accept a req_i
    dbus_we_i    : in  std_logic_vector(f_opa_num_dway(g_config)-1 downto 0);
    dbus_adr_i   : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    dbus_valid_i : in  std_logic_vector(c_dline_size            -1 downto 0);
    dbus_data_i  : in  std_logic_vector(c_dline_size*8          -1 downto 0));
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
  constant c_num_ways      : natural := f_opa_num_dway(g_config);
  constant c_reg_wide      : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide      : natural := f_opa_adr_wide(g_config);
  constant c_imm_wide      : natural := f_opa_imm_wide(g_config);
  constant c_reg_bytes     : natural := c_reg_wide/8;
  constant c_log_reg_wide  : natural := f_opa_log2(c_reg_wide);
  constant c_log_reg_bytes : natural := c_log_reg_wide - 3;
  constant c_line_bytes    : natural := c_dline_size;
  constant c_idx_low       : natural := f_opa_log2(c_line_bytes);
  constant c_idx_high      : natural := f_opa_log2(c_page_size);
  constant c_idx_wide      : natural := c_idx_high - c_idx_low;
  constant c_tag_wide      : natural := c_adr_wide - c_idx_high;
  constant c_ent_wide      : natural := 1 + c_tag_wide + c_dline_size*9;

  constant c_way_ones  : std_logic_vector(c_num_ways-1 downto 0) := (others => '1');
  constant c_off_zeros : std_logic_vector(c_idx_low -1 downto 0) := (others => '0'); 
  
  type t_tag   is array(natural range <>) of std_logic_vector(c_adr_wide-1 downto c_idx_high);
  type t_idx   is array(natural range <>) of std_logic_vector(c_idx_high-1 downto c_idx_low);
  type t_off   is array(natural range <>) of std_logic_vector(c_idx_low -1 downto 0);
  type t_ent   is array(natural range <>) of std_logic_vector(c_ent_wide-1 downto 0);
  type t_reg   is array(natural range <>) of std_logic_vector(c_reg_wide-1 downto 0);
  type t_way   is array(natural range <>) of std_logic_vector(c_num_ways-1 downto 0);
  type t_valid is array(natural range <>) of std_logic_vector(c_dline_size  -1 downto 0);
  type t_line  is array(natural range <>) of std_logic_vector(c_dline_size*8-1 downto 0);
  type t_mux   is array(natural range <>) of std_logic_vector(c_log_reg_bytes  downto 0);
  type t_size  is array(natural range <>) of std_logic_vector(1 downto 0);
  
  signal s_random_idx : std_logic_vector(f_opa_log2(c_num_ways)-1 downto 0);
  signal s_random : std_logic_vector(c_num_ways-1 downto 0);
  signal s_size   : t_size(c_num_slow-1 downto 0);
  signal s_vtag   : t_tag (c_num_slow-1 downto 0);
  signal s_vidx   : t_idx (c_num_slow-1 downto 0);
  signal s_voff   : t_off (c_num_slow-1 downto 0);
  signal s_sizes  : t_off (c_num_slow-1 downto 0);
  signal s_bmask  : t_valid(c_num_slow-1 downto 0);
  signal s_shift  : t_off (c_num_slow-1 downto 0);
  signal s_adr    : t_opa_matrix(c_num_slow-1 downto 0, c_adr_wide-1 downto 0) := (others => (others => '0'));
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
  signal s_rot    : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal s_mux    : t_mux (c_num_slow*c_num_ways*c_reg_wide-1 downto 0);
  signal s_sext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_zext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal s_clear  : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal s_ways   : t_way (c_num_slow*c_reg_wide-1 downto 0);
  signal s_0dat   : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_wb_mux : t_reg(c_log_reg_bytes downto 0);
  signal s_wb_dat : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_0we    : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_we  : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_line : t_line (c_num_ways-1 downto 0);
  signal s_was_valid: t_valid(c_num_ways-1 downto 0);
  signal s_wb_valid: t_valid(c_num_ways-1 downto 0);
  signal s_widx   : std_logic_vector(c_idx_high -1 downto c_idx_low);
  signal s_wdirty : std_logic_vector(0 downto 0);
  signal s_wtag   : std_logic_vector(c_adr_wide -1 downto c_idx_high);
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
  signal s_rtag_m    : t_opa_matrix(c_adr_wide-1 downto c_idx_high, c_num_slow*c_num_ways-1 downto 0);
  signal s_rvalid_m  : t_opa_matrix(c_dline_size  -1 downto 0, c_num_slow*c_num_ways-1 downto 0);
  signal s_rdat_m    : t_opa_matrix(c_dline_size*8-1 downto 0, c_num_slow*c_num_ways-1 downto 0);
  signal s_busy   : std_logic_vector(c_num_slow-1 downto 0);
  
  
  -- for range only??
  signal s_woff   : std_logic_vector(c_idx_low  -1 downto 0);
  
  signal r_stb    : std_logic_vector(c_num_slow-1 downto 0);
  signal r_we     : std_logic_vector(c_num_slow-1 downto 0);
  signal r_vtag   : t_tag(c_num_slow-1 downto 0);
  signal r_vidx   : t_idx(c_num_slow-1 downto 0);
  signal r_voff   : t_off(c_num_slow-1 downto 0);
  signal r_bmask  : t_valid(c_num_slow-1 downto 0);
  signal r_size   : t_size(c_num_slow-1 downto 0);
  signal r_shift  : t_off(c_num_slow-1 downto 0);
  signal r_clear  : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal r_wb_dat : std_logic_vector(c_reg_wide-1 downto 0);
  signal r_vidx0  : std_logic_vector(c_idx_high-1 downto c_idx_low);
  signal r_random : std_logic_vector(c_num_ways-1 downto 0);
  signal r_rtag   : t_tag (c_num_slow*c_num_ways-1 downto 0);
  signal r_rvalid : t_valid(c_num_slow*c_num_ways-1 downto 0);
  signal r_rdat   : t_line(c_num_slow*c_num_ways-1 downto 0);
  signal r_matchw : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_victimw: t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_zext   : t_reg (c_num_slow*c_num_ways-1 downto 0);
  signal r_grant  : std_logic_vector(c_num_slow-1 downto 0);
  
  function f_idx(p, w    : natural) return natural is begin return w*c_num_slow+p; end f_idx;
  function f_idx(p, w, b : natural) return natural is begin return (f_idx(p,w)*c_reg_wide)+b; end f_idx;
  function f_pow(m : natural) return natural is begin return 8*2**m; end f_pow;
  
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
    s_random(w) <= f_opa_bit(unsigned(s_random_idx) = w);
  end generate;

  rdports : for p in 0 to c_num_slow-1 generate
    -- Select the address lines
    s_size(p) <= f_opa_select_row(slow_size_i, p);
    s_vtag(p) <= f_opa_select_row(slow_addr_i, p)(s_wtag'range);
    s_vidx(p) <= f_opa_select_row(slow_addr_i, p)(s_widx'range);
    s_voff(p) <= f_opa_select_row(slow_addr_i, p)(s_woff'range);
    
    -- 1-hot decode the size
    size : for s in 0 to c_idx_low-1 generate
      s_sizes(p)(s) <= f_opa_bit(unsigned(s_size(p)) = s);
    end generate;
    
    -- Which bytes of the line get accessed?
    bmask_little : if not c_big_endian generate
      bmask : for b in 0 to c_line_bytes-1 generate
        -- Hopefully synthesis realizes this all fits into a 6:1 LUT
        s_bmask(p)(b) <= f_opa_bit(b - unsigned(s_voff(p)) <= unsigned(s_sizes(p))-1);
      end generate;
    end generate;
    bmask_big : if c_big_endian generate
      bmask : for b in 0 to c_line_bytes-1 generate
        s_bmask(p)(c_line_bytes-1-b) <= f_opa_bit(b - unsigned(s_voff(p)) <= unsigned(s_sizes(p))-1);
      end generate;
    end generate;
    
    -- Compute the line data shift to satisfy load request
    big_shift : if c_big_endian generate
      s_shift(p) <= std_logic_vector(unsigned(s_voff(p)) + unsigned(s_sizes(p)));
    end generate;
    little_shift : if not c_big_endian generate
      s_shift(p) <= s_voff(p);
    end generate;
    
    -- If we miss, which word to load first? (we wrap around within the line)
    tag_bits : for b in s_wtag'range generate -- !!! use physical address
      s_adr(p,b) <= r_vtag(p)(b);
    end generate;
    idx_bits : for b in s_widx'range generate
      s_adr(p,b) <= r_vidx(p)(b);
    end generate;
    off_bits : for b in c_idx_low-1 downto c_log_reg_bytes generate
      s_adr(p,b) <= r_voff(p)(b);
    end generate;
    
    -- !!! on power up, set each way to a tag = its index, valid=0s, and dirty=0
    -- The L1d ways
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
      s_rtag  (f_idx(p,w)) <= not s_rent(f_idx(p,w))(c_ent_wide-2 downto 9*c_dline_size);
      s_rvalid(f_idx(p,w)) <= s_rent(f_idx(p,w))(9*c_dline_size-1 downto 8*c_dline_size);
      s_rdat  (f_idx(p,w)) <= s_rent(f_idx(p,w))(8*c_dline_size-1 downto 0);
      
      -- A load is done if the tag matches and the valid bits cover the request
      s_dirtyw(p,w) <= s_rdirty(f_idx(p,w));
      s_validw(p,w) <= f_opa_and(not r_bmask(p) or s_rvalid(f_idx(p,w)));
      s_matchw(p,w) <= f_opa_bit(r_vtag(p) = s_rtag(f_idx(p,w)));
      s_donew (p,w) <= s_matchw(p,w) and (r_we(p) or s_validw(p,w));
      
      -- Would this way be the victim on a refill?
      s_victimw(p,w) <= s_matchw(p,w) when s_match(p)='1' else s_random(w);
      
      -- Rotate read line data to align with requested load
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
        s_zext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) <= 
          s_sext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) when r_clear(p,b)='0' else (others => '0');
      end generate;
    end generate;
    zext : for b in 0 to c_log_reg_bytes generate
      s_clear(p,b) <= f_opa_bit(unsigned(s_size(p)) < b) and not slow_sext_i(p);
    end generate;
  end generate;
  
  -- Pick the matching way for load result
  out_ports : for p in 0 to c_num_slow-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      ways : for w in 0 to c_num_ways-1 generate
        s_ways(f_idx(p,b))(w) <= r_zext(f_idx(p,w))(b);
      end generate;
      slow_data_o(p,b) <= f_opa_or(s_ways(f_idx(p,b)) and f_opa_select_row(r_matchw, p));
    end generate;
  end generate;
  
  -- We will execute stores from port 0
  
  -- Turn ...B into BBBB ..Hh into HhHh and ABCD into ABCD
  s_0dat <= f_opa_select_row(slow_data_i, 0);
  wb_mux : for m in 0 to c_log_reg_bytes generate
    bits : for b in 0 to c_reg_wide-1 generate
      s_wb_mux(m)(b) <= s_0dat(b mod f_pow(m));
    end generate;
  end generate;
  s_wb_dat <= s_wb_mux(to_integer(unsigned(s_size(0))));
  
  -- Which way gets written by port 0?
  -- Note: s_wb_we is ignored if dbus_busy_i=1
  s_0we   <= (others => r_we(0) and slow_oldest_i(0)); -- only the oldest write is allowed
  s_wb_we <= s_0we and f_opa_select_row(s_victimw, 0);
  
  -- Construct the per-way data we would like to write
  wb_ways : for w in 0 to c_num_ways-1 generate
    wbytes : for b in 0 to c_line_bytes-1 generate
      s_wb_line(w)((b+1)*8-1 downto b*8) <= 
        s_rdat(f_idx(0,w))((b+1)*8-1 downto b*8) when r_bmask(0)(b)='0' else
        r_wb_dat(((b mod c_reg_bytes)+1)*8-1 downto (b mod c_reg_bytes)*8);
    end generate;
    -- What is the new valid state?
    s_was_valid(w) <= s_rvalid(f_idx(0,w)) when s_matchw(0,w)='1' else (others => '0');
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
    s_went(w)  <= s_wdirty & (not s_wtag) & s_wvalid(w) & s_wdat(w);
    -- !!! don't need not on tag?
  end generate;
  
  -- Pick which port wins access to the dbus b/c no way satisfied its ldst
  -- Note: streq=1 => ldreq(0)=1 ... b/c load s_donew => s_matchw
  s_match <= f_opa_product(s_matchw, c_way_ones); -- a way tag matched?
  s_dirty <= f_opa_product(s_dirtyw and s_victimw, c_way_ones); -- dirty line?
  s_streq <= not s_match(0) and r_we(0); -- store0 has priority over all loads
  s_ldreq <= r_stb and not f_opa_product(s_donew, c_way_ones); -- which port?
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
      tag : for b in c_adr_wide-1 downto c_idx_high generate
        s_rtag_m  (b,f_idx(p,w)) <= r_rtag  (f_idx(p,w))(b);
      end generate;
      valid : for b in 0 to c_dline_size-1 generate
        s_rvalid_m(b,f_idx(p,w)) <= r_rvalid(f_idx(p,w))(b);
      end generate;
      dat : for b in 0 to c_dline_size*8-1 generate
        s_rdat_m  (b,f_idx(p,w)) <= r_rdat  (f_idx(p,w))(b);
      end generate;
    end generate;
  end generate;
  
  dbus_wadr_o  <= f_opa_product(s_rtag_m,   s_grant_way) & r_vidx0 & c_off_zeros;
  dbus_dirty_o <= f_opa_product(s_rvalid_m, s_grant_way);
  dbus_data_o  <= f_opa_product(s_rdat_m,   s_grant_way);
  
  -- Restart if load misses cache or store unacceptable
  -- We only accept a store if it is the oldest and dbus is not busy
  s_busy <= (others => dbus_busy_i);
  retry : for p in 0 to c_num_slow-1 generate
    slow_retry_o(p) <= s_ldreq(p) when r_we(p)='0' else 
                       (not slow_oldest_i(p) or s_busy(p));
  end generate;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_stb   <= slow_stb_i;
      r_we    <= slow_we_i and slow_stb_i;
      r_vtag  <= s_vtag;
      r_vidx  <= s_vidx;
      r_voff  <= s_voff;
      r_bmask <= s_bmask;
      r_size  <= s_size;
      r_shift <= s_shift;
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
      r_grant <= s_grant;
    end if;
  end process;
  
end rtl;
