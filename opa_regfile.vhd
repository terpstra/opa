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

entity opa_regfile is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i        : in  std_logic;
    rst_n_i      : in  std_logic;
    
    -- Record PC + immediate data
    decode_stb_i : in  std_logic;
    decode_aux_i : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    decode_arg_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_arg_wide   (g_config)-1 downto 0);
    decode_imm_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_imm_wide   (g_config)-1 downto 0);
    decode_pc_i  : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
    decode_pcf_i : in  t_opa_matrix(f_opa_renamers (g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
    decode_pcn_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);

    -- Issue has dispatched these instructions to us
    issue_rstb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_geta_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_getb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_aux_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_aux_wide  (g_config)-1 downto 0);
    issue_dec_i  : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_ren_wide  (g_config)-1 downto 0);
    issue_baka_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
    issue_bakb_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
    
    -- Feed the EUs one cycle later (they register this => result is two cycles later)
    eu_stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_rega_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide   (g_config)-1 downto 0);
    eu_regb_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide   (g_config)-1 downto 0);
    eu_arg_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_arg_wide   (g_config)-1 downto 0);
    eu_imm_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_imm_wide   (g_config)-1 downto 0);
    eu_pc_o      : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
    eu_pcf_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fetch_align(g_config)-1 downto c_op_align);
    eu_pcn_o     : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide   (g_config)-1 downto c_op_align);
    
    -- Issue has indicated these EUs will write now
    issue_wstb_i : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    issue_bakx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide (g_config)-1 downto 0);
    
    -- The results arrive two cycles after the issue said they would
    eu_regx_i    : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_reg_wide  (g_config)-1 downto 0));
end opa_regfile;

architecture rtl of opa_regfile is

  constant c_executers : natural := f_opa_executers (g_config);
  constant c_renamers  : natural := f_opa_renamers  (g_config);
  constant c_num_back  : natural := f_opa_num_back  (g_config);
  constant c_num_aux   : natural := f_opa_num_aux   (g_config);
  constant c_back_wide : natural := f_opa_back_wide (g_config);
  constant c_reg_wide  : natural := f_opa_reg_wide  (g_config);
  constant c_adr_wide  : natural := f_opa_adr_wide  (g_config);
  constant c_fetch_align: natural := f_opa_fetch_align(g_config);
  constant c_arg_wide  : natural := f_opa_arg_wide  (g_config);
  constant c_aux_wide  : natural := f_opa_aux_wide  (g_config);
  constant c_imm_wide  : natural := f_opa_imm_wide  (g_config);
  constant c_ren_wide  : natural := f_opa_ren_wide  (g_config);
  constant c_pc_wide   : natural := c_adr_wide   - c_op_align;
  constant c_pcf_wide  : natural := c_fetch_align - c_op_align;
  
  constant c_aux_num_arg   : natural := c_renamers;
  constant c_aux_num_imm   : natural := c_renamers;
  constant c_aux_num_pc    : natural := c_renamers + 1;
  constant c_aux_num_pcf   : natural := c_renamers;
  constant c_aux_off_arg   : natural := 0;
  constant c_aux_off_imm   : natural := c_aux_num_arg * c_arg_wide;
  constant c_aux_off_pc    : natural := c_aux_num_imm * c_imm_wide + c_aux_off_imm;
  constant c_aux_off_pcf   : natural := c_aux_num_pc  * c_pc_wide  + c_aux_off_pc;
  constant c_aux_data_wide : natural := c_aux_num_pcf * c_pcf_wide + c_aux_off_pcf;
  
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
  
  -- Inverse of f_nat2mux
  function f_mux2nat(x : natural) return natural is
  begin
    if x < 4*c_num_short then
      return x/4; -- rounded down
    else
      return x-c_num_short*3;
    end if;
  end f_mux2nat;
  
  -- The particular indexes for unit attachment
  function f_eu (x : natural) return natural is begin return f_nat2mux(x+c_executers*0); end f_eu;
  function f_reg(x : natural) return natural is begin return f_nat2mux(x+c_executers*1); end f_reg;
  function f_mem(x : natural) return natural is begin return f_nat2mux(x+c_executers*2); end f_mem;
  constant c_imm : natural := c_num_mux-1;
  
  function f_age_table return t_opa_matrix is
    variable result : t_opa_matrix(c_num_mux-1 downto 0, c_mux_wide-1 downto 0);
    variable row : std_logic_vector(result'range(2));
    variable off : natural;
  begin
    for i in result'range(1) loop
      -- decode the index
      off := f_mux2nat(i);
      -- age the index
      if off < 2*c_executers then
        off := off + c_executers;
      end if;
      -- encode the index
      off := f_nat2mux(off);
      row := std_logic_vector(to_unsigned(off, row'length));
      for j in result'range(2) loop
        result(i,j) := row(j);
      end loop;
    end loop;
    return result;
  end f_age_table;
  
  -- Fixed labels for 1hot selecting a particular mux stage
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
  
  constant c_age_table   : t_opa_matrix := f_age_table;
  constant c_eu_indexes  : t_opa_matrix := f_indexes(c_executers*0);
  constant c_reg_indexes : t_opa_matrix := f_indexes(c_executers*1);
  constant c_mem_indexes : t_opa_matrix := f_indexes(c_executers*2);
  
  signal r_wstb0       : std_logic_vector(c_executers-1 downto 0);
  signal r_wstb1       : std_logic_vector(c_executers-1 downto 0);
  signal r_bakx0       : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakx1       : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  signal r_regx        : t_opa_matrix(c_executers-1 downto 0, c_reg_wide -1 downto 0);
  
  signal s_map_set     : std_logic_vector(c_num_back-1 downto 0);
  signal s_map_match   : t_opa_matrix(c_num_back-1 downto 0, c_executers-1 downto 0);
  signal s_map_new     : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0);
  signal s_map_aged    : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0);
  signal s_map         : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0);
  signal r_map         : t_opa_matrix(c_num_back-1 downto 0, c_mux_wide-1 downto 0) := (others => (others => '0'));
  
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
  
  type t_aux_address  is array(c_executers-1 downto 0) of std_logic_vector(c_aux_wide-1 downto 0);
  type t_aux_data_out is array(c_executers-1 downto 0) of std_logic_vector(c_aux_data_wide-1 downto 0);
  signal s_aux_addr  : t_aux_address;
  signal s_aux_rdata : t_aux_data_out;
  signal s_aux_wdata : std_logic_vector(c_aux_data_wide-1 downto 0);
  
  type t_aux_imm_mux  is array(c_executers*c_imm_wide-1 downto 0) of std_logic_vector(c_renamers-1 downto 0);
  type t_aux_arg_mux  is array(c_executers*c_arg_wide-1 downto 0) of std_logic_vector(c_renamers-1 downto 0);
  type t_aux_pc_mux   is array(c_executers*c_pc_wide -1 downto 0) of std_logic_vector(c_renamers-1 downto 0);
  type t_aux_pcn_mux  is array(c_executers*c_pc_wide -1 downto 0) of std_logic_vector(c_renamers-1 downto 0);
  type t_aux_pcf_mux  is array(c_executers*c_pcf_wide-1 downto 0) of std_logic_vector(c_renamers-1 downto 0);
  signal r_dec         : t_opa_matrix(c_executers-1 downto 0, c_ren_wide-1 downto 0);
  signal s_aux_imm_mux : t_aux_imm_mux;
  signal s_aux_arg_mux : t_aux_arg_mux;
  signal s_aux_pc_mux  : t_aux_pc_mux;
  signal s_aux_pcn_mux : t_aux_pcn_mux;
  signal s_aux_pcf_mux : t_aux_pcf_mux;
  signal s_arg         : t_opa_matrix(c_executers-1 downto 0, c_arg_wide-1 downto 0);
  signal s_imm         : t_opa_matrix(c_executers-1 downto 0, c_imm_wide-1 downto 0);
  signal s_pc          : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal s_pcn         : t_opa_matrix(c_executers-1 downto 0, c_adr_wide-1 downto c_op_align);
  signal s_pcf         : t_opa_matrix(c_executers-1 downto 0, c_fetch_align-1 downto c_op_align);
  signal s_imm_pad     : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1 downto 0) := (others => (others => '0'));
  signal s_pc_pad      : t_opa_matrix(c_executers-1 downto 0, c_reg_wide-1 downto 0) := (others => (others => '0'));
  
  type t_mux is array(c_executers*c_reg_wide-1 downto 0) of std_logic_vector(c_num_mux-1 downto 0);
  signal s_mux_a     : t_mux;
  signal s_mux_b     : t_mux;
  signal r_mux_idx_a : t_opa_matrix(c_executers-1 downto 0, c_mux_wide-1 downto 0);
  signal r_mux_idx_b : t_opa_matrix(c_executers-1 downto 0, c_mux_wide-1 downto 0);
  
begin

  input : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      eu_stb_o <= issue_rstb_i;
      r_dec    <= issue_dec_i;
      r_wstb0  <= issue_wstb_i;
      r_wstb1  <= r_wstb0;
      r_bakx0  <= issue_bakx_i;
      r_bakx1  <= r_bakx0;
      r_regx   <= eu_regx_i;
    end if;
  end process;
  
  -- !!! the strobe line is a real bummer. much nicer would be if we had a 'bad' reg
  -- we would be able to compress 6:1 reg match, 5:1 EU decode w/ aged as +1
  -- result: 2 levels to compute s_map, in line with 2-levels for 18-stat bak[ab]
  -- => final mux decodes within 4 levels!! (with 1 in the register!)
  -- if i forbade write access to reg0, this would be possible
  
  -- Calculate the new mapping from back registers to units
  s_map_match <= f_opa_match_index(c_num_back, issue_bakx_i) and f_opa_dup_row(c_num_back, issue_wstb_i);
  s_map_set   <= f_opa_product(s_map_match, c_ones); -- 2 levels with 3 EU and 64 bak
  s_map_new   <= f_opa_product(s_map_match, c_eu_indexes);
  s_map_aged  <= f_opa_compose(c_age_table, r_map); -- 1 level decode
  
  -- Was a register written?
  regs : for i in s_map'range(1) generate
    bits : for b in s_map'range(2) generate
      s_map(i,b) <= s_map_new(i,b) when s_map_set(i)='1' else s_map_aged(i,b);
    end generate;
  end generate;
  
  back_reg : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      -- On power-up, select the first EU; it will age to regfile before anything gets issued
      r_map <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      r_map <= s_map;
    end if;
  end process;
  
  mux_idx : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_mux_idx_a <= f_opa_compose(r_map, issue_baka_i) or not f_opa_dup_col(c_mux_wide, issue_geta_i);
      r_mux_idx_b <= f_opa_compose(r_map, issue_bakb_i) or not f_opa_dup_col(c_mux_wide, issue_getb_i);
    end if;
  end process;
  
  remap_aux_adr : for u in 0 to c_executers-1 generate
    s_aux_addr(u) <= f_opa_select_row(issue_aux_i, u);
  end generate;
  
  remap_aux_wdata : for d in 0 to c_renamers-1 generate
    -- We stride the data so that the muxed bits are adjacent (from same MLAB)
    arg : for b in 0 to c_arg_wide-1 generate
      s_aux_wdata(c_aux_off_arg + b*c_aux_num_arg + d) <= decode_arg_i(d,b);
    end generate;
    imm : for b in 0 to c_imm_wide-1 generate
      s_aux_wdata(c_aux_off_imm + b*c_aux_num_imm + d) <= decode_imm_i(d,b);
    end generate;
    pc  : for b in 0 to c_pc_wide-1 generate
      s_aux_wdata(c_aux_off_pc  + b*c_aux_num_pc  + d) <= decode_pc_i (d,b+c_op_align);
    end generate;
    pcf : for b in 0 to c_pcf_wide-1 generate
      s_aux_wdata(c_aux_off_pcf + b*c_aux_num_pcf + d) <= decode_pcf_i(d,b+c_op_align);
    end generate;
  end generate;
  pcn : for b in 0 to c_pc_wide-1 generate
    s_aux_wdata(c_aux_off_pc + b*c_aux_num_pc + c_renamers) <= decode_pcn_i(b+c_op_align);
  end generate;
  
  auxs : for u in 0 to c_executers-1 generate
    aux : opa_dpram
      generic map(
        g_width  => c_aux_data_wide,
        g_size   => c_num_aux,
        g_equal  => OPA_UNDEF,
        g_regin  => true,
        g_regout => false)
      port map(
        clk_i    => clk_i,
        rst_n_i  => rst_n_i,
        r_addr_i => s_aux_addr(u),
        r_data_o => s_aux_rdata(u),
        w_en_i   => decode_stb_i,
        w_addr_i => decode_aux_i,
        w_data_i => s_aux_wdata);
  end generate;
  
  demux_aux : for u in 0 to c_executers-1 generate
    dec : for d in 0 to c_renamers-1 generate
      arg : for b in 0 to c_arg_wide-1 generate
        s_aux_arg_mux(f_idx(u,b))(d) <= s_aux_rdata(u)(c_aux_off_arg + b*c_aux_num_arg + d);
      end generate;
      imm : for b in 0 to c_imm_wide-1 generate
        s_aux_imm_mux(f_idx(u,b))(d) <= s_aux_rdata(u)(c_aux_off_imm + b*c_aux_num_imm + d);
      end generate;
      pc : for b in 0 to c_pc_wide-1 generate
        s_aux_pc_mux (f_idx(u,b))(d) <= s_aux_rdata(u)(c_aux_off_pc  + b*c_aux_num_pc  + d);
      end generate;
      pcn : for b in 0 to c_pc_wide-1 generate
        s_aux_pcn_mux(f_idx(u,b))(d) <= s_aux_rdata(u)(c_aux_off_pc  + b*c_aux_num_pc  + d + 1);
      end generate;
      pcf : for b in 0 to c_pcf_wide-1 generate
        s_aux_pcf_mux(f_idx(u,b))(d) <= s_aux_rdata(u)(c_aux_off_pcf + b*c_aux_num_pcf + d);
      end generate;
    end generate;
    arg : for b in 0 to c_arg_wide-1 generate
      s_arg(u,b) <= f_opa_index(s_aux_arg_mux(f_idx(u,b)), unsigned(f_opa_select_row(r_dec,u)));
    end generate;
    imm : for b in 0 to c_imm_wide-1 generate
      s_imm(u,b) <= f_opa_index(s_aux_imm_mux(f_idx(u,b)), unsigned(f_opa_select_row(r_dec,u)));
      s_imm_pad(u,b) <= s_imm(u,b);
    end generate;
    pc : for b in 0 to c_pc_wide-1 generate
      s_pc (u,b+c_op_align) <= f_opa_index(s_aux_pc_mux (f_idx(u,b)), unsigned(f_opa_select_row(r_dec,u)));
      s_pc_pad(u,b+c_op_align) <= s_pc(u,b+c_op_align);
    end generate;
    pcn : for b in 0 to c_pc_wide-1 generate
      s_pcn(u,b+c_op_align) <= f_opa_index(s_aux_pcn_mux(f_idx(u,b)), unsigned(f_opa_select_row(r_dec,u)));
    end generate;
    pcf : for b in 0 to c_pcf_wide-1 generate
      s_pcf(u,b+c_op_align) <= f_opa_index(s_aux_pcf_mux(f_idx(u,b)), unsigned(f_opa_select_row(r_dec,u)));
    end generate;
    
    sext_imm : if c_imm_wide < c_reg_wide generate
      imm : for b in c_imm_wide to c_reg_wide-1 generate
        s_imm_pad(u,b) <= s_imm(u,c_imm_wide-1);
      end generate;
    end generate;
    sext_adr : if c_adr_wide < c_reg_wide generate
      imm : for b in c_adr_wide to c_reg_wide-1 generate
        s_pc_pad(u,b) <= s_pc(u,c_adr_wide-1);
      end generate;
    end generate;
  end generate;
  
  eu_arg_o <= s_arg;
  eu_imm_o <= s_imm;
  eu_pc_o  <= s_pc;
  eu_pcf_o <= s_pcf;
  eu_pcn_o <= s_pcn;
  
  -- !!! move s_imm to r_imm using async dpram; mux before choice?
  
  remap_rf_in : for u in 0 to c_executers-1 generate
    s_ra_addr(u) <= f_opa_select_row(issue_baka_i, u);
    s_rb_addr(u) <= f_opa_select_row(issue_bakb_i, u);
    s_w_addr(u)  <= f_opa_select_row(r_bakx1, u);
    s_w_data(u)  <= f_opa_select_row(eu_regx_i, u);
  end generate;

  ramsw : for w in 0 to c_executers-1 generate
    ramsr : for r in 0 to c_executers-1 generate
      rama : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_equal  => OPA_UNDEF,
          g_regin  => true,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_addr_i => s_ra_addr(r),
          r_data_o => s_ra_data(f_idx(r, w)),
          w_en_i   => r_wstb1(w),
          w_addr_i => s_w_addr(w),
          w_data_i => s_w_data(w));
      ramb : opa_dpram
        generic map(
          g_width  => c_reg_wide,
          g_size   => c_num_back,
          g_equal  => OPA_UNDEF,
          g_regin  => true,
          g_regout => false)
        port map(
          clk_i    => clk_i,
          rst_n_i  => rst_n_i,
          r_addr_i => s_rb_addr(r),
          r_data_o => s_rb_data(f_idx(r, w)),
          w_en_i   => r_wstb1(w),
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
      
      -- Select from PC+immediate, preventing synthesis from rearranging higher muxes
      pc  : opa_lcell port map(a_i => s_pc_pad (u,b), b_o => s_mux_a(f_idx(u,b))(c_imm));
      imm : opa_lcell port map(a_i => s_imm_pad(u,b), b_o => s_mux_b(f_idx(u,b))(c_imm));
      
      -- Execute the mux
      eu_rega_o(u,b) <= f_opa_index(s_mux_a(f_idx(u,b)), unsigned(f_opa_select_row(r_mux_idx_a,u)));
      eu_regb_o(u,b) <= f_opa_index(s_mux_b(f_idx(u,b)), unsigned(f_opa_select_row(r_mux_idx_b,u)));
    end generate;
  end generate;
  
end rtl;
