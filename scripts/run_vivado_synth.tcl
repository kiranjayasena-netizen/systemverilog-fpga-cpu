# Phase 3A synthesis script for the FPGA CPU baseline.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_synth.tcl
#
# Before running, replace FPGA_PART with the part for your chosen board.
# If you have a real board constraint file, set XDC_FILE to that path.

set FPGA_PART "TODO_SET_FPGA_PART"
set XDC_FILE "constraints/board.xdc"
set TOP_MODULE "fpga_top"

if {$FPGA_PART eq "TODO_SET_FPGA_PART"} {
    error "Set FPGA_PART in scripts/run_vivado_synth.tcl before running synthesis."
}

file mkdir reports
file mkdir reports/utilisation
file mkdir reports/timing
file mkdir reports/power
file mkdir reports/checkpoints

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/alu.sv
read_verilog -sv rtl/register_file.sv
read_verilog -sv rtl/program_counter.sv
read_verilog -sv rtl/instruction_memory.sv
read_verilog -sv rtl/data_memory.sv
read_verilog -sv rtl/fetch_unit.sv
read_verilog -sv rtl/instruction_decoder.sv
read_verilog -sv rtl/control_unit.sv
read_verilog -sv rtl/cpu_core.sv
read_verilog -sv rtl/fpga_top.sv

if {[file exists $XDC_FILE]} {
    read_xdc $XDC_FILE
} else {
    puts "WARNING: No constraints file found at $XDC_FILE. Synthesis can run, but timing and pin reports are only placeholders."
}

synth_design -top $TOP_MODULE -part $FPGA_PART

report_utilization -file reports/utilisation/fpga_top_synth_utilization.rpt
report_timing_summary -file reports/timing/fpga_top_synth_timing_summary.rpt
report_power -file reports/power/fpga_top_synth_power.rpt

write_checkpoint -force reports/checkpoints/fpga_top_synth.dcp
