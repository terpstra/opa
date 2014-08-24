library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_prefixsum is
  generic(
    g_target  : t_opa_target;
    g_width   : natural;
    g_count   : natural);
  port(
    bits_i    : in  std_logic_vector(g_width-1 downto 0);
    count_o   : out t_opa_matrix(g_width-1 downto 0, g_count-1 downto 0);
    total_o   : out std_logic_vector(g_width-1 downto 0));
end opa_prefixsum;

architecture rtl of opa_prefixsum is

  constant c_width     : natural := g_width;
  constant c_lut_wide  : natural := g_target.lut_width;
  constant c_num_lut   : natural := 2**c_lut_wide;
  constant c_max_wide  : natural := 3; -- If you increase this, duplicate code below
  constant c_max_units : natural := 2**c_max_wide-1;

  -- Thank VHDL's restriction on flexible array sub-types for this duplication:
  type t_lut_romb is array(c_num_lut-1 downto 0) of std_logic_vector(c_max_wide-1 downto 0);
  type t_lut_romu is array(c_num_lut-1 downto 0) of std_logic_vector(c_max_units  downto 0);
  
  function f_matrix_to_romb(x : t_opa_matrix) return t_lut_romb is
    variable result : t_lut_romb := (others => (others => '0'));
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i)(j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_matrix_to_romb;
  
  function f_matrix_to_romu(x : t_opa_matrix) return t_lut_romu is
    variable result : t_lut_romu;
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i)(j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_matrix_to_romu;
  
  -- Directly decode the final result to 1-hot
  function f_decode_table(num_unit : natural; table : t_lut_romb) return t_opa_matrix is
    variable result : t_opa_matrix(c_num_lut-1 downto 0, c_max_units downto 0) := (others => (others => '0'));
    variable row    : unsigned(c_max_wide-1 downto 0);
  begin
    for i in result'range(1) loop
      row := unsigned(table(i));
      for b in 0 to num_unit-1 loop
        result(i, b) := f_opa_bit(row = to_unsigned(b, row'length));
      end loop;
      result(i, num_unit) := f_opa_bit(row < num_unit);
    end loop;
    return result;
  end f_decode_table;
  
  ---------------------------------------------------------------------------------------
  
  -- Count the # of ones, saturated up to the specified bits
  function f_compress_table(bits : natural) return t_opa_matrix is
    variable result : t_opa_matrix(c_num_lut-1 downto 0, c_max_wide-1 downto 0) := (others => (others => '0'));
    variable input  : unsigned(c_lut_wide-1 downto 0);
    variable count  : unsigned(bits-1 downto 0);
    constant ones   : unsigned(bits-1 downto 0) := (others => '1');
  begin
    for i in result'range(1) loop
      input := to_unsigned(i, input'length);
      count := (others => '0');
      for j in input'range loop
        if count /= ones and input(j) = '1' then
          count := count + 1;
        end if;
      end loop;
      for b in 0 to bits-1 loop
        result(i,b) := count(b);
      end loop;
    end loop;
    return result;
  end f_compress_table;
  
  constant c_compress_rom3 : t_lut_romb := f_matrix_to_romb(f_compress_table(3));
  constant c_compress_rom2 : t_lut_romb := f_matrix_to_romb(f_compress_table(2));
  constant c_compress_rom1 : t_lut_romb := f_matrix_to_romb(f_compress_table(1));
  
  constant c_compress_decode_rom7 : t_lut_romu := f_matrix_to_romu(f_decode_table(7, c_compress_rom3));
  constant c_compress_decode_rom6 : t_lut_romu := f_matrix_to_romu(f_decode_table(6, c_compress_rom3));
  constant c_compress_decode_rom5 : t_lut_romu := f_matrix_to_romu(f_decode_table(5, c_compress_rom3));
  constant c_compress_decode_rom4 : t_lut_romu := f_matrix_to_romu(f_decode_table(4, c_compress_rom3));
  constant c_compress_decode_rom3 : t_lut_romu := f_matrix_to_romu(f_decode_table(3, c_compress_rom2));
  constant c_compress_decode_rom2 : t_lut_romu := f_matrix_to_romu(f_decode_table(2, c_compress_rom2));
  constant c_compress_decode_rom1 : t_lut_romu := f_matrix_to_romu(f_decode_table(1, c_compress_rom1));
  
  function f_compress(bits : natural; x : std_logic_vector) return std_logic_vector is
    constant bug : std_logic_vector(c_max_wide-1 downto 0) := (others => '0');
  begin
    assert (bits >= 1 and bits <= c_max_wide) report "unsupported bit width" severity failure;
    if bits = 3 then return c_compress_rom3(to_integer(unsigned(x))); end if;
    if bits = 2 then return c_compress_rom2(to_integer(unsigned(x))); end if;
    if bits = 1 then return c_compress_rom1(to_integer(unsigned(x))); end if;
    return bug;
  end f_compress;
  
  function f_compress_decode(num_unit : natural; x : std_logic_vector) return std_logic_vector is
    constant bug : std_logic_vector(c_max_units downto 0) := (others => '0');
  begin
    assert (num_unit >= 1 and num_unit <= c_max_units) report "unsupported unit count" severity failure;
    if num_unit = 7 then return c_compress_decode_rom7(to_integer(unsigned(x))); end if;
    if num_unit = 6 then return c_compress_decode_rom6(to_integer(unsigned(x))); end if;
    if num_unit = 5 then return c_compress_decode_rom5(to_integer(unsigned(x))); end if;
    if num_unit = 4 then return c_compress_decode_rom4(to_integer(unsigned(x))); end if;
    if num_unit = 3 then return c_compress_decode_rom3(to_integer(unsigned(x))); end if;
    if num_unit = 2 then return c_compress_decode_rom2(to_integer(unsigned(x))); end if;
    if num_unit = 1 then return c_compress_decode_rom1(to_integer(unsigned(x))); end if;
    return bug;
  end f_compress_decode;
  
  ---------------------------------------------------------------------------------------
  
  -- Combine subproblem sums
  function f_combine_table(bits : natural) return t_opa_matrix is
    constant c_parts : natural := c_lut_wide/bits;
    variable result  : t_opa_matrix(c_num_lut-1 downto 0, c_max_wide-1 downto 0) := (others => (others => '0'));
    variable shf     : integer;
    variable sum     : integer;
    variable bin     : unsigned(bits-1 downto 0);
  begin
    for i in result'range(1) loop
      -- Determine the sum of the fields
      sum := 0;
      shf := i;
      for j in 0 to c_parts-1 loop
        sum := sum + (shf mod 2**bits);
        shf := shf / 2**bits;
      end loop;
      
      -- Saturate the arithmetic and convert to unsigned
      if sum >= 2**bits then sum := 2**bits-1; end if;
      bin := to_unsigned(sum, bits);
      
      -- Split result into LUT tables
      for b in 0 to bits-1 loop
        result(i,b) := bin(b);
      end loop;
    end loop;
    return result;
  end f_combine_table;
  
  constant c_combine_rom3 : t_lut_romb := f_matrix_to_romb(f_combine_table(3));
  constant c_combine_rom2 : t_lut_romb := f_matrix_to_romb(f_combine_table(2));
  constant c_combine_rom1 : t_lut_romb := f_matrix_to_romb(f_combine_table(1));
  
  constant c_combine_decode_rom7 : t_lut_romu := f_matrix_to_romu(f_decode_table(7, c_combine_rom3));
  constant c_combine_decode_rom6 : t_lut_romu := f_matrix_to_romu(f_decode_table(6, c_combine_rom3));
  constant c_combine_decode_rom5 : t_lut_romu := f_matrix_to_romu(f_decode_table(5, c_combine_rom3));
  constant c_combine_decode_rom4 : t_lut_romu := f_matrix_to_romu(f_decode_table(4, c_combine_rom3));
  constant c_combine_decode_rom3 : t_lut_romu := f_matrix_to_romu(f_decode_table(3, c_combine_rom2));
  constant c_combine_decode_rom2 : t_lut_romu := f_matrix_to_romu(f_decode_table(2, c_combine_rom2));
  constant c_combine_decode_rom1 : t_lut_romu := f_matrix_to_romu(f_decode_table(1, c_combine_rom1));
  
  function f_combine(bits : natural; x : std_logic_vector) return std_logic_vector is
    constant bug : std_logic_vector(c_max_wide-1 downto 0) := (others => '0');
  begin
    assert (bits >= 1 and bits <= c_max_wide) report "unsupported bit width" severity failure;
    if bits = 3 then return c_combine_rom3(to_integer(unsigned(x))); end if;
    if bits = 2 then return c_combine_rom2(to_integer(unsigned(x))); end if;
    if bits = 1 then return c_combine_rom1(to_integer(unsigned(x))); end if;
    return bug;
  end f_combine;
  
  function f_combine_decode(num_unit : natural; x : std_logic_vector) return std_logic_vector is
    constant bug : std_logic_vector(c_max_units downto 0) := (others => '0');
  begin
    assert (num_unit >= 1 and num_unit <= c_max_units) report "unsupported unit count" severity failure;
    if num_unit = 7 then return c_combine_decode_rom7(to_integer(unsigned(x))); end if;
    if num_unit = 6 then return c_combine_decode_rom6(to_integer(unsigned(x))); end if;
    if num_unit = 5 then return c_combine_decode_rom5(to_integer(unsigned(x))); end if;
    if num_unit = 4 then return c_combine_decode_rom4(to_integer(unsigned(x))); end if;
    if num_unit = 3 then return c_combine_decode_rom3(to_integer(unsigned(x))); end if;
    if num_unit = 2 then return c_combine_decode_rom2(to_integer(unsigned(x))); end if;
    if num_unit = 1 then return c_combine_decode_rom1(to_integer(unsigned(x))); end if;
    return bug;
  end f_combine_decode;
  
  ---------------------------------------------------------------------------------------
  
  function f_satadd_step(num_unit : natural; step : natural; x : t_opa_matrix) return t_opa_matrix is
    constant c_bits  : natural := f_opa_log2(num_unit+1);
    constant c_parts : natural := c_lut_wide/c_bits;
    variable chunk   : std_logic_vector(c_lut_wide-1 downto 0);
    variable row     : std_logic_vector(c_max_wide-1 downto 0);
    variable unit    : std_logic_vector(c_max_units downto 0);
    variable recurse : t_opa_matrix(x'range(1), c_max_wide-1 downto 0) := (others => (others => '0'));
    variable result  : t_opa_matrix(x'range(1), c_max_units  downto 0) := (others => (others => '0'));
  begin
    assert (step < x'length(1)) report "incorrect invocation" severity failure;
    for i in x'range(1) loop
      chunk := (others => '0');
      for j in 0 to c_parts-1 loop
        if i - j*step >= x'low(1) then
          for b in 0 to c_bits-1 loop
            chunk(j*c_bits+b) := x(i-j*step,b);
          end loop;
        end if;
      end loop;
      row  := f_combine(c_bits, chunk);
      unit := f_combine_decode(num_unit, chunk);
      for b in row'range loop
        recurse(i, b) := row(b);
      end loop;
      for b in unit'range loop
        result(i, b) := unit(b);
      end loop;
    end loop;
    if c_parts*step >= x'length(1) then
      return result;
    else
      return f_satadd_step(num_unit, c_parts*step, recurse);
    end if;
  end f_satadd_step;
  
  function f_satadd(num_unit : natural; x : std_logic_vector) return t_opa_matrix is
    constant c_bits  : natural := f_opa_log2(num_unit+1);
    variable chunk   : std_logic_vector(c_lut_wide-1 downto 0);
    variable row     : std_logic_vector(c_max_wide-1 downto 0);
    variable unit    : std_logic_vector(c_max_units downto 0);
    variable recurse : t_opa_matrix(x'range(1), c_max_wide-1 downto 0) := (others => (others => '0'));
    variable result  : t_opa_matrix(x'range(1), c_max_units  downto 0) := (others => (others => '0'));
  begin
    for i in x'range(1) loop
      chunk := (others => '0');
      for j in 0 to c_lut_wide-1 loop
        if i-j >= x'low then
          chunk(j) := x(i-j);
        end if;
      end loop;
      row  := f_compress(c_bits, chunk);
      unit := f_compress_decode(num_unit, chunk);
      for b in row'range loop
        recurse(i, b) := row(b);
      end loop;
      for b in unit'range loop
        result(i, b) := unit(b);
      end loop;
    end loop;
    if c_lut_wide >= x'length(1) then
      return result;
    else
      return f_satadd_step(num_unit, c_lut_wide, recurse);
    end if;
  end f_satadd;
  
  function f_shift(x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2));
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        if i = x'low(1) then
          result(i,j) := f_opa_bit(j = 0);
        else
          result(i,j) := x(i-1,j);
        end if;
      end loop;
    end loop;
    return result;
  end f_shift;
  
  ---------------------------------------------------------------------------------------
  
  signal s_bits : std_logic_vector(bits_i'range);
  signal s_sum  : t_opa_matrix(bits_i'range, c_max_units downto 0);
  
begin

  check_width :
    assert (g_count <= c_max_units)
    report "More units of a single type than supported"
    severity failure;
  
  -- Stop synthesis tools from breaking the circuit I built
  -- The issue critical path was carefully hand-crafted
  pending : for i in bits_i'range generate
    lcell : opa_lcell
      port map(
        a_i => bits_i(i),
        b_o => s_bits(i));
  end generate;
  
  s_sum <= f_shift(f_satadd(g_count, s_bits));
  
  bits : for b in bits_i'range generate
    total_o(b) <= s_sum(b, g_count);
    count : for i in count_o'range(2) generate
      count_o(b,i) <= s_sum(b,i);
    end generate;
  end generate;
  
end rtl;
