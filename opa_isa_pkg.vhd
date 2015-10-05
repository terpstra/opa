--  opa: Open Processor Architecture
--  Copyright (C) 2014-2016  Wesley W. Terpstra
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  To apply the GPL to my VHDL, please follow these definitions:
--    Program        - The entire collection of VHDL in this project and any
--                     netlist or floorplan derived from it.
--    System Library - Any macro that translates directly to hardware
--                     e.g. registers, IO pins, or memory blocks
--    
--  My intent is that if you include OPA into your project, all of the HDL
--  and other design files that go into the same physical chip must also
--  be released under the GPL. If this does not cover your usage, then you

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_riscv_pkg.all;
use work.opa_lm32_pkg.all;

package opa_isa_pkg is

  function f_opa_isa_info(isa : t_opa_isa) return t_opa_isa_info;
  function f_opa_isa_accept(isa : t_opa_isa; config : t_opa_config) return std_logic;
  function f_opa_isa_decode(isa : t_opa_isa; config : t_opa_config; x : std_logic_vector) return t_opa_op;
  
end package;

package body opa_isa_pkg is

  function f_opa_isa_info(isa : t_opa_isa) return t_opa_isa_info is
  begin
    case isa is
      when T_OPA_RV32 => return c_opa_rv32;
      when T_OPA_LM32 => return c_opa_lm32;
    end case;
  end f_opa_isa_info;
  
  function f_opa_isa_accept(isa : t_opa_isa; config : t_opa_config) return std_logic is
  begin
    case isa is
      when T_OPA_RV32 => return f_opa_accept_rv32(config);
      when T_OPA_LM32 => return f_opa_accept_lm32(config);
    end case;
  end f_opa_isa_accept;
  
  function f_opa_isa_decode(isa : t_opa_isa; config : t_opa_config; x : std_logic_vector) return t_opa_op is
    alias y : std_logic_vector(x'length-1 downto 0) is x;
  begin
    case isa is
      when T_OPA_RV32 => return f_opa_decode_rv32(config, y);
      when T_OPA_LM32 => return f_opa_decode_lm32(config, y);
    end case;
  end f_opa_isa_decode;

end opa_isa_pkg;
