# Phase 13B branch-prefetch pipeline synthesis script for the separate pipelined FPGA top.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_synth_pipeline_branchprefetch.tcl

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_branchprefetch"
set REPORT_ROOT "reports/phase13b"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/checkpoints

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem_dualread.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline_branchprefetch.sv
read_verilog -sv rtl/fpga_top_pipeline_branchprefetch.sv

if {[file exists $XDC_FILE]} {
    read_xdc $XDC_FILE
} else {
    puts "WARNING: No constraints file found at $XDC_FILE. Synthesis can run, but timing and pin reports are only placeholders."
}

synth_design -top $TOP_MODULE -part $FPGA_PART

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_branchprefetch_synth_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_branchprefetch_synth_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_branchprefetch_synth_worst_paths.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_branchprefetch_synth_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_branchprefetch_synth.dcp
