# Phase 13D performance-directive implementation experiment.
#
# Run from the repository root in Vivado Tcl mode:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_loadtiming.tcl
#
# Optional PowerShell period override:
#   $env:PHASE13D_PERIOD="9.100"; vivado -mode batch -source scripts/run_vivado_impl_pipeline_loadtiming.tcl
#
# This script keeps the Phase 13D RTL unchanged and evaluates a separate
# Vivado implementation strategy under reports/phase13d_timing/perf_directive_*.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_loadtiming"

if {[info exists ::env(PHASE13D_PERIOD)] && $::env(PHASE13D_PERIOD) ne ""} {
    set PERIOD $::env(PHASE13D_PERIOD)
} else {
    set PERIOD "9.100"
}

set PERIOD_TAG [string map {. p} $PERIOD]
set REPORT_ROOT "reports/phase13d_timing/perf_directive_${PERIOD_TAG}ns"

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
read_verilog -sv rtl/cpu_core_pipeline_loadtiming.sv
read_verilog -sv rtl/fpga_top_pipeline_loadtiming.sv

if {[file exists $XDC_FILE]} {
    set xdc_in [open $XDC_FILE "r"]
    set xdc_text [read $xdc_in]
    close $xdc_in

    set half_period [expr {$PERIOD / 2.0}]
    set clock_line [format {create_clock -add -name sys_clk_pin -period %.3f -waveform {0 %.3f} [get_ports clk]} $PERIOD $half_period]
    if {![regsub -line {^create_clock .*\[get_ports clk\]} $xdc_text $clock_line xdc_text]} {
        error "Could not find the Basys 3 create_clock line in $XDC_FILE."
    }

    set period_xdc "$REPORT_ROOT/constraints_period_${PERIOD_TAG}.xdc"
    set xdc_out [open $period_xdc "w"]
    puts $xdc_out $xdc_text
    close $xdc_out

    read_xdc $period_xdc
} else {
    error "No constraints file found at $XDC_FILE. Create a board-specific XDC before implementation."
}

synth_design -top $TOP_MODULE -part $FPGA_PART -directive PerformanceOptimized
opt_design -directive Explore
place_design -directive ExtraNetDelay_high
phys_opt_design -directive AggressiveExplore
route_design -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_loadtiming_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_loadtiming_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_loadtiming_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/fpga_top_pipeline_loadtiming_route_status.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_loadtiming_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_loadtiming_impl.dcp
write_bitstream -force $REPORT_ROOT/bitstreams/fpga_top_pipeline_loadtiming.bit
