set clk_period 2.0
create_clock [get_ports clk] -name core_clk -period $clk_period
set_clock_uncertainty 0.05 [get_clocks core_clk]
set_input_delay  -clock core_clk [expr $clk_period * 0.2] [all_inputs]
set_output_delay -clock core_clk [expr $clk_period * 0.2] [all_outputs]
