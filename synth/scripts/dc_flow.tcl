###################################################################
# These environment variables must be set before runnning
set DESIGN_NAME $::env(DESIGN_NAME)
set TOP_MODULE  $::env(TOP_MODULE)

set OUT_DIR ./outputs/${DESIGN_NAME}
set REPORT_DIR ./reports/${DESIGN_NAME}
set LOG_DIR ./logs/${DESIGN_NAME}

###################################################################
# Setup
puts "Hostname : [info hostname]"
puts "Design   : ${DESIGN_NAME} (Top: ${TOP_MODULE})"

################################
# Directory housekeeping
foreach dir "outputs reports logs ${OUT_DIR} ${REPORT_DIR} ${LOG_DIR}" {
  if {![file isdirectory $dir]} {
    file mkdir $dir
  }
}

redirect -file /dev/null {set start_time [clock seconds]}

################################
# setup tool cache so it doesn't clutter up working dir
if {![file exists ./synopsys_cache]} {file mkdir ./synopsys_cache}
set_app_var cache_write ./synopsys_cache
set_app_var cache_read ./synopsys_cache
set_app_var cache_file_chmod_octal 666
set_app_var cache_dir_chmod_octal 777

################################
# Add SRAM macro library to link_library
lappend link_library ./lib/sram_macros_lib.db

################################
# STEP: Analyze and elaborate the design, read the design constraints
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0 }]
puts [format "##### Analyzing the Design. Runtime: %.2f mins #####" $elapsed_time]

if {[file exists ./filelist.f]} {
  set file_list {}
  set fp [open ./filelist.f r]
  while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line ne "" && ![string match "#*" $line]} {
      lappend file_list $line
    }
  }
  close $fp

  puts "==> INFORMATION: Analyzing files from filelist.f"
  analyze -format sverilog $file_list
} else {
  puts "==>FATAL: filelist.f list could not be found. Exiting..."
  exit
}

elaborate ${TOP_MODULE} -architecture verilog -library WORK -update
current_design ${TOP_MODULE}

redirect -file ${REPORT_DIR}/${TOP_MODULE}.syn.link.rpt {set link_status [link]}
if {!$link_status} {
  puts "==>FATAL: Design Link Failed... Check ${REPORT_DIR}/${TOP_MODULE}.syn.link.rpt. Exiting..."
  exit
}

###############################
# prevent assign statements
set_app_var verilogout_no_tri true
set_fix_multiple_port_nets -all -buffer_constants
set_app_var uniquify_keep_original_design true

###############################
# Lock SRAM Macros so DC treats them as untouched hard macros
set sram_insts [get_cells -hierarchical -filter "ref_name =~ sram_32x*"]
if {[sizeof_collection $sram_insts] > 0} {
  puts "==> INFORMATION: Setting dont_touch on [sizeof_collection $sram_insts] SRAM macro instances."
  set_dont_touch $sram_insts
}

###############################
# Read IO, Loading and timing constraints
if {[file exists ./inputs/constraints/${TOP_MODULE}.constraints.tcl]} {
  puts "==>INFORMATION: Sourcing the design constraints file"
  source -echo -verbose ./inputs/constraints/${TOP_MODULE}.constraints.tcl
} else {
  puts "==>FATAL: Design Constraints file does not exists... Exiting..."
  exit
}

##############################
# Set the Clock network as Dont Touch Network
set_dont_touch_network [get_clocks]

###############################
# Set operating condition and DRC targets
set_app_var auto_wire_load_selection true
set_wire_load_mode top
set_operating_conditions -analysis_type bc_wc -max tt0p8v25c
set_critical_range 0.1 [current_design]
set_max_fanout 32 [current_design]
set_max_transition 0.25 [current_design]

###############################
# Create DFT Ports Early & Hook Up SRAM DFT_BYPASS Pins
create_port -direction "in"  {test_si test_se test_tm}
create_port -direction "out" {test_so}

# Automatically punch and connect test_tm to all SRAM DFT_BYPASS pins across hierarchies
set sram_bypass_pins [get_pins -hierarchical */DFT_BYPASS]
if {[sizeof_collection $sram_bypass_pins] > 0} {
  foreach_in_collection bp_pin $sram_bypass_pins {
    set conn_net [all_connected $bp_pin]
    if {[sizeof_collection $conn_net] > 0} {
      disconnect_net $conn_net $bp_pin
    }
    connect_pin -from [get_ports test_tm] -to $bp_pin -port_name test_tm
  }
}

###############################
# path group setup (after test ports exist so they are excluded)
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports {clk test_se test_tm}]]
group_path -name inputs  -from $non_clk_inputs
group_path -name output  -to [all_outputs]
group_path -name comb    -from $non_clk_inputs -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

###############################
# Clock Gating Style (Ensures -gate_clock ICG cells have a TE pin for DFT)
set_clock_gating_style -sequential_cell latch \
  -positive_edge_logic {integrated} \
  -control_point before \
  -control_signal scan_enable

###############################
# RTL Test DRC (Run BEFORE setting case_analysis 0 on test_se / test_tm)
set_scan_configuration -style multiplexed_flip_flop
set_dft_signal -view existing_dft -type ScanClock -timing {45 55} -port clk
set_dft_signal -view existing_dft -type TestMode  -active_state 1 -port test_tm
create_test_protocol -infer_asynch -infer_clock
dft_drc -verbose > ${REPORT_DIR}/${DESIGN_NAME}.RTLTestDRC.rpt
write_test_protocol -output ${OUT_DIR}/${DESIGN_NAME}_pre_dft.spf

# Lock test_se and test_tm to 0 during initial functional compile
set_case_analysis 0 [get_ports {test_se test_tm}]

###############################
# STEP: Compile
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Compile. Runtime: %.2f mins #####" $elapsed_time]

set_app_var fsm_auto_inferring true
set_app_var fsm_enable_state_minimization true
set_fsm_minimize true

compile_ultra -gate_clock -scan -no_autoungroup
write_file -format verilog -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}_pre_dft.vg

##############################
# STEP: Configure Scan Chain and Insert DFT Logic
# Remove case_analysis temporarily so DFT DRC and insert_dft see test_se and test_tm active
remove_case_analysis [get_ports {test_se test_tm}]

set_driving_cell -lib_cell BUFFD2BWP20P90 -input_transition_rise 0.1 -input_transition_fall 0.1 [get_ports {test_si test_se test_tm}]
set_load [expr {[load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4}] [get_ports test_so]

set_input_delay  0.08 -clock [get_clocks *] [get_ports {test_si test_se test_tm}]
set_output_delay 0.06 -clock [get_clocks *] [get_ports test_so]

# Enable automatic connection of both mux controls AND clock-gating TE pins
set_dft_configuration -connect_mux_controls enable -connect_clock_gating enable
set_scan_configuration -respect_async_ctrls true -replace false

set_dft_signal -view existing_dft -type ScanClock  -timing {45 55} -port clk
set_dft_signal -view existing_dft -type TestMode   -active_state 1 -port test_tm
set_dft_signal -view spec         -type ScanDataIn  -port test_si
set_dft_signal -view spec         -type ScanDataOut -port test_so
set_dft_signal -view spec         -type ScanEnable  -port test_se
set_dft_signal -view spec         -type TestMode    -active_state 1 -port test_tm

create_test_protocol -infer_asynch -infer_clock

dft_drc -verbose           > ${REPORT_DIR}/${DESIGN_NAME}.PreDFTDRC.rpt
insert_dft
dft_drc -verbose -coverage > ${REPORT_DIR}/${DESIGN_NAME}.PostDFTDRC.rpt

# Write out the test protocol (.spf) for TetraMAX BEFORE re-applying case_analysis 0!
write_test_protocol -output ${OUT_DIR}/${DESIGN_NAME}_post_dft.spf

set_dont_touch_network [get_ports {test_se test_tm}]
set_ideal_network      [get_ports {test_se test_tm}]
set_case_analysis 0    [get_ports {test_se test_tm}]

##############################
# STEP: Incremental Compile
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Incremental Compile. Runtime: %.2f mins #####" $elapsed_time]
compile_ultra -incremental -gate_clock -scan -no_autoungroup

##############################
# STEP: Outputs and Reports
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Outputs and Reports. Runtime: %.2f mins #####" $elapsed_time]

###############################
# path group re-setup - some path graph may have become invalid during design compile
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports {clk test_se test_tm}]]
group_path -name inputs -from $non_clk_inputs
group_path -name output -to [all_outputs]
group_path -name comb -from $non_clk_inputs -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

##############################
# change names
define_name_rules standard_names \
	-allowed "A-Za-z0-9_\[\]" \
	-equal_ports_nets \
	-remove_internal_net_bus \
	-target_bus_naming_style "%s\[%d\]" \
	-add_dummy_nets \
	-flatten_multi_dimension_busses

define_name_rules reg_names \
	-type cell \
	-map {{{"\]", "x"}, {"\[", "x"}}}

change_names -hierarchy -verbose -rules reg_names > ${LOG_DIR}/change_names_reg.log
change_names -hierarchy -verbose -rules standard_names > ${LOG_DIR}/change_names_standard.log
remove_case_analysis [get_ports {test_se test_tm}]
dft_drc -verbose -coverage > ${REPORT_DIR}/${DESIGN_NAME}.FinalDFTDRC.rpt
write_test_protocol -output ${OUT_DIR}/${DESIGN_NAME}.spf
set_case_analysis 0 [get_ports {test_se test_tm}]

##############################
# Outputs
write_file -format verilog -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}.vg
write_file -format ddc -hierarchy -output ${OUT_DIR}/${DESIGN_NAME}.ddc
# Setting variables to not write out load/resistance in sdc
set write_sdc_output_lumped_net_capacitance false
set write_sdc_output_net_resistance false
write_sdc -nosplit ${OUT_DIR}/${DESIGN_NAME}.sdc

##############################
# Reports
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
report_reference -hierarchy -nosplit        > ${REPORT_DIR}/${DESIGN_NAME}.ref.rpt
report_qor -significant_digits 4            > ${REPORT_DIR}/${DESIGN_NAME}.qor.rpt
report_power -hierarchy -verbose -nosplit   > ${REPORT_DIR}/${DESIGN_NAME}.power.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.power.rpt {printenv LOGNAME}
report_constraint -all_violators -significant_digits 4 -nosplit > ${REPORT_DIR}/${DESIGN_NAME}.constraint.rpt
check_design                                > ${REPORT_DIR}/${DESIGN_NAME}.check_design.rpt
check_timing                                > ${REPORT_DIR}/${DESIGN_NAME}.check_timing.rpt
report_fsm					                > ${REPORT_DIR}/${DESIGN_NAME}.fsm.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.fsm.rpt {printenv LOGNAME}

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

set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Done. Runtime: %.2f mins, Memory Used: %.1f GB #####" $elapsed_time [expr [mem] / 1000000.0]]
exit
