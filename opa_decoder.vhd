library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_decoder is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;

    -- Incoming data
    stb_i          : in  std_logic;
    stall_o        : out std_logic;
    data_i         : in  std_logic_vector(f_opa_decoders(g_config)*c_op_wide-1 downto 0);
    
    -- Parsed
    rename_stb_o   : out std_logic;
    rename_stall_i : in  std_logic;
    rename_setx_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_geta_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1        downto 0);
    rename_typ_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1           downto 0);
    rename_regx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_rega_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_regb_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
end opa_decoder;

architecture rtl of opa_decoder is

  -- Instruction format: CoaB
  -- reg(b) = C(o,a,reg(a),reg(b))

  type t_code is (T_CONST, T_ADDER, T_LOGIC, T_MUL, T_LOAD, T_STORE, T_NOOP);
  type t_code_array is array(natural range <>) of t_code;
  
  function f_typ(x : std_logic_vector(3 downto 0)) return t_code is
  begin
    case x is
      when "0000" => return T_CONST;
      when "0010" => return T_ADDER;
      when "0011" => return T_LOGIC;
      when "0100" => return T_MUL;
      when "1000" => return T_LOAD;
      when "1001" => return T_STORE;
      when others => return T_NOOP;
    end case;
  end f_typ;
  
  function f_setx(x : t_code) return std_logic is
  begin
    case x is
      when T_CONST => return '1';
      when T_ADDER => return '1';
      when T_LOGIC => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '1';
      when T_STORE => return '0';
      when T_NOOP  => return '0';
    end case;
  end f_setx;
  
  function f_geta(x : t_code) return std_logic is
  begin
    case x is
      when T_CONST => return '0';
      when T_ADDER => return '1';
      when T_LOGIC => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '0';
      when T_STORE => return '1';
      when T_NOOP  => return '0';
    end case;
  end f_geta;
  
  function f_getb(x : t_code) return std_logic is
  begin
    case x is
      when T_CONST => return '0';
      when T_ADDER => return '1';
      when T_LOGIC => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '1';
      when T_STORE => return '1';
      when T_NOOP  => return '0';
    end case;
  end f_getb;
  
  function f_unit(x : t_code) return std_logic_vector is
    variable y : natural;
    variable result : std_logic_vector(c_types-1 downto 0) := (others => '0');
  begin
    case x is
      when T_CONST => y := c_type_ieu;
      when T_ADDER => y := c_type_ieu;
      when T_LOGIC => y := c_type_ieu;
      when T_MUL   => y := c_type_mul;
      when T_LOAD  => y := c_type_load;
      when T_STORE => y := c_type_store;
      when T_NOOP  => y := c_type_ieu;
    end case;
    result(y) := '1';
    return result;
  end f_unit;
  
  function f_aux(x : t_code; w : std_logic_vector) return std_logic_vector is
    alias v : std_logic_vector(7 downto 0) is w;
    variable result : std_logic_vector(c_aux_wide-1 downto 0) := (others => '-');
  begin
    case x is
      when T_CONST => 
        result(9 downto 8) := "00"; 
        result(7 downto 0) := v;
      when T_ADDER => 
        result(9 downto 8) := "1" & v(7);
        result(2 downto 0) := v(6 downto 4);
      when T_LOGIC => 
        result(9 downto 8) := "01";
        result(3 downto 0) := v(7 downto 4);
      when T_MUL   => null;
      when T_LOAD  => null;
      when T_STORE => null;
      when T_NOOP  => null;
    end case;
    return result;
  end f_aux;
  
  signal s_typ : t_code_array(f_opa_decoders(g_config)-1 downto 0);

begin

  rename_stb_o <= stb_i;
  stall_o <= rename_stall_i;
  
  parse : for i in 0 to f_opa_decoders(g_config)-1 generate
  
    s_typ(i) <= f_typ(data_i(16*i+15 downto 16*i+12));
    
    rename_setx_o(i) <= f_setx(s_typ(i));
    rename_geta_o(i) <= f_geta(s_typ(i));
    rename_getb_o(i) <= f_getb(s_typ(i));
    
    typ : for b in 0 to c_types-1 generate
      rename_typ_o(i,b) <= f_unit(s_typ(i))(b);
    end generate;
    
    aux : for b in 0 to c_aux_wide-1 generate
      rename_aux_o(i,b) <= f_aux(s_typ(i), data_i(16*i+11 downto 16*i+4))(b);
    end generate;
  
    bits : for b in 0 to 3 generate
      rename_regx_o(i,b) <= data_i(16*i+ 0+b);
      rename_rega_o(i,b) <= data_i(16*i+ 4+b);
      rename_regb_o(i,b) <= data_i(16*i+ 0+b);
    end generate;
  end generate;
  
end rtl;
