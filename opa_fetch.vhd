library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_fetch is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;
    
    -- Deliver our prediction
    decode_stb_o    : out std_logic;
    decode_stall_i  : in  std_logic;
    decode_hit_o    : out std_logic;
    decode_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_jump_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    
    -- Push a return stack entry
    decode_push_i   : in  std_logic;
    decode_ret_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    
    -- Fixup PC to new target
    decode_fault_i  : in  std_logic;
    decode_return_i : in  std_logic;
    decode_jump_o   : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_source_o : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_target_o : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align));
    
    -- Branch misprediction reported by issue stage
    -- !!! write this
end opa_fetch;

architecture rtl of opa_fetch is
  -- We lookup the icache (2-cycle) at the same time as the BTB
  -- The BTB tells us what to load next
  
  constant c_adr_wide : natural := f_opa_adr_wide(g_config);
  constant c_num_btb  : natural := 1024; -- from config?
  constant c_btb_wide : natural := f_opa_log2(c_num_btb);
  constant c_tag_wide : natural := c_btb_wide;
  constant c_out_wide : natural := c_adr_wide + c_tag_wide + c_decoders + 1;

  signal r_pc    : unsigned(c_adr_wide-1 downto c_op_align);
  signal s_pc    : unsigned(c_adr_wide-1 downto c_op_align);
  signal r_tag   : std_logic_vector(c_tag_wide-1 downto 0);
  signal s_tag   : std_logic_vector(c_tag_wide-1 downto 0);
  signal s_hash  : std_logic_vector(c_btb_wide-1 downto 0);
  signal r_match : std_logic;
  signal s_match : std_logic;
  
begin

  -- Consider making this N-way
  btb : opa_dpram
     generic(
       g_width  => c_btb_wide,
       g_size   => c_num_btb,
       g_bypass => true,
       g_regout => false);
     port(
       clk_i    => clk_i,
       rst_n_i  => rst_n_i,
       r_en_i   => '1',
       r_addr_i => s_hash,
       r_data_o => s_out,
       w_en_i   => ... -- !!! update on issue fault
       w_addr_i =>
       w_data_i => );
  
  s_out_target    <=
  s_out_tag       <=
  s_out_mask      <=
  s_out_pop_stack <= 
  
  s_match <= '1' when r_tag = s_out_tag else '0';

  s_pc <= 
    unsigned(issue_pcn_i) when issue_fault_i='1' else
    r_pc + 8              when s_match='0'       else
    s_stack_target        when s_pop_stack='1'   else
    s_out_target; -- !!! also include fault from decoder
  
  s_hash <= f_opa_hash(s_pc, 1); -- !!! concat PID
  s_tag  <= f_opa_hash(s_pc, 0);
  
  btb_main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_tag   <= s_tag;
      r_pc    <= s_pc;
      r_match <= s_match;
    end if;
  end process;
  
  -- Use MLABs for the PC/imm+arg data => shallow depth! (window/decoder <= 32) (80 wide)
  --   we pay decoders*EU copies ... altho this is somewhat ok, b/c EU reads two at once
  --     ... for big opa: 20 copies. a MLAB storage goes from 20 to 32*20
  --                      20*4=80 MLABs to store 80*24=2240 bits > 80*20 ... so still a win
  --     ... for mid opa: 6 copies vs 14*80=1120 > 6*4*20=480 ... also a win
  --     ... and this neglects the combinational cost you pay to decode the raw bits
  --   would be a good choice for the stack buffer
  -- When decoding aux_o in issue, maybe don't compose? use aux_count + f_1hot_decode(schedule)
  --  ... compose has only 4* the fan-in of f_1hot_decode... and is highly regular
  -- Try also using an MLAB for bak[abx1]
  --  ...  you only do the fan in ONCE with the MLAB; the MLAB spits out all 6*3 bits
  --       it lets you go from aux to bak[abx1]... but it puts an MLAB on the critical path
  -- the mux decode path is SO FUCKING HUGE! what can be done???
  -- ... i still find it shocking that making issue_bak[ax]_i a register didn't help
  
  -- also, maybe use a CAM writen by each load, read on store commit
  
end rtl;
