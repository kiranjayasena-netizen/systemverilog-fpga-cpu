# Phase 17D timing sweep for the Phase 13 forward-timing five-stage CPU.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_timing_sweep.tcl
#
# Optional environment overrides:
#   PHASE17D_PERIODS    space-separated periods, for example "10.000 9.500 9.000"
#   PHASE17D_STRATEGIES space-separated strategies: default fanout_opt explore physopt
#
# Generated outputs are written under reports/phase17d_forwardtiming_timing_sweep/
# and should not be committed wholesale.

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_forwardtiming"

if {[info exists ::env(PHASE17D_PERIODS)] && $::env(PHASE17D_PERIODS) ne ""} {
    set PERIODS [split $::env(PHASE17D_PERIODS)]
} else {
    set PERIODS [list "10.000" "9.500" "9.000" "8.750" "8.650" "8.500" "8.250" "8.000" "7.750" "7.500"]
}

if {[info exists ::env(PHASE17D_STRATEGIES)] && $::env(PHASE17D_STRATEGIES) ne ""} {
    set STRATEGIES [split $::env(PHASE17D_STRATEGIES)]
} else {
    set STRATEGIES [list "default" "fanout_opt" "explore" "physopt"]
}

set SWEEP_ROOT "reports/phase17d_forwardtiming_timing_sweep"
file mkdir $SWEEP_ROOT

proc emit_period_xdc {src_xdc period out_xdc} {
    set xdc_in [open $src_xdc "r"]
    set xdc_text [read $xdc_in]
    close $xdc_in

    set half_period [expr {$period / 2.0}]
    set clock_line [format {create_clock -add -name sys_clk_pin -period %.3f -waveform {0 %.3f} [get_ports clk]} $period $half_period]
    if {![regsub -line {^create_clock .*\[get_ports clk\]} $xdc_text $clock_line xdc_text]} {
        error "Could not find the Basys 3 create_clock line in $src_xdc."
    }

    set xdc_out [open $out_xdc "w"]
    puts $xdc_out $xdc_text
    close $xdc_out
}

proc apply_strategy {strategy} {
    switch -- $strategy {
        "default" {
            synth_design -top $::TOP_MODULE -part $::FPGA_PART
            opt_design
            place_design
            route_design
        }
        "fanout_opt" {
            synth_design -top $::TOP_MODULE -part $::FPGA_PART -directive PerformanceOptimized
            opt_design -directive Explore
            place_design -directive ExtraNetDelay_high
            phys_opt_design -directive AggressiveFanoutOpt
            route_design -directive AggressiveExplore
            phys_opt_design -directive AggressiveExplore
        }
        "explore" {
            synth_design -top $::TOP_MODULE -part $::FPGA_PART -directive PerformanceOptimized
            opt_design -directive Explore
            place_design -directive Explore
            phys_opt_design -directive Explore
            route_design -directive Explore
            phys_opt_design -directive Explore
        }
        "physopt" {
            synth_design -top $::TOP_MODULE -part $::FPGA_PART -directive PerformanceOptimized
            opt_design -directive Explore
            place_design -directive ExtraNetDelay_high
            phys_opt_design -directive AggressiveExplore
            route_design -directive HigherDelayCost
            phys_opt_design -directive AggressiveExplore
        }
        default {
            error "Unsupported PHASE17D strategy '$strategy'. Use default, fanout_opt, explore, or physopt."
        }
    }
}

foreach strategy $STRATEGIES {
    foreach period $PERIODS {
        set period_tag [string map {. p} $period]
        set run_root "$SWEEP_ROOT/${strategy}_${period_tag}ns"

        file mkdir $run_root
        file mkdir "$run_root/constraints"
        file mkdir "$run_root/utilisation"
        file mkdir "$run_root/timing"
        file mkdir "$run_root/power"
        file mkdir "$run_root/route"
        file mkdir "$run_root/checkpoints"
        file mkdir "$run_root/bitstreams"

        puts "Phase 17D run: strategy=$strategy period=$period ns"

        create_project -in_memory -part $FPGA_PART

        read_verilog -sv rtl/cpu_defs_pkg.sv
        read_verilog -sv rtl/bram_instr_mem.sv
        read_verilog -sv rtl/bram_data_mem.sv
        read_verilog -sv rtl/cpu_core_pipeline_forwardtiming.sv
        read_verilog -sv rtl/fpga_top_pipeline_forwardtiming.sv

        set period_xdc "$run_root/constraints/forwardtiming_${strategy}_${period_tag}ns.xdc"
        emit_period_xdc $XDC_FILE $period $period_xdc
        read_xdc $period_xdc

        apply_strategy $strategy

        report_utilization -file "$run_root/utilisation/fpga_top_pipeline_forwardtiming_impl_utilization.rpt"
        report_timing_summary -file "$run_root/timing/fpga_top_pipeline_forwardtiming_impl_timing_summary.rpt"
        report_timing -max_paths 10 -path_type full -file "$run_root/timing/fpga_top_pipeline_forwardtiming_impl_worst_paths.rpt"
        report_route_status -file "$run_root/route/fpga_top_pipeline_forwardtiming_route_status.rpt"
        report_power -file "$run_root/power/fpga_top_pipeline_forwardtiming_impl_power.rpt"

        write_checkpoint -force "$run_root/checkpoints/fpga_top_pipeline_forwardtiming_impl.dcp"
        write_bitstream -force "$run_root/bitstreams/fpga_top_pipeline_forwardtiming.bit"

        set timing_summary [report_timing_summary -return_string]
        puts "Timing excerpt for strategy=$strategy period=$period:"
        foreach line [split $timing_summary "\n"] {
            if {[regexp {WNS|TNS|WHS|THS} $line]} {
                puts $line
            }
        }

        close_project
    }
}

puts "Phase 17D sweep complete. Output root: $SWEEP_ROOT"
