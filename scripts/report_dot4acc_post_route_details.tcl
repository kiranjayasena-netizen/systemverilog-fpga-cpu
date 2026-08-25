# Read-only detailed inspection of one routed Stage F checkpoint.
# Usage: vivado -mode batch -source scripts/report_dot4acc_post_route_details.tcl \
#          -tclargs <post_route.dcp> <output_directory> <frequency_label>

if {$argc != 3} {
    error "Expected: post_route_checkpoint output_directory frequency_label"
}

set CHECKPOINT [file normalize [lindex $argv 0]]
set OUTPUT_DIR [file normalize [lindex $argv 1]]
set FREQUENCY_LABEL [lindex $argv 2]
file mkdir $OUTPUT_DIR

open_checkpoint $CHECKPOINT
update_timing

proc safe_property {object property_name} {
    if {$object eq ""} { return "" }
    if {[catch {get_property $property_name $object} value]} { return "" }
    return $value
}

proc write_path_detail {path output_path title} {
    set output [open $output_path w]
    puts $output $title
    foreach property_name {
        SLACK STARTPOINT_PIN ENDPOINT_PIN ENDPOINT_CLOCK DATAPATH_DELAY
        DATAPATH_LOGIC_DELAY DATAPATH_NET_DELAY LOGIC_LEVELS UNCERTAINTY
    } {
        puts $output "$property_name: [safe_property $path $property_name]"
    }
    puts $output ""
    puts $output "Path pins, cells, placement and nets"
    foreach path_pin [get_pins -quiet -of_objects $path] {
        set owner [get_cells -quiet -of_objects $path_pin]
        set path_net [get_nets -quiet -of_objects $path_pin]
        puts $output [format "%s | cell=%s | ref=%s | loc=%s | bel=%s | net=%s" \
            $path_pin $owner [get_property -quiet REF_NAME $owner] \
            [get_property -quiet LOC $owner] [get_property -quiet BEL $owner] $path_net]
    }
    close $output
}

set setup_path [lindex [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1] 0]
set hold_path [lindex [get_timing_paths -quiet -delay_type min -max_paths 1 -nworst 1] 0]
write_path_detail $setup_path [file join $OUTPUT_DIR worst_setup_objects.txt] \
    "$FREQUENCY_LABEL worst routed setup path"
write_path_detail $hold_path [file join $OUTPUT_DIR worst_hold_objects.txt] \
    "$FREQUENCY_LABEL worst routed hold path"

report_timing -delay_type max -path_type full_clock_expanded -input_pins \
    -max_paths 25 -nworst 1 -file [file join $OUTPUT_DIR top_25_setup_paths.rpt]
report_timing -delay_type min -path_type full_clock_expanded -input_pins \
    -max_paths 10 -nworst 1 -file [file join $OUTPUT_DIR top_10_hold_paths.rpt]

set dsp_cells [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}]
set dsp_output [open [file join $OUTPUT_DIR dsp48e1_summary.txt] w]
puts $dsp_output "DSP48E1 count: [llength $dsp_cells]"
foreach dsp_cell $dsp_cells {
    puts $dsp_output ""
    puts $dsp_output "Cell: $dsp_cell"
    puts $dsp_output "LOC: [get_property -quiet LOC $dsp_cell]"
    puts $dsp_output "BEL: [get_property -quiet BEL $dsp_cell]"
    foreach property_name {
        AREG ACASCREG BREG BCASCREG CREG DREG ADREG MREG PREG
        ALUMODEREG CARRYINREG CARRYINSELREG INMODEREG OPMODEREG
        USE_DPORT USE_MULT USE_SIMD
    } {
        puts $dsp_output "$property_name: [get_property -quiet $property_name $dsp_cell]"
    }
}
close $dsp_output

set dot_dsp_cells [get_cells -quiet -hier -filter \
    {REF_NAME == DSP48E1 && NAME =~ *dot4acc_pipeline_inst*}]
set mac_dsp_cells {}
foreach dsp_cell $dsp_cells {
    if {[lsearch -exact $dot_dsp_cells $dsp_cell] < 0} { lappend mac_dsp_cells $dsp_cell }
}

set dsp_path_summary [open [file join $OUTPUT_DIR dsp_timing_summary.txt] w]
puts $dsp_path_summary "DOT DSP count: [llength $dot_dsp_cells]"
puts $dsp_path_summary "Non-DOT/MAC8 DSP count: [llength $mac_dsp_cells]"
foreach label {DOT MAC8} cells [list $dot_dsp_cells $mac_dsp_cells] {
    set pins [get_pins -quiet -of_objects $cells]
    set paths [get_timing_paths -quiet -delay_type max -through $pins -max_paths 5 -nworst 1]
    puts $dsp_path_summary ""
    puts $dsp_path_summary "$label paths found: [llength $paths]"
    set index 0
    foreach timing_path $paths {
        incr index
        puts $dsp_path_summary [format \
            "%s path %d: slack=%s start=%s end=%s delay=%s logic=%s route=%s levels=%s" \
            $label $index [safe_property $timing_path SLACK] \
            [safe_property $timing_path STARTPOINT_PIN] [safe_property $timing_path ENDPOINT_PIN] \
            [safe_property $timing_path DATAPATH_DELAY] [safe_property $timing_path DATAPATH_LOGIC_DELAY] \
            [safe_property $timing_path DATAPATH_NET_DELAY] [safe_property $timing_path LOGIC_LEVELS]]
    }
}
close $dsp_path_summary

set selected_output [open [file join $OUTPUT_DIR selected_control_nets.txt] w]
foreach pattern {
    *dot_issue* *dot_complete* *dot_chain* *dot_wb* *rf_write*
    *wb_write_data* *ex_operand* *ex_branch* *redirect* *frontend_hold*
} {
    puts $selected_output "Pattern: $pattern"
    foreach selected_net [get_nets -quiet -hier $pattern] {
        puts $selected_output [format "  %s | flat_pin_count=%s | driver=%s" \
            $selected_net [get_property -quiet FLAT_PIN_COUNT $selected_net] \
            [get_pins -quiet -leaf -of_objects $selected_net -filter {DIRECTION == OUT}]]
    }
}
close $selected_output

report_high_fanout_nets -fanout_greater_than 16 -max_nets 100 \
    -file [file join $OUTPUT_DIR high_fanout_nets.rpt]

close_design
exit 0
