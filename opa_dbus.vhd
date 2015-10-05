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

entity opa_dbus is
  generic(
    g_isa    : t_opa_isa;
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i       : in  std_logic;
    rst_n_i     : in  std_logic;
    
    d_cyc_o     : out std_logic;
    d_stb_o     : out std_logic;
    d_we_o      : out std_logic;
    d_stall_i   : in  std_logic;
    d_ack_i     : in  std_logic;
    d_err_i     : in  std_logic;
    d_addr_o    : out std_logic_vector(g_config.adr_width  -1 downto 0);
    d_sel_o     : out std_logic_vector(g_config.reg_width/8-1 downto 0);
    d_data_o    : out std_logic_vector(g_config.reg_width  -1 downto 0);
    d_data_i    : in  std_logic_vector(g_config.reg_width  -1 downto 0);
    
    -- L1d requests action
    l1d_req_i   : in  t_opa_dbus_request;
    l1d_radr_i  : in  std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    l1d_way_i   : in  std_logic_vector(f_opa_num_dway  (g_config)  -1 downto 0);
    l1d_wadr_i  : in  std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    l1d_dirty_i : in  std_logic_vector(f_opa_dline_size(g_config)  -1 downto 0);
    l1d_data_i  : in  std_logic_vector(f_opa_dline_size(g_config)*8-1 downto 0);
    
    l1d_busy_o  : out std_logic; -- can accept a req_i
    l1d_we_o    : out std_logic_vector(f_opa_num_dway  (g_config)  -1 downto 0);
    l1d_adr_o   : out std_logic_vector(f_opa_adr_wide  (g_config)  -1 downto 0);
    l1d_valid_o : out std_logic_vector(f_opa_dline_size(g_config)  -1 downto 0);
    l1d_data_o  : out std_logic_vector(f_opa_dline_size(g_config)*8-1 downto 0));
end opa_dbus;

architecture rtl of opa_dbus is

  constant c_big_endian:boolean := f_opa_big_endian(g_isa);
  constant c_page_size: natural := f_opa_page_size(g_isa);
  constant c_dline_size:natural := f_opa_dline_size(g_config);
  constant c_reg_wide : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide : natural := f_opa_adr_wide(g_config);
  constant c_num_slow : natural := f_opa_num_slow(g_config);
  constant c_num_dway : natural := f_opa_num_dway(g_config);
  
  constant c_idx_low    : natural := f_opa_log2(c_reg_wide/8);
  constant c_idx_high   : natural := f_opa_log2(c_dline_size);
  constant c_idx_wide   : natural := c_idx_high - c_idx_low;
  constant c_line_words : natural := 2**c_idx_wide;
  constant c_page_high  : natural := f_opa_log2(c_page_size);
  
  constant c_ones : std_logic_vector(c_page_high-1 downto c_idx_high) := (others => '1');

  signal r_state    : t_opa_dbus_request := OPA_DBUS_WIPE;
  signal r_cyc      : std_logic := '0';
  signal r_stb      : std_logic := '0';
  signal r_we       : std_logic := '1'; -- May only be '0' if r_cyc='1'
  signal r_idle1    : std_logic; -- was idle last cycle?
  signal r_sel      : std_logic_vector(c_reg_wide/8-1 downto 0);
  signal r_radr     : std_logic_vector(c_adr_wide-1 downto 0) := (others => '0');
  signal s_way_en   : std_logic_vector(c_num_dway-1 downto 0);
  signal r_way      : std_logic_vector(c_num_dway-1 downto 0);
  signal r_wadr     : std_logic_vector(c_adr_wide-1 downto 0) := (others => '0');
  signal s_dirty    : std_logic_vector(c_dline_size-1 downto 0);
  signal r_dirty    : std_logic_vector(c_dline_size-1 downto 0);
  signal s_storeline: std_logic_vector(c_dline_size*8-1 downto 0);
  signal r_storeline: std_logic_vector(c_dline_size*8-1 downto 0);
  signal r_adr      : std_logic_vector(c_adr_wide-1 downto 0) := (others => '0');
  signal s_last_ack : std_logic;
  signal s_last_stb : std_logic;
  signal s_loadat_in: std_logic_vector(c_line_words-1 downto 0);
  signal s_loadat   : std_logic_vector(c_line_words-1 downto 0);
  signal r_loadat   : std_logic_vector(c_line_words-1 downto 0) := (others => '0');
  signal r_loaded   : std_logic_vector(c_line_words-1 downto 0) := (others => '0');
  signal s_loaded_b : std_logic_vector(c_dline_size-1 downto 0);
  signal s_loadline : std_logic_vector(c_dline_size*8-1 downto 0);
  signal r_loadline : std_logic_vector(c_dline_size*8-1 downto 0) := (others => '0');
  signal s_way_ack  : std_logic_vector(c_num_dway-1 downto 0);
  signal s_wipe     : std_logic_vector(c_num_dway-1 downto 0);
  signal s_lineout  : std_logic_vector(c_reg_wide-1 downto 0);
  signal s_dirty_mux: std_logic_vector(c_dline_size-1 downto 0);
  signal s_storeline_mux : std_logic_vector(c_dline_size*8-1 downto 0);
  signal s_wadr_mux : std_logic_vector(c_adr_wide-1 downto 0);

begin

  radr : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_radr <= (others => '0');
    elsif rising_edge(clk_i) then
      case r_state is
        when OPA_DBUS_WIPE =>
          r_radr <= r_radr;
          r_radr(c_ones'high downto c_ones'low)
            <= std_logic_vector(unsigned(r_radr(c_ones'high downto c_ones'low)) + 1);
        when OPA_DBUS_IDLE =>
          r_radr <= l1d_radr_i;
        when others =>
          r_radr <= r_radr;
      end case;
    end if;
  end process;
  
  way : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_state = OPA_DBUS_IDLE then
        r_way <= l1d_way_i;
      end if;
    end if;
  end process;
  
  count : if c_line_words > 1 generate
    b : block is
      signal r_out : unsigned(c_idx_wide-1 downto 0);
      signal r_in  : unsigned(c_idx_wide-1 downto 0);
    begin
      counters : process(clk_i) is
      begin
        if rising_edge(clk_i) then
          if r_stb = '0' then
            r_out <= (others => '0');
          elsif d_stall_i = '0' then
            r_out <= r_out + 1;
          end if;
          
          if r_cyc = '0' then
            r_in <= (others => '0');
          elsif d_ack_i = '1' then
            r_in <= r_in + 1;
          end if;
        end if;
      end process;
      
      s_last_ack <= d_ack_i       and f_opa_eq(r_in,  c_line_words-1);
      s_last_stb <= not d_stall_i and f_opa_eq(r_out, c_line_words-1);
    end block;
  end generate;
  nocount : if c_line_words = 1 generate
    s_last_ack <= d_ack_i;
    s_last_stb <= not d_stall_i;
  end generate;
  
  fsm : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_state <= OPA_DBUS_WIPE;
      r_cyc   <= '0';
      r_stb   <= '0';
      r_we    <= '1';
      r_sel   <= (others => '-');
    elsif rising_edge(clk_i) then
      case r_state is
        when OPA_DBUS_WIPE =>
          if r_radr(c_ones'range) = c_ones then
            r_state <= OPA_DBUS_IDLE;
          else
            r_state <= OPA_DBUS_WIPE;
          end if;
          r_cyc <= '0';
          r_stb <= '0';
          r_we  <= '1';
          r_sel <= (others => '1');
        when OPA_DBUS_IDLE =>
          r_state <= l1d_req_i;
          r_sel   <= (others => '1');
          case l1d_req_i is
            when OPA_DBUS_IDLE =>
              r_cyc <= '0';
              r_stb <= '0';
              r_we  <= '1';
            when OPA_DBUS_WAIT_STORE_LOAD | OPA_DBUS_WAIT_STORE =>
              r_cyc <= '0';
              r_stb <= '0';
              r_we  <= '1';
            when OPA_DBUS_LOAD_STORE | OPA_DBUS_LOAD =>
              r_cyc <= '1';
              r_stb <= '1';
              r_we  <= '0';
            when others => -- impossible cases
              r_cyc <= '-';
              r_stb <= '-';
              r_we  <= '-';
          end case;
        when OPA_DBUS_WAIT_STORE_LOAD =>
          r_state <= OPA_DBUS_STORE_LOAD;
          r_cyc   <= '1';
          r_stb   <= '1';
          r_we    <= '1';
          r_sel   <= s_dirty_mux(r_sel'range);
        when OPA_DBUS_STORE_LOAD =>
          r_stb <= r_stb and not s_last_stb;
          if s_last_ack = '1' then
            r_state <= OPA_DBUS_WAIT_LOAD;
            r_cyc   <= '0';
            r_we    <= '1';
            r_sel   <= (others => '-');
          else
            r_state <= OPA_DBUS_STORE_LOAD;
            r_cyc   <= '1';
            r_we    <= '1';
            r_sel   <= s_dirty_mux(r_sel'range);
          end if;
        when OPA_DBUS_LOAD_STORE =>
          r_stb <= r_stb and not s_last_stb;
          if s_last_ack = '1' then
            r_state <= OPA_DBUS_WAIT_STORE;
            r_cyc   <= '0';
            r_we    <= '1';
            r_sel   <= (others => '-');
          else
            r_state <= OPA_DBUS_LOAD_STORE;
            r_cyc   <= '1';
            r_we    <= '0';
            r_sel   <= (others => '1');
          end if;
        when OPA_DBUS_WAIT_LOAD =>
          r_state <= OPA_DBUS_LOAD;
          r_cyc   <= '1';
          r_stb   <= '1';
          r_we    <= '0';
          r_sel   <= (others => '1');
        when OPA_DBUS_WAIT_STORE =>
          r_state <= OPA_DBUS_STORE;
          r_cyc   <= '1';
          r_stb   <= '1';
          r_we    <= '1';
          r_sel   <= s_dirty_mux(r_sel'range);
        when OPA_DBUS_LOAD =>
          r_stb <= r_stb and not s_last_stb;
          if s_last_ack = '1' then
            r_state <= OPA_DBUS_IDLE;
            r_cyc   <= '0';
            r_we    <= '1';
            r_sel   <= (others => '-');
          else
            r_state <= OPA_DBUS_LOAD;
            r_cyc   <= '1';
            r_we    <= '0';
            r_sel   <= (others => '1');
          end if;
        when OPA_DBUS_STORE =>
          r_stb <= r_stb and not s_last_stb;
          if s_last_ack = '1' then
            r_state <= OPA_DBUS_IDLE;
            r_cyc   <= '0';
            r_we    <= '1';
            r_sel   <= (others => '-');
          else
            r_state <= OPA_DBUS_STORE;
            r_cyc   <= '1';
            r_we    <= '1';
            r_sel   <= s_dirty_mux(r_sel'range);
          end if;
      end case;
    end if;
  end process;
  
  endian : if c_line_words > 1 generate
    load_big : if c_big_endian generate
      s_loadat <= std_logic_vector(rotate_right(unsigned(r_loadat), 1));
      onehot : for i in 0 to c_line_words-1 generate
        s_loadat_in(i) <= f_opa_eq(unsigned(l1d_radr_i(c_idx_high-1 downto c_idx_low)), (c_line_words-1)-i);
      end generate;
    end generate;
    load_small : if not c_big_endian generate
      s_loadat <= std_logic_vector(rotate_left(unsigned(r_loadat), 1));
      onehot : for i in 0 to c_line_words-1 generate
        s_loadat_in(i) <= f_opa_eq(unsigned(l1d_radr_i(c_idx_high-1 downto c_idx_low)), i);
      end generate;
    end generate;
  end generate;
  noendian : if c_line_words = 1 generate
    s_loadat    <= (others => '1');
    s_loadat_in <= (others => '1');
  end generate;
  
  datin : for i in 0 to c_line_words-1 generate
    s_loadline(c_reg_wide*(i+1)-1 downto c_reg_wide*i) <= 
      f_opa_mux(r_loadat(i), d_data_i, r_loadline(c_reg_wide*(i+1)-1 downto c_reg_wide*i));
  end generate;
  
  loadat : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_state = OPA_DBUS_WIPE then
        r_loadat <= (others => '0');
        r_loaded <= (others => '0');
      elsif r_state = OPA_DBUS_IDLE then
        r_loadat <= s_loadat_in;
        r_loaded <= s_loadat_in;
      else
        if d_ack_i = '1' then
          -- does not matter if this rotates also on writes => complete rotation before read
          r_loadat <= s_loadat;
        end if;
        if (not r_we and d_ack_i) = '1' then
          -- need to be more careful here; note: r_we=0 implies r_cyc=1
          r_loaded <= r_loaded or s_loadat;
        end if;
      end if;
    end if;
  end process;
  
  loaded_bytes : for i in 0 to c_dline_size-1 generate
    s_loaded_b(i) <= r_loaded(i / (c_reg_wide/8));
  end generate;
  
  loadline : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_state = OPA_DBUS_WIPE then
        r_loadline <= (others => '0');
      elsif d_ack_i = '1' then
        -- ack only needs to be '1' at the correct times during a load cycle
        -- any garbage accepted will just get overwritten => harmless
        r_loadline <= s_loadline;
      end if;
    end if;
  end process;
  
  address : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      case r_state is
        when OPA_DBUS_WIPE =>
          r_adr <= (others => '-');
        when OPA_DBUS_IDLE =>
          r_adr(l1d_radr_i'range) <= l1d_radr_i;
        when OPA_DBUS_WAIT_STORE_LOAD | OPA_DBUS_WAIT_STORE =>
          r_adr(r_wadr'range) <= s_wadr_mux;
        when OPA_DBUS_WAIT_LOAD =>
          r_adr(r_radr'range) <= r_radr;
        when OPA_DBUS_STORE_LOAD | OPA_DBUS_LOAD_STORE | OPA_DBUS_LOAD | OPA_DBUS_STORE =>
          r_adr <= r_adr;
          if d_stall_i = '0' and c_line_words > 1 then -- next output address
            r_adr(c_idx_high-1 downto c_idx_low) <= 
              std_logic_vector(unsigned(r_adr(c_idx_high-1 downto c_idx_low)) + 1);
          end if;
      end case;
    end if;
  end process;
  
  write_big : if c_big_endian generate
    s_dirty     <= std_logic_vector(rotate_right(unsigned(r_dirty),     c_reg_wide/8));
    s_storeline <= std_logic_vector(rotate_right(unsigned(r_storeline), c_reg_wide));
    s_lineout   <= r_storeline(c_dline_size*8-1 downto c_dline_size*8-c_reg_wide);
  end generate;
  write_little : if not c_big_endian generate
    s_dirty     <= std_logic_vector(rotate_left(unsigned(r_dirty),     c_reg_wide/8));
    s_storeline <= std_logic_vector(rotate_left(unsigned(r_storeline), c_reg_wide));
    s_lineout   <= r_storeline(c_reg_wide-1 downto 0);
  end generate;
  
  -- Need this bypass to setup r_sel and r_adr
  s_dirty_mux <= 
    s_dirty     when (r_stb and not d_stall_i) = '1' else 
    l1d_dirty_i when r_idle1                   = '1' else
    r_dirty;
  s_storeline_mux <=
    s_storeline when (r_stb and not d_stall_i) = '1' else
    l1d_data_i  when r_idle1                   = '1' else
    r_storeline;
  s_wadr_mux <= l1d_wadr_i when r_idle1 = '1' else r_wadr;
  
  wdata : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_idle1     <= f_opa_bit(r_state = OPA_DBUS_IDLE);
      r_wadr      <= s_wadr_mux;
      r_dirty     <= s_dirty_mux;
      r_storeline <= s_storeline_mux;
    end if;
  end process;
  
  d_cyc_o  <= r_cyc;
  d_stb_o  <= r_stb;
  d_we_o   <= r_we;
  d_addr_o <= r_adr;
  d_sel_o  <= r_sel;
  d_data_o <= s_lineout;
  
  l1d_busy_o  <= not f_opa_bit(r_state = OPA_DBUS_IDLE);
  s_way_ack   <= (others => d_ack_i and not r_we);
  s_wipe      <= (others => f_opa_bit(r_state = OPA_DBUS_WIPE));
  l1d_we_o    <= (r_way and s_way_ack) or s_wipe;
  l1d_adr_o   <= r_radr(l1d_adr_o'range);
  l1d_valid_o <= s_loaded_b;
  l1d_data_o  <= s_loadline;

end rtl;
