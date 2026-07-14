# Phase 14G six-stage pipeline implementation and timing evidence flow.
#
# Run from the repository root, for example:
#   $env:PHASE14G_PERIOD="8.000"
#   $env:PHASE14G_STRATEGY="fanout_opt"
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline6.tcl
#
# Generated Vivado outputs are written under reports/phase14g_impl/ and are
# evidence artifacts, not source files that should be committed wholesale.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline6"

if {[info exists ::env(PHASE14G_PERIOD)] && $::env(PHASE14G_PERIOD) ne ""} {
    set PERIOD $::env(PHASE14G_PERIOD)
} else {
    set PERIOD "8.000"
}

if {[info exists ::env(PHASE14G_STRATEGY)] && $::env(PHASE14G_STRATEGY) ne ""} {
    set STRATEGY $::env(PHASE14G_STRATEGY)
} else {
    set STRATEGY "fanout_opt"
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
        error "Unknown PHASE14G_STRATEGY '$STRATEGY'. Expected baseline_perf, route_highcost, route_moreglobal, fanout_opt, or spread_logic."
    }
}

set PERIOD_TAG [string map {. p} $PERIOD]
set REPORT_ROOT "reports/phase14g_impl/${STRATEGY}_${PERIOD_TAG}ns"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/route
file mkdir $REPORT_ROOT/checkpoints
file mkdir $REPORT_ROOT/bitstreams

puts "Phase 14G six-stage pipeline implementation"
puts "  Strategy: $STRATEGY"
puts "  Period:   $PERIOD ns"
puts "  Reports:  $REPORT_ROOT"

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline6.sv
read_verilog -sv rtl/fpga_top_pipeline6.sv

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
    error "No constraints file found at $XDC_FILE."
}

synth_design -top $TOP_MODULE -part $FPGA_PART -directive $SYNTH_DIRECTIVE
opt_design -directive $OPT_DIRECTIVE
place_design -directive $PLACE_DIRECTIVE
phys_opt_design -directive $PHYS_DIRECTIVE
route_design -directive $ROUTE_DIRECTIVE
phys_opt_design -directive $POST_ROUTE_PHYS_DIRECTIVE

report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline6_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline6_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline6_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/fpga_top_pipeline6_route_status.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline6_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline6_impl.dcp
write_bitstream -force $REPORT_ROOT/bitstreams/fpga_top_pipeline6.bit

set timing_summary [report_timing_summary -return_string]
puts "Phase 14G timing summary excerpt:"
foreach line [split $timing_summary "\n"] {
    if {[regexp {WNS|TNS|WHS|THS} $line]} {
        puts $line
    }
}
