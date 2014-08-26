library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_decode is
  generic(
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;

    fetch_dat_i    : in  std_logic_vector(f_opa_decoders(g_config)*c_op_wide-1 downto 0);
    rename_fast_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_slow_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_setx_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_geta_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_aux_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_aux_wide-1        downto 0);
    rename_archx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_archa_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_archb_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
end opa_decode;

architecture rtl of opa_decode is

  -- Instruction format: CoaB
  -- reg(b) = C(o,a,reg(a),reg(b))
  
  constant c_decoders : natural := f_opa_decoders(g_config);

  type t_code is (T_CONST, T_ADDER, T_LOGIC, T_MUL, T_JUMP, T_LOAD, T_STORE, T_NOOP);
  type t_code_array is array(natural range <>) of t_code;
  
  function f_typ(x : std_logic_vector(3 downto 0)) return t_code is
  begin
    case x is
      when "0000" => return T_CONST;
      when "0010" => return T_ADDER;
      when "0011" => return T_LOGIC;
      when "0100" => return T_MUL;
      when "0101" => return T_JUMP;
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
      when T_JUMP  => return '0';
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
      when T_JUMP  => return '1';
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
      when T_JUMP  => return '1';
      when T_LOAD  => return '1';
      when T_STORE => return '1';
      when T_NOOP  => return '0';
    end case;
  end f_getb;
  
  function f_fast(x : t_code) return std_logic is
  begin
    case x is
      when T_CONST => return '1';
      when T_ADDER => return '1';
      when T_LOGIC => return '1';
      when T_MUL   => return '0';
      when T_JUMP  => return '1';
      when T_LOAD  => return '0';
      when T_STORE => return '0';
      when T_NOOP  => return '1';
    end case;
  end f_fast;
  
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
      when T_JUMP  => null;
      when T_MUL   => 
        result(0)          := v(4);
      when T_LOAD  => result(0) := '0';
      when T_STORE => result(0) := '1';
      when T_NOOP  => null;
    end case;
    return result;
  end f_aux;
  
  signal s_typ : t_code_array(c_decoders-1 downto 0);
  
  function f(x : natural) return natural is
  begin
    return 16*(c_decoders-1-x);
  end f;

begin

  -- We want to execute the lowest address instruction first
  -- In bigendian, that means the high bits of fetch_dat_i
  -- Everywhere in the design, the lowest indexes instruction goes first
  -- Thus we need to flip the bit order here, using f(i)
  
  parse : for i in 0 to c_decoders-1 generate
  
    s_typ(i) <= f_typ(fetch_dat_i(f(i)+15 downto f(i)+12));
    
    rename_fast_o(i) <= f_fast(s_typ(i));
    rename_slow_o(i) <= not f_fast(s_typ(i));
    
    rename_setx_o(i) <= f_setx(s_typ(i));
    rename_geta_o(i) <= f_geta(s_typ(i));
    rename_getb_o(i) <= f_getb(s_typ(i));
    
    aux : for b in 0 to c_aux_wide-1 generate
      rename_aux_o(i,b) <= f_aux(s_typ(i), fetch_dat_i(f(i)+11 downto f(i)+4))(b);
    end generate;
  
    bits : for b in 0 to 3 generate
      rename_archx_o(i,b) <= fetch_dat_i(f(i)+ 0+b);
      rename_archa_o(i,b) <= fetch_dat_i(f(i)+ 4+b);
      rename_archb_o(i,b) <= fetch_dat_i(f(i)+ 0+b);
    end generate;
  end generate;
  
end rtl;
