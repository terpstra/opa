library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

-- Used to implement FP and integer adders
-- Pipeline depth is always 3                       
entity opa_prim_mul is
  generic(
    g_wide   : natural;
    g_regmul : boolean;
    g_target : t_opa_target);
  port(
    clk_i    : in  std_logic;
    a_i      : in  std_logic_vector(  g_wide-1 downto 0);
    b_i      : in  std_logic_vector(  g_wide-1 downto 0);
    x_o      : out std_logic_vector(2*g_wide-1 downto 0));
end opa_prim_mul;

architecture rtl of opa_prim_mul is

  constant c_lut_width  : natural := g_target.lut_width;
  constant c_add_width  : natural := g_target.add_width;
  constant c_post_adder : boolean := g_target.post_adder;
  
  -------------------------------------------------------------------------------------------
  -- Wallace adder tree section                                                           --
  -------------------------------------------------------------------------------------------

  -- Helpful to simplify wallace recursion
  function f_submatrix(rows : natural; x : t_opa_matrix) return t_opa_matrix is
    variable result : t_opa_matrix(x'low(1)+rows-1 downto x'low(1), x'range(2));
  begin
    for i in result'range(1) loop
      for j in result'range(2) loop
        result(i,j) := x(i,j);
      end loop;
    end loop;
    return result;
  end f_submatrix;
  
  -- Reasonable Wallace-tree reduction sizes
  type t_options is array(natural range <>) of natural;
  constant c_wallace_options  : t_options(4 downto 0) := (1, 3, 5, 6, 7);
  constant c_wallace_bits_out : natural               := f_opa_log2(c_wallace_options(0)+1);
  
  subtype t_wallace_bits_out is std_logic_vector(c_wallace_bits_out-1 downto 0);
  type t_wallace_lut is array(natural range <>) of t_wallace_bits_out;
  function f_wallace_table(bits : natural) return t_wallace_lut is
    variable row_in  : unsigned(bits-1 downto 0);
    variable row_out : unsigned(t_wallace_bits_out'range);
    variable result  : t_wallace_lut(2**bits-1 downto 0);
    variable c : natural := 0;
  begin
    for i in result'range loop
      row_in := to_unsigned(i, bits);
      c := 0; -- count bits
      for i in row_in'range loop
        if row_in(i) = '1' then c := c + 1; end if;
      end loop;
      
      row_out := to_unsigned(c, c_wallace_bits_out);
      for j in row_out'range loop
        result(i)(j) := row_out(j);
      end loop;
    end loop;
    return result;
  end f_wallace_table;
  
  constant c_wallace_lut1 : t_wallace_lut(2**1-1 downto 0) := f_wallace_table(1);
  constant c_wallace_lut3 : t_wallace_lut(2**3-1 downto 0) := f_wallace_table(3);
  constant c_wallace_lut5 : t_wallace_lut(2**5-1 downto 0) := f_wallace_table(5);
  constant c_wallace_lut6 : t_wallace_lut(2**6-1 downto 0) := f_wallace_table(6);
  constant c_wallace_lut7 : t_wallace_lut(2**7-1 downto 0) := f_wallace_table(7);
  
  function f_wallace_lut(bits : natural; x : std_logic_vector) return std_logic_vector is
    constant c_error : t_wallace_bits_out := (others => '1');
  begin
    if bits = 1 then return c_wallace_lut1(to_integer(unsigned(x(0 downto 0)))); end if;
    if bits = 3 then return c_wallace_lut3(to_integer(unsigned(x(2 downto 0)))); end if;
    if bits = 5 then return c_wallace_lut5(to_integer(unsigned(x(4 downto 0)))); end if;
    if bits = 6 then return c_wallace_lut6(to_integer(unsigned(x(5 downto 0)))); end if;
    if bits = 7 then return c_wallace_lut7(to_integer(unsigned(x(6 downto 0)))); end if;
    assert (false) report "Invalid Wallace reduction" severity failure;
    return c_error;
  end f_wallace_lut;
  
  function f_wallace(x : t_opa_matrix) return t_opa_matrix is
    constant rows_in  : natural := x'length(1); -- How many rows to combine?
    variable rows_out : natural := 0;
    variable row      : natural := 0;
    variable step_in  : natural;
    variable step_out : natural;
    variable result   : t_opa_matrix(x'range(1), x'range(2)) := (others => (others => '0'));
    variable chunk    : std_logic_vector(c_wallace_options(0)-1 downto 0);
  begin
    if x'length(1) <= c_add_width then
      return x;
    end if;
    
    while row < rows_in loop
      -- Pick reduction step size
      step_in := 99; -- should never be read
      for i in c_wallace_options'range loop
        if c_wallace_options(i) <= c_lut_width and  -- supported by hardware?
           c_wallace_options(i) <= rows_in-row then -- not too big?
          step_in := c_wallace_options(i);
        end if;
      end loop;
      
      -- This results in a reduction to
      step_out := f_opa_log2(step_in+1);
      
      -- Map the wallace tree
      for i in x'range(2) loop
        chunk := (others => '0');
        for j in 0 to step_in-1 loop
          chunk(j) := x(row+j, i);
        end loop;
        chunk(t_wallace_bits_out'range) := f_wallace_lut(step_in, chunk);
        for j in 0 to step_out-1 loop
          if i+j <= result'high(2) then -- we know multiplication will never carry
            result(rows_out+j, i+j) := chunk(j);
          end if;
        end loop;
      end loop;
      
      row      := row      + step_in;
      rows_out := rows_out + step_out;
    end loop;
    
    return f_wallace(f_submatrix(rows_out, result));
  end f_wallace;
  
  -------------------------------------------------------------------------------------------
  -- DSP hardware multiplier section                                                       --
  -------------------------------------------------------------------------------------------
  
  constant c_parts    : natural := (g_wide+g_target.mul_width-1)/g_target.mul_width;
  constant c_mul_wide : natural := (g_wide+c_parts-1)/c_parts;
  constant c_wide     : natural := c_parts*c_mul_wide;
  constant c_wallace  : natural := 2*c_parts-1; -- the -1 is due to the f_clip optimization
  
  function f_clip(x : natural) return natural is
  begin
    if x = c_wallace then
      return (c_parts mod 2);
    else
      return x;
    end if;
  end f_clip;
  
  -- Register stages
  type t_mul_out is array(c_parts*c_parts-1 downto 0) of unsigned(2*c_mul_wide-1 downto 0);
  type t_sum_in  is array(c_add_width-1     downto 0) of unsigned(2*c_wide-1     downto 0);
  signal r_a     : unsigned(c_wide-1 downto 0);
  signal r_b     : unsigned(c_wide-1 downto 0);
  signal s_mul   : t_mul_out;
  signal r_mul   : t_mul_out; -- optional register (g_regmul)
  signal s_wal_i : t_opa_matrix(c_wallace  -1 downto 0, 2*c_wide-1 downto 0) := (others => (others => '0'));
  signal s_wal_o : t_opa_matrix(c_add_width-1 downto 0, 2*c_wide-1 downto 0);
  signal r_wal   : t_sum_in; -- result of wallace tree
  signal s_sum3  : unsigned(2*c_wide-1 downto 0);
  signal r_sumx  : unsigned(2*c_wide-1 downto 0);
  
begin

  check_add_width : 
    assert (c_add_width > 1)
    report "adder_width must be greater than 1"
    severity failure;
  
  -- Register and pad the inputs
  edge1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_a <= (others => '0');
      r_b <= (others => '0');
      r_a(a_i'range) <= unsigned(a_i);
      r_b(b_i'range) <= unsigned(b_i);
    end if;
  end process;
  
  mul_rows : for i in 0 to c_parts-1 generate
    mul_cols : for j in 0 to c_parts-1 generate
      s_mul(i*c_parts + j) <= 
        r_a(c_mul_wide*(i+1)-1 downto c_mul_wide*i) *
        r_b(c_mul_wide*(j+1)-1 downto c_mul_wide*j);
    end generate;
  end generate;
  
  -- Register the results of native DSP blocks
  -- This is bypassed when g_regmul is false
  edge2 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_mul <= s_mul;
    end if;
  end process;
  
  -- Remap the DSP outputs into the wallace input
  rows : for i in 0 to c_parts-1 generate
    cols : for j in 0 to c_parts-1 generate
      bits : for b in 0 to 2*c_mul_wide-1 generate
        -- unset bits take '0' from default assignment
        s_wal_i(f_clip(2*i + (j mod 2)), (i+j)*c_mul_wide + b) <= 
          r_mul(i*c_parts + j)(b) when g_regmul else
          s_mul(i*c_parts + j)(b);
      end generate;
    end generate;
  end generate;
  s_wal_o <= f_wallace(s_wal_i);
  
  -- Register the result of a wallace tree
  edge3 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      for i in 0 to c_add_width-1 loop
        r_wal(i) <= unsigned(f_opa_select_row(s_wal_o, i));
      end loop;
    end if;
  end process;
  
  -- Hold quartus' hand. Appalling.
  ternary : if c_add_width = 3 generate
    prim : opa_prim_ternary
      generic map(
        g_wide => 2*c_wide)
      port map(
        a_i => r_wal(0),
        b_i => r_wal(1),
        c_i => r_wal(2),
        x_o => s_sum3);
  end generate;
  
  -- Finally, sum the output
  -- This is double the width of a normal adder so back-to-back register it
  sum : process(clk_i) is
    variable acc : unsigned(r_sumx'range);
  begin
    if rising_edge(clk_i) then
      if c_add_width = 3 then
        r_sumx <= s_sum3;
      else
        acc := r_wal(0);
        for i in 1 to c_add_width-1 loop
          acc := acc + r_wal(i);
        end loop;
        r_sumx <= acc;
      end if;
    end if;
  end process;
  
  x_o <= std_logic_vector(r_sumx(x_o'range));

  -- !!! handle c_post_adder for older generations
  
end rtl;
