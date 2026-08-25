# Parameterised post-route timing flow for the Phase 12 MAC8 pipeline.
#
# Usage from the repository root:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_mac_sweep.tcl \
#       -tclargs <period_ns> <frequency_mhz> <implementation_seed_label> <output_dir> \
#       ?<core_rtl> <top_rtl> <top_module> <bitstream_name>?
#
# Vivado 2026.1 does not expose an implementation seed through place_design,
# route_design, run properties, or a supported set_param. The third argument
# is therefore retained as an independent-run label and is reported with
# seed_applied=false. It must not be represented as a controlled placer seed.

if {($argc != 4) && ($argc != 8)} {
    error "Expected 4 baseline arguments or 8 arguments including core_rtl top_rtl top_module bitstream_name"
}

set TARGET_PERIOD_NS [lindex $argv 0]
set TARGET_FREQUENCY_MHZ [lindex $argv 1]
set IMPLEMENTATION_SEED [lindex $argv 2]
set OUTPUT_DIR [file normalize [lindex $argv 3]]

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set CORE_RTL "rtl/cpu_core_pipeline_full.sv"
set TOP_RTL "rtl/fpga_top_pipeline.sv"
set TOP_MODULE "fpga_top_pipeline"
set BITSTREAM_NAME "fpga_top_pipeline_mac.bit"
if {$argc == 8} {
    set CORE_RTL [lindex $argv 4]
    set TOP_RTL [lindex $argv 5]
    set TOP_MODULE [lindex $argv 6]
    set BITSTREAM_NAME [lindex $argv 7]
}
set IMEM_FILE "programs/ai_dot_product_mac.mem"

file mkdir $OUTPUT_DIR
foreach child_dir {bitstreams checkpoints constraints route timing utilisation} {
    file mkdir [file join $OUTPUT_DIR $child_dir]
}

# The board XDC remains the source of pin assignments and the clock port. A
# second, per-run XDC overwrites only sys_clk_pin, avoiding dynamic mutation of
# a synthesized design and making the target visible to synthesis and implementation.
set CLOCK_OVERRIDE_XDC [file join $OUTPUT_DIR constraints clock_override.xdc]
set override_file [open $CLOCK_OVERRIDE_XDC w]
puts $override_file "create_clock -name sys_clk_pin -period $TARGET_PERIOD_NS -waveform {0.0 [expr {$TARGET_PERIOD_NS / 2.0}]} \[get_ports clk\]"
close $override_file

set synthesis_success false
set applied_period_ns ""
set synthesis_wns_ns ""
set implementation_success false
set placement_success false
set routing_success false
set setup_wns_ns ""
set hold_wns_ns ""
set setup_tns_ns ""
set hold_tns_ns ""
set failing_setup_endpoints ""
set failing_hold_endpoints ""
set critical_data_delay_ns ""
set critical_logic_delay_ns ""
set critical_routing_delay_ns ""
set critical_logic_levels ""
set critical_startpoint ""
set critical_endpoint ""
set clock_name ""
set lut_count ""
set ff_count ""
set dsp_count ""
set bram_tiles ""
set bitstream_status "not_attempted"
set vivado_version [version -short]
set timing_report_path [file join $OUTPUT_DIR timing post_route_timing_summary.rpt]
set critical_path_report_path [file join $OUTPUT_DIR timing post_route_worst_setup_paths.rpt]
set flow_error ""

proc csv_quote {value} {
    return "\"[string map [list \" \"\"] $value]\""
}

proc worst_slack {delay_type} {
    set paths [get_timing_paths -quiet -delay_type $delay_type -max_paths 1 -nworst 1]
    if {[llength $paths] == 0} {
        return ""
    }
    return [get_property SLACK [lindex $paths 0]]
}

proc violation_stats {delay_type} {
    set paths [get_timing_paths -quiet -delay_type $delay_type \
        -slack_lesser_than 0.0 -max_paths 100000 -nworst 1]
    set total_slack 0.0
    foreach timing_path $paths {
        set total_slack [expr {$total_slack + [get_property SLACK $timing_path]}]
    }
    return [list [format %.3f $total_slack] [llength $paths]]
}

proc extract_utilisation {report_text row_name fallback} {
    set escaped_name [regsub -all {([][(){}.*+?^$\\|])} $row_name {\\\1}]
    set expression [format {^\|[[:space:]]*%s[[:space:]]*\|[[:space:]]*([0-9.]+)} $escaped_name]
    if {[regexp -line -- $expression $report_text -> value]} {
        return $value
    }
    return $fallback
}

set flow_rc [catch {
    read_verilog -sv rtl/cpu_defs_pkg.sv
    read_verilog -sv rtl/bram_instr_mem.sv
    read_verilog -sv rtl/bram_data_mem.sv
    read_verilog -sv $CORE_RTL
    read_verilog -sv $TOP_RTL
    read_xdc $XDC_FILE
    read_xdc $CLOCK_OVERRIDE_XDC

    synth_design -top $TOP_MODULE -part $FPGA_PART \
        -generic IMEM_INIT_FILE=$IMEM_FILE
    set synthesis_success true

    set constrained_clocks [get_clocks -quiet sys_clk_pin]
    if {[llength $constrained_clocks] != 1} {
        error "Expected exactly one sys_clk_pin clock after synth_design"
    }
    set clock_name [get_property NAME [lindex $constrained_clocks 0]]
    set applied_period_ns [get_property PERIOD [lindex $constrained_clocks 0]]
    set synthesis_wns_ns [worst_slack max]
    report_timing_summary -file [file join $OUTPUT_DIR timing synthesis_timing_summary.rpt]
    report_utilization -file [file join $OUTPUT_DIR utilisation synthesis_utilisation.rpt]
    write_checkpoint -force [file join $OUTPUT_DIR checkpoints post_synthesis.dcp]

    opt_design
    place_design
    set placement_success true
    report_timing_summary -file [file join $OUTPUT_DIR timing post_place_timing_summary.rpt]

    route_design
    set implementation_success true
    set route_text [report_route_status -return_string]
    report_route_status -file [file join $OUTPUT_DIR route post_route_status.rpt]
    set have_routable [regexp {# of routable nets[^:]*:[[:space:]]*([0-9]+)} \
        $route_text -> routable_nets]
    set have_fully_routed [regexp {# of fully routed nets[^:]*:[[:space:]]*([0-9]+)} \
        $route_text -> fully_routed_nets]
    set have_route_errors [regexp {# of nets with routing errors[^:]*:[[:space:]]*([0-9]+)} \
        $route_text -> route_errors]
    if {$have_routable && $have_fully_routed && $have_route_errors &&
        ($routable_nets == $fully_routed_nets) && ($route_errors == 0)} {
        set routing_success true
    } else {
        error "route_design returned but report_route_status was not fully routed with zero errors"
    }

    report_timing_summary -file $timing_report_path
    report_timing -delay_type max -path_type full_clock_expanded -input_pins -nets \
        -max_paths 10 -nworst 1 -file $critical_path_report_path
    report_timing -delay_type min -path_type full_clock_expanded -input_pins -nets \
        -max_paths 10 -nworst 1 -file [file join $OUTPUT_DIR timing post_route_worst_hold_paths.rpt]

    set setup_path [lindex [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]
    set hold_path [lindex [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]
    set setup_wns_ns [get_property SLACK $setup_path]
    set hold_wns_ns [get_property SLACK $hold_path]
    lassign [violation_stats max] setup_tns_ns failing_setup_endpoints
    lassign [violation_stats min] hold_tns_ns failing_hold_endpoints

    set critical_data_delay_ns [get_property DATAPATH_DELAY $setup_path]
    set critical_logic_delay_ns [get_property DATAPATH_LOGIC_DELAY $setup_path]
    set critical_routing_delay_ns [get_property DATAPATH_NET_DELAY $setup_path]
    set critical_logic_levels [get_property LOGIC_LEVELS $setup_path]
    set critical_startpoint [get_property STARTPOINT_PIN $setup_path]
    set critical_endpoint [get_property ENDPOINT_PIN $setup_path]
    set clock_name [get_property ENDPOINT_CLOCK $setup_path]

    set detail_file [open [file join $OUTPUT_DIR timing critical_path_cells.txt] w]
    puts $detail_file "Startpoint: $critical_startpoint"
    puts $detail_file "Endpoint: $critical_endpoint"
    puts $detail_file "Clock: $clock_name"
    puts $detail_file "Data path delay (ns): $critical_data_delay_ns"
    puts $detail_file "Logic delay (ns): $critical_logic_delay_ns"
    puts $detail_file "Routing delay (ns): $critical_routing_delay_ns"
    puts $detail_file "Logic levels: $critical_logic_levels"
    puts $detail_file ""
    puts $detail_file "Timing-path pins and owning cells:"
    foreach path_pin [get_pins -quiet -of_objects $setup_path] {
        set owner [get_cells -quiet -of_objects $path_pin]
        set ref_name [get_property -quiet REF_NAME $owner]
        puts $detail_file "$path_pin | $owner | $ref_name"
    }
    puts $detail_file ""
    puts $detail_file "Timing-path nets:"
    foreach path_net [get_nets -quiet -of_objects $setup_path] {
        puts $detail_file $path_net
    }
    close $detail_file

    set util_text [report_utilization -return_string]
    report_utilization -file [file join $OUTPUT_DIR utilisation post_route_utilisation.rpt]
    set lut_fallback [llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]
    set ff_fallback [llength [get_cells -hier -filter {REF_NAME =~ FD*}]]
    set dsp_fallback [llength [get_cells -hier -filter {REF_NAME =~ DSP*}]]
    set ramb18_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ RAMB18*}]]
    set ramb36_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ RAMB36*}]]
    set bram_fallback [expr {$ramb36_count + (0.5 * $ramb18_count)}]
    set lut_count [extract_utilisation $util_text "Slice LUTs" $lut_fallback]
    set ff_count [extract_utilisation $util_text "Slice Registers" $ff_fallback]
    set dsp_count [extract_utilisation $util_text "DSPs" $dsp_fallback]
    set bram_tiles [extract_utilisation $util_text "Block RAM Tile" $bram_fallback]

    write_checkpoint -force [file join $OUTPUT_DIR checkpoints post_route.dcp]
    if {[catch {
        write_bitstream -force [file join $OUTPUT_DIR bitstreams $BITSTREAM_NAME]
    } bitstream_error]} {
        set bitstream_status "failed: $bitstream_error"
    } else {
        set bitstream_status "passed"
    }
} flow_message flow_options]

if {$flow_rc != 0} {
    set flow_error $flow_message
}

set header_fields {
    target_frequency_mhz target_period_ns applied_period_ns implementation_seed seed_applied
    vivado_version fpga_part top_module clock_name synthesis_success
    synthesis_wns_ns implementation_success placement_success routing_success
    post_route_setup_wns_ns post_route_hold_wns_ns setup_tns_ns hold_tns_ns
    failing_setup_endpoints failing_hold_endpoints critical_path_data_delay_ns
    critical_path_logic_delay_ns critical_path_routing_delay_ns logic_levels
    critical_path_startpoint critical_path_endpoint lut_count ff_count dsp_count
    bram_tiles bitstream_status run_directory timing_report_path
    critical_path_report_path flow_error
}
set value_fields [list \
    $TARGET_FREQUENCY_MHZ $TARGET_PERIOD_NS $applied_period_ns $IMPLEMENTATION_SEED false \
    $vivado_version $FPGA_PART $TOP_MODULE $clock_name $synthesis_success \
    $synthesis_wns_ns $implementation_success $placement_success $routing_success \
    $setup_wns_ns $hold_wns_ns $setup_tns_ns $hold_tns_ns \
    $failing_setup_endpoints $failing_hold_endpoints $critical_data_delay_ns \
    $critical_logic_delay_ns $critical_routing_delay_ns $critical_logic_levels \
    $critical_startpoint $critical_endpoint $lut_count $ff_count $dsp_count \
    $bram_tiles $bitstream_status $OUTPUT_DIR $timing_report_path \
    $critical_path_report_path $flow_error]

set result_file [open [file join $OUTPUT_DIR run_result.csv] w]
puts $result_file [join $header_fields ,]
set quoted_values {}
foreach value $value_fields {
    lappend quoted_values [csv_quote $value]
}
puts $result_file [join $quoted_values ,]
close $result_file

if {$flow_rc != 0} {
    puts stderr "FMAX_SWEEP_RUN_FAILED: $flow_error"
    exit 1
}

puts "FMAX_SWEEP_RUN_PASSED: frequency=${TARGET_FREQUENCY_MHZ}MHz period=${TARGET_PERIOD_NS}ns repetition=${IMPLEMENTATION_SEED}"
exit 0
