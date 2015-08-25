library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;
use work.opa_isa_pkg.all;

entity opa_decode is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i            : in  std_logic;
    rst_n_i          : in  std_logic;

    -- Predicted jumps?
    predict_hit_i    : in  std_logic;
    predict_jump_i   : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    
    -- Push a return stack entry
    predict_push_o   : out std_logic;
    predict_ret_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    
    -- Fixup PC to new target
    predict_fault_o  : out std_logic;
    predict_return_o : out std_logic;
    predict_jump_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    predict_source_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    predict_target_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);

    -- Instructions delivered from icache
    icache_stb_i     : in  std_logic;
    icache_stall_o   : out std_logic;
    icache_pc_i      : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    icache_pcn_i     : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    icache_dat_i     : in  std_logic_vector(f_opa_num_fetch(g_config)*8-1 downto 0);
    
    -- Feed data to the renamer
    rename_stb_o     : out std_logic;
    rename_stall_i   : in  std_logic;
    rename_fast_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_slow_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_setx_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_geta_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_o    : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_o     : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    rename_archx_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    rename_archa_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);
    rename_archb_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arch_wide(g_config)-1 downto 0);

    -- Give the regfile the information EUs will need for these operations
    regfile_stb_o    : out std_logic;
    regfile_aux_o    : out std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    regfile_arg_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_arg_wide(g_config)-1 downto 0);
    regfile_imm_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_imm_wide(g_config)-1 downto 0);
    regfile_pc_o     : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto c_op_align);
    regfile_pcf_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_fetch_wide(g_config)-1 downto c_op_align);
    regfile_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align));
end opa_decode;

architecture rtl of opa_decode is

  constant c_decoders : natural := f_opa_decoders(g_config);
  constant c_num_aux  : natural := f_opa_aux_wide(g_config);
  constant c_adr_wide : natural := f_opa_adr_wide(g_config);
  constant c_dec_wide : natural := f_opa_dec_wide(g_config);
  constant c_aux_wide : natural := f_opa_aux_wide(g_config);
  constant c_fetch_wide : natural := f_opa_fetch_wide(g_config);
  
  constant c_min_imm_pc : natural := f_opa_choose(c_imm_wide<c_adr_wide, c_imm_wide, c_adr_wide);
  
  constant c_zeros : std_logic_vector(c_decoders-1 downto 0) := (others => '0');
  
  type t_op_array  is array(natural range <>) of t_opa_op;
  type t_pc_array  is array(natural range <>) of std_logic_vector(c_adr_wide-1 downto c_op_align);
  type t_pcf_array is array(natural range <>) of std_logic_vector(c_fetch_wide-1 downto c_op_align);
  type t_idx_array is array(natural range <>) of unsigned(c_dec_wide-1 downto 0);
  
  function f_flip(x : natural) return natural is
  begin
    if c_big_endian then
      return c_decoders-1-x;
    else
      return x;
    end if;
  end f_flip;

  signal s_pc_off      : unsigned(c_dec_wide-1 downto 0);
  signal s_ops_in      : t_op_array(c_decoders-1 downto 0);
  signal s_pc_in       : t_pc_array(c_decoders-1 downto 0);
  signal s_mask_skip   : std_logic_vector(c_decoders-1 downto 0);
  signal s_mask_tail   : std_logic_vector(c_decoders-1 downto 0);
  signal s_can_jump    : std_logic_vector(c_decoders-1 downto 0);
  signal s_often_jump  : std_logic_vector(c_decoders-1 downto 0);
  signal s_must_jump   : std_logic_vector(c_decoders-1 downto 0);
  signal s_push        : std_logic_vector(c_decoders-1 downto 0);
  signal s_pop         : std_logic_vector(c_decoders-1 downto 0);
  
  signal s_hit         : std_logic_vector(c_decoders-1 downto 0);
  signal s_bad_jump    : std_logic_vector(c_decoders-1 downto 0);
  signal s_fault       : std_logic;
  signal r_fault       : std_logic;
  
  signal s_mux           : t_opa_matrix(c_decoders-1 downto 0, 1 downto 0);
  signal s_imm           : t_opa_matrix(c_decoders-1 downto 0, c_imm_wide-1 downto 0);
  signal s_static_jump   : std_logic_vector(c_decoders-1 downto 0);
  signal s_static_mux    : std_logic_vector(1 downto 0);
  signal s_static_imm    : std_logic_vector(c_imm_wide-1 downto 0);
  signal s_static_imm_pad: unsigned(c_adr_wide-1 downto c_op_align);
  signal s_static_pc     : unsigned(c_adr_wide-1 downto c_op_align);
  signal s_static_target : unsigned(c_adr_wide-1 downto c_op_align);
  
  signal s_jump_taken : std_logic_vector(c_decoders-1 downto 0);
  signal s_pcn_taken  : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal s_jal_pc     : std_logic_vector(c_adr_wide-1 downto c_op_align);

  signal s_idx_base : unsigned(c_dec_wide-1 downto 0);
  signal s_idx      : t_idx_array(c_decoders*3-1 downto 0);
  signal s_ops      : t_op_array(c_decoders*3-1 downto 0);
  signal r_ops      : t_op_array(c_decoders*3-1 downto 0);
  signal s_pc       : t_pc_array(c_decoders*3-1 downto 0);
  signal r_pc       : t_pc_array(c_decoders*3-1 downto 0);
  signal s_pcf      : t_pcf_array(c_decoders*3-1 downto 0);
  signal r_pcf      : t_pcf_array(c_decoders*3-1 downto 0);
  
  signal s_stb      : std_logic;
  signal s_stall    : std_logic;
  signal s_progress : std_logic;
  signal s_accept   : std_logic;
  signal s_ops_sub  : unsigned(c_dec_wide-1 downto 0);
  signal r_fill     : unsigned(c_dec_wide+1 downto 0);
  signal r_aux      : unsigned(c_aux_wide-1 downto 0);
  
begin

  -- Decode the flow control information from the instructions
  s_pc_off <= unsigned(icache_pc_i(c_fetch_wide-1 downto c_op_align));
  s_mask_tail(0) <= '0';
  decode : for i in 0 to c_decoders-1 generate
    s_ops_in(i)     <= f_decode(icache_dat_i((f_flip(i)+1)*c_op_wide-1 downto f_flip(i)*c_op_wide));
    s_pc_in(i)      <= icache_pc_i(c_adr_wide-1 downto c_fetch_wide) & std_logic_vector(to_unsigned(i, c_dec_wide));
    
    s_mask_skip(i)  <= '1' when i < s_pc_off else '0'; -- Unused ops before loaded PC
    tail : if i > 0 generate
      s_mask_tail(i)  <= s_mask_tail(i-1) or predict_jump_i(i-1); -- Ops following a taken jump
    end generate;
    
    s_can_jump(i)   <= '1' when s_ops_in(i).jump >= c_opa_jump_seldom else '0';
    s_often_jump(i) <= '1' when s_ops_in(i).jump >= c_opa_jump_often  else '0';
    s_must_jump(i)  <= '1' when s_ops_in(i).jump >= c_opa_jump_always else '0';
    s_push(i)       <= '1' when s_ops_in(i).push = '1' else '0';
    s_pop(i)        <= '1' when s_ops_in(i).dest = c_opa_jump_return_stack else '0';
  end generate;
  
  -- Decide if we want to accept the fetch prediction
  s_hit <= (others => predict_hit_i);
  s_bad_jump <= ((not s_can_jump and predict_jump_i) or
                 (s_must_jump and not predict_jump_i) or
                 (s_often_jump and not s_hit))
                 and not s_mask_skip and not s_mask_tail;
  s_fault <= '0' when s_bad_jump = c_zeros else '1';
  
  map_imm : for i in 0 to c_decoders-1 generate
    s_mux(i,0) <= s_ops_in(i).dest(0);
    s_mux(i,1) <= s_ops_in(i).dest(1);
    bits : for b in 0 to c_imm_wide-1 generate
      s_imm(i,b) <= s_ops_in(i).imm(b);
    end generate;
  end generate;
  
  -- What is our prediction?
  s_static_jump <= f_opa_pick_small(s_often_jump and not s_mask_skip);
  s_static_mux  <= f_opa_product(f_opa_transpose(s_mux), s_static_jump);
  s_static_imm  <= f_opa_product(f_opa_transpose(s_imm), s_static_jump);
  
  s_static_pc(c_adr_wide-1 downto c_fetch_wide) <= unsigned(icache_pc_i(c_adr_wide-1 downto c_fetch_wide));
  s_static_pc(c_fetch_wide-1 downto c_op_align) <= unsigned(f_opa_1hot_dec(s_static_jump));
  
  s_static_imm_pad(c_min_imm_pc-1 downto c_op_align) <= unsigned(s_static_imm(c_min_imm_pc-1 downto c_op_align));
  pad : if c_imm_wide < c_adr_wide generate
    s_static_imm_pad(c_adr_wide-1 downto c_imm_wide) <= (others => s_static_imm_pad(c_imm_wide-1));
  end generate;
  
  with s_static_mux select
  s_static_target <= 
    s_static_imm_pad               when c_opa_jump_to_immediate,
    s_static_imm_pad + s_static_pc when c_opa_jump_add_immediate,
    (others => '-')                when others;

  s_jump_taken <= s_static_jump when s_fault='1' else predict_jump_i;
  s_pcn_taken  <= std_logic_vector(s_static_target) when s_fault='1' else icache_pcn_i;
  
  -- Feed back information to fetch
  predict_fault_o  <= s_fault and s_accept;
  predict_return_o <= '0' when (s_pop and s_static_jump) = c_zeros else '1';
  predict_jump_o   <= s_static_jump;
  predict_source_o <= icache_pc_i;
  predict_target_o <= std_logic_vector(s_static_target);
  
  -- Do we need to push the PC?
  s_jal_pc(c_adr_wide  -1 downto c_fetch_wide) <= icache_pc_i(c_adr_wide-1 downto c_fetch_wide);
  s_jal_pc(c_fetch_wide-1 downto c_op_align)   <= f_opa_1hot_dec(s_jump_taken);
  predict_push_o <= '0' when (s_push and s_jump_taken) = c_zeros else s_accept;
  predict_ret_o  <= std_logic_vector(1 + unsigned(s_jal_pc));
  
  -- Flow control from fetch and to rename
  s_stall    <= '1' when r_fill >  2*c_decoders else '0';
  s_stb      <= '1' when r_fill >=   c_decoders else '0';
  s_progress <= s_stb and not rename_stall_i;
  s_accept   <= icache_stb_i and not r_fault and not s_stall;
  
  -- Select the new buffer fill state
  s_idx_base <= s_pc_off - r_fill(s_idx_base'range);
  ops : for i in 0 to c_decoders*3-1 generate
    s_idx(i) <= s_idx_base + to_unsigned(i mod c_decoders, c_dec_wide);
    s_ops(i) <= r_ops(i) when i < r_fill else s_ops_in(to_integer(s_idx(i)));
    s_pcf(i) <= r_pcf(i) when i < r_fill else icache_pc_i(c_fetch_wide-1 downto c_op_align);
    s_pc (i) <= r_pc (i)    when i < r_fill else 
                s_pcn_taken when i >= r_fill+c_decoders-s_ops_sub else
                s_pc_in(to_integer(s_idx(i)));
    -- the hideous s_pcn_taken case might be too slow.
    -- an alternative is to only s_stb when >= c_decoders+1
  end generate;
  
  s_ops_sub <= unsigned(f_opa_1hot_dec(f_opa_reverse(s_jump_taken))) + s_pc_off;
  fill : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_fault <= '0';
      r_fill  <= (others => '0');
    elsif rising_edge(clk_i) then
      -- On a fault, we ignore the next valid icache strobe
      if (icache_stb_i and not s_stall) = '1' then
        if r_fault = '1' then
          r_fault <= '0';
        else
          r_fault <= s_fault;
        end if;
      end if;
      
      if s_progress = '1' then
        if s_accept = '1' then
          r_fill <= r_fill - s_ops_sub; -- r_fill - c_decoders + (c_decoders - s_ops_sub)
        else
          r_fill <= r_fill - c_decoders;
        end if;
      else
        if s_accept = '1' then
          r_fill <= r_fill + c_decoders - s_ops_sub;
        else
          r_fill <= r_fill;
        end if;
      end if;
    end if;
  end process;
  
  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_progress = '1' then
        r_ops(c_decoders*2-1 downto 0) <= s_ops(c_decoders*3-1 downto c_decoders);
        r_pcf(c_decoders*2-1 downto 0) <= s_pcf(c_decoders*3-1 downto c_decoders);
        r_pc (c_decoders*2-1 downto 0) <= s_pc (c_decoders*3-1 downto c_decoders);
        r_pc (c_decoders*3-1 downto c_decoders*2) <= (others => s_pcn_taken);
        if r_aux = c_num_aux-1 then
          r_aux <= (others => '0');
        else
          r_aux <= r_aux+1;
        end if;
      else
        r_ops <= s_ops;
        r_pcf <= s_pcf;
        r_pc  <= s_pc;
        r_aux <= r_aux;
      end if;
    end if;
  end process;
  
  icache_stall_o <= s_stall;
  
  rename_stb_o <= s_stb;
  rename_aux_o <= std_logic_vector(r_aux);
  ops_out : for d in 0 to c_decoders-1 generate
    rename_fast_o(d) <= r_ops(d).fast;
    rename_slow_o(d) <= not r_ops(d).fast;
    rename_setx_o(d) <= r_ops(d).setx;
    rename_geta_o(d) <= r_ops(d).geta;
    rename_getb_o(d) <= r_ops(d).getb;
    bits : for b in 0 to c_log_arch-1 generate
      rename_archx_o(d,b) <= r_ops(d).archx(b);
      rename_archa_o(d,b) <= r_ops(d).archa(b);
      rename_archb_o(d,b) <= r_ops(d).archb(b);
    end generate;
  end generate;
  
  regfile_stb_o <= s_stb;
  regfile_aux_o <= std_logic_vector(r_aux);
  rf_out : for d in 0 to c_decoders-1 generate
    arg : for b in 0 to c_arg_wide-1 generate
      regfile_arg_o(d,b) <= r_ops(d).arg(b);
    end generate;
    imm : for b in 0 to c_imm_wide-1 generate
      regfile_imm_o(d,b) <= r_ops(d).imm(b);
    end generate;
    pc : for b in c_op_align to c_adr_wide-1 generate
      regfile_pc_o(d,b) <= r_pc(d)(b);
    end generate;
    pcf : for b in c_op_align to c_fetch_wide-1 generate
      regfile_pcf_o(d,b) <= r_pcf(d)(b);
    end generate;
  end generate;
  pcn : for b in c_op_align to c_adr_wide-1 generate
    regfile_pcn_o(b) <= r_pc(c_decoders)(b);
  end generate;
  
end rtl;
