library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_fifo is
  generic(
    g_config : t_opa_config);
  port(
    clk_i         : in  std_logic;
    rst_n_i       : in  std_logic;
    mispredict_i  : in  std_logic;
    
    commit_step_i : in  std_logic;
    commit_valid_o: out std_logic;
    commit_bakx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    commit_setx_o : out std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    commit_regx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    
    commit_we_i   : in  std_logic;
    commit_bakx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    rename_step_i : in  std_logic;
    rename_bakx_o : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    rename_setx_i : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    rename_regx_i : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
end opa_fifo;

architecture rtl of opa_fifo is

  constant c_back_num   : natural := f_opa_back_num(g_config);
  constant c_back_wide  : natural := f_opa_back_wide(g_config);
  constant c_decoders   : natural := f_opa_decoders(g_config);
  constant c_size       : natural := f_opa_fifo_deep(g_config);
  constant c_width_bak  : natural := c_decoders*c_back_wide;
  constant c_width_reg  : natural := c_decoders*(g_config.log_arch + 1);
  constant c_index_bits : natural := f_opa_log2(c_size);
  
  constant c_zeros : unsigned(c_index_bits-1 downto 0) := (others => '0');
  
  type t_rom is array(c_size-1 downto 0) of std_logic_vector(c_width_bak-1 downto 0);
  function f_rom return t_rom is
    variable result : t_rom;
    variable val : unsigned(c_width_bak-1 downto 0);
    variable idx : integer;
  begin
    for i in 0 to c_size-1 loop
      val := (others => '0');
      for d in 0 to c_decoders-1 loop
        idx := (i*c_decoders+d) + (2**g_config.log_arch+1);
        val := (val rol c_back_wide) + to_unsigned(idx, val'length);
      end loop;
      result(i) := std_logic_vector(val);
    end loop;
    return result;
  end f_rom;
  constant c_rom : t_rom := f_rom;
  
  signal s_bak_rename_o : std_logic_vector(c_width_bak-1 downto 0);
  signal s_bak_commit_o : std_logic_vector(c_width_bak-1 downto 0);
  signal s_bak_ext      : std_logic_vector(c_width_bak-1 downto 0);
  signal s_bak_rom      : std_logic_vector(c_width_bak-1 downto 0);
  signal s_bak_i        : std_logic_vector(c_width_bak-1 downto 0);
  signal s_reg_i        : std_logic_vector(c_width_reg-1 downto 0);
  signal s_reg_o        : std_logic_vector(c_width_reg-1 downto 0);
  signal s_bak_wen      : std_logic;
  
  signal r_commit       : unsigned(c_index_bits-1 downto 0) := (others => '0');
  signal r_commit1      : unsigned(c_index_bits-1 downto 0);
  signal s_commit1      : unsigned(c_index_bits-1 downto 0);
  signal s_commitx      : unsigned(c_index_bits-1 downto 0);
  signal s_commit       : unsigned(c_index_bits-1 downto 0);
  signal r_rename       : unsigned(c_index_bits-1 downto 0) := (others => '0');
  signal r_rename1      : unsigned(c_index_bits-1 downto 0);
  signal s_rename1      : unsigned(c_index_bits-1 downto 0);
  signal s_renamex      : unsigned(c_index_bits-1 downto 0);
  signal s_rename       : unsigned(c_index_bits-1 downto 0);
  
begin

  -- One read-port for reg
  reg : opa_dpram
    generic map(
      g_width => c_width_reg,
      g_size  => c_size)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      r_en_i   => '1',
      r_addr_i => std_logic_vector(s_commit),
      r_data_o => s_reg_o,
      w_en_i   => rename_step_i,
      w_addr_i => std_logic_vector(s_rename),
      w_data_i => s_reg_i);

  -- Two read-ports for bak
  s_bak_wen <= commit_we_i or not rst_n_i;
    
  bak_commit : opa_dpram
    generic map(
      g_width => c_width_bak,
      g_size  => c_size)
    port map(
      clk_i    => clk_i,
      rst_n_i  => '1',
      r_en_i   => '1',
      r_addr_i => std_logic_vector(s_commit),
      r_data_o => s_bak_commit_o,
      w_en_i   => s_bak_wen,
      w_addr_i => std_logic_vector(r_commit1),
      w_data_i => s_bak_i);
      
  bak_rename : opa_dpram
    generic map(
      g_width => c_width_bak,
      g_size  => c_size)
    port map(
      clk_i    => clk_i,
      rst_n_i  => '1',
      r_en_i   => '1',
      r_addr_i => std_logic_vector(s_rename),
      r_data_o => s_bak_rename_o,
      w_en_i   => s_bak_wen,
      w_addr_i => std_logic_vector(r_commit1),
      w_data_i => s_bak_i);
  
  bakx_rows : for i in commit_bakx_i'range(1) generate
    bakx_cols : for j in commit_bakx_i'range(2) generate
      rename_bakx_o(i,j) <= s_bak_rename_o(i*commit_bakx_i'length(2) + j);
      commit_bakx_o(i,j) <= s_bak_commit_o(i*commit_bakx_i'length(2) + j);
      s_bak_ext(i*commit_bakx_i'length(2) + j) <= commit_bakx_i(i,j);
    end generate;
  end generate;
  
  s_bak_rom <= c_rom(to_integer(r_commit));
  s_bak_i <= s_bak_ext when rst_n_i='1' else s_bak_rom;
  
  regx_rows : for i in rename_regx_i'range(1) generate
    commit_setx_o(i) <= s_reg_i((i+1)*(rename_regx_i'length(2)+1)-1);
    s_reg_i((i+1)*(rename_regx_i'length(2)+1)-1) <= rename_setx_i(i);
    regx_cols : for j in rename_regx_i'range(2) generate
      commit_regx_o(i,j) <= s_reg_o(i*(rename_regx_i'length(2)+1) + j);
      s_reg_i(i*(rename_regx_i'length(2)+1) + j) <= rename_regx_i(i,j);
    end generate;
  end generate;
  
  s_commit1 <= to_unsigned(0, r_commit'length) when r_commit=c_size-1 else (r_commit+1);
  s_rename1 <= to_unsigned(0, r_rename'length) when r_rename=c_size-1 else (r_rename+1);
  s_commitx <= s_commit1 when (not rst_n_i or commit_step_i)='1' else r_commit;
  s_renamex <= s_rename1 when (not rst_n_i or rename_step_i)='1' else r_rename;
  s_rename <= c_zeros when mispredict_i='1' else s_renamex;
  s_commit <= c_zeros when mispredict_i='1' else s_commitx;
  
  edge1r : process(clk_i) is
  begin
    if rst_n_i = '0' then
      commit_valid_o <= '0';
    elsif rising_edge(clk_i) then
      -- reflects changes to commit index immediately
      -- reacts to changes from renamer after 3 cycles
      commit_valid_o <= f_opa_bit(s_commit /= r_rename1) and not mispredict_i;
    end if;
  end process;
  edge1m : process(clk_i, mispredict_i) is
  begin
    if mispredict_i = '1' then
      r_commit1 <= (others => '0');
      r_rename1 <= (others => '0');
    elsif rising_edge(clk_i) then
      r_commit1 <= r_commit;
      r_rename1 <= r_rename;
    end if;
  end process;
  edge1a : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_commit  <= s_commit;
      r_rename  <= s_rename;
    end if;
  end process;
    
end rtl;
