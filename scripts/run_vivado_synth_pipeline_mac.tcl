# Phase 2 MAC8 synthesis flow for the Phase 12 five-stage pipeline.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/run_vivado_synth_pipeline_mac.tcl

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline"
set REPORT_ROOT "reports/ai_mac_phase2"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/checkpoints

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline_full.sv
read_verilog -sv rtl/fpga_top_pipeline.sv
read_xdc $XDC_FILE

synth_design -top $TOP_MODULE -part $FPGA_PART \
    -generic IMEM_INIT_FILE=programs/ai_dot_product_mac.mem

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_mac_synth_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_mac_synth_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_mac_synth_worst_paths.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_mac_synth_power.rpt
write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_mac_synth.dcp
