library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_internal_pkg.all;

entity opa_depmap is
  generic(
    g_config : t_opa_config);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- also track ready for regs? there is otherwise a sync problem
    
    -- how to test?
    -- correctness: every op becomes ready eventually
    --              no arg is ready before it really is
    
    -- magic register -1 = always ready, never written
    -- magic register -2 = no-ops write to it, no one reads it
    
    -- Values the decoder needs to provide us (stage0)
    dec_stb_i      : in  t_opa_map(1 to 2**g_config.log_decode);
    dec_stax_i     : in  t_opa_map(1 to 2**g_config.log_decode*(g_config.log_stat-g_config.log_decode));
    dec_regx_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    dec_staa_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_stat);
    dec_rega_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    dec_stab_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_stat);
    dec_regb_i     : in  t_opa_map(1 to 2**g_config.log_decode*g_config.log_back);
    
    -- These became ready (stage2)
    dep_readya_o   : out t_opa_map(1 to 2**g_config.log_stat);
    dep_readyb_o   : out t_opa_map(1 to 2**g_config.log_stat);
    
    -- EU says these are done (stat will be registered inside; stage2)
    eu_done_stb_i  : in  t_opa_map(1 to g_config.num_units); -- may be async fed from readya_o
    eu_done_stax_i : in  t_opa_map(1 to g_config.num_units*g_config.log_stat);
    eu_done_regx_i : in  t_opa_map(1 to g_config.num_units*g_config.log_back));
end opa_depmap;

architecture rtl of opa_depmap is
begin

  -- Edge 0: register inputs, register read address
  stage1 : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      -- !!! measure impact (+1 mispredict cost, but faster clock?)
      r0_stb  <= dec_stb_i;
      r0_stax <= dec_stax_i;
      r0_regx <= dec_regx_i;
      r0_staa <= dec_staa_i;
      r0_rega <= dec_rega_i;
      r0_stab <= dec_stab_i;
      r0_regb <= dec_regb_i;
    end if;
  end process;
  
  Fx1a : for i in 0 to 2**g_config.log_decode-1 generate
   a : opa_dpram
    generic map(
      g_mode      => c_opa_newdata, -- => why r0 is needed
      g_addr_bits => g_config.log_stat,
      g_data_bits => 2**(g_config.log_stat-g_config.log_decode))
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      r_en_i  => r0_stb(i),   -- crosses edge 0
      r_adr_i => r0_rega(i),
      r_dat_o => s1_odat(i),
      w_en_i  => r1_stb(i),   -- precedes edge 2 (bypass)
      w_adr_i => r1_rega(i),
      w_dat_i => s1_ndat(i));
  end generate;
  
  -- Edge 1: register inputs, register read address
  stage1 : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      r1_stb  <= r0_stb;
      r1_stax <= r0_stax;
      r1_regx <= r0_regx;
      r1_staa <= r0_staa;
      r1_rega <= r0_rega;
      r1_stab <= r0_stab;
      r1_regb <= r0_regb;
    end if;
  end process;
  
  f : opa_dpram
    generic map(
      g_mode      => c_opa_olddata,
      g_addr_bits => g_config.log_stat,
      g_data_bits => 2**(g_config.log_stat-g_config.log_decode))
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      w_en_i  => r1_stb(i),        -- crosses edge 2
      w_adr_i => r1_rega(i),
      w_dat_i => s1_ndat(i),
      r_en_i  => eu_done_stb_i(j), -- s1
      r_adr_i => eu_done_stax_i(j),
      r_dat_o => s2_);
      
  
  s_ignorea <= r_cleara || F* r_statx=me;
  s_write_to_mem <= s_old&!s_ignore || r_statx=me
  
  s_readya <= vector_OR(r_clear & mapval) || r_readya;
  dep_readya_o <= s_readya;
  
  -- Edge 2: register write address and r_clear
  --   bypass assures r_clear and concurrent read agree
  stage2 : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      r_cleara <= s_ignorea && F* rega!=me;
      
      
      r_catch_stax <= eu_done_stax_i;
      r_catch_regx <= eu_done_regx_i;
    end if;
  end process;
  
  stage3 : process(clk_i, rst_n_i) is
  begin
    if rising_edge(clk_i) then
      r_readya <= s_readya || s_complete(r_rega);
      r_complete <= r_complete && !regx=me || r_catch_regx
    end if;
  end process;
  
  -- Concern: no gaps; r_complete and map read cannot desync
  --   done_statx_i registered at stage3 will see dependancy
  --   therefore: r_ready must include anything < stage2
  --   
  
  -- Concern: same-cycle interdependancy
  --   Correctly written to map: only new dependants and clear not set.
  --   Cannot miss instant-ready op dependencies:
  --     no-bypassed write for EU-input map happens at stage2
  --     r_complete only arrives into r_ready => s_ready in stage2
  --     This means that the earliest eu_done_stat_i reaches map @ stage3
  
end rtl;
