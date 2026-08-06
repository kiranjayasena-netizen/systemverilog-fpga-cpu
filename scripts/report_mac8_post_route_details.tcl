# Read-only post-route inspection for the Phase 12 MAC8 implementation.
#
# Usage:
#   vivado -mode batch -source scripts/report_mac8_post_route_details.tcl \
#       -tclargs <post_route.dcp> <output_directory>

if {$argc != 2} {
    error "Expected 2 arguments: post_route_checkpoint output_directory"
}

set CHECKPOINT [file normalize [lindex $argv 0]]
set OUTPUT_DIR [file normalize [lindex $argv 1]]
file mkdir $OUTPUT_DIR

open_checkpoint $CHECKPOINT

report_timing -delay_type max -path_type full_clock_expanded -input_pins -nets \
    -max_paths 25 -nworst 1 -file [file join $OUTPUT_DIR top_25_setup_paths.rpt]

set detail [open [file join $OUTPUT_DIR critical_path_objects.txt] w]
set setup_path [lindex [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]
puts $detail "Critical path"
foreach property_name {
    SLACK STARTPOINT_PIN ENDPOINT_PIN ENDPOINT_CLOCK DATAPATH_DELAY
    DATAPATH_LOGIC_DELAY DATAPATH_NET_DELAY LOGIC_LEVELS
} {
    puts $detail "$property_name: [get_property $property_name $setup_path]"
}

puts $detail ""
puts $detail "Path pins, cells, placement and nets"
foreach path_pin [get_pins -quiet -of_objects $setup_path] {
    set owner [get_cells -quiet -of_objects $path_pin]
    set path_net [get_nets -quiet -of_objects $path_pin]
    puts $detail [format "%s | cell=%s | ref=%s | loc=%s | bel=%s | net=%s" \
        $path_pin $owner [get_property -quiet REF_NAME $owner] \
        [get_property -quiet LOC $owner] [get_property -quiet BEL $owner] $path_net]
}

puts $detail ""
puts $detail "Path nets and flat pin counts"
foreach path_net [get_nets -quiet -of_objects $setup_path] {
    puts $detail [format "%s | flat_pin_count=%s | route_status=%s" \
        $path_net [get_property -quiet FLAT_PIN_COUNT $path_net] \
        [get_property -quiet ROUTE_STATUS $path_net]]
}
close $detail

set dsp_cells [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}]
set dsp_summary [open [file join $OUTPUT_DIR dsp48e1_summary.txt] w]
puts $dsp_summary "DSP48E1 count: [llength $dsp_cells]"
foreach dsp_cell $dsp_cells {
    puts $dsp_summary ""
    puts $dsp_summary "Cell: $dsp_cell"
    puts $dsp_summary "LOC: [get_property -quiet LOC $dsp_cell]"
    puts $dsp_summary "BEL: [get_property -quiet BEL $dsp_cell]"
    foreach property_name {
        AREG ACASCREG BREG BCASCREG CREG DREG ADREG MREG PREG
        ALUMODEREG CARRYINREG CARRYINSELREG INMODEREG OPMODEREG
        USE_DPORT USE_MULT USE_SIMD
    } {
        puts $dsp_summary "$property_name: [get_property -quiet $property_name $dsp_cell]"
    }
    puts $dsp_summary "Input pins and nets:"
    foreach dsp_pin [get_pins -quiet -of_objects $dsp_cell -filter {DIRECTION == IN}] {
        set dsp_net [get_nets -quiet -of_objects $dsp_pin]
        puts $dsp_summary [format "  %s | net=%s | flat_pin_count=%s" \
            $dsp_pin $dsp_net [get_property -quiet FLAT_PIN_COUNT $dsp_net]]
    }
    puts $dsp_summary "Output pins and nets:"
    foreach dsp_pin [get_pins -quiet -of_objects $dsp_cell -filter {DIRECTION == OUT}] {
        set dsp_net [get_nets -quiet -of_objects $dsp_pin]
        puts $dsp_summary [format "  %s | net=%s | flat_pin_count=%s" \
            $dsp_pin $dsp_net [get_property -quiet FLAT_PIN_COUNT $dsp_net]]
    }
}
close $dsp_summary

set dsp_properties [open [file join $OUTPUT_DIR dsp48e1_properties.txt] w]
foreach dsp_cell $dsp_cells {
    puts $dsp_properties "Cell: $dsp_cell"
    foreach property_name [lsort [list_property $dsp_cell]] {
        puts $dsp_properties "$property_name: [get_property $property_name $dsp_cell]"
    }
}
close $dsp_properties

if {[llength $dsp_cells] > 0} {
    set dsp_pins [get_pins -quiet -of_objects $dsp_cells]
    catch {
        report_timing -delay_type max -path_type full_clock_expanded -input_pins -nets \
            -through $dsp_pins -max_paths 20 -nworst 1 \
            -file [file join $OUTPUT_DIR dsp48e1_setup_paths.rpt]
    } dsp_timing_error
    if {$dsp_timing_error ne ""} {
        set dsp_error_file [open [file join $OUTPUT_DIR dsp48e1_timing_error.txt] w]
        puts $dsp_error_file $dsp_timing_error
        close $dsp_error_file
    }
}

if {[catch {
    report_high_fanout_nets -fanout_greater_than 16 -max_nets 200 \
        -file [file join $OUTPUT_DIR high_fanout_nets.rpt]
} fanout_error]} {
    set fanout_error_file [open [file join $OUTPUT_DIR high_fanout_error.txt] w]
    puts $fanout_error_file $fanout_error
    close $fanout_error_file
}

set selected_nets [open [file join $OUTPUT_DIR selected_datapath_nets.txt] w]
foreach pattern {
    *wb_write_data* *ex_operand_a* *ex_operand_b* *ex_accumulator*
    *ex_mac* *ex_branch_taken* *redirect_taken* *fetch_buffer_instruction*
} {
    puts $selected_nets "Pattern: $pattern"
    foreach selected_net [get_nets -quiet -hier $pattern] {
        puts $selected_nets [format "  %s | flat_pin_count=%s | driver=%s" \
            $selected_net [get_property -quiet FLAT_PIN_COUNT $selected_net] \
            [get_pins -quiet -leaf -of_objects $selected_net -filter {DIRECTION == OUT}]]
    }
}
close $selected_nets

close_design
