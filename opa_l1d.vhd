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
  constant c_ent_wide      : natural := c_tag_wide + c_dline_size*8;

  constant c_way_ones : std_logic_vector(c_num_ways-1 downto 0) := (others => '1');
  
  type t_tag  is array(natural range <>) of std_logic_vector(c_adr_wide-1 downto c_idx_high);
  type t_idx  is array(natural range <>) of std_logic_vector(c_idx_high-1 downto c_idx_low);
  type t_off  is array(natural range <>) of std_logic_vector(c_idx_low -1 downto 0);
  type t_ent  is array(natural range <>) of std_logic_vector(c_ent_wide-1 downto 0);
  type t_reg  is array(natural range <>) of std_logic_vector(c_reg_wide-1 downto 0);
  type t_way  is array(natural range <>) of std_logic_vector(c_num_ways-1 downto 0);
  type t_line is array(natural range <>) of std_logic_vector(8*c_dline_size-1 downto 0);
  type t_mux  is array(natural range <>) of std_logic_vector(c_log_reg_bytes  downto 0);
  type t_size is array(natural range <>) of std_logic_vector(1 downto 0);
  
  signal s_we    : std_logic_vector(c_num_ways -1 downto 0);
  signal s_wtag  : std_logic_vector(c_adr_wide -1 downto c_idx_high);
  signal s_widx  : std_logic_vector(c_idx_high -1 downto c_idx_low);
  signal s_woff  : std_logic_vector(c_idx_low  -1 downto 0);
  signal s_wdat  : t_line(c_num_ways-1 downto 0);
  signal s_went  : t_ent (c_num_ways-1 downto 0);
  
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
  signal r_we    : std_logic_vector(c_num_slow-1 downto 0);
  signal r_size  : t_size(c_num_slow-1 downto 0);
  signal r_vtag  : t_tag(c_num_slow-1 downto 0);
  signal r_vidx  : t_idx(c_num_slow-1 downto 0);
  signal r_voff  : t_off(c_num_slow-1 downto 0);
  signal r_shift : t_off(c_num_slow-1 downto 0);
  signal r_match : t_opa_matrix(c_num_slow-1 downto 0, c_num_ways-1 downto 0);
  signal r_clear : t_opa_matrix(c_num_slow-1 downto 0, c_log_reg_bytes downto 0);
  signal r_zext  : t_reg (c_num_slow*c_num_ways-1 downto 0);
  
  signal s_0dat  : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_wb_msk: std_logic_vector(c_line_bytes-1 downto 0);
  signal r_wb_msk: std_logic_vector(c_line_bytes-1 downto 0);
  signal s_wb_mux: t_reg(c_log_reg_bytes downto 0);
  signal s_wb_dat: std_logic_vector(c_reg_wide-1 downto 0);
  signal r_wb_dat: std_logic_vector(c_reg_wide-1 downto 0);
  signal s_busy  : std_logic_vector(c_num_slow-1 downto 0) := (others => '1');
  signal s_0we   : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_we : std_logic_vector(c_num_ways-1 downto 0);
  signal s_wb_line : t_line(c_num_ways-1 downto 0);
  
  function f_idx(p, w    : natural) return natural is begin return w*c_num_slow+p; end f_idx;
  function f_idx(p, w, b : natural) return natural is begin return (f_idx(p,w)*c_reg_wide)+b; end f_idx;
  function f_pow(m : natural) return natural is begin return 8*2**m; end f_pow;
  
begin

  ports : for p in 0 to c_num_slow-1 generate
    -- Select the address lines
    s_size(p) <= f_opa_select_row(slow_size_i, p);
    s_vtag(p) <= f_opa_select_row(slow_addr_i, p)(s_wtag'range);
    s_vidx(p) <= f_opa_select_row(slow_addr_i, p)(s_widx'range);
    s_voff(p) <= f_opa_select_row(slow_addr_i, p)(s_woff'range);
    
    -- 1-hot decode the size
    size : for s in 0 to c_idx_low-1 generate
      s_sizes(p)(s) <= f_opa_bit(unsigned(s_size(p)) = s);
    end generate;
    
    -- Compute the data shift
    big_shift : if c_big_endian generate
      s_shift(p) <= std_logic_vector(unsigned(s_voff(p)) + unsigned(s_sizes(p)));
    end generate;
    little_shift : if not c_big_endian generate
      s_shift(p) <= s_voff(p);
    end generate;
    
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
    
    -- The L1d ways !!! find a way to use OPA_OLD instead ?
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
      
      -- Split out the line contents
      s_rtag(f_idx(p,w)) <= not s_rent(f_idx(p,w))(c_ent_wide-1 downto 8*c_dline_size);
      s_rdat(f_idx(p,w)) <= s_rent(f_idx(p,w))(8*c_dline_size-1 downto 0);
      
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
        s_zext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) <= 
          s_sext(f_idx(p,w))(8*2**b-1 downto 8*((2**b)/2)) when r_clear(p,b)='0' else (others => '0');
      end generate;
    end generate;
    zext : for b in 0 to c_log_reg_bytes generate
      s_clear(p,b) <= f_opa_bit(unsigned(s_size(p)) < b) and not slow_sext_i(p);
    end generate;
  end generate;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_stb   <= slow_stb_i;
      r_we    <= slow_we_i and slow_stb_i;
      r_size  <= s_size;
      r_vtag  <= s_vtag;
      r_vidx  <= s_vidx;
      r_voff  <= s_voff;
      r_size  <= s_size;
      r_shift <= s_shift;
      r_clear <= s_clear;
      r_wb_msk<= s_wb_msk;
      r_wb_dat<= s_wb_dat;
      --
      r_match <= s_match;
      r_zext  <= s_zext;
    end if;
  end process;
  
  -- We will execute stores from port 0 to the matching way
  
  -- Which bytes of the line get written?
  wb_little : if not c_big_endian generate
    wb_msk : for b in 0 to c_line_bytes-1 generate
      -- Hopefully synthesis realizes this all fits into a 6:1 LUT
      s_wb_msk(b) <= f_opa_bit(b - unsigned(s_voff(0)) <= unsigned(s_sizes(0))-1);
    end generate;
  end generate;
  wb_big : if c_big_endian generate
    wb_msk : for b in 0 to c_line_bytes-1 generate
      s_wb_msk(c_line_bytes-1-b) <= f_opa_bit(b - unsigned(s_voff(0)) <= unsigned(s_sizes(0))-1);
    end generate;
  end generate;
  
  -- Turn ...B into BBBB ..Hh into HhHh and ABCD into ABCD
  s_0dat <= f_opa_select_row(slow_data_i, 0);
  wb_mux : for m in 0 to c_log_reg_bytes generate
    bits : for b in 0 to c_reg_wide-1 generate
      s_wb_mux(m)(b) <= s_0dat(b mod f_pow(m));
    end generate;
  end generate;
  s_wb_dat <= s_wb_mux(to_integer(unsigned(s_size(0))));
  
  -- Which ways get written by writeback?
  s_0we     <= (others => r_we(0) and slow_oldest_i(0));
  s_wb_we   <= s_0we and f_opa_select_row(s_match, 0);
  
  -- Construct the per-way data we would like to write
  wb_ways : for w in 0 to c_num_ways-1 generate
    wbytes : for b in 0 to c_line_bytes-1 generate
      s_wb_line(w)((b+1)*8-1 downto b*8) <= 
        s_rdat(f_idx(0,w))((b+1)*8-1 downto b*8) when r_wb_msk(b)='0' else
        r_wb_dat(((b mod c_reg_bytes)+1)*8-1 downto (b mod c_reg_bytes)*8);
    end generate;
  end generate;
  
  -- Decide what to write to L1; dbus has priority
  s_wtag    <= dbus_adr_i(s_wtag'range) when dbus_busy_i='1' else r_vtag(0);
  s_widx    <= dbus_adr_i(s_widx'range) when dbus_busy_i='1' else r_vidx(0);
  write_ways : for w in 0 to c_num_ways-1 generate
    s_we(w)   <= dbus_we_i(w)           when dbus_busy_i='1' else s_wb_we(w);
    s_wdat(w) <= dbus_data_i            when dbus_busy_i='1' else s_wb_line(w);
    -- !!! store valid bits
    s_went(w) <= (not s_wtag) & s_wdat(w);
  end generate;
  
  -- Let the dbus know we need to load something
  s_miss <= r_stb and not f_opa_product(s_match, c_way_ones);
  s_pick <= f_opa_pick_small(s_miss);
  
  dbus_req_o   <= OPA_DBUS_LOAD when f_opa_or(s_miss) = '1' else OPA_DBUS_IDLE; -- !!! also store
  dbus_radr_o  <= f_opa_product(f_opa_transpose(s_adr), s_pick);
  dbus_way_o   <= (0 => '1', others => '0'); -- !!! pick a way
  dbus_wadr_o  <= (others => '0');
  dbus_dirty_o <= (others => '0');
  dbus_data_o  <= (others => '0');
  
  -- Restart if cache miss or store unacceptable
  -- We only accept a store if it is the oldest and the dbus is not already writing L1
  s_busy(0) <= dbus_busy_i; -- rest are 1s
  slow_retry_o <= s_miss or ((not slow_oldest_i or s_busy) and r_we);
  
  -- Pick the matching way
  out_ports : for p in 0 to c_num_slow-1 generate
    bits : for b in 0 to c_reg_wide-1 generate
      ways : for w in 0 to c_num_ways-1 generate
        s_ways(f_idx(p,b))(w) <= r_zext(f_idx(p,w))(b);
      end generate;
      slow_data_o(p,b) <= f_opa_or(s_ways(f_idx(p,b)) and f_opa_select_row(r_match, p));
    end generate;
  end generate;
    
end rtl;
