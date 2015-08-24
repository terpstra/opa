library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Open Processor Architecture
package opa_pkg is

  type t_opa_config is record
    log_width  : natural; -- 2**log_width  = # of bits in registers
    adr_width  : natural; -- Virtual address space
    num_decode : natural; -- # of instructions decoded concurrently
    num_stat   : natural; -- # of reservation stations
    num_fast   : natural; -- # of fast EUs (logic, add/sub, branch, ...)
    num_slow   : natural; -- # of slow EUs (load/store, mul, fp, ...)
    ieee_fp    : boolean; -- Floating point support
    dc_ways    : natural; -- Data cache ways (each is 4KB=page_size)
    dtlb_ways  : natural; -- Data TLB ways
  end record;
  
  -- 16-bit processor, 1-issue,  6 stations, 2 EU, 4KB dcache
  constant c_opa_tiny  : t_opa_config := ( 4, 16, 1,  6, 1, 1, false, 1, 1);
  
  -- 32-bit processor, 2-issue,  6 stations, 2 EU, 8KB dcache
  constant c_opa_small : t_opa_config := ( 5, 22, 2,  6, 1, 1, false, 2, 1);
  
  -- 32-bit processor, 2-issue, 14 stations, 3 EU, 16KB dcache
  constant c_opa_mid   : t_opa_config := ( 5, 32, 2, 14, 2, 1, false, 4, 2);
  
  -- 64-bit processor, 4-issue, 28 stations, 5 EU, 32KB dcache
  constant c_opa_large : t_opa_config := ( 6, 39, 4, 28, 3, 2, true,  8, 4);
  
  type t_opa_target is record
    lut_width  : natural; -- How many inputs to combine at once
    add_width  : natural; -- Hardware support for simultaneous adders
    mul_width  : natural; -- Widest DSP multiplier block
    mem_depth  : natural; -- Minimum depth of a memory block
    post_adder : boolean; -- Can add two products (a*b)<<wide + (c*d)
  end record;
  
  -- FPGA flavors supported
  constant c_opa_cyclone_iv : t_opa_target := (4, 2, 18, 256, true);
  constant c_opa_arria_ii   : t_opa_target := (6, 2, 18, 256, true);
  constant c_opa_cyclone_v  : t_opa_target := (6, 3, 27, 256, false);
  constant c_opa_asic       : t_opa_target := (4, 2,  1,   1, false);
  
  component opa is
    generic(
      g_config  : t_opa_config;
      g_target  : t_opa_target);
    port(
      clk_i     : in  std_logic;
      rst_n_i   : in  std_logic;

      -- Wishbone instruction bus
      i_stb_o   : out std_logic;
      i_stall_i : in  std_logic;
      i_ack_i   : in  std_logic;
      i_err_i   : in  std_logic;
      i_addr_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      i_data_i  : in  std_logic_vector(2**g_config.log_width  -1 downto 0);
      
      -- Wishbone data bus
      d_stb_o   : out std_logic;
      d_we_o    : out std_logic;
      d_stall_i : in  std_logic;
      d_ack_i   : in  std_logic;
      d_err_i   : in  std_logic;
      d_addr_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      d_sel_o   : out std_logic_vector(2**g_config.log_width/8-1 downto 0);
      d_data_o  : out std_logic_vector(2**g_config.log_width  -1 downto 0);
      d_data_i  : in  std_logic_vector(2**g_config.log_width  -1 downto 0));
  end component;
  
end package;
