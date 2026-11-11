###################################################################
# These environment variables must be set before runnning
set DESIGN_NAME "h264_dft"
set TOP_MODULE  "me_top"

set OUT_DIR ./outputs/${DESIGN_NAME}
set REPORT_DIR ./reports/${DESIGN_NAME}
set LOG_DIR ./logs/${DESIGN_NAME}

###################################################################
# Setup
read_netlist ./lib/N16ADFP_StdCell.v -library
read_netlist ./lib/sram_atpg_model.v -library
read_netlist ./outputs/h264_dft/h264_dft.vg
run_build_model me_top

add_nofaults -module sram_32x384
add_nofaults -module sram_32x416
add_nofaults -module sram_32x448
add_nofaults -module sram_32x480

###################################################################
# Run
read_test_protocol ./outputs/h264_dft.spf
run_drc
run_atpg -auto

###################################################################
# Report
write_patterns ${OUT_DIR}/${DESIGN_NAME}.patterns.stil -format stil -replace
report_summaries > ${REPORT_DIR}/${DESIGN_NAME}.tmax_summary.rpt
report_faults -all > ${REPORT_DIR}/${DESIGN_NAME}.faults.rpt

puts "##### TetraMAX ATPG Completed Successfully #####"
exit
