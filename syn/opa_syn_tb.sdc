derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous -group { altera_reserved_tck } -group { osc } -group { clockpll|altera_pll_i|* }
