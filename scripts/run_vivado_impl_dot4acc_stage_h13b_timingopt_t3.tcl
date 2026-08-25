# One clean default-flow Stage H1.3b implementation of the selective
# second-LOAD DOT4ACC CPU.
#
# Usage:
#   vivado -mode batch -source scripts/run_vivado_impl_dot4acc_stage_g.tcl \
#     -tclargs <period_ns> <frequency_mhz> <repetition> <output_dir> <identifier>

if {$argc != 5} {
    error "Expected: period_ns frequency_mhz repetition output_dir implementation_identifier"
}

set TARGET_PERIOD_NS [lindex $argv 0]
set TARGET_FREQUENCY_MHZ [lindex $argv 1]
set REPETITION_NUMBER [lindex $argv 2]
set OUTPUT_DIR [file normalize [lindex $argv 3]]
set IMPLEMENTATION_IDENTIFIER [lindex $argv 4]

set FPGA_PART "xc7a35tcpg236-1"
set XDC_FILE "constraints/basys3.xdc"
set IMEM_FILE "programs/dot4acc_stage_d.mem"
set TOP_MODULE "fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t3"
set BITSTREAM_NAME "fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t3.bit"

set SYNTHESIS_DIRECTIVE "Default"
set OPT_DIRECTIVE "Default"
set PLACE_DIRECTIVE "Default"
set PHYS_OPT_DIRECTIVE "NotRun"
set ROUTE_DIRECTIVE "Default"

file mkdir $OUTPUT_DIR
foreach child_dir {bitstreams checkpoints constraints methodology route timing utilisation} {
    file mkdir [file join $OUTPUT_DIR $child_dir]
}

# Keep the board XDC as the pin source and override only its clock definition,
# matching the published MAC8 boundary methodology.
set CLOCK_OVERRIDE_XDC [file join $OUTPUT_DIR constraints clock_override.xdc]
set override_file [::open $CLOCK_OVERRIDE_XDC w]
puts $override_file "create_clock -name sys_clk_pin -period $TARGET_PERIOD_NS -waveform {0.0 [expr {$TARGET_PERIOD_NS / 2.0}]} \[get_ports clk\]"
::close $override_file

proc csv_quote {value} {
    return "\"[string map [list \" \"\"] $value]\""
}

proc safe_property {object property_name} {
    if {$object eq ""} { return "" }
    if {[catch {get_property $property_name $object} value]} { return "" }
    return $value
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
    if {[regexp -line -- $expression $report_text -> value]} { return $value }
    return $fallback
}

set synthesis_success false
set placement_success false
set implementation_success false
set routing_success false
set applied_period_ns ""
set synthesis_wns_ns ""
set setup_wns_ns ""
set setup_tns_ns ""
set failing_setup_endpoints ""
set hold_wns_ns ""
set hold_tns_ns ""
set failing_hold_endpoints ""
set pulse_width_wns_ns ""
set pulse_width_tns_ns ""
set failing_pulse_width_endpoints ""
set critical_data_delay_ns ""
set critical_logic_delay_ns ""
set critical_routing_delay_ns ""
set critical_logic_levels ""
set critical_startpoint ""
set critical_endpoint ""
set critical_path_group ""
set critical_clock_uncertainty_ns ""
set hold_startpoint ""
set hold_endpoint ""
set hold_path_group ""
set clock_name ""
set clock_count ""
set lut_count ""
set ff_count ""
set ramb18_count ""
set ramb36_count ""
set dsp_count ""
set bufg_count ""
set latch_count ""
set bitstream_status "not_attempted"
set vivado_version [version -short]
set timing_report_path [file join $OUTPUT_DIR timing post_route_timing_summary.rpt]
set critical_path_report_path [file join $OUTPUT_DIR timing post_route_worst_setup_paths.rpt]
set hold_path_report_path [file join $OUTPUT_DIR timing post_route_worst_hold_paths.rpt]
set check_timing_report_path [file join $OUTPUT_DIR methodology check_timing.rpt]
set methodology_report_path [file join $OUTPUT_DIR methodology report_methodology.rpt]
set clock_interaction_report_path [file join $OUTPUT_DIR methodology clock_interaction.rpt]
set drc_report_path [file join $OUTPUT_DIR methodology post_route_drc.rpt]
set flow_error ""

set flow_rc [catch {
    read_verilog -sv rtl/cpu_defs_pkg.sv
    read_verilog -sv rtl/bram_instr_mem.sv
    read_verilog -sv rtl/bram_data_mem.sv
    read_verilog -sv rtl/dot4acc_pipeline.sv
    read_verilog -sv rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t3.sv
    read_verilog -sv rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t3.sv
    read_xdc $XDC_FILE
    read_xdc $CLOCK_OVERRIDE_XDC

    synth_design -top $TOP_MODULE -part $FPGA_PART \
        -generic IMEM_INIT_FILE=$IMEM_FILE
    set synthesis_success true

    set constrained_clocks [get_clocks -quiet sys_clk_pin]
    set clock_count [llength [get_clocks -quiet *]]
    if {[llength $constrained_clocks] != 1} {
        error "Expected exactly one sys_clk_pin clock after synth_design"
    }
    set clock_name [get_property NAME [lindex $constrained_clocks 0]]
    set applied_period_ns [get_property PERIOD [lindex $constrained_clocks 0]]
    set synth_path [lindex [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1] 0]
    set synthesis_wns_ns [safe_property $synth_path SLACK]
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
    set have_routable [regexp {# of routable nets[^:]*:[[:space:]]*([0-9]+)} $route_text -> routable_nets]
    set have_fully_routed [regexp {# of fully routed nets[^:]*:[[:space:]]*([0-9]+)} $route_text -> fully_routed_nets]
    set have_route_errors [regexp {# of nets with routing errors[^:]*:[[:space:]]*([0-9]+)} $route_text -> route_errors]
    if {$have_routable && $have_fully_routed && $have_route_errors &&
        ($routable_nets == $fully_routed_nets) && ($route_errors == 0)} {
        set routing_success true
    } else {
        error "route_design completed without a fully routed, zero-error design"
    }

    update_timing
    set timing_summary_text [report_timing_summary -return_string]
    set timing_summary_file [::open $timing_report_path w]
    puts $timing_summary_file $timing_summary_text
    ::close $timing_summary_file
    report_timing -delay_type max -path_type full_clock_expanded -input_pins \
        -max_paths 25 -nworst 1 -file $critical_path_report_path
    report_timing -delay_type min -path_type full_clock_expanded -input_pins \
        -max_paths 10 -nworst 1 -file $hold_path_report_path
    check_timing -verbose -file $check_timing_report_path
    report_methodology -file $methodology_report_path
    report_clock_interaction -file $clock_interaction_report_path
    report_drc -file $drc_report_path

    set setup_path [lindex [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1] 0]
    set hold_path [lindex [get_timing_paths -quiet -delay_type min -max_paths 1 -nworst 1] 0]
    set found_summary_header false
    set capture_summary_values false
    foreach summary_line [split $timing_summary_text "\n"] {
        if {[string first "WNS(ns)" $summary_line] >= 0 &&
            [string first "WPWS(ns)" $summary_line] >= 0} {
            set found_summary_header true
            continue
        }
        if {$found_summary_header} {
            set found_summary_header false
            set capture_summary_values true
            continue
        }
        if {$capture_summary_values} {
            set summary_values [regexp -all -inline {\S+} $summary_line]
            if {[llength $summary_values] >= 12} {
                set setup_wns_ns [lindex $summary_values 0]
                set setup_tns_ns [lindex $summary_values 1]
                set failing_setup_endpoints [lindex $summary_values 2]
                set hold_wns_ns [lindex $summary_values 4]
                set hold_tns_ns [lindex $summary_values 5]
                set failing_hold_endpoints [lindex $summary_values 6]
                set pulse_width_wns_ns [lindex $summary_values 8]
                set pulse_width_tns_ns [lindex $summary_values 9]
                set failing_pulse_width_endpoints [lindex $summary_values 10]
                break
            }
        }
    }
    if {$setup_wns_ns eq ""} { set setup_wns_ns [safe_property $setup_path SLACK] }
    if {$hold_wns_ns eq ""} { set hold_wns_ns [safe_property $hold_path SLACK] }
    set critical_data_delay_ns [safe_property $setup_path DATAPATH_DELAY]
    set critical_logic_delay_ns [safe_property $setup_path DATAPATH_LOGIC_DELAY]
    set critical_routing_delay_ns [safe_property $setup_path DATAPATH_NET_DELAY]
    set critical_logic_levels [safe_property $setup_path LOGIC_LEVELS]
    set critical_startpoint [safe_property $setup_path STARTPOINT_PIN]
    set critical_endpoint [safe_property $setup_path ENDPOINT_PIN]
    set critical_path_group [safe_property $setup_path PATH_GROUP]
    set critical_clock_uncertainty_ns [safe_property $setup_path UNCERTAINTY]
    set hold_startpoint [safe_property $hold_path STARTPOINT_PIN]
    set hold_endpoint [safe_property $hold_path ENDPOINT_PIN]
    set hold_path_group [safe_property $hold_path PATH_GROUP]
    set clock_name [safe_property $setup_path ENDPOINT_CLOCK]
    if {$critical_path_group eq ""} { set critical_path_group $clock_name }
    if {$hold_path_group eq ""} { set hold_path_group [safe_property $hold_path ENDPOINT_CLOCK] }

    set detail_file [::open [file join $OUTPUT_DIR timing critical_path_objects.txt] w]
    puts $detail_file "Startpoint: $critical_startpoint"
    puts $detail_file "Endpoint: $critical_endpoint"
    puts $detail_file "Path group: $critical_path_group"
    puts $detail_file "Clock: $clock_name"
    puts $detail_file "Setup slack (ns): $setup_wns_ns"
    puts $detail_file "Data path delay (ns): $critical_data_delay_ns"
    puts $detail_file "Logic delay (ns): $critical_logic_delay_ns"
    puts $detail_file "Routing delay (ns): $critical_routing_delay_ns"
    puts $detail_file "Clock uncertainty (ns): $critical_clock_uncertainty_ns"
    puts $detail_file "Logic levels: $critical_logic_levels"
    puts $detail_file ""
    puts $detail_file "Path pins, cells, placement and nets"
    foreach path_pin [get_pins -quiet -of_objects $setup_path] {
        set owner [get_cells -quiet -of_objects $path_pin]
        set path_net [get_nets -quiet -of_objects $path_pin]
        puts $detail_file [format "%s | cell=%s | ref=%s | loc=%s | bel=%s | net=%s" \
            $path_pin $owner [get_property -quiet REF_NAME $owner] \
            [get_property -quiet LOC $owner] [get_property -quiet BEL $owner] $path_net]
    }
    ::close $detail_file

    set util_text [report_utilization -return_string]
    report_utilization -file [file join $OUTPUT_DIR utilisation post_route_utilisation.rpt]
    set lut_fallback [llength [get_cells -quiet -hier -filter {REF_NAME =~ LUT*}]]
    set ff_fallback [llength [get_cells -quiet -hier -filter {REF_NAME =~ FD*}]]
    set lut_count [extract_utilisation $util_text "Slice LUTs" $lut_fallback]
    set ff_count [extract_utilisation $util_text "Slice Registers" $ff_fallback]
    set ramb18_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ RAMB18*}]]
    set ramb36_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ RAMB36*}]]
    set dsp_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ DSP48*}]]
    set bufg_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ BUFG*}]]
    set latch_count [llength [get_cells -quiet -hier -filter {REF_NAME =~ LDCE || REF_NAME =~ LDPE}]]

    write_checkpoint -force [file join $OUTPUT_DIR checkpoints post_route.dcp]
    if {[catch {write_bitstream -force [file join $OUTPUT_DIR bitstreams $BITSTREAM_NAME]} bitstream_error]} {
        set bitstream_status "failed: $bitstream_error"
    } else {
        set bitstream_status "passed"
    }
} flow_message flow_options]

if {$flow_rc != 0} { set flow_error $flow_message }

set header_fields {
    implementation_identifier frequency_mhz period_ns applied_period_ns run_id flow
    synthesis_directive opt_directive place_directive phys_opt_directive route_directive
    deterministic_repetition seed_applied vivado_version fpga_part top_module clock_name
    clock_count synthesis_success synthesis_wns_ns implementation_success placement_success
    routing_success wns_ns tns_ns failing_setup_endpoints worst_hold_slack_ns hold_tns_ns
    failing_hold_endpoints pulse_width_wns_ns pulse_width_tns_ns failing_pulse_width_endpoints critical_startpoint
    critical_endpoint critical_path_group critical_data_delay_ns critical_logic_delay_ns
    critical_routing_delay_ns critical_clock_uncertainty_ns logic_levels hold_startpoint
    hold_endpoint hold_path_group lut ff ramb18 ramb36 dsp48 bufg latches bitstream_status
    run_directory timing_report_path critical_path_report_path hold_path_report_path
    check_timing_report_path methodology_report_path clock_interaction_report_path
    drc_report_path flow_error
}
set value_fields [list \
    $IMPLEMENTATION_IDENTIFIER $TARGET_FREQUENCY_MHZ $TARGET_PERIOD_NS $applied_period_ns \
    $REPETITION_NUMBER default $SYNTHESIS_DIRECTIVE $OPT_DIRECTIVE $PLACE_DIRECTIVE \
    $PHYS_OPT_DIRECTIVE $ROUTE_DIRECTIVE true false $vivado_version $FPGA_PART $TOP_MODULE \
    $clock_name $clock_count $synthesis_success $synthesis_wns_ns $implementation_success \
    $placement_success $routing_success $setup_wns_ns $setup_tns_ns $failing_setup_endpoints \
    $hold_wns_ns $hold_tns_ns $failing_hold_endpoints $pulse_width_wns_ns \
    $pulse_width_tns_ns $failing_pulse_width_endpoints $critical_startpoint $critical_endpoint $critical_path_group \
    $critical_data_delay_ns $critical_logic_delay_ns $critical_routing_delay_ns \
    $critical_clock_uncertainty_ns $critical_logic_levels $hold_startpoint $hold_endpoint \
    $hold_path_group $lut_count $ff_count $ramb18_count $ramb36_count $dsp_count $bufg_count \
    $latch_count $bitstream_status $OUTPUT_DIR $timing_report_path $critical_path_report_path \
    $hold_path_report_path $check_timing_report_path $methodology_report_path \
    $clock_interaction_report_path $drc_report_path $flow_error]

set result_file [::open [file join $OUTPUT_DIR run_result.csv] w]
puts $result_file [join $header_fields ,]
set quoted_values {}
foreach value $value_fields { lappend quoted_values [csv_quote $value] }
puts $result_file [join $quoted_values ,]
::close $result_file

if {$flow_rc != 0} {
    puts stderr "DOT4ACC_STAGE_G_RUN_FAILED: $flow_error"
    exit 1
}

puts "DOT4ACC_STAGE_G_RUN_COMPLETED: id=$IMPLEMENTATION_IDENTIFIER"
exit 0
