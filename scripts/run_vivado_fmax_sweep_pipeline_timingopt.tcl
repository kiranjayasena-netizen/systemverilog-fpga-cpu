# Phase 13C clock-period sweep for the separate timing-optimised pipeline top.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/run_vivado_fmax_sweep_pipeline_timingopt.tcl
#
# To run a shorter custom sweep from PowerShell:
#   $env:PHASE13C_PERIODS="9.500,9.250,9.000"; vivado -mode batch -source scripts/run_vivado_fmax_sweep_pipeline_timingopt.tcl

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set TOP_MODULE "fpga_top_pipeline_timingopt"
set REPORT_ROOT "reports/phase13c_timing/sweep"

if {[info exists ::env(PHASE13C_PERIODS)] && $::env(PHASE13C_PERIODS) ne ""} {
    set PERIODS [split $::env(PHASE13C_PERIODS) ","]
} else {
    set PERIODS {10.000 9.500 9.000 8.750 8.500 8.300 8.000}
}

file mkdir $REPORT_ROOT
set summary_file "$REPORT_ROOT/phase13c_fmax_sweep_summary.csv"
set summary_fh [open $summary_file "w"]
puts $summary_fh "period_ns,requested_mhz,wns_ns,tns_ns,whs_ns,ths_ns,bitstream_status,report_dir"

proc run_period {period} {
    global FPGA_PART XDC_FILE TOP_MODULE REPORT_ROOT summary_fh

    set tag [string map {. p} $period]
    set period_root "$REPORT_ROOT/period_${tag}ns"
    file mkdir $period_root
    file mkdir "$period_root/utilisation"
    file mkdir "$period_root/timing"
    file mkdir "$period_root/route"
    file mkdir "$period_root/power"
    file mkdir "$period_root/checkpoints"
    file mkdir "$period_root/bitstreams"

    create_project -in_memory -part $FPGA_PART

    read_verilog -sv rtl/cpu_defs_pkg.sv
    read_verilog -sv rtl/bram_instr_mem.sv
    read_verilog -sv rtl/bram_data_mem.sv
    read_verilog -sv rtl/cpu_core_pipeline_timingopt.sv
    read_verilog -sv rtl/fpga_top_pipeline_timingopt.sv

    set half_period [expr {$period / 2.0}]
    if {[file exists $XDC_FILE]} {
        set xdc_in [open $XDC_FILE "r"]
        set xdc_text [read $xdc_in]
        close $xdc_in

        set clock_line [format {create_clock -add -name sys_clk_pin -period %.3f -waveform {0 %.3f} [get_ports clk]} $period $half_period]
        if {![regsub -line {^create_clock .*\[get_ports clk\]} $xdc_text $clock_line xdc_text]} {
            error "Could not find the Basys 3 create_clock line in $XDC_FILE."
        }

        set period_xdc "$period_root/constraints_period_${tag}.xdc"
        set xdc_out [open $period_xdc "w"]
        puts $xdc_out $xdc_text
        close $xdc_out

        read_xdc $period_xdc
    } else {
        error "No constraints file found at $XDC_FILE."
    }

    synth_design -top $TOP_MODULE -part $FPGA_PART

    opt_design
    place_design
    route_design

    report_utilization -file "$period_root/utilisation/fpga_top_pipeline_timingopt_impl_utilization.rpt"
    set timing_summary_file "$period_root/timing/fpga_top_pipeline_timingopt_impl_timing_summary.rpt"
    report_timing_summary -file $timing_summary_file
    report_timing -max_paths 10 -path_type full -file "$period_root/timing/fpga_top_pipeline_timingopt_impl_worst_paths.rpt"
    report_route_status -file "$period_root/route/fpga_top_pipeline_timingopt_route_status.rpt"
    report_power -file "$period_root/power/fpga_top_pipeline_timingopt_impl_power.rpt"
    write_checkpoint -force "$period_root/checkpoints/fpga_top_pipeline_timingopt_impl.dcp"

    set bitstream_status "PASS"
    if {[catch {write_bitstream -force "$period_root/bitstreams/fpga_top_pipeline_timingopt.bit"} bitstream_error]} {
        set bitstream_status "FAIL"
        puts "WARNING: write_bitstream failed for period $period ns: $bitstream_error"
    }

    set timing_fh [open $timing_summary_file "r"]
    set timing_text [read $timing_fh]
    close $timing_fh

    set wns "NA"
    set tns "NA"
    set whs "NA"
    set ths "NA"
    if {[regexp {sys_clk_pin\s+(-?[0-9]+\.[0-9]+)\s+(-?[0-9]+\.[0-9]+)\s+\d+\s+\d+\s+(-?[0-9]+\.[0-9]+)\s+(-?[0-9]+\.[0-9]+)} $timing_text -> parsed_wns parsed_tns parsed_whs parsed_ths]} {
        set wns $parsed_wns
        set tns $parsed_tns
        set whs $parsed_whs
        set ths $parsed_ths
    }
    set requested_mhz [expr {1000.0 / $period}]

    puts $summary_fh [format "%.3f,%.3f,%s,%s,%s,%s,%s,%s" \
        $period $requested_mhz $wns $tns $whs $ths $bitstream_status $period_root]
    flush $summary_fh

    close_project
}

foreach period $PERIODS {
    puts ""
    puts "============================================================"
    puts "Running Phase 13C timing sweep at period ${period} ns"
    puts "============================================================"
    run_period $period
}

close $summary_fh
puts "Phase 13C sweep summary written to $summary_file"
