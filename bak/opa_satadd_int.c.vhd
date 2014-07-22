library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_satadd_int is
  generic(
    g_state : natural;
    g_width : natural)
  port(
    state_i : in  t_opa_map(1 to g_state*g_width);
    state_o : out t_opa_map(1 to g_state));
end opa_satadd_int;

architecture rtl of opa_satadd_int is
begin

  gen14 : if g_state = 1 and g_width = 4 generate
    state_o <= "0" when s_input="0000" else "1";
  end generate;

  gen16 : if g_state = 1 and g_width = 6 generate
    state_o <= "0" when s_input="000000" else "1";
  end generate;

  gen22 : if g_state = 2 and g_width = 2 generate
    with s_input select
      state_o <=
        "00" when "0000",
        "01" when "0001",
        "10" when "0010",
        "11" when "0011",
        "01" when "0100",
        "10" when "0101",
        "11" when "0110",
        "11" when "0111",
        "10" when "1000",
        "11" when "1001",
        "11" when "1010",
        "11" when "1011",
        "11" when "1100",
        "11" when "1101",
        "11" when "1110",
        "11" when "1111",
        "--" when others;
  end generate;
  
  gen23 : if g_state = 2 and g_width = 3 generate
    with s_input select
      state_o <= 
        "00" when "000000",
        "01" when "000001",
        "10" when "000010",
        "11" when "000011",
        "01" when "000100",
        "10" when "000101",
        "11" when "000110",
        "11" when "000111",
        "10" when "001000",
        "11" when "001001",
        "11" when "001010",
        "11" when "001011",
        "11" when "001100",
        "11" when "001101",
        "11" when "001110",
        "11" when "001111",
        "01" when "010000",
        "10" when "010001",
        "11" when "010010",
        "11" when "010011",
        "10" when "010100",
        "11" when "010101",
        "11" when "010110",
        "11" when "010111",
        "11" when "011000",
        "11" when "011001",
        "11" when "011010",
        "11" when "011011",
        "11" when "011100",
        "11" when "011101",
        "11" when "011110",
        "11" when "011111",
        "10" when "100000",
        "11" when "100001",
        "11" when "100010",
        "11" when "100011",
        "11" when "100100",
        "11" when "100101",
        "11" when "100110",
        "11" when "100111",
        "11" when "101000",
        "11" when "101001",
        "11" when "101010",
        "11" when "101011",
        "11" when "101100",
        "11" when "101101",
        "11" when "101110",
        "11" when "101111",
        "11" when "110000",
        "11" when "110001",
        "11" when "110010",
        "11" when "110011",
        "11" when "110100",
        "11" when "110101",
        "11" when "110110",
        "11" when "110111",
        "11" when "111000",
        "11" when "111001",
        "11" when "111010",
        "11" when "111011",
        "11" when "111100",
        "11" when "111101",
        "11" when "111110",
        "11" when "111111",
        "--" when others;
  end generate;
  
  gen32 : if g_state = 3 and g_width = 2 generate
    with s_input select
      state_o <=
        "000" when "000000",
        "001" when "000001",
        "010" when "000010",
        "011" when "000011",
        "100" when "000100",
        "101" when "000101",
        "110" when "000110",
        "111" when "000111",
        "001" when "001000",
        "010" when "001001",
        "011" when "001010",
        "100" when "001011",
        "101" when "001100",
        "110" when "001101",
        "111" when "001110",
        "111" when "001111",
        "010" when "010000",
        "011" when "010001",
        "100" when "010010",
        "101" when "010011",
        "110" when "010100",
        "111" when "010101",
        "111" when "010110",
        "111" when "010111",
        "011" when "011000",
        "100" when "011001",
        "101" when "011010",
        "110" when "011011",
        "111" when "011100",
        "111" when "011101",
        "111" when "011110",
        "111" when "011111",
        "100" when "100000",
        "101" when "100001",
        "110" when "100010",
        "111" when "100011",
        "111" when "100100",
        "111" when "100101",
        "111" when "100110",
        "111" when "100111",
        "101" when "101000",
        "110" when "101001",
        "111" when "101010",
        "111" when "101011",
        "111" when "101100",
        "111" when "101101",
        "111" when "101110",
        "111" when "101111",
        "110" when "110000",
        "111" when "110001",
        "111" when "110010",
        "111" when "110011",
        "111" when "110100",
        "111" when "110101",
        "111" when "110110",
        "111" when "110111",
        "111" when "111000",
        "111" when "111001",
        "111" when "111010",
        "111" when "111011",
        "111" when "111100",
        "111" when "111101",
        "111" when "111110",
        "111" when "111111",
        "---" when others;
  end generate;
  
end rtl;
