# Phase 13I implementation-strategy sweep for the preferred Phase 13E pipeline.
#
# Run from the repository root, for example:
#   $env:PHASE13I_PERIOD="8.800"
#   $env:PHASE13I_STRATEGY="route_highcost"
#   C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source scripts/run_vivado_phase13i_strategy_sweep.tcl
#
# This script intentionally reuses the Phase 13E RTL unchanged. It only changes
# Vivado implementation directives and the generated clock period.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_forwardtiming"

if {[info exists ::env(PHASE13I_PERIOD)] && $::env(PHASE13I_PERIOD) ne ""} {
    set PERIOD $::env(PHASE13I_PERIOD)
} else {
    set PERIOD "8.850"
}

if {[info exists ::env(PHASE13I_STRATEGY)] && $::env(PHASE13I_STRATEGY) ne ""} {
    set STRATEGY $::env(PHASE13I_STRATEGY)
} else {
    set STRATEGY "baseline_perf"
}

switch -exact -- $STRATEGY {
    baseline_perf {
        set SYNTH_DIRECTIVE "PerformanceOptimized"
        set OPT_DIRECTIVE "Explore"
        set PLACE_DIRECTIVE "ExtraNetDelay_high"
        set PHYS_DIRECTIVE "AggressiveExplore"
        set ROUTE_DIRECTIVE "AggressiveExplore"
        set POST_ROUTE_PHYS_DIRECTIVE "AggressiveExplore"
    }
    route_highcost {
        set SYNTH_DIRECTIVE "PerformanceOptimized"
        set OPT_DIRECTIVE "Explore"
        set PLACE_DIRECTIVE "ExtraNetDelay_high"
        set PHYS_DIRECTIVE "AggressiveExplore"
        set ROUTE_DIRECTIVE "HigherDelayCost"
        set POST_ROUTE_PHYS_DIRECTIVE "AggressiveExplore"
    }
    route_moreglobal {
        set SYNTH_DIRECTIVE "PerformanceOptimized"
        set OPT_DIRECTIVE "Explore"
        set PLACE_DIRECTIVE "ExtraNetDelay_high"
        set PHYS_DIRECTIVE "AggressiveExplore"
        set ROUTE_DIRECTIVE "MoreGlobalIterations"
        set POST_ROUTE_PHYS_DIRECTIVE "AggressiveExplore"
    }
    fanout_opt {
        set SYNTH_DIRECTIVE "PerformanceOptimized"
        set OPT_DIRECTIVE "Explore"
        set PLACE_DIRECTIVE "ExtraNetDelay_high"
        set PHYS_DIRECTIVE "AggressiveFanoutOpt"
        set ROUTE_DIRECTIVE "AggressiveExplore"
        set POST_ROUTE_PHYS_DIRECTIVE "AggressiveExplore"
    }
    spread_logic {
        set SYNTH_DIRECTIVE "PerformanceOptimized"
        set OPT_DIRECTIVE "ExploreWithRemap"
        set PLACE_DIRECTIVE "AltSpreadLogic_high"
        set PHYS_DIRECTIVE "AggressiveExplore"
        set ROUTE_DIRECTIVE "AggressiveExplore"
        set POST_ROUTE_PHYS_DIRECTIVE "AggressiveExplore"
    }
    default {
        error "Unknown PHASE13I_STRATEGY '$STRATEGY'. Expected baseline_perf, route_highcost, route_moreglobal, fanout_opt, or spread_logic."
    }
}

set PERIOD_TAG [string map {. p} $PERIOD]
set REPORT_ROOT "reports/phase13i_strategy/${STRATEGY}_${PERIOD_TAG}ns"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/route
file mkdir $REPORT_ROOT/checkpoints
file mkdir $REPORT_ROOT/bitstreams

puts "Phase 13I strategy sweep"
puts "  Strategy: $STRATEGY"
puts "  Period:   $PERIOD ns"
puts "  Reports:  $REPORT_ROOT"

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline_forwardtiming.sv
read_verilog -sv rtl/fpga_top_pipeline_forwardtiming.sv

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

synth_design -top $TOP_MODULE -part $FPGA_PART -directive $SYNTH_DIRECTIVE
opt_design -directive $OPT_DIRECTIVE
place_design -directive $PLACE_DIRECTIVE
phys_opt_design -directive $PHYS_DIRECTIVE
route_design -directive $ROUTE_DIRECTIVE
phys_opt_design -directive $POST_ROUTE_PHYS_DIRECTIVE

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_forwardtiming_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_forwardtiming_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_forwardtiming_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/fpga_top_pipeline_forwardtiming_route_status.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_forwardtiming_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_forwardtiming_impl.dcp
write_bitstream -force $REPORT_ROOT/bitstreams/fpga_top_pipeline_forwardtiming.bit
