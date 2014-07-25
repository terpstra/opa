library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_commit is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- When thins go wrong, we force our map on the renamer
    mispredict_o   : out std_logic;
    rename_map_o   : out t_opa_matrix(2**g_config.log_arch-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- What instructions just completed? => decide if we commit
    -- Probably better to get r_back_ready and r_done_regx from opa_issue
    eu_done_regx_i : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- fifo_bakx_o has to get to the renamer fast (FIFO should bypass it)
    -- Due to the nature of the pipeline, the FIFO is always ready
    fifo_commit_o  : out std_logic;
    fifo_bakx_o    : out t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    fifo_bakx_i    : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- Due to the nature of the pipeline, this is always ready
    fifo_pop_o     : out std_logic;
    fifo_regx_i    : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0));
end opa_commit;

architecture rtl of opa_commit is

  constant c_executers : natural := f_opa_executers(g_config);
  constant c_c_back_wide : natural := f_opa_back_wide(g_config);
  
  signal r_done_regx : t_opa_matrix(c_executers-1 downto 0, c_back_wide-1 downto 0);
  
begin

  edge1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_done_regx <= eu_done_regx_i;
      r_fifo_bakx <= fifo_bakx_o; -- careful; may need to gate this
    end if;
  end process;
  
  -- Combine r_done_regx with r_fifo_bakx
  -- Compose done_ready with r_fifo_bakx
  -- Decide if complete
  fifo_commit_o <= '1';
  
  -- This can be determined completely independently of issue
  -- Just recombine the fifo_bakx and fifo_regx
  fifo_bakx_o  <= ...;

end rtl;
