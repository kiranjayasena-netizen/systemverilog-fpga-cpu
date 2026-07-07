# Phase 3A implementation script for the FPGA CPU baseline.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_impl.tcl
#
# Target board: Digilent Basys 3, Artix-7 xc7a35tcpg236-1.
# The generated bitstream must only be used after the board constraints
# have been checked against the actual Basys 3 schematic and master XDC.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top"

file mkdir reports
file mkdir reports/utilisation
file mkdir reports/timing
file mkdir reports/power
file mkdir reports/checkpoints
file mkdir reports/bitstreams

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
read_verilog -sv rtl/slow_tick_generator.sv
read_verilog -sv rtl/fpga_top.sv

if {[file exists $XDC_FILE]} {
    read_xdc $XDC_FILE
} else {
    error "No constraints file found at $XDC_FILE. Create a board-specific XDC before implementation."
}

synth_design -top $TOP_MODULE -part $FPGA_PART
opt_design
place_design
route_design

report_utilization -file reports/utilisation/fpga_top_impl_utilization.rpt
report_timing_summary -file reports/timing/fpga_top_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file reports/timing/fpga_top_impl_worst_paths.rpt
report_power -file reports/power/fpga_top_impl_power.rpt

write_checkpoint -force reports/checkpoints/fpga_top_impl.dcp

# Only use this bitstream after the board-specific XDC has been checked
# against the actual FPGA board schematic and pinout.
write_bitstream -force reports/bitstreams/fpga_top.bit
