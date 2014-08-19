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
  end record;
  
  -- target modern FPGAs with 6-input LUTs
  -- 16-bit processor, 1-issue,  6+2 stations, 2 EU
  constant c_opa_tiny  : t_opa_config := ( 4, 4, 1,  6, 2, 1, 0, false);
  
  -- 32-bit processor, 2-issue,  6+2 stations, 2 EU
  constant c_opa_small : t_opa_config := ( 4, 5, 2,  6, 2, 1, 0, false);
  
  -- 32-bit processor, 2-issue, 12+4 stations, 3 EU
  constant c_opa_mid   : t_opa_config := ( 4, 5, 2, 12, 4, 2, 1, true);
  
  -- 64-bit processor, 2-issue, 12+4 stations, 4 EU
  constant c_opa_large : t_opa_config := ( 4, 6, 2, 12, 4, 2, 1, true);
  
  -- 64-bit processor, 4-issue, 24+8 stations, 8 EU
  constant c_opa_huge  : t_opa_config := ( 4, 6, 4, 64, 0, 3, 2, true);
  
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
      g_config : t_opa_config;
      g_target : t_opa_target);
    port(
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;

      -- Incoming data
      stb_i          : in  std_logic;
      stall_o        : out std_logic;
      data_i         : in  std_logic_vector(g_config.num_decode*c_op_wide-1 downto 0);
      good_o         : out std_logic);
  end component;
  
end package;

package body opa_pkg is
end opa_pkg;
