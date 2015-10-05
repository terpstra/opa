--  opa: Open Processor Architecture
--  Copyright (C) 2014-2016  Wesley W. Terpstra
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  To apply the GPL to my VHDL, please follow these definitions:
--    Program        - The entire collection of VHDL in this project and any
--                     netlist or floorplan derived from it.
--    System Library - Any macro that translates directly to hardware
--                     e.g. registers, IO pins, or memory blocks
--    
--  My intent is that if you include OPA into your project, all of the HDL
--  and other design files that go into the same physical chip must also
--  be released under the GPL. If this does not cover your usage, then you
--  must consult me directly to receive the code under a different license.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.opa_pkg.all;
use work.opa_isa_base_pkg.all;
use work.opa_functions_pkg.all;
use work.opa_components_pkg.all;

entity opa_issue is
  generic(
    g_isa    : t_opa_isa;
    g_config : t_opa_config;
    g_target : t_opa_target);
  port(
    clk_i          : in  std_logic;
    rst_n_i        : in  std_logic;
    
    -- Values the renamer provides us
    rename_stb_i   : in  std_logic;
    rename_stall_o : out std_logic;
    rename_fast_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_slow_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_order_i : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_geta_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_getb_i  : in  std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_aux_i   : in  std_logic_vector(f_opa_aux_wide(g_config)-1 downto 0);
    rename_bakx_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    rename_baka_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    rename_bakb_i  : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    rename_stata_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)      -1 downto 0);
    rename_statb_i : in  t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_stat_wide(g_config)      -1 downto 0);
    rename_bakx_o  : out t_opa_matrix(f_opa_renamers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    
    -- Exceptions from the EUs
    eu_oldest_o    : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_retry_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_fault_i     : in  std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    eu_pc_i        : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    eu_pcf_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_fet_wide(g_config)-1 downto 0);
    eu_pcn_i       : in  t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    
    -- Selected fault fed back up pipeline
    rename_fault_o : out std_logic;
    rename_mask_o  : out std_logic_vector(f_opa_renamers(g_config)-1 downto 0);
    rename_pc_o    : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    rename_pcf_o   : out std_logic_vector(f_opa_fet_wide(g_config)-1 downto 0);
    rename_pcn_o   : out std_logic_vector(f_opa_adr_wide(g_config)-1 downto f_opa_op_align(g_isa));
    
    -- Regfile needs to fetch these for EU
    regfile_rstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_geta_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_getb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_aux_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_aux_wide (g_config)-1 downto 0);
    regfile_dec_o  : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_ren_wide (g_config)-1 downto 0);
    regfile_baka_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    regfile_bakb_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    
    -- Regfile should capture result from EU
    regfile_wstb_o : out std_logic_vector(f_opa_executers(g_config)-1 downto 0);
    regfile_bakx_o : out t_opa_matrix(f_opa_executers(g_config)-1 downto 0, f_opa_back_wide(g_isa,g_config)-1 downto 0);
    
    -- Gather information from L1d about aliased loads
    l1d_store_i    : in  std_logic;
    l1d_load_i     : in  std_logic_vector(f_opa_num_slow(g_config)-1 downto 0);
    l1d_addr_i     : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_alias_high(g_isa) downto f_opa_alias_low(g_config));
    l1d_mask_i     : in  t_opa_matrix(f_opa_num_slow(g_config)-1 downto 0, f_opa_reg_wide(g_config)/8-1 downto 0));
end opa_issue;

architecture rtl of opa_issue is

  constant c_op_align  : natural := f_opa_op_align (g_isa);
  constant c_num_arch  : natural := f_opa_num_arch (g_isa);
  constant c_num_stat  : natural := f_opa_num_stat (g_config);
  constant c_num_fast  : natural := f_opa_num_fast (g_config);
  constant c_num_slow  : natural := f_opa_num_slow (g_config);
  constant c_back_wide : natural := f_opa_back_wide(g_isa,g_config);
  constant c_aux_wide  : natural := f_opa_aux_wide (g_config);
  constant c_ren_wide  : natural := f_opa_ren_wide (g_config);
  constant c_stat_wide : natural := f_opa_stat_wide(g_config);
  constant c_adr_wide  : natural := f_opa_adr_wide (g_config);
  constant c_alias_low : natural := f_opa_alias_low(g_config);
  constant c_alias_high: natural := f_opa_alias_high(g_isa);
  constant c_reg_bytes : natural := f_opa_reg_wide (g_config)/8;
  constant c_fet_wide  : natural := f_opa_fet_wide (g_config);
  constant c_renamers  : natural := f_opa_renamers (g_config);
  constant c_executers : natural := f_opa_executers(g_config);
  constant c_fast0     : natural := f_opa_fast_index(g_config, 0);
  constant c_slow0     : natural := f_opa_slow_index(g_config, 0);
  constant c_mux_share : natural := 2;
  
  constant c_stat_ones     : std_logic_vector(c_num_stat -1 downto 0) := (others => '1');
  constant c_fast_zeros    : std_logic_vector(c_num_fast -1 downto 0) := (others => '0');
  constant c_slow_ones     : std_logic_vector(c_num_slow -1 downto 0) := (others => '1');
  constant c_slow_only     : std_logic_vector(c_executers-1 downto 0) := c_slow_ones & c_fast_zeros;
  constant c_executer_ones : std_logic_vector(c_executers-1 downto 0) := (others => '1');
  
  constant c_init_bak : t_opa_matrix := f_opa_labels(c_num_stat, c_back_wide, c_num_arch);

  -- OPA makes heavy use of speculative execution; instructions run opportunistically.
  -- It can make these kinds of mistakes, detected during execution:
  --   A. A branch/jump detects the next instruction is wrong   (misprediction)
  --   B. A load needed data not yet in the cache               (cache miss)
  --   C. A load/store accessed unmapped memory                 (page fault)
  --   D. A load did not see the result of an older store       (RaW hazard)
  --
  -- The OPA processor execution stage only has these public effects:
  --   1. A store to L1/memory
  --   2. A load from uncacheable memory
  --   3. Reporting a mispredicted branch/jump
  -- ... none of these effects can be reversed in OPA, so they are not speculated.
  --
  -- To ensure in-order execution, instructions with public effects are only
  -- executed when they are the oldest remaining instruction. This has the consequence
  -- of limiting OPA to one store / bus operation at a time. In the future, it might
  -- be possible to support multiple concurrent stores to L1 cache if the stores are
  -- all the oldest remaining instructions, but this requires more write ports on L1
  -- and I chose not to implement this in order to keep L1 reasonably cost effective.
  --
  -- Instructions in the window (c_num_stat) have these flags:
  --   issued:   already sent to the execution units
  --   ready:    result is available for dependants
  --   final:    no mistakes detected during execution
  --   complete: instruction and all priors are final
  --
  -- An instruction may only be issued if both its inputs are ready.
  -- Slow instructions transition ready to high 2 cycles after issued goes high.
  -- Fast instructions transition issued and ready to high at the same time.
  -- Both types transition final to high 4 cycles after issued goes high.
  --
  -- The oldest instruction is at index 0. Newer instructions have larger indexes.
  -- Only complete instructions are shifted out of the window, updating the commit map.
  -- As mentioned above, only the oldest incomplete instruction may cause public effects.
  --
  -- Incomplete instructions can have their issue+ready+final flags removed.
  -- This can happen in three ways:
  --   1. One of the inputs of the instruction was retried (ready went to 0)
  --     => on the following cycle issued+ready+final of the dependent instruction go to 0
  --   2. A store causes following loads to be retried (they alias)
  --     => on the cycle the store goes final=1, the loads have issued+ready+final=0
  --   3. An instruction must be retried, because after 4 cycles it asked for retry
  --     => on the cycle final WOULD have gone to 1, instead issued+ready go to 0
  --
  -- There is a slight wrinkle in this plan: inflight instructions (ie: issued+!final)
  -- When these have issued reset to 0, the running execution must not set ready/final.
  -- Consider the three causes of a retry:
  --   1. If an input went unready, this is the easiest case.
  --      The input precedes our instruction, so we won't be shifted out till after it.
  --      It will be at least 4 cycles before that happens.
  --      However, we must still ensure that our instruction does not prematurely 
  --        set ready/final=1 due to an inflight execution.
  --      For a fast instruction, it is impossible for ready to go high if deps are unready.
  --      A slow instruction must also block ready for this cycle.
  --      Both must wipe the schedule so that final (and ready for slow) won't come later.
  --   2. We must ensure two things for retried loads:
  --     They must not be shifted out! The store final=1 and loads final=0 must be atomic.
  --     If the load was being executed, it must be prevented from going ready/final
  --     Loads are slow, so this means just blocking delayed ready and wiping the schedule
  --   3. An instruction that does not go final has two sub-cases
  --     a. The instruction was retried: this failed execution is ignored
  --     b. The instruction was not retried: set issued+ready to 0
  --
  -- Here is how we handle mistakes A-D.
  --   A. A branch/jump that detects the wrong next instruction will:
  --      if it is preceded by non-final instructions, refuse to go final, causing its own reissue
  --      otherwise, report the fault, causing an irreversible update to the branch predictor
  --   B. A load that cannot find its data in cache will:
  --      request the L1 to refill a selected line (this request can be ignored)
  --      not go final, causing its own reissue later (dbus has 5 cycles to refill L1)
  --   C. A page fault is handled like a mispredicted branch/jump; reissue until oldest, then fault
  --   D. When a store executes, any loads with a matching address are reissued
  --      For now, I consider addresses to alias if they have the same word offset in a page
  --
  -- To avoid wasteful reissue, we only issue stores once all priors are issued, making
  -- it very likely that they execute only when all priors are final. Unfortunately, 
  -- without a dedicated 'ioload' instruction, we cannot likewise delay load issue.
  -- 
  -- To keep r_schedule0 as easy to compute as possible, half of the reservation station
  -- is shifted early, and half is shifted late. r_schedule0 is late, as is anything fed
  -- to the regfile stage. Anything used to feed r_schedule0 is shifted early.
  
  -- These have 1 latency indexes
  signal s_schedule_fast : t_opa_matrix(c_num_fast-1  downto 0, c_num_stat-1 downto 0);
  signal s_schedule_slow : t_opa_matrix(c_num_slow-1  downto 0, c_num_stat-1 downto 0);
  signal r_schedule0     : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule1s    : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule2     : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule3s    : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal r_schedule4s    : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0) := (others => (others => '0'));
  signal s_schedule_wb   : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  
  -- These have 0 latency indexes (fed directly)
  signal r_fast       : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal r_slow       : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal s_issued     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_new_issued : std_logic_vector(c_num_stat-1 downto 0);
  signal r_issued     : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  signal s_final      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_new_final  : std_logic_vector(c_num_stat-1 downto 0);
  signal r_final      : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  -- These have 0 latency indexes, but 1 latency content
  signal s_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_stata      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0) := (others => (others => '1'));
  signal s_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0);
  signal r_statb      : t_opa_matrix(c_num_stat-1 downto 0, c_stat_wide-1 downto 0) := (others => (others => '1'));
  -- These have 1 latency indexes (fed by skidpad)
  signal s_ready      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_ready_slow : std_logic_vector(c_num_stat-1 downto 0);
  signal s_new_ready  : std_logic_vector(c_num_stat-1 downto 0);
  signal r_ready      : std_logic_vector(c_num_stat-1 downto 0) := (others => '1');
  signal r_geta       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_getb       : std_logic_vector(c_num_stat-1 downto 0);
  signal r_aux        : t_opa_matrix(c_num_stat-1 downto 0, c_aux_wide -1 downto 0);
  signal r_bakx       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0) := c_init_bak;
  signal r_baka       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  signal r_bakb       : t_opa_matrix(c_num_stat-1 downto 0, c_back_wide-1 downto 0);
  
  -- Calculation of what to issue
  type t_ready_pad is array(natural range <>) of std_logic_vector(2**c_stat_wide-1 downto 0);
  signal s_ready_pads      : t_ready_pad((c_num_stat+c_mux_share-1)/c_mux_share-1 downto 0);
  signal s_ready_pad       : std_logic_vector(2**c_stat_wide-1 downto 0) := (others => '0');
  signal s_readya          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyb          : std_logic_vector(c_num_stat-1 downto 0);
  signal s_readyab         : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_fast    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_pending_slow    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_fast_issue      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_fast_issue      : std_logic_vector(c_num_stat-1 downto 0);
  signal s_slow_issue      : std_logic_vector(c_num_stat-1 downto 0);
  signal r_slow_issue      : std_logic_vector(c_num_stat-1 downto 0);
  
  -- The three sources of reissue
  signal s_nodep           : std_logic_vector(c_num_stat-1 downto 0);
  signal r_alias           : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal s_retry           : std_logic_vector(c_num_stat-1 downto 0);
  
  signal r_retry           : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_finalize        : std_logic_vector(c_executers-1 downto 0);
  signal r_wipe            : std_logic_vector(c_num_stat-1  downto 0) := (others => '0');
  signal s_wipe            : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
  
  -- Load buffer CAM
  signal s_slow_schedule3s : t_opa_matrix(c_num_stat-1 downto 0, c_num_slow-1 downto 0);
  signal s_store_schedule3s: std_logic_vector(c_num_stat-1 downto 0);
  signal s_after_store     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_alias_write     : std_logic_vector(c_num_stat-1 downto 0);
  signal s_alias_valid     : std_logic_vector(c_num_stat-1 downto 0);
  signal r_alias_valid     : std_logic_vector(c_num_stat-1 downto 0) := (others => '0');
  signal s_alias_addr_new  : t_opa_matrix(c_num_stat-1 downto 0, c_alias_high downto c_alias_low);
  signal s_alias_addr      : t_opa_matrix(c_num_stat-1 downto 0, c_alias_high downto c_alias_low);
  signal r_alias_addr      : t_opa_matrix(c_num_stat-1 downto 0, c_alias_high downto c_alias_low);
  signal s_alias_mask_new  : t_opa_matrix(c_num_stat-1 downto 0, c_reg_bytes-1 downto 0);
  signal s_alias_mask      : t_opa_matrix(c_num_stat-1 downto 0, c_reg_bytes-1 downto 0);
  signal r_alias_mask      : t_opa_matrix(c_num_stat-1 downto 0, c_reg_bytes-1 downto 0);
  signal s_alias           : std_logic_vector(c_num_stat-1 downto 0);
  
  -- Determine if side effects are allowed
  signal s_future_final    : std_logic_vector(c_num_stat-1 downto 0);
  signal s_future_complete : std_logic_vector(c_num_stat-1 downto 0);
  signal s_future_pcomplete: std_logic_vector(c_num_stat-1 downto 0);
  signal s_old             : std_logic_vector(c_executers-1 downto 0);
  signal r_old             : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_oldest_candidate: std_logic_vector(c_executers-1 downto 0);
  signal r_oldest_candidate: std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_oldest_possible : std_logic;
  signal s_am_oldest       : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  
  -- Flow control of the issue pipeline
  signal s_stall         : std_logic;
  signal s_shift         : std_logic;
  signal r_shift         : std_logic := '0';
  
  -- Accept data from the renamer; use a skidpad to synchronize state
  signal r_sp_geta : std_logic_vector(c_renamers-1 downto 0);
  signal r_sp_getb : std_logic_vector(c_renamers-1 downto 0);
  signal r_sp_bakx : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_baka : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_bakb : t_opa_matrix(c_renamers-1 downto 0, c_back_wide-1 downto 0);
  signal r_sp_aux  : t_opa_matrix(c_renamers-1 downto 0, c_aux_wide -1 downto 0);
  
  -- Faults are resolved to the oldest and executed when all preceding ops are final
  signal r_fault_in      : std_logic_vector(c_executers-1 downto 0) := (others => '0');
  signal s_fault_pending : std_logic;
  signal r_fault_pending : std_logic := '0';
  signal s_fault_out     : std_logic;
  signal r_fault_out     : std_logic := '0'; -- lasts one cycle
  signal r_fault_out1    : std_logic := '0'; -- one cycle delayed
  signal r_fault_pipe    : std_logic := '0'; -- lasts two cycles
  signal r_fault_mask    : std_logic_vector(c_renamers-1 downto 0);
  signal r_fault_pc      : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_fault_pcf     : std_logic_vector(c_fet_wide-1 downto 0);
  signal r_fault_pcn     : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_fault_slow_pc : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_fault_slow_pcf: std_logic_vector(c_fet_wide-1 downto 0);
  signal r_fault_slow_pcn: std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_fault_fast_pc : std_logic_vector(c_adr_wide-1 downto c_op_align);
  signal r_fault_fast_pcf: std_logic_vector(c_fet_wide-1 downto 0);
  signal r_fault_fast_pcn: std_logic_vector(c_adr_wide-1 downto c_op_align);
  
  function f_decoder_labels(renamers : natural) return t_opa_matrix is
    variable result : t_opa_matrix(c_num_stat-1 downto 0, c_ren_wide-1 downto 0);
    variable value : unsigned(result'range(2));
  begin
    for s in result'range(1) loop
      value := to_unsigned(s mod c_renamers, value'length);
      for b in value'range loop
        result(s,b) := value(b);
      end loop;
    end loop;
    return result;
  end f_decoder_labels;
  constant c_decoder_labels : t_opa_matrix := f_decoder_labels(c_renamers);
  
  function f_shift(x : std_logic_vector; s : std_logic; fill : std_logic := '0') return std_logic_vector is
    alias y : std_logic_vector(x'high downto x'low) is x;
    variable result : std_logic_vector(y'range) :=  y;
  begin
    if s = '1' then 
      result := (others => fill);
      result(y'high-c_renamers downto y'low) := y(y'high downto y'low+c_renamers);
    end if;
    return result;
  end f_shift;
  
  function f_shift(x : t_opa_matrix; s : std_logic) return t_opa_matrix is
    variable result : t_opa_matrix(x'range(1), x'range(2)) := x;
  begin
    if s = '1' then
      result := (others => (others => '0'));
      for i in x'range(1) loop
        for j in x'high(2)-c_renamers downto x'low(2) loop
          result(i,j) := x(i,j+c_renamers);
        end loop;
      end loop;
    end if;
    return result;
  end f_shift;
  
begin

  check : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      -- input control signals
      assert (f_opa_safe(rename_stb_i) = '1') report "issue: rename_stb_i has metavalue" severity failure;
      assert (f_opa_safe(l1d_store_i)  = '1') report "issue: l1d_store_i has metavalue" severity failure;
      assert (f_opa_safe(l1d_load_i)   = '1') report "issue: l1d_load_i has metavalue" severity failure;
      -- internal control signals
      assert (f_opa_safe(r_shift)      = '1') report "issue: r_shift has metavalue" severity failure;
      assert (f_opa_safe(s_shift)      = '1') report "issue: s_shift has metavalue" severity failure;
      assert (f_opa_safe(r_fault_pipe) = '1') report "issue: r_fault_pipe has metavalue" severity failure;
      assert (f_opa_safe(r_fault_out)  = '1') report "issue: r_fault_out has metavalue" severity failure;
      assert (f_opa_safe(s_fault_out)  = '1') report "issue: s_fault_out has metavalue" severity failure;
      assert (f_opa_safe(r_fault_in)   = '1') report "issue: r_fault_in has metavalue" severity failure;
      
      for i in 0 to c_num_stat-1 loop
        assert (f_opa_safe(f_opa_select_row(r_stata,i)) = '1') report "issue: stata bad" severity warning;
        assert (f_opa_safe(f_opa_select_row(r_statb,i)) = '1') report "issue: statb bad" severity warning;
      end loop;
    end if;
  end process;

  invariants : process(clk_i) is
    variable v_schedule0s : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
    variable v_schedule1s : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
    variable v_schedule2s : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
    variable v_schedule3s : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
    variable v_schedule4s : t_opa_matrix(c_executers-1 downto 0, c_num_stat-1 downto 0);
    variable v_schedule2p : std_logic_vector(c_num_stat-1 downto 0);
    variable v_seen       : std_logic_vector(c_num_stat-1 downto 0);
    variable v_old        : std_logic_vector(c_num_stat-1 downto 0);
    variable v_complete   : std_logic_vector(c_num_stat-1 downto 0);
  begin
    if rising_edge(clk_i) then
      -- r_final => r_ready (s_ready b/c r_ready has indexes one cycle late)
      assert (f_opa_or(r_final and not s_ready) = '0')
      report "issue: final operation that is not ready!"
      severity failure;
    
      -- r_ready => r_issued (s_issued b/c issued is actually the union of three vectors)
      assert (f_opa_or(s_ready and not s_issued) = '0')
      report "issue: ready operation that is not issued!"
      severity failure;
      
      -- r_issued => r_ready for fast ops
      assert (f_opa_or(s_issued and r_fast and not s_ready) = '0')
      report "issue: issued fast operation is not ready!"
      severity failure;
      
      -- If the CAM has an entry, it better be a store
      assert (f_opa_or(r_alias_valid and not r_slow) = '0')
      report "issue: load alias for non-slow op!"
      severity failure;
      
      -- r_alias => r_final (we only wake up final ops)
      assert (f_opa_or(r_alias and not r_final) = '0')
      report "issue: load alias for non-final op!"
      severity failure;
      
      -- Start checking the schedule
      v_schedule0s := not f_opa_dup_row(c_executers, r_wipe) and f_shift(r_schedule0, r_shift);
      v_schedule1s := not f_opa_dup_row(c_executers, r_wipe) and r_schedule1s;
      v_schedule2s := not f_opa_dup_row(c_executers, r_wipe) and f_shift(r_schedule2, r_shift);
      v_schedule3s := not f_opa_dup_row(c_executers, r_wipe) and r_schedule3s; 
      v_schedule4s := not f_opa_dup_row(c_executers, r_wipe) and r_schedule4s;
      
      -- r_schedule2+ => r_ready for all ops
      v_schedule2p := f_opa_product(f_opa_transpose(v_schedule2s or v_schedule3s or v_schedule4s), c_executer_ones);
      assert (f_opa_or(v_schedule2p and not s_ready) = '0')
      report "issue: scheduled op older than 2 cycles is not ready!"
      severity failure;
      
      -- An instruction can only be in-flight for one EU at one offset at a time
      v_seen := (others => '0');
      for u in 0 to c_executers-1 loop
        for s in 0 to c_num_stat-1 loop
          assert (v_seen(s) = '0' or v_schedule0s(u,s) = '0') report "issue: double-scheduled operation" severity failure;
          v_seen(s) := v_seen(s) or v_schedule0s(u,s);
          assert (v_seen(s) = '0' or v_schedule1s(u,s) = '0') report "issue: double-scheduled operation" severity failure;
          v_seen(s) := v_seen(s) or v_schedule1s(u,s);
          assert (v_seen(s) = '0' or v_schedule2s(u,s) = '0') report "issue: double-scheduled operation" severity failure;
          v_seen(s) := v_seen(s) or v_schedule2s(u,s);
          assert (v_seen(s) = '0' or v_schedule3s(u,s) = '0') report "issue: double-scheduled operation" severity failure;
          v_seen(s) := v_seen(s) or v_schedule3s(u,s);
          assert (v_seen(s) = '0' or v_schedule4s(u,s) = '0') report "issue: double-scheduled operation" severity failure;
          v_seen(s) := v_seen(s) or v_schedule4s(u,s);
        end loop;
      end loop;
      
      -- If it's scheduled, it better be issued!
      assert (f_opa_or(v_seen and not s_issued) = '0')
      report "issue: scheduled operation is not issued!"
      severity failure;
      
      -- If it's issued, it better be scheduled or final!
      assert (f_opa_or(s_issued and not v_seen and not r_final) = '0')
      report "issue: issued operation is not scheduled!"
      severity failure;
      
      -- If it's scheduled, it better not be final!
      assert (f_opa_or(v_seen and r_final) = '0')
      report "issue: scheduled operation is final!"
      severity failure;

      -- Confirm r_old makes sense
      for u in 0 to c_executers-1 loop
        assert (r_old(u) = '0' or f_opa_or(f_opa_select_row(v_schedule4s, u)) = '1')
        report "issue: unscheduled old instruction"
        severity failure;
      end loop;
      
      -- Find the instructions we claim are old
      v_old := f_opa_product(f_opa_transpose(v_schedule4s), r_old);
      
      assert (f_opa_or(v_old and r_final) = '0')
      report "issue: an old instruction cannot be final!"
      severity failure;
      
      -- r_old combined with r_final must form unbroken 1s including r_old
      v_complete := v_old or r_final;
      v_complete := v_complete and not std_logic_vector(unsigned(v_complete) + 1);
      assert (f_opa_or(v_old and not v_complete) = '0')
      report "issue: an old instruction did not form a part of the new complete chain"
      severity failure;
      
      -- The current 'oldest' instruction had better be correct
      assert (s_am_oldest(c_fast0) = '0' or s_old(c_fast0) = '1')
      report "issue: fast0 s_am_oldest, but not old?!"
      severity failure;
      
      assert (s_am_oldest(c_slow0) = '0' or s_old(c_slow0) = '1')
      report "issue: fast0 s_am_oldest, but not old?!"
      severity failure;
      
      assert (s_am_oldest(c_fast0) = '0' or s_am_oldest(c_slow0) = '0')
      report "issue: there can not be two oldest"
      severity failure;
      
    end if;
  end process;
  
  -- Which stations are already issued?
  s_issued <= f_shift(r_fast_issue or r_slow_issue, r_shift) or r_issued;

  -- Which stations have ready operands?
  -- 
  -- What follows is a fancy way of doing this:
  --   s_ready_pad(s_ready_pad'high) <= '1';
  --   s_ready_pad(r_ready'range) <= r_ready;
  --   s_readya <= f_opa_compose(s_ready_pad, r_stata);
  --   s_readyb <= f_opa_compose(s_ready_pad, r_statb);
  -- 
  -- We know that r_stat[ab] never refer backwards, so there are wasted cases
  -- in the mux. The ready muxes are the largest component in the critical path,
  -- so this seeming small optimization does matter.
  -- 
  -- For this calculation, insert '-'s for backward references (impossible) to save area.
  s_ready_pad(r_ready'range) <= r_ready; -- pad with 0s
  pads : for i in 0 to ((c_num_stat+c_mux_share-1)/c_mux_share)-1 generate
    s_ready_pads(i)(2**c_stat_wide-1) <= '1'; -- no-stat-dep means always ready
    s_ready_pads(i)((i+1)*c_mux_share+c_renamers-2 downto 0) <= s_ready_pad((i+1)*c_mux_share+c_renamers-2 downto 0);
    gap : if 2**c_stat_wide-2 >= (i+1)*c_mux_share+c_renamers-1 generate
      s_ready_pads(i)(2**c_stat_wide-2 downto (i+1)*c_mux_share+c_renamers-1) <= (others => '-');
    end generate;
  end generate;
  compose : for i in 0 to c_num_stat-1 generate
    s_readya(i) <= s_ready_pads(i / c_mux_share)(to_integer(unsigned(f_opa_select_row(r_stata, i))));
    s_readyb(i) <= s_ready_pads(i / c_mux_share)(to_integer(unsigned(f_opa_select_row(r_statb, i))));
  end generate;
  
  -- Which stations are pending issue?
  s_readyab <= s_readya and s_readyb; -- 3 levels (for stat_wide <= 5)
  s_pending_fast <= s_readyab and not s_issued and r_fast;
  s_pending_slow <= s_readyab and not s_issued and r_slow;
  
  -- Derive the schedule from the pending instructions
  fast : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_fast)
    port map(
      bits_i   => s_pending_fast,
      count_o  => s_schedule_fast,
      total_o  => s_fast_issue);
  slow : opa_prefixsum
    generic map(
      g_target => g_target,
      g_width  => c_num_stat,
      g_count  => c_num_slow)
    port map(
      bits_i   => s_pending_slow,
      count_o  => s_schedule_slow,
      total_o  => s_slow_issue);
  
  -- Report our scheduling decision to the regfile
  -- r_bak[abx], r_aux shifted one cycle later, so s_stat has correct index
  regfile_rstb_o <= f_opa_product(r_schedule0, c_stat_ones);
  regfile_geta_o <= f_opa_product(r_schedule0, r_geta);
  regfile_getb_o <= f_opa_product(r_schedule0, r_getb);
  regfile_baka_o <= f_opa_product(r_schedule0, r_baka);
  regfile_bakb_o <= f_opa_product(r_schedule0, r_bakb);
  regfile_aux_o  <= f_opa_product(r_schedule0, r_aux);
  regfile_dec_o  <= f_opa_product(r_schedule0, c_decoder_labels);
    -- 2 levels with stations <= 18
  
  -- Report our writeback schedule to the regfile
  wb_sched : for j in 0 to c_num_stat-1 generate
    fast : for i in 0 to c_num_fast-1 generate
      s_schedule_wb(i,j) <= r_schedule0(i,j);
    end generate;
    slow : for i in c_num_fast to c_executers-1 generate
      s_schedule_wb(i,j) <= r_schedule2(i,j);
    end generate;
  end generate;
  regfile_wstb_o <= f_opa_product(s_schedule_wb, c_stat_ones);
  regfile_bakx_o <= f_opa_product(s_schedule_wb, r_bakx);
  
  -- All the reasons we might have to reissue instructions
  s_nodep <= not s_readyab;
  -- r_alias
  s_retry <= f_opa_product(f_opa_transpose(r_schedule4s), r_retry) and not r_wipe; -- EU wants to re-run
  
  -- issued must go low in all three cases
  s_new_issued <= s_issued and not (s_nodep or r_alias or s_retry);
  
  -- ready must go low in all three cases, however there are three sources of readiness
  -- 1. old readiness / instructions where r_ready=1 already
  --    => these must be masked out by all three cases
  -- 2. slow readiness / slow instructions issued 2 cycles ago
  --    => s_nodep
  --    => s_alias is impossible => it implies the op was final
  --    => s_retry is impossible => it implies simultaneous execution
  -- 3. fast readiness / fast instructions issued just now
  --    => s_nodep is already considered via s_pending_fast
  --    => s_alias does not apply to fast instructions, only slow ones (loads)
  --    => s_retry is impossible => it implies simultaneous execution
  s_ready <= f_shift(r_ready, r_shift, r_fault_out1);
  s_ready_slow <= 
    not (s_nodep or r_alias or s_retry) and
    (s_ready or (f_opa_product(f_opa_transpose(r_schedule1s), c_slow_only) and not r_wipe));
  s_new_ready <= (s_fast_issue and s_pending_fast) or s_ready_slow;
  
  -- final must go low in all three cases, however not all must be considered for completeness/shift
  --   => s_nodep is irrevelant to completeness, because the (older) input already blocks complete
  --   => s_retry is actually the opposite here; we only go final if its false
  --   => r_alias must be considered, in order for store final=1 to be atomic with load final=0
  --      however, r_alias cannot affect anything scheduled, as they are not final
  s_finalize <= not r_retry;
  s_final <= (r_final and not r_alias) or (f_opa_product(f_opa_transpose(r_schedule4s), s_finalize) and not r_wipe);
  s_new_final <= s_final and not s_nodep;
  
  -- Determine if the execution window should be shifted
  s_stall  <= not f_opa_and(s_final(c_renamers-1 downto 0));
  s_shift  <= (rename_stb_i and not s_stall) or r_fault_out;
  rename_stall_o <= s_stall;
  
  -- Plan oldest calculation one cycle ahead:
  -- Recall that complete = this and all later instructions are final.
  --   Nothing can undo complete instructions; alias/nodep affect younger instructions and retry scheduled
  -- Define old = will be complete if all the instructions at schedule4 go final
  --   Old instructions can be prevented from becoming complete if they or an older old instruction
  --   report retry. Only old instructions might retry. Suppose none of them retry. Then:
  --   1. s_nodep can't stop them; they are all final => ready => clearly not woken up
  --   2. r_alias can't stop them; the only younger instructions are also old, which means that they
  --      ran in the same cycle. same cycle aliases are resolved with a retry.
  -- Therefore, the only thing that prevents an old instruction from going final is retry.
  --
  -- Now, suppose we are an instruction that runs in the cycle after the current old instructions.
  -- The question is: will we be the oldest in that cycle?
  -- Well, to answer this, suppose first that all the old instructions succeed (s_future_final).
  -- If our precedecessor is then complete (s_future_complete), we must be oldest!
  -- 
  -- Obviously, not all the instructions last cycle necessarily complete. However, we only have
  -- to care about the old instructions, because only those can preceed us if we become oldest. 
  -- As argued above, those old instructions can only be stopped by a retry. So we just need to
  -- know two things: which executed instructions are old (r_old), and did they retry?
  --
  -- If an instruction is old, then it's predecessor this cycle must be complete, so we can just
  -- re-use s_future_complete to check. We record this into r_was_old to combine with r_retry.
  
  -- We don't need to consider s_nodep in s_future_final, because nodep => an earlier non-final,
  -- and we don't care about future_final per-se, but about future_complete.
  s_future_final <= s_final or (f_opa_product(f_opa_transpose(r_schedule3s), c_executer_ones) and not r_wipe);
  s_future_complete <= s_future_final and not std_logic_vector(unsigned(s_future_final) + 1);
  s_future_pcomplete <= not r_wipe and (s_future_complete(s_future_complete'high-1 downto s_future_complete'low) & '1');
  -- Next cycle, these instructions are old
  s_old <= f_opa_product(r_schedule3s, s_future_pcomplete);
  -- In two cycles, these instructions can become oldest IF the next cycle's old instructions complete
  s_oldest_candidate <= f_opa_product(f_shift(r_schedule2, r_shift), s_future_pcomplete);
  
  -- Let's prove a bit more in-depth that the above cannot go wrong
  --   1. alias. Not an issue, because these ops are scheduled => !final => !r_alias
  --   2. retry. This is explicitly covered for schedule4 by using s_final and schedule3 using r_retry
  --   3. nodep. If schedule4 fail, then s_future_complete will be zero beyond that point
  --             If schedule3 fail, that is covered by considering their r_retry
  --             schedule2 cannot have cross-depends
  --             No other instructions are earlier, if we are an oldest candidate.
  
  s_oldest_possible <= f_opa_and(not r_old or s_finalize);
  s_am_oldest(c_fast0) <= s_oldest_possible and r_oldest_candidate(c_fast0);
  s_am_oldest(c_slow0) <= s_oldest_possible and r_oldest_candidate(c_slow0);
  eu_oldest_o <= s_am_oldest;
  
  -- Forward the fault up the pipeline
  rename_fault_o <= r_fault_out;
  rename_mask_o  <= r_fault_mask;
  rename_pc_o    <= r_fault_pc;
  rename_pcf_o   <= r_fault_pcf;
  rename_pcn_o   <= r_fault_pcn;
  -- faults always come with an s_shift
  
  -- We can use r_final instead of s_final/s_stall because a fault only happens if it was last
  s_fault_pending <= r_fault_in(c_fast0) or r_fault_in(c_slow0);
  s_fault_out     <= (s_fault_pending or r_fault_pending) and 
                     not f_opa_and(r_final(c_renamers-1 downto 0));
  
  fault_ctl : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_fault_in      <= (others => '0');
      r_fault_pending <= '0';
      r_fault_out     <= '0';
      r_fault_out1    <= '0';
      r_fault_pipe    <= '0';
    elsif rising_edge(clk_i) then
      r_fault_out1 <= r_fault_out;
      r_fault_pipe <= s_fault_out or r_fault_out;
      if r_fault_out = '1' then
        r_fault_in      <= (others => '0');
        r_fault_pending <= '0';
        r_fault_out     <= '0';
      else
        r_fault_in      <= eu_fault_i;
        r_fault_pending <= r_fault_pending or s_fault_pending;
        r_fault_out     <= s_fault_out;
      end if;
    end if;
  end process;
  
  fault_adr : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_fault_out = '1' then
        r_fault_mask <= s_final(c_renamers-1 downto 0) and
                        not std_logic_vector(unsigned(s_final(c_renamers-1 downto 0)) + 1);
      else
        r_fault_mask <= (others => '1');
      end if;
      r_fault_fast_pc  <= f_opa_select_row(eu_pc_i,  c_fast0);
      r_fault_fast_pcf <= f_opa_select_row(eu_pcf_i, c_fast0);
      r_fault_fast_pcn <= f_opa_select_row(eu_pcn_i, c_fast0);
      r_fault_slow_pc  <= f_opa_select_row(eu_pc_i,  c_slow0);
      r_fault_slow_pcf <= f_opa_select_row(eu_pcf_i, c_slow0);
      r_fault_slow_pcn <= f_opa_select_row(eu_pcn_i, c_slow0);
      
      r_fault_pc  <= r_fault_pc;
      r_fault_pcf <= r_fault_pcf;
      r_fault_pcn <= r_fault_pcn;
      
      -- These two cases are actually mutually exclusive, but whatever.
      if r_fault_in(c_fast0) = '1' then
        r_fault_pc   <= r_fault_fast_pc;
        r_fault_pcf  <= r_fault_fast_pcf;
        r_fault_pcn  <= r_fault_fast_pcn;
      end if;
      if r_fault_in(c_slow0) = '1' then
        r_fault_pc   <= r_fault_slow_pc;
        r_fault_pcf  <= r_fault_slow_pcf;
        r_fault_pcn  <= r_fault_slow_pcn;
      end if;
    end if;
  end process;
  
  -- Extract the slow unit schedule
  slow_sched3 : for j in 0 to c_num_stat-1 generate
    ldst : for i in 0 to c_num_slow-1 generate
      s_slow_schedule3s(j,i) <= r_schedule3s(i+c_num_fast,j);
    end generate;
    s_store_schedule3s(j) <= r_schedule3s(c_num_fast,j);
  end generate;
  
  -- Which operations come AFTER the store?
  s_after_store <= std_logic_vector(unsigned(not s_store_schedule3s) + 1);
  
  -- Add new loads to the CAM
  s_alias_write    <= f_opa_product(s_slow_schedule3s, l1d_load_i) and not r_wipe;
  s_alias_valid    <= s_alias_write or r_alias_valid;
  s_alias_addr_new <= f_opa_product(s_slow_schedule3s, l1d_addr_i);
  s_alias_mask_new <= f_opa_product(s_slow_schedule3s, l1d_mask_i);
  s_alias_addr     <= f_opa_mux(s_alias_write, s_alias_addr_new, r_alias_addr);
  s_alias_mask     <= f_opa_mux(s_alias_write, s_alias_mask_new, r_alias_mask);
  
  -- Process the load alias CAM
  -- Note: l1d_store_i might strobe even though it was wiped.
  --       This is harmless. If it was wiped, it can't be final or complete.
  --       Therefore, anything we restart (which is newer) is safe to reissue.
  alias_check : for s in 0 to c_num_stat-1 generate
    s_alias(s) <= l1d_store_i and r_alias_valid(s) and s_after_store(s)
                  and f_opa_eq(f_opa_select_row(r_alias_addr, s), f_opa_select_row(l1d_addr_i, 0))
                  and f_opa_or(f_opa_select_row(r_alias_mask, s) and f_opa_select_row(l1d_mask_i, 0));
  end generate;
  
  -- Prepare decremented versions of the station references
  s_stata <= f_opa_decrement(r_stata, c_renamers) when r_shift='1' else r_stata;
  s_statb <= f_opa_decrement(r_statb, c_renamers) when r_shift='1' else r_statb;
  
  -- Feed back unused registers back to the renamer
  bakx_o : for b in 0 to c_back_wide-1 generate
    dec : for i in 0 to c_renamers-1 generate
      rename_bakx_o(i,b) <= r_bakx(i+c_renamers,b) when r_shift='1' else r_bakx(i,b);
    end generate;
  end generate;
  
  -- Register the inputs with reset, with clock enable
  skidpad : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_shift = '1' then
        if r_fault_out = '1' then
          r_sp_geta <= (others => '0');
          r_sp_getb <= (others => '0');
        else
          r_sp_geta <= rename_geta_i;
          r_sp_getb <= rename_getb_i;
        end if;
        r_sp_bakx <= rename_bakx_i;
        r_sp_baka <= rename_baka_i;
        r_sp_bakb <= rename_bakb_i;
        r_sp_aux  <= f_opa_dup_row(c_renamers, rename_aux_i);
      end if;
    end if;
  end process;
  
  -- Register the stations 0-latency with reset, with load enable
  stations_0rs : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then -- asynchronous clear
      r_issued      <= (others => '1');
      r_final       <= (others => '1');
      r_alias_valid <= (others => '0');
      r_alias       <= (others => '0');
      r_old              <= (others => '0');
      r_oldest_candidate <= (others => '0');
    elsif rising_edge(clk_i) then
      if r_fault_pipe = '1' then -- synchronous clear
        r_issued      <= (others => '1');
        r_final       <= (others => '1');
        r_alias_valid <= (others => '0');
        r_alias       <= (others => '0');
        r_old              <= (others => '0');
        r_oldest_candidate <= (others => '0');
      else
        r_issued      <= f_shift(s_new_issued, s_shift);
        r_final       <= f_shift(s_new_final,  s_shift);
        r_alias_valid <= f_shift(s_alias_valid, s_shift);
        r_alias       <= f_shift(s_alias and s_new_final, s_shift);
        r_old              <= s_old;
        r_oldest_candidate <= s_oldest_candidate;
      end if;
    end if;
  end process;

  stations_0 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      r_alias_addr <= f_opa_transpose(f_shift(f_opa_transpose(s_alias_addr), s_shift));
      r_alias_mask <= f_opa_transpose(f_shift(f_opa_transpose(s_alias_mask), s_shift));
    end if;
  end process;
  
  stations_0rl : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then -- asynchronous clear
      r_stata  <= (others => (others => '1'));
      r_statb  <= (others => (others => '1'));
    elsif rising_edge(clk_i) then
      if s_shift = '1' then -- load enable
        -- These two are sneaky; they are half lagged. Content lags thanks to s_stat[ab].
        for i in 0 to c_num_stat-c_renamers-1 loop
          for b in 0 to c_stat_wide-1 loop
            r_stata(i,b) <= s_stata(i+c_renamers,b);
            r_statb(i,b) <= s_statb(i+c_renamers,b);
          end loop;
        end loop;
        if r_fault_out = '1' then
          for i in c_num_stat-c_renamers to c_num_stat-1 loop
            for b in 0 to c_stat_wide-1 loop
              r_stata(i,b) <= '1';
              r_statb(i,b) <= '1';
            end loop;
          end loop;
        else
          for i in c_num_stat-c_renamers to c_num_stat-1 loop
            for b in 0 to c_stat_wide-1 loop
              r_stata(i,b) <= rename_stata_i(i-(c_num_stat-c_renamers),b);
              r_statb(i,b) <= rename_statb_i(i-(c_num_stat-c_renamers),b);
            end loop;
          end loop;
        end if;
      else
        r_stata <= s_stata;
        r_statb <= s_statb;
      end if;
    end if;
  end process;

  -- Register the stations, 0-latency with reset, with clock enable
  stations_0rc : process(rst_n_i, clk_i) is
  begin
    if rst_n_i = '0' then
      r_fast <= (others => '0');
      r_slow <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_shift = '1' then
        if r_fault_out = '1' then
          r_fast(c_num_stat-1 downto c_num_stat-c_renamers) <= (others => '0');
          r_slow(c_num_stat-1 downto c_num_stat-c_renamers) <= (others => '0');
        else
          r_fast(c_num_stat-1 downto c_num_stat-c_renamers) <= rename_fast_i;
          r_slow(c_num_stat-1 downto c_num_stat-c_renamers) <= rename_slow_i;
        end if;
        r_fast(c_num_stat-c_renamers-1 downto 0) <= r_fast(c_num_stat-1 downto c_renamers);
        r_slow(c_num_stat-c_renamers-1 downto 0) <= r_slow(c_num_stat-1 downto c_renamers);
      end if;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset
  s_wipe <= f_opa_dup_row(c_executers, r_wipe);
  stations_1rs : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_ready      <= (others => '1');
      r_wipe       <= (others => '0');
      r_schedule0  <= (others => (others => '0'));
      r_schedule1s <= (others => (others => '0'));
      r_schedule2  <= (others => (others => '0'));
      r_schedule3s <= (others => (others => '0'));
      r_schedule4s <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      if r_fault_pipe = '1' then
        r_ready      <= (others => '1');
        r_wipe       <= (others => '0');
        r_schedule0  <= (others => (others => '0'));
        r_schedule1s <= (others => (others => '0'));
        r_schedule2  <= (others => (others => '0'));
        r_schedule3s <= (others => (others => '0'));
        r_schedule4s <= (others => (others => '0'));
      else
        r_ready      <= s_new_ready;
        -- wipe does not need to consider r_alias; r_alias => r_final => not in schedule
        r_wipe       <= f_shift(s_nodep or s_retry, s_shift);
        r_schedule0  <= f_opa_transpose(f_opa_concat(
          f_opa_transpose(s_schedule_slow and f_opa_dup_row(c_num_slow, s_pending_slow)), 
          f_opa_transpose(s_schedule_fast and f_opa_dup_row(c_num_fast, s_pending_fast))));
        r_schedule1s <= f_shift(f_shift(r_schedule0, r_shift) and not s_wipe, s_shift);
        r_schedule2  <= r_schedule1s and not s_wipe;
        r_schedule3s <= f_shift(f_shift(r_schedule2, r_shift) and not s_wipe, s_shift);
        r_schedule4s <= f_shift(r_schedule3s and not s_wipe, s_shift);
      end if;
    end if;
  end process;
  
  stations_1r : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_shift <= '0';
    elsif rising_edge(clk_i) then
      r_shift <= s_shift;
    end if;
  end process;
  
  -- Registers the stations, 1-latency without reset
  stations_1 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      -- These also need to consider all three sources of reissue as they feed s_issue
      --   s_pending_{fast,slow} already covers s_nodep
      --   both are just issued now, so s_retry is impossible (retry=>scheduled=>issued=>!not issued now)
      --   r_alias => r_final => r_issued => not issued now
      r_fast_issue <= s_fast_issue and s_pending_fast;
      r_slow_issue <= s_slow_issue and s_pending_slow;
      r_retry      <= eu_retry_i;
    end if;
  end process;
  
  -- Register the stations, 1-latency with reset, with clock enable
  stations_1rc : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_bakx <= c_init_bak;
    elsif rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        for i in 0 to c_num_stat-c_renamers-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx(i,b) <= r_bakx(i+c_renamers,b);
          end loop;
        end loop;
        for i in c_num_stat-c_renamers to c_num_stat-1 loop
          for b in 0 to c_back_wide-1 loop
            r_bakx(i,b) <= r_sp_bakx(i-(c_num_stat-c_renamers),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;

  -- Register the stations, 1-latency without reset, with clock enable
  stations_1c : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if r_shift = '1' then -- clock enable port
        for i in 0 to c_num_stat-c_renamers-1 loop
          r_geta(i) <= r_geta(i+c_renamers);
          r_getb(i) <= r_getb(i+c_renamers);
          for b in 0 to c_aux_wide-1 loop
            r_aux (i,b) <= r_aux (i+c_renamers,b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b) <= r_baka(i+c_renamers,b);
            r_bakb(i,b) <= r_bakb(i+c_renamers,b);
          end loop;
        end loop;
        for i in c_num_stat-c_renamers to c_num_stat-1 loop
          r_geta(i) <= r_sp_geta(i-(c_num_stat-c_renamers));
          r_getb(i) <= r_sp_getb(i-(c_num_stat-c_renamers));
          for b in 0 to c_aux_wide-1 loop
            r_aux (i,b) <= r_sp_aux (i-(c_num_stat-c_renamers),b);
          end loop;
          for b in 0 to c_back_wide-1 loop
            r_baka(i,b) <= r_sp_baka(i-(c_num_stat-c_renamers),b);
            r_bakb(i,b) <= r_sp_bakb(i-(c_num_stat-c_renamers),b);
          end loop;
        end loop;
      end if;
    end if;
  end process;
  
end rtl;
