library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_icache is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i           : in  std_logic;
    rst_n_i         : in  std_logic;
    
    predict_stall_o : out std_logic;
    predict_pc_i    : in  std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    
    decode_stb_o    : out std_logic;
    decode_stall_i  : in  std_logic;
    decode_pc_o     : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_pcn_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto c_op_align);
    decode_dat_o    : out std_logic_vector(f_opa_num_fetch(g_config)*8-1 downto 0);
    
    i_cyc_o         : out std_logic;
    i_stb_o         : out std_logic;
    i_stall_i       : in  std_logic;
    i_ack_i         : in  std_logic;
    i_err_i         : in  std_logic;
    i_addr_o        : out std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0);
    i_data_i        : in  std_logic_vector(f_opa_reg_wide(g_config)-1 downto 0));
end opa_icache;

architecture rtl of opa_icache is

  constant c_reg_wide  : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide  : natural := f_opa_adr_wide(g_config);
  constant c_num_fetch : natural := f_opa_num_fetch(g_config);
  constant c_num_load  : natural := c_num_fetch*8/c_reg_wide;
  constant c_reg_align : natural := f_opa_log2(c_reg_wide/8);
  constant c_load_wide : natural := f_opa_log2(c_num_load);
  constant c_page_wide : natural := f_opa_log2(c_page_size);
  constant c_fetch_wide: natural := f_opa_log2(c_num_fetch);
  constant c_tag_wide  : natural := c_adr_wide - c_page_wide;
  constant c_size      : natural := c_page_size/c_num_fetch;
  
  constant c_fetch_adr : unsigned(c_adr_wide-1 downto 0) := to_unsigned(c_num_fetch, c_adr_wide);
  constant c_increment : unsigned(c_adr_wide-1 downto c_op_align) := c_fetch_adr(c_adr_wide-1 downto c_op_align);
  
  signal r_hit   : std_logic;
  signal s_stall : std_logic;
  signal s_dstb  : std_logic;
  signal s_repeat: std_logic;
  signal s_wen   : std_logic;
  signal r_wen   : std_logic;
  signal r_icyc  : std_logic;
  signal r_istb  : std_logic;
  signal s_raddr : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal s_rtag  : std_logic_vector(c_adr_wide-1 downto c_page_wide);
  signal s_rdata : std_logic_vector(c_num_fetch*8-1 downto 0);
  signal r_rdata : std_logic_vector(c_num_fetch*8-1 downto 0);
  signal s_wdata : std_logic_vector(c_num_fetch*8-1 downto 0);
  signal r_wdata : std_logic_vector(c_num_fetch*8-1 downto 0);
  signal s_rraw  : std_logic_vector(c_tag_wide+c_num_fetch*8-1 downto 0);
  signal s_wraw  : std_logic_vector(c_tag_wide+c_num_fetch*8-1 downto 0);
  signal r_pc1   : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_pc2   : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_load  : unsigned(c_load_wide-1 downto 0);
  signal r_got   : unsigned(c_load_wide-1 downto 0);

begin

  -- !!! figure out a way get a read address stall in dpram
  s_raddr <= predict_pc_i when s_stall='0' else r_pc1;
  
  cache : opa_dpram
    generic map(
      g_width  => s_rtag'length + s_rdata'length,
      g_size   => c_size,
      g_bypass => false,
      g_regin  => true,
      g_regout => false)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_addr_i => s_raddr(c_page_wide-1 downto c_fetch_wide),
      r_data_o => s_rraw,
      w_en_i   => s_wen,
      w_addr_i => r_pc2 (c_page_wide-1 downto c_fetch_wide),
      w_data_i => s_wraw);
  
  -- !!! add a valid bit; inverting the tag is temporary
  s_rtag  <= not s_rraw(s_rraw'left downto s_rdata'length);
  s_rdata <= s_rraw(s_rdata'range);
  s_wraw(s_wraw'left downto s_wdata'length) <= not r_pc2(s_rtag'range);
  s_wraw(s_wdata'range) <= s_wdata;

  -- The r_pc[12] comparison ensures that if we just wrote to the cache,
  -- and there were two back-to-back fetches of the same address, we get
  -- the new data as output.
  s_repeat <= f_opa_bit(r_pc1 = r_pc2);
  
  pc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_hit <= '0';
      r_pc1 <= std_logic_vector(c_increment);
      r_pc2 <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_stall = '0' then
        r_hit <= f_opa_bit(r_pc1(s_rtag'range) = s_rtag) or s_repeat;
        r_pc1 <= predict_pc_i;
        r_pc2 <= r_pc1;
      end if;
    end if;
  end process;
  
  rdata : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_stall = '0' and s_repeat = '0' then
        r_rdata <= s_rdata;
      end if;
      if s_wen = '1' then
        r_rdata <= s_wdata;
      end if;
    end if;
  end process;
  
  s_stall <= decode_stall_i or not s_dstb;
  s_dstb <= r_hit or r_wen;
  
  predict_stall_o <= s_stall;
  
  decode_stb_o  <= s_dstb;
  decode_pc_o   <= r_pc2;
  decode_pcn_o  <= r_pc1;
  decode_dat_o  <= r_rdata;
  
  -- When accepting data into the line, endian matters
  big : if c_big_endian generate
    s_wdata <= r_wdata(c_num_fetch*8-c_reg_wide-1 downto 0) & i_data_i;
  end generate;
  small : if not c_big_endian generate
    s_wdata <= i_data_i & r_wdata(c_num_fetch*8-1 downto c_reg_wide);
  end generate;
  
  refill : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if (r_icyc and i_ack_i) = '1' then
        r_wdata <= s_wdata;
      end if;
    end if;
  end process;
  
  -- !!! think about what to do on i_err_i
  
  i_cyc_o <= r_icyc;
  i_stb_o <= r_istb;
  
  i_addr_o(c_reg_wide  -1 downto c_adr_wide-1) <= (others => r_pc2(r_pc2'left));
  i_addr_o(c_adr_wide  -2 downto c_fetch_wide) <= r_pc2(c_adr_wide-2 downto c_fetch_wide);
  -- !!! what if c_decoders*c_op_size <= c_reg_wide ... => make icache line larger
  i_addr_o(c_fetch_wide-1 downto c_reg_align)  <= std_logic_vector(r_load);
  i_addr_o(c_reg_align -1 downto 0)            <= (others => '0');
  
  s_wen  <= i_ack_i and f_opa_bit(r_got = c_num_load-1);
  fill : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_wen  <= '0';
      r_load <= (others => '0');
      r_got  <= (others => '0');
      r_icyc <= '0';
      r_istb <= '0';
    elsif rising_edge(clk_i) then
      if s_wen = '1' then
        r_wen <= '1';
      elsif decode_stall_i = '0' then
        r_wen <= '0';
      end if;
      if (not s_dstb and not r_icyc) = '1' then
        r_load <= (others => '0');
        r_got  <= (others => '0');
        r_istb <= '1';
        r_icyc <= '1';
      else
        if (r_istb and not i_stall_i) = '1' then
          r_load <= r_load + 1;
          r_istb <= f_opa_bit(r_load /= c_num_load-1);
        end if;
        if (r_icyc and i_ack_i) = '1' then
          r_got  <= r_got + 1;
          r_icyc <= f_opa_bit(r_got /= c_num_load-1);
        end if;
      end if;
    end if;
  end process;
  
end rtl;
