library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_arbitrate is
  generic(
    g_config  : t_opa_config;
    g_target  : t_opa_target);
  port(
    clk_i     : in  std_logic;
    rst_n_i   : in  std_logic;
    pending_i : in  t_opa_matrix(f_opa_num_stat(g_config)-1 downto 0, c_types-1 downto 0);
    stb_o     : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    stat_o    : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0));
end opa_arbitrate;

architecture rtl of opa_arbitrate is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_lut_wide  : natural := g_target.lut_width;
  constant c_num_stat  : natural := f_opa_num_stat(g_config);
  constant c_num_lut   : natural := 2**c_lut_wide;

  -- Thank VHDL's restriction on flexible array sub-types for this duplication:
  type t_lut_rom3 is array(c_num_lut-1 downto 0) of std_logic_vector(2 downto 0);
  type t_lut_rom2 is array(c_num_lut-1 downto 0) of std_logic_vector(1 downto 0);
  type t_lut_rom1 is array(c_num_lut-1 downto 0) of std_logic_vector(0 downto 0);
  
  function f_matrix_to_rom3(x : t_opa_matrix) return t_lut_rom3 is
    variable result : t_lut_rom3;
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i)(j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_matrix_to_rom3;
  
  function f_matrix_to_rom2(x : t_opa_matrix) return t_lut_rom2 is
    variable result : t_lut_rom2;
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i)(j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_matrix_to_rom2;
  
  function f_matrix_to_rom1(x : t_opa_matrix) return t_lut_rom1 is
    variable result : t_lut_rom1;
  begin
    for i in x'range(1) loop
      for j in x'range(2) loop
        result(i)(j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_matrix_to_rom1;
  
  ---------------------------------------------------------------------------------------
  
  -- Count the # of ones, saturated up to the specified bits
  function f_compress_table(bits : natural) return t_opa_matrix is
    variable result : t_opa_matrix(c_num_lut-1 downto 0, bits-1 downto 0);
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
  
  constant c_compress_rom3 : t_lut_rom3 := f_matrix_to_rom3(f_compress_table(3));
  constant c_compress_rom2 : t_lut_rom2 := f_matrix_to_rom2(f_compress_table(2));
  constant c_compress_rom1 : t_lut_rom1 := f_matrix_to_rom1(f_compress_table(1));
  
  function f_compress(bits : natural; x : std_logic_vector) return std_logic_vector is
    variable widest : std_logic_vector(2 downto 0);
    variable result : std_logic_vector(bits-1 downto 0);
  begin
    assert (bits >= 1 and bits <= 3) report "unsupported bit width" severity failure;
    if bits = 3 then widest :=        c_compress_rom3(to_integer(unsigned(x))); end if;
    if bits = 2 then widest :=  "0" & c_compress_rom2(to_integer(unsigned(x))); end if;
    if bits = 1 then widest := "00" & c_compress_rom1(to_integer(unsigned(x))); end if;
    result := widest(result'range);
    return result;
  end f_compress;
  
  ---------------------------------------------------------------------------------------
  
  -- Combine subproblem sums
  function f_combine_table(bits : natural) return t_opa_matrix is
    constant c_parts : natural := c_lut_wide/bits;
    variable result  : t_opa_matrix(c_num_lut-1 downto 0, bits-1 downto 0);
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
  
  constant c_combine_rom3 : t_lut_rom3 := f_matrix_to_rom3(f_combine_table(3));
  constant c_combine_rom2 : t_lut_rom2 := f_matrix_to_rom2(f_combine_table(2));
  constant c_combine_rom1 : t_lut_rom1 := f_matrix_to_rom1(f_combine_table(1));
  
  function f_combine(bits : natural; x : std_logic_vector) return std_logic_vector is
    variable widest : std_logic_vector(2 downto 0);
    variable result : std_logic_vector(bits-1 downto 0);
  begin
    assert (bits >= 1 and bits <= 3) report "unsupported bit width" severity failure;
    if bits = 3 then widest :=        c_combine_rom3(to_integer(unsigned(x))); end if;
    if bits = 2 then widest :=  "0" & c_combine_rom2(to_integer(unsigned(x))); end if;
    if bits = 1 then widest := "00" & c_combine_rom1(to_integer(unsigned(x))); end if;
    result := widest(result'range);
    return result;
  end f_combine;
  
  ---------------------------------------------------------------------------------------
  
  function f_satadd_step(bits : natural; step : natural; x : t_opa_matrix) return t_opa_matrix is
    constant c_parts : natural := c_lut_wide/bits;
    variable chunk   : std_logic_vector(c_lut_wide-1 downto 0);
    variable row     : std_logic_vector(bits-1 downto 0);
    variable result  : t_opa_matrix(x'range(1), x'range(2));
  begin
    -- Base case
    if step >= x'length(1) then return x; end if;
    for i in x'range(1) loop
      chunk := (others => '0');
      for j in 0 to c_parts-1 loop
        if i >= j*step then
          for b in 0 to bits-1 loop
            chunk(j*bits+b) := x(i-j*step,b);
          end loop;
        end if;
      end loop;
      row := f_combine(bits, chunk);
      for b in x'range(2) loop
        result(i, b) := row(b);
      end loop;
    end loop;
    -- Recurively divide
    return f_satadd_step(bits, c_parts*step, result);
  end f_satadd_step;
  
  function f_satadd(bits : natural; x : std_logic_vector) return t_opa_matrix is
    variable chunk  : std_logic_vector(c_lut_wide-1 downto 0);
    variable row    : std_logic_vector(bits-1 downto 0);
    variable result : t_opa_matrix(x'range(1), bits-1 downto 0);
  begin
    for i in x'range(1) loop
      chunk := (others => '0');
      for j in 0 to c_lut_wide-1 loop
        if i >= j then
          chunk(j) := x(i-j);
        end if;
      end loop;
      row := f_compress(bits, chunk);
      for b in row'range loop
        result(i, b) := row(b);
      end loop;
    end loop;
    return f_satadd_step(bits, c_lut_wide, result);
  end f_satadd;
  
  function f_satadd_pad(bits : natural; x : std_logic_vector) return t_opa_matrix is
    variable proper : t_opa_matrix(x'range(1), bits-1 downto 0);
    variable result : t_opa_matrix(x'range(1), 2 downto 0) := (others => (others => '0'));
  begin
    proper := f_satadd(bits, x);
    for i in proper'range(1) loop
      for j in proper'range(2) loop
        result(i,j) := proper(i,j);
      end loop;
    end loop;
    return result;
  end f_satadd_pad;
  
  ---------------------------------------------------------------------------------------
  
  -- Leave only the u^th bit set
  function f_select(x : std_logic_vector; y : t_opa_matrix; u : natural) return std_logic_vector is
    constant unit : std_logic_vector(y'range(2)) := std_logic_vector(to_unsigned(u, y'length(2)));
    variable result : std_logic_vector(x'range);
  begin
    for i in result'range loop
      if i <= y'low(2) then
        result(i) := x(i) and f_opa_bit(u = 0);
      else
        result(i) := x(i) and f_opa_bit(f_opa_select_row(y, i-1) = unit);
      end if;
    end loop;
    return result;
  end f_select;
  
  -- as many columns as units
--  function f_arbitrate_table(index) return t_opa_matrix -- (stb,stat),(stb,stat),(stb,stat),...
--  constant c_arbitrate_rom
  
  ---------------------------------------------------------------------------------------
  
  type t_satadd   is array(c_types-1 downto 0) of t_opa_matrix(c_num_stat-1 downto 0, 2 downto 0);
  type t_schedule is array(c_executers-1 downto 0) of std_logic_vector(c_num_stat-1 downto 0);
  type t_stat     is array(c_executers-1 downto 0) of std_logic_vector(c_stat_wide-1 downto 0);
  
  signal s_satadd   : t_satadd;
  signal s_schedule : t_schedule;
  signal r_stat     : t_stat;
  
begin

  ---------------------------------------------------------------------------------------
  -- Non-ROM implementation
  combinational : if true generate -- 2**f_opa_num_issue(g_config) > g_target.max_rom generate
    typ : for t in 0 to c_types-1 generate
      exists : if f_opa_unit_count(g_config, t) > 0 generate
        s_satadd(t) <= 
          f_satadd_pad(f_opa_log2(f_opa_unit_count(g_config, t)+1), 
                  f_opa_select_col(pending_i, t));
      end generate;
    end generate;
    
    eus2 : for u in 0 to c_executers-1 generate
      s_schedule(u) <= f_select(
        f_opa_select_col(pending_i, f_opa_unit_type(g_config, u)), 
        s_satadd(f_opa_unit_type(g_config, u)), 
        f_opa_unit_index(g_config, u));
      
      bits : for b in 0 to c_stat_wide-1 generate
        stat_o(u,b) <= r_stat(u)(b);
      end generate;
    end generate;
    
    decode : process(clk_i) is
    begin
      if rising_edge(clk_i) then
        for u in 0 to c_executers-1 loop
          r_stat(u) <= f_opa_1hot_dec(s_schedule(u));
          stb_o(u)  <= f_opa_or(s_schedule(u));
        end loop;
      end if;
    end process;
  end generate;
  
  ---------------------------------------------------------------------------------------
  -- ROM implementation
--  generate types
--    s_rom(t) <= c_abitrate_rom(pending_i(t));
--    relabel stb+units from s_rom

-- !!! ROM version
-- !!! don't include num_wait

end rtl;
