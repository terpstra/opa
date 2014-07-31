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
    data_i         : in  std_logic_vector(f_opa_decoders(g_config)*16-1 downto 0);
    
    -- Parsed
    rename_stb_o   : out std_logic;
    rename_stall_i : in  std_logic;
    rename_setx_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_geta_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_getb_o  : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_typ_o   : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1           downto 0);
    rename_regx_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_rega_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    rename_regb_o  : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
end opa_decoder;

architecture rtl of opa_decoder is

  type t_code is (T_IEU, T_MUL, T_LOAD, T_STORE, T_SLEEP);
  type t_code_array is array(natural range <>) of t_code;
  
  function f_typ(x : std_logic_vector(3 downto 0)) return t_code is
  begin
    case x is
      when "0001" => return T_IEU;
      when "0010" => return T_MUL;
      when "0100" => return T_LOAD;
      when "1000" => return T_STORE;
      when others => return T_SLEEP;
    end case;
  end f_typ;
  
  function f_setx(x : t_code) return std_logic is
  begin
    case x is
      when T_IEU   => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '1';
      when T_STORE => return '0';
      when T_SLEEP => return '0';
    end case;
  end f_setx;
  
  function f_geta(x : t_code) return std_logic is
  begin
    case x is
      when T_IEU   => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '0';
      when T_STORE => return '1';
      when T_SLEEP => return '0';
    end case;
  end f_geta;
  
  function f_getb(x : t_code) return std_logic is
  begin
    case x is
      when T_IEU   => return '1';
      when T_MUL   => return '1';
      when T_LOAD  => return '1';
      when T_STORE => return '1';
      when T_SLEEP => return '0';
    end case;
  end f_getb;
  
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
      rename_typ_o(i,b) <= data_i(16*i+12+b);
    end generate;
  
    bits : for b in 0 to 3 generate
      rename_regx_o(i,b) <= data_i(16*i+8+b);
      rename_rega_o(i,b) <= data_i(16*i+4+b);
      rename_regb_o(i,b) <= data_i(16*i+0+b);
    end generate;
  end generate;
  
end rtl;
