library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_predict is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;
    
    -- Deliver our prediction
    icache_stall_i  : in  std_logic;
    icache_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_hit_o    : out std_logic;
    decode_jump_o   : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    
    -- Push a return stack entry
    decode_push_i   : in  std_logic;
    decode_ret_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    
    -- Fixup PC to new target
    decode_fault_i  : in  std_logic;
    decode_return_i : in  std_logic;
    decode_jump_i   : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    decode_source_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_target_i : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align));
end opa_predict;

architecture rtl of opa_predict is

  constant c_adr_wide  : natural := f_opa_adr_wide(g_config);
  constant c_decoders  : natural := f_opa_decoders(g_config);
  constant c_num_fetch : natural := f_opa_num_fetch(g_config);
  constant c_rs_wide   : natural := 5; -- can maybe bump to 8 if IPC gain is substantial
  constant c_rs_deep   : natural := 2**c_rs_wide;
  
  constant c_fetch_adr : unsigned(c_adr_wide-1 downto 0) := to_unsigned(c_num_fetch, c_adr_wide);
  constant c_increment : unsigned(c_adr_wide-1 downto c_op_align) := c_fetch_adr(c_adr_wide-1 downto c_op_align);
  constant c_mask      : unsigned(c_adr_wide-1 downto c_op_align) := not (c_increment - 1);

  signal r_pc : unsigned(c_adr_wide-1 downto c_op_align) := c_increment;
  signal s_pc : unsigned(c_adr_wide-1 downto c_op_align);
  
  signal s_return : unsigned(c_adr_wide-1 downto c_op_align);
  
  signal r_rs_idx : unsigned(c_rs_wide-1 downto 0) := (others => '1');
  signal s_rs_idx : unsigned(c_rs_wide-1 downto 0);
  
  signal r_loop_pc   : unsigned(c_adr_wide-1 downto c_op_align);
  signal r_loop_jump : std_logic_vector(c_decoders-1 downto 0);
  signal r_loop_pcn  : unsigned(c_adr_wide-1 downto c_op_align);

begin

  -- Return stack
  rs : opa_dpram
    generic map(
      g_width  => r_pc'length,
      g_size   => c_rs_deep,
      g_equal  => OPA_UNDEF,
      g_regin  => true,
      g_regout => false)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_addr_i => std_logic_vector(s_rs_idx),
      unsigned(r_data_o) => s_return,
      w_en_i   => decode_push_i,
      w_addr_i => std_logic_vector(s_rs_idx),
      w_data_i => decode_ret_i);
  
  s_rs_idx <=
    r_rs_idx + 1 when decode_push_i = '1' and decode_return_i = '0' else
    r_rs_idx - 1 when decode_push_i = '0' and decode_return_i = '1' else
    r_rs_idx;
  
  rs_idx : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_rs_idx <= (others => '1');
    elsif rising_edge(clk_i) then
      r_rs_idx <= s_rs_idx;
    end if;
  end process;

  -- World's simplest branch predictor!
  s_pc <= 
    s_return                        when decode_return_i='1' else
    unsigned(decode_target_i)       when decode_fault_i ='1' else 
    r_loop_pcn                      when r_pc=r_loop_pc      else
    (r_pc + c_increment) and c_mask;
  
  main : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_pc          <= c_increment;
      decode_jump_o <= (others => '0');
      decode_hit_o  <= '0';
    elsif rising_edge(clk_i) then
      if decode_fault_i = '1' then
        r_loop_pc   <= unsigned(decode_source_i);
        r_loop_jump <= decode_jump_i;
        r_loop_pcn  <= unsigned(decode_target_i);
      end if;
      if icache_stall_i = '0' then
        r_pc          <= s_pc(r_pc'range);
        if r_pc = r_loop_pc then
          decode_jump_o <= r_loop_jump;
          decode_hit_o  <= '1';
        else
          decode_jump_o <= (others => '0');
          decode_hit_o  <= '0';
        end if;
      end if;
    end if;
  end process;
  
  icache_pc_o   <= std_logic_vector(s_pc);

end rtl;
