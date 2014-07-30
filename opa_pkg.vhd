library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Open Processor Architecture
package opa_pkg is

  type t_opa_config is record
    log_arch   : natural; -- 2**log_arch   = # of architectural registers
    log_width  : natural; -- 2**log_width  = # of bits in registers
    num_decode : natural; -- # of instructions decoded concurrently
    num_stat   : natural; -- # of reservation stations (must be divisible by num_decode)
    num_ieu    : natural; -- # of IEUs (logic, add/sub, ...)
    num_mul    : natural; -- # of multipliers (mulhi, mullo, <<, >>, rol, ...)
  end record;
  
  -- target modern FPGAs with 6-input LUTs
  constant c_lut_width : natural := 6;
  
  -- 16-bit processor, 1-issue
  constant c_opa_tiny : t_opa_config := ( 4, 4, 1,  4, 1, 1);
  
  -- 32-bit processor, 2-issue
  constant c_opa_mid  : t_opa_config := ( 4, 5, 2,  8, 1, 1);
  
  -- 64-bit processor, 4-issue
  constant c_opa_full : t_opa_config := ( 4, 6, 4, 24, 3, 2);
  
  component opa is
    generic(
      g_config : t_opa_config);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;

      -- Incoming data
      stb_i          : in  std_logic;
      stall_o        : out std_logic;
      data_i         : in  std_logic_vector(g_config.num_decode*16-1 downto 0));
  end component;
  
  -- good sizes for reservation stations on a 6-lut system: 4, 9, 24, 69
  
  -- instruction format:
  -- 4op 4sub 4dst 4arg
  -- 4op 12const    ==> const replaces dst as arg1
  -- ... constants in a row => bigger constants
  -- constants + moves never reach the issue stage
  
end package;

package body opa_pkg is
end opa_pkg;
