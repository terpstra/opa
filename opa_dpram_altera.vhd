library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity opa_dpram is
  generic(
    g_width : natural;
    g_size  : natural;
    g_bypass: boolean);
  port(
    clk_i    : in  std_logic;
    rst_n_i  : in  std_logic;
    r_en_i   : in  std_logic;
    r_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    r_data_o : out std_logic_vector(g_width-1 downto 0);
    w_en_i   : in  std_logic;
    w_addr_i : in  std_logic_vector(f_opa_log2(g_size)-1 downto 0);
    w_data_i : in  std_logic_vector(g_width-1 downto 0));
end opa_dpram;

architecture syn of opa_dpram is

  signal r_bypass : std_logic;
  signal s_data   : std_logic_vector(g_width-1 downto 0);
  signal r_data   : std_logic_vector(g_width-1 downto 0);

begin

  ram : altsyncram
    generic map(
      -- intended_device_family             => "Arria V",
      address_aclr_b                     => "NONE",
      address_reg_b                      => "CLOCK0",
      clock_enable_input_a               => "BYPASS",
      clock_enable_input_b               => "BYPASS",
      clock_enable_output_b              => "BYPASS",
      lpm_type                           => "altsyncram",
      numwords_a                         => g_size,
      numwords_b                         => g_size,
      operation_mode                     => "DUAL_PORT",
      outdata_aclr_b                     => "NONE",
      outdata_reg_b                      => "UNREGISTERED",
      power_up_uninitialized             => "FALSE",
      ram_block_type                     => "MLAB",
      read_during_write_mode_mixed_ports => "DONT_CARE",
      widthad_a                          => f_opa_log2(g_size),
      widthad_b                          => f_opa_log2(g_size),
      width_a                            => g_width,
      width_b                            => g_width,
      width_byteena_a                    => 1)
    port map(
      clock0    => clk_i,
      wren_a    => w_en_i,
      address_a => w_addr_i,
      data_a    => w_data_i,
      address_b => r_addr_i,
      q_b       => s_data);

  main : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_data   <= w_data_i;
      r_bypass <= f_opa_bit(r_addr_i = w_addr_i);
    end if;
  end process;
  
  r_data_o <= r_data when (g_bypass and r_bypass = '1') else s_data;

end syn;
