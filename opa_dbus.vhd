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
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    
    d_cyc_o    : out std_logic;
    d_stb_o    : out std_logic;
    d_we_o     : out std_logic;
    d_stall_i  : in  std_logic;
    d_ack_i    : in  std_logic;
    d_err_i    : in  std_logic;
    d_addr_o   : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_sel_o    : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
    d_data_o   : out std_logic_vector(2**g_config.log_width  -1 downto 0);
    d_data_i   : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
    
    slow_stb_o : out std_logic;
    slow_adr_o : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto 0);
    slow_dat_o : out std_logic_vector(c_dline_size*8          -1 downto 0);
    slow_stb_i : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    slow_adr_i : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto 0));
end opa_dbus;

architecture rtl of opa_dbus is

  constant c_reg_wide : natural := f_opa_reg_wide(g_config);
  constant c_adr_wide : natural := f_opa_adr_wide(g_config);
  constant c_num_slow : natural := f_opa_num_slow(g_config);
  
  constant c_idx_low    : natural := f_opa_log2(c_reg_wide/8);
  constant c_idx_high   : natural := f_opa_log2(c_dline_size);
  constant c_idx_high1  : natural := f_opa_choose(c_idx_low=c_idx_high,1,c_idx_high);
  constant c_idx_wide   : natural := c_idx_high - c_idx_low;
  constant c_idx_wide1  : natural := c_idx_high1- c_idx_low;
  constant c_line_words : natural := 2**c_idx_wide;

  signal s_pick: std_logic_vector(c_num_slow-1 downto 0);
  signal r_cyc : std_logic := '0';
  signal r_stb : std_logic := '0';
  signal s_adr : std_logic_vector(c_adr_wide-1 downto 0);
  signal r_adr : std_logic_vector(c_reg_wide-1 downto 0) := (others => '0');
  signal r_out : unsigned(c_idx_wide1-1 downto 0);
  signal r_in  : unsigned(c_idx_wide1-1 downto 0);
  signal s_mask: unsigned(c_line_words-1 downto 0) := (others => '1');
  signal r_mask: unsigned(c_line_words-1 downto 0);
  signal s_dat : std_logic_vector(c_dline_size*8-1 downto 0);
  signal r_dat : std_logic_vector(c_dline_size*8-1 downto 0);

begin

  datin : for i in 0 to c_line_words-1 generate
    s_dat(c_reg_wide*(i+1)-1 downto c_reg_wide*i) <= 
      d_data_i when r_mask(i)='1' else
      r_dat(c_reg_wide*(i+1)-1 downto c_reg_wide*i);
  end generate;

  s_pick <= f_opa_pick_small(slow_stb_i);
  s_adr  <= f_opa_product(f_opa_transpose(slow_adr_i), s_pick);
  
  mask : for i in 0 to c_line_words-1 generate
    useful : if c_line_words > 1 generate
      big : if c_big_endian generate
        s_mask(i) <= f_opa_bit(unsigned(s_adr(c_idx_high-1 downto c_idx_low)) = (c_line_words-1)-i);
      end generate;
      small : if not c_big_endian generate
        s_mask(i) <= f_opa_bit(unsigned(s_adr(c_idx_high-1 downto c_idx_low)) = i);
      end generate;
    end generate;
  end generate;

  main : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_cyc <= '0';
      r_stb <= '0';
      r_adr <= (others => '0');
      r_out <= (others => '-');
      r_in  <= (others => '-');
      r_mask<= (others => '-');
      r_dat <= (others => '-');
    elsif rising_edge(clk_i) then
      if r_cyc = '0' then
        r_cyc <= f_opa_or(slow_stb_i);
        r_stb <= f_opa_or(slow_stb_i);
        r_adr(c_adr_wide-1 downto 0) <= s_adr;
        r_out <= (others => '0');
        r_in  <= (others => '0');
        r_mask<= s_mask;
        r_dat <= (others => '-');
      else
        if d_stall_i = '0' then
          if r_out = c_line_words-1 then
            r_stb <= '0';
          end if;
          r_out <= r_out + 1;
          -- increment is harmless if only loading one word
          r_adr(c_idx_high1-1 downto c_idx_low) <= 
            std_logic_vector(unsigned(r_adr(c_idx_high1-1 downto c_idx_low)) + 1);
        end if;
        if d_ack_i = '1' then
          if r_in = c_line_words-1 then
            r_cyc <= '0';
          end if;
          r_in <= r_in + 1;
          r_dat <= s_dat;
          if c_big_endian then
            r_mask <= rotate_right(r_mask, 1);
          else
            r_mask <= rotate_left(r_mask, 1);
          end if;
        end if;
      end if;
    end if;
  end process;
  
  d_cyc_o  <= r_cyc;
  d_stb_o  <= r_stb;
  d_we_o   <= '0';
  d_addr_o <= r_adr;
  d_sel_o  <= (others => '1');
  d_data_o <= (others => '0');
  
  slow_stb_o <= d_ack_i;
  slow_adr_o <= r_adr(c_adr_wide-1 downto 0);
  slow_dat_o <= s_dat;

end rtl;
