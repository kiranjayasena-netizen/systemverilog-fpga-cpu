# Phase 17D timing sweep for the Phase 17C optimised forward-timing CPU.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_opt_sweep.tcl
#
# Optional:
#   $env:PHASE17D_OPT_PERIODS = "10.000 8.650 8.000"

if {[info exists ::env(PHASE17D_OPT_PERIODS)]} {
    set PERIODS [split $::env(PHASE17D_OPT_PERIODS)]
} else {
    set PERIODS {10.000 9.500 9.000 8.750 8.650 8.500 8.250 8.000}
}

set SWEEP_ROOT "reports/phase17d_forwardtiming_opt_timing_sweep"
file mkdir $SWEEP_ROOT
set summary_file "$SWEEP_ROOT/runtime_summary.txt"
set summary [open $summary_file "w"]
puts $summary "Phase 17D optimised forward-timing timing sweep"
puts $summary "Period(ns),Fmax(MHz),Status,ReportRoot"
close $summary

set vivado_exe [info nameofexecutable]

foreach period $PERIODS {
    puts "============================================================"
    puts "Running Phase 17C optimised implementation at $period ns"
    puts "============================================================"
    set run_root "$SWEEP_ROOT/period_${period}"
    set ::env(PHASE17C_PERIOD) $period
    set ::env(PHASE17C_REPORT_ROOT) $run_root
    set run_status [catch {
        exec $vivado_exe -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_opt.tcl
    } run_message]
    if {$run_status != 0} {
        puts "Run at $period ns failed: $run_message"
        set status "FAILED"
    } else {
        set status "COMPLETED"
    }

    set summary [open $summary_file "a"]
    puts $summary "$period,[expr {1000.0 / $period}],$status,$run_root"
    close $summary
}

unset -nocomplain ::env(PHASE17C_PERIOD)
unset -nocomplain ::env(PHASE17C_REPORT_ROOT)

puts "Sweep finished. Runtime summary: $summary_file"
