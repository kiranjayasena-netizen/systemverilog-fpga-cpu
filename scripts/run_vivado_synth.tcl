# Phase 3A synthesis script for the FPGA CPU baseline.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_synth.tcl
#
# Target board: Digilent Basys 3, Artix-7 xc7a35tcpg236-1.
# The XDC is based on the Basys 3 master XDC pin names used by this project.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top"

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
