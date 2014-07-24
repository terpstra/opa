library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_renamer is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    mispredict_i   : in  std_logic;
    
    -- Values the decoder needs to provide us
    dec_stb_i      : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    dec_typ_i      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1           downto 0);
    dec_regx_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0); -- -1 on no-op
    dec_rega_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);
    dec_regb_i     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, g_config.log_arch-1 downto 0);

    -- Values we provide to the issuer
    iss_stb_o      : in  std_logic_vector(f_opa_decoders(g_config)-1 downto 0);
    iss_typ_o      : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, c_types-1                   downto 0);
    iss_stat_o     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_stat_wide(g_config)-1 downto 0);
    iss_regx_o     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0); -- -1 on no-op
    iss_rega_o     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    iss_regb_o     : in  t_opa_matrix(f_opa_decoders(g_config)-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    -- What does the commiter have to say?
    commit_map_i   : in  t_opa_matrix(2**g_config.log_arch-1 downto 0, f_opa_back_wide(g_config)-1 downto 0);
    
    fifo_ready_i : in  std_logic; -- we are allowed to add instructions?
    fifo_peek_i  : in  t_opa_matrix(
    
end opa_renamer;

architecture rtl of opa_renamer is
begin
end rtl;
