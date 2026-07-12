# Phase 13A jumpfast pipeline implementation script for the separate pipelined FPGA top.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_jumpfast.tcl
#
# The generated bitstream should only be used after the Basys 3 constraints
# have been checked against the board schematic and master XDC.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_jumpfast"
set REPORT_ROOT "reports/phase13a"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/route
file mkdir $REPORT_ROOT/checkpoints
file mkdir $REPORT_ROOT/bitstreams

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline_jumpfast.sv
read_verilog -sv rtl/fpga_top_pipeline_jumpfast.sv

if {[file exists $XDC_FILE]} {
    read_xdc $XDC_FILE
} else {
    error "No constraints file found at $XDC_FILE. Create a board-specific XDC before implementation."
}

synth_design -top $TOP_MODULE -part $FPGA_PART
opt_design
place_design
route_design

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_jumpfast_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_jumpfast_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_jumpfast_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/fpga_top_pipeline_jumpfast_route_status.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_jumpfast_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_jumpfast_impl.dcp

# Only use this bitstream after the board-specific XDC has been checked
# against the actual FPGA board schematic and pinout.
write_bitstream -force $REPORT_ROOT/bitstreams/fpga_top_pipeline_jumpfast.bit
