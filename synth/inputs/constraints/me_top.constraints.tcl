###############################################
# Clock Definition
create_clock -name CLK -period 1 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks CLK]
###############################################
## Input Constraints
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_driving_cell -lib_cell BUFFD2BWP20P90 -input_transition_rise 0.1 -input_transition_fall 0.1 $data_inputs
set_input_delay 0.08 -clock [get_clocks CLK] $data_inputs
###############################################
# Output Constraints
set_load [expr [load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4] [all_outputs]
set_output_delay 0.12 -clock [get_clocks CLK] [all_outputs]
set_max_area 0
