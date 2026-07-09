# Phase 8G synthesis script for the separate multi-cycle FPGA top.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_synth_multicycle.tcl
#
# This script does not replace the Phase 7 fpga_top flow. It synthesizes
# fpga_top_multicycle and writes separate Phase 8G reports.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_multicycle"
set REPORT_ROOT "reports/phase8g"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/checkpoints

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/cpu_core_multicycle.sv
read_verilog -sv rtl/slow_tick_generator.sv
read_verilog -sv rtl/fpga_top_multicycle.sv

if {[file exists $XDC_FILE]} {
    read_xdc $XDC_FILE
} else {
    puts "WARNING: No constraints file found at $XDC_FILE. Synthesis can run, but timing and pin reports are only placeholders."
}

synth_design -top $TOP_MODULE -part $FPGA_PART

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_multicycle_synth_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_multicycle_synth_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_multicycle_synth_worst_paths.rpt
report_power -file $REPORT_ROOT/power/fpga_top_multicycle_synth_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_multicycle_synth.dcp
