library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Open Processor Architecture
package opa_pkg is

  type t_opa_config is record
    log_arch   : natural; -- 2**log_arch   = # of architectural registers
    log_width  : natural; -- 2**log_width  = # of bits in registers
    num_decode : natural; -- # of instructions decoded concurrently
    num_issue  : natural; -- # of reservation stations used for issue
    num_wait   : natural; -- # of reservation stations used for commit
    num_ieu    : natural; -- # of IEUs (logic, add/sub, ...)
    num_mul    : natural; -- # of *independant* multipliers (mulhi, mullo, <<, >>, rol, ...)
    ieee_fp    : boolean; -- Floating point support (in mul units)
    da_bits    : natural; -- Data address bits
    dc_ways    : natural; -- Data cache ways
    dc_depth   : natural; -- Data cache depth
    dc_words   : natural; -- Data cache words/line
    dtlb_ways  : natural; -- Data TLB ways
    dtlb_depth : natural; -- Data TLB depth
  end record;
  
  -- 16-bit processor, 1-issue,  6+2 stations, 2 EU,  256x  2KB pages,  2KB cache
  constant c_opa_tiny  : t_opa_config := ( 4, 4, 1,  6, 2, 1, 0, false, 16, 1,  8, 4, 1,  8);
  
  -- 32-bit processor, 2-issue,  6+2 stations, 2 EU,  256x  4KB pages,  4KB cache
  constant c_opa_small : t_opa_config := ( 4, 5, 2,  6, 2, 1, 0, false, 32, 1,  8, 4, 1,  8);
  
  -- 32-bit processor, 2-issue, 12+4 stations, 3 EU, 2048x 16KB pages, 32KB cache
  constant c_opa_mid   : t_opa_config := ( 4, 5, 2, 12, 4, 2, 1, true,  32, 2, 10, 4, 2, 10);
  
  -- 64-bit processor, 2-issue, 12+4 stations, 4 EU, 4096x 32KB pages, 128KB cache
  constant c_opa_large : t_opa_config := ( 4, 6, 2, 12, 4, 2, 1, true,  32, 4, 10, 4, 4, 10);
  
  -- 64-bit processor, 4-issue, 24+8 stations, 8 EU, 4096x 32KB pages, 128KB cache
  constant c_opa_huge  : t_opa_config := ( 4, 6, 4, 64, 0, 3, 2, true,  64, 4, 10, 4, 4, 10);
  
  type t_opa_target is record
    lut_width  : natural; -- How many inputs to combine at once
    add_width  : natural; -- Hardware support for simultaneous adders
    mul_width  : natural; -- Widest DSP multiplier block
    post_adder : boolean; -- Can add two products (a*b)<<wide + (c*d)
  end record;
  
  -- FPGA flavors supported
  constant c_opa_cyclone_iv : t_opa_target := (4, 2, 18, true);
  constant c_opa_arria_ii   : t_opa_target := (6, 2, 18, true);
  constant c_opa_cyclone_v  : t_opa_target := (6, 3, 27, false);
  constant c_opa_asic       : t_opa_target := (4, 2,  1, false);
  
  -- current ISA has 16-bit sized instructions
  constant c_op_wide   : natural := 16;
  
  component opa is
    generic(
      g_config  : t_opa_config;
      g_target  : t_opa_target);
    port(
      clk_i     : in  std_logic;
      rst_n_i   : in  std_logic;

      -- Incoming data
      stb_i     : in  std_logic;
      stall_o   : out std_logic;
      data_i    : in  std_logic_vector(g_config.num_decode*c_op_wide-1 downto 0);
      
      -- Wishbone data bus
      d_stb_o   : out std_logic;
      d_we_o    : out std_logic;
      d_stall_i : in  std_logic;
      d_ack_i   : in  std_logic;
      d_err_i   : in  std_logic;
      d_addr_o  : out std_logic_vector(g_config.da_bits-1 downto 0);
      d_sel_o   : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
      d_data_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      d_data_i  : out std_logic_vector(2**g_config.log_width  -1 downto 0));
  end component;
  
end package;

package body opa_pkg is
end opa_pkg;
