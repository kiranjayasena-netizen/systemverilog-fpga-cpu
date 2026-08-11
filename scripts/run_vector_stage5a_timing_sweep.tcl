# Bounded Stage 5A timing-target sweep.  Each target gets a fresh in-memory
# synthesis/implementation, using the same RTL and default implementation flow.
set PART xc7a35tcpg236-1
set TOP vector_program_core_synth_top
set OUT_ROOT reports/vector_stage5a/sweep
set TARGETS {80 100 120 140 160 180}
file mkdir $OUT_ROOT
set summary [open "$OUT_ROOT/summary.csv" w]
puts $summary "frequency_mhz,period_ns,wns_ns,tns_ns,setup_failures,status"

foreach freq $TARGETS {
    set period [expr {1000.0 / $freq}]
    set run_dir "$OUT_ROOT/${freq}mhz"
    file mkdir $run_dir
    read_verilog -sv rtl/vector_register_file.sv
    read_verilog -sv rtl/vector_alu.sv
    read_verilog -sv rtl/vector_execution_unit.sv
    read_verilog -sv rtl/vector_instruction_decoder.sv
    read_verilog -sv rtl/vector_instruction_execution_unit.sv
    read_verilog -sv rtl/vector_instruction_memory.sv
    read_verilog -sv rtl/vector_program_core.sv
    read_verilog -sv rtl/vector_program_core_synth_top.sv
    set_property PACKAGE_PIN W5 [get_ports clk]
    set_property IOSTANDARD LVCMOS33 [get_ports clk]
    create_clock -name vector_core_clk -period $period [get_ports clk]
    synth_design -top $TOP -part $PART
    opt_design
    place_design
    route_design
    report_timing_summary -file "$run_dir/timing_summary.rpt"
    set summ [report_timing_summary -return_string]
    set wns "NA"
    set tns "NA"
    set fails "NA"
    if {[regexp {WNS\s*\(ns\)\s+(-?[0-9.]+)} $summ -> value]} {set wns $value}
    if {[regexp {TNS\s*\(ns\)\s+(-?[0-9.]+)} $summ -> value]} {set tns $value}
    if {[regexp {Failing Endpoints\s+([0-9]+)} $summ -> value]} {set fails $value}
    set status PASS
    if {$wns ne "NA" && [expr {$wns < 0.0}]} {set status FAIL}
    puts $summary "$freq,$period,$wns,$tns,$fails,$status"
    close_project -quiet
    reset_run -quiet synth_1
}
close $summary
puts "STAGE5A_SWEEP_COMPLETE"
