
###################################################################
# Environment and Housekeeping
###################################################################

# Set design variables
set DESIGN_NAME $::env(DESIGN_NAME)
set TOP_MODULE  $::env(TOP_MODULE)

set OUT_DIR ./outputs/${DESIGN_NAME}
set REPORT_DIR ./reports/${DESIGN_NAME}
set LOG_DIR ./logs/${DESIGN_NAME}

puts "Hostname : [info hostname]"
puts "Design   : ${DESIGN_NAME} (Top: ${TOP_MODULE})"
redirect -file /dev/null {set start_time [clock seconds]}

# Ensure directories exist
foreach dir "outputs reports logs ${OUT_DIR} ${REPORT_DIR} ${LOG_DIR}" {
  if {![file isdirectory $dir]} {
    file mkdir $dir
  }
}

# Set permissions on synopsys cache
if {![file exists ./synopsys_cache]} {file mkdir ./synopsys_cache}
set_app_var cache_write ./synopsys_cache
set_app_var cache_read ./synopsys_cache
set_app_var cache_file_chmod_octal 666
set_app_var cache_dir_chmod_octal 777

# Suppress noisy log messages
suppress_message {PWR-806 PWR-730 OPT-319}

###################################################################
# Analyze, Elaborate, and Link
###################################################################

set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0 }]
puts [format "##### Analyzing the Design. Runtime: %.2f mins #####" $elapsed_time]

# Parse filelist.f
set file_list {}
set fp [open ./filelist.f r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line ne "" && ![string match "#*" $line]} { lappend file_list $line }
}
close $fp

# Set naming style for structs in ports.
set_app_var hdlin_field_naming_style "%s_%s"
set_app_var hdlin_array_naming_style "%s_%d"

# Analyze and elaborate the design
puts "==> INFORMATION: Analyzing files from filelist.f"
analyze -format sverilog $file_list
elaborate ${TOP_MODULE} -architecture verilog -library WORK -update
current_design ${TOP_MODULE}

# Link the design
redirect -file ${REPORT_DIR}/${TOP_MODULE}.syn.link.rpt {set link_status [link]}
if {!$link_status} {
  puts "==>FATAL: Design Link Failed... Check ${REPORT_DIR}/${TOP_MODULE}.syn.link.rpt. Exiting..."
  exit
}

# Add switching information into the design.
if {[file exists ./me_top_rtl.saif]} {
  puts "==> INFORMATION: Reading RTL switching activity from ./me_top_rtl.saif"
  read_saif -auto_map_names -input ./inputs/constraints/me_top_rtl.saif -instance_name me_top_saif_tb/dut -verbose
}

###################################################################
# Constraints, Macros, Attributes
###################################################################

# Source SDC constraints
if {[file exists ./inputs/constraints/${TOP_MODULE}.constraints.tcl]} {
    source -echo -verbose ./inputs/constraints/${TOP_MODULE}.constraints.tcl
} else {
    puts "==>FATAL: Constraints file missing. Exiting..."
    exit
}

# Global app vars and drc targets
set_app_var verilogout_no_tri true
set_fix_multiple_port_nets -all -buffer_constants
set_app_var uniquify_keep_original_design true
set_app_var auto_wire_load_selection true
set_wire_load_mode top
set_operating_conditions -analysis_type bc_wc -max tt0p8v25c
set_critical_range 0.1 [current_design]
set_max_fanout 32 [current_design]
set_max_transition 0.25 [current_design]
set_app_var high_fanout_net_threshold 1000
set_cost_priority -delay

# Lock SRAM macros
set sram_insts [get_cells -hierarchical -filter "ref_name =~ sram_32x*"]
if {[sizeof_collection $sram_insts] > 0} {
 	puts "==> INFORMATION: Setting dont_touch on [sizeof_collection $sram_insts] SRAM macro instances."
 	set_dont_touch $sram_insts
}

# Disable register merging for the PE array
if {[sizeof_collection [get_designs -quiet fs_pe_array*]] > 0} {
  	puts "==> INFORMATION: Disabling register merging on fs_pe_array."
  	set_register_merging [get_designs fs_pe_array*] false
}

# Prevent register merging on broadcast pipeline regs
set pe_fanout_regs [get_cells -hierarchical -filter "full_name =~ *stall_q_reg* || full_name =~ *clear_q_reg*"]
if {[sizeof_collection $pe_fanout_regs] > 0} {
  	puts "==> INFORMATION: Disabling register merging on stall_q_reg and clear_q_reg."
    set_register_merging $pe_fanout_regs false
    set_attribute $pe_fanout_regs preserve_sequential true
}

###################################################################
# Create DFT Ports and Functional Setup
###################################################################

create_port -direction "in"  {test_si test_se test_tm}
create_port -direction "out" {test_so}

# Setup clock gating style
set_clock_gating_style -sequential_cell latch \
  -positive_edge_logic {integrated} \
  -control_point before \
  -control_signal scan_enable

# Lock test pins to 0 for functional optimization
set_case_analysis 0 [get_ports {test_se test_tm}]
set_dont_touch_network [get_clocks]

###################################################################
# Pre-Compile Optimizations & Path Grouping
###################################################################

# Setup clock gating
set_clock_gating_style -sequential_cell latch \
  -positive_edge_logic {integrated} \
  -control_point before \
  -control_signal scan_enable
set_app_var power_cg_flatten true
set_app_var power_cg_balance_stages true

# Allow for dynamic and leakage power optimization
set_dynamic_optimization true
set_leakage_optimization true

# Setup FSM optimization
set_app_var fsm_auto_inferring true
set_app_var fsm_enable_state_minimization true
set_fsm_minimize true

# Setup path groups
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports {clk}]]
group_path -name inputs  -from $non_clk_inputs
group_path -name output  -to [all_outputs]
group_path -name comb    -from $non_clk_inputs -to [all_outputs]
group_path -name reg2reg -from [all_registers] -to [all_registers]

###################################################################
# Primary Synthesis (Compile Ultra)
###################################################################

compile_ultra -gate_clock -scan -no_autoungroup
split_clock_gates -max_fanout 32
write_file -format verilog -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}_pre_dft.vg

###################################################################
# DFT Insertion and Protocol Generation
###################################################################

# Release case analysis so DFT sees active test signals
remove_case_analysis [get_ports {test_se test_tm}]

# Configure DFT signals and rules
set_dft_signal -view existing_dft -type ScanClock   -timing {45 55} -port clk
set_dft_signal -view existing_dft -type TestMode    -active_state 1 -port test_tm
set_dft_signal -view spec         -type ScanDataIn  -port test_si
set_dft_signal -view spec         -type ScanDataOut -port test_so
set_dft_signal -view spec         -type ScanEnable  -port test_se
set_dft_signal -view spec         -type TestMode    -active_state 1 -port test_tm

set_dft_configuration -connect_mux_controls enable -connect_clock_gating enable
set_scan_configuration -respect_async_ctrls true -replace false

# Insert DFT_BYPASS wire so that TMax stops complaining at me
set sram_bypass_pins [get_pins -hierarchical */DFT_BYPASS]
if {[sizeof_collection $sram_bypass_pins] > 0} {
    puts "==> INFORMATION: Connecting [sizeof_collection $sram_bypass_pins] SRAM DFT_BYPASS pins to test_tm."
    foreach_in_collection bp_pin $sram_bypass_pins {
        set conn_net [all_connected $bp_pin]
        if {[sizeof_collection $conn_net] > 0} {
            disconnect_net $conn_net $bp_pin
        }
        connect_pin -from [get_ports test_tm] -to $bp_pin -port_name test_tm
    }
} else {
    puts "==> WARNING: No SRAM DFT_BYPASS pins found in the hierarchy!"
}

create_test_protocol -infer_asynch -infer_clock

# Run DRC, insert DFT, and verify coverage
dft_drc -verbose > ${REPORT_DIR}/${DESIGN_NAME}.PreDFTDRC.rpt
insert_dft

###################################################################
# Incremental Compile (Post-DFT Timing)
###################################################################

compile_ultra -incremental -gate_clock -scan -no_autoungroup
set_ideal_network [get_ports {clk test_se test_tm}]

remove_path_group {inputs output comb reg2reg}
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports {clk test_se test_tm}]]
group_path -name inputs  -from $non_clk_inputs
group_path -name output  -to [all_outputs]
group_path -name comb    -from $non_clk_inputs -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

###################################################################
# Clean Names and Write Outputs
###################################################################

# Use verilog naming rules when generating the netlist.
change_names -hierarchy -verbose -rules verilog > ${LOG_DIR}/change_names.log

# Write TetraMAX test protocol BEFORE locking test pins back to functional 0
dft_drc -verbose -coverage > ${REPORT_DIR}/${DESIGN_NAME}.PostDFTDRC.rpt
write_test_protocol -output ${OUT_DIR}/${DESIGN_NAME}.spf

# Restore functional mode for ICC2 SDC and timing reports
set_case_analysis 0 [get_ports {test_se test_tm}]

# Export post-dft netlist and ddc file
write_file -format verilog -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}.vg
write_file -format ddc     -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}.ddc

# Export SDC constraints for ICC2
set write_sdc_output_lumped_net_capacitance false
set write_sdc_output_net_resistance false
write_sdc -nosplit ${OUT_DIR}/${DESIGN_NAME}.sdc

###################################################################
# Comprehensive Reporting
###################################################################

# Area Report with custom SRAM Macro vs. Standard Cell breakdown
report_area -hierarchy -nosplit > ${REPORT_DIR}/${DESIGN_NAME}.area.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.area.rpt {
  	set total_area [get_attribute [current_design] area]
  	set macro_area 0.0

  	# Find all macro/black-box instances in the design
  	set macro_cells [get_cells -hierarchical -filter "is_macro_cell == true || is_black_box == true"]
  	if {[sizeof_collection $macro_cells] > 0} {
  	  	foreach_in_collection cell $macro_cells {
  	    	set cell_area [get_attribute $cell area]
  	    	if {$cell_area ne ""} {
  	      		set macro_area [expr {$macro_area + $cell_area}]
  	    	}
  	  	}
  	}
  	set stdcell_only_area [expr {$total_area - $macro_area}]

  	puts "\n========================================================"
  	puts "AREA SUMMARY (WITH vs. WITHOUT SRAM MACROS)"
  	puts "========================================================"
  	puts [format "Standard Cell Area Only (No SRAMs) : %12.2f um^2" $stdcell_only_area]
  	puts [format "Estimated SRAM Macro Area (%d inst) : %12.2f um^2" [sizeof_collection $macro_cells] $macro_area]
  	puts "--------------------------------------------------------"
  	puts [format "Total Area (With Estimated SRAMs)  : %12.2f um^2" $total_area]
  	puts "========================================================\n"
  	printenv LOGNAME
}

# Reference, QoR, Power, and Clock Gating Reports
report_reference -hierarchy -nosplit          > ${REPORT_DIR}/${DESIGN_NAME}.ref.rpt
report_qor -significant_digits 4              > ${REPORT_DIR}/${DESIGN_NAME}.qor.rpt
report_power -hierarchy -verbose -nosplit     > ${REPORT_DIR}/${DESIGN_NAME}.power.rpt
report_power -analysis_effort high -verbose -nosplit > ${REPORT_DIR}/${DESIGN_NAME}.power.summary.rpt
report_clock_gating -nosplit -verbose         > ${REPORT_DIR}/${DESIGN_NAME}.clock_gating.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.power.rpt {printenv LOGNAME}

# Constraint Violators, Design Checks, and Timing Checks
report_constraint -all_violators -significant_digits 4 -nosplit > ${REPORT_DIR}/${DESIGN_NAME}.constraint.rpt
check_design                                  > ${REPORT_DIR}/${DESIGN_NAME}.check_design.rpt
check_timing                                  > ${REPORT_DIR}/${DESIGN_NAME}.check_timing.rpt
report_fsm                                    > ${REPORT_DIR}/${DESIGN_NAME}.fsm.rpt
report_saif -hierarchy -rtl_saif -missing     > ${REPORT_DIR}/${DESIGN_NAME}.saif_map.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.fsm.rpt {printenv LOGNAME}

# Detailed Path-by-Path Timing Reports for each Path Group
foreach_in_collection group [get_path_groups] {
  set group_name [get_object_name $group]
  if { [sizeof_collection [get_timing_paths -group $group_name]] } {
    redirect -file ${REPORT_DIR}/${DESIGN_NAME}.timing.${group_name}.rpt {
      report_timing \
            -nosplit \
            -capacitance \
            -transition_time \
            -significant_digits 4 \
            -input_pins -nets -max_paths 20 \
            -group $group_name
    }
    redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.timing.${group_name}.rpt {printenv LOGNAME}
  }
}

# Final Runtime and Memory Summary
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Done. Runtime: %.2f mins, Memory Used: %.1f GB #####" $elapsed_time [expr [mem] / 1000000.0]]
exit
