###############################################
# Clock Definition
if {[info exists ::env(CLK_PERIOD)]} {
    set clk_period $::env(CLK_PERIOD)
} else {
    set clk_period 1.25;
}
set_dont_touch_network [get_clocks clk]
set_clock_uncertainty -setup 0.20 [get_clocks clk]

###############################################
## Input Constraints
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_driving_cell -lib_cell BUFFD2BWP20P90 -input_transition_rise 0.1 -input_transition_fall 0.1 $data_inputs
set_input_delay 0.08 -clock [get_clocks clk] $data_inputs

###############################################
# Output Constraints
set_load [expr [load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4] [all_outputs]
set_output_delay 0.06 -clock [get_clocks clk] [all_outputs]

###############################################
# Area Target
set_max_area 70000
