###################################################################
# This variable needs to be modified before running this script:
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
lappend link_library /home/kuehn348/src/ee5327/ee5327-mpeg4me/synth/lib/sram_macros.db

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
# Set wire load model and operating condition
#set_wire_load_model -name 8000 -library [get_libs]
#set_operating_conditions -analysis_type bc_wc -max tt1p05v125c
set_operating_conditions -analysis_type bc_wc -max tt0p8v25c

###############################
# path group setup
set non_clk_inputs [remove_from_collection [all_inputs] [get_ports clk]]
group_path -name inputs -from $non_clk_inputs
group_path -name output -to [all_outputs]
group_path -name comb -from [all_inputs] -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

###############################
# STEP: Compile
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Compile. Runtime: %.2f mins #####" $elapsed_time]
compile_ultra -no_autoungroup

##############################
# STEP: Outputs and Reports
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Outputs and Reports. Runtime: %.2f mins #####" $elapsed_time]

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
report_qor                                  > ${REPORT_DIR}/${DESIGN_NAME}.qor.rpt
report_power -hierarchy -verbose -nosplit   > ${REPORT_DIR}/${DESIGN_NAME}.power.rpt
redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.power.rpt {printenv LOGNAME}
report_constraint -all_violators -nosplit   > ${REPORT_DIR}/${DESIGN_NAME}.constraint.rpt
check_design                                > ${REPORT_DIR}/${DESIGN_NAME}.check_design.rpt
check_timing                                > ${REPORT_DIR}/${DESIGN_NAME}.check_timing.rpt

foreach_in_collection group [get_path_groups] {
  set group_name [get_object_name $group]
  if { [sizeof_collection [get_timing_paths -group $group_name]] } {
    redirect -file ${REPORT_DIR}/${DESIGN_NAME}.timing.${group_name}.rpt {
      report_timing \
		-nosplit \
		-capacitance \
		-transition_time \
		-significant_digits 2 \
		-input_pins -nets -max_paths 20 \
		-group $group_name
    }
    redirect -append -file ${REPORT_DIR}/${DESIGN_NAME}.timing.${group_name}.rpt {printenv LOGNAME}
  }
}

set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Done. Runtime: %.2f mins, Memory Used: %.1f GB #####" $elapsed_time [expr [mem] / 1000000.0]]
exit
