# Shared Phase 19 MMCM implementation flow.
#
# Caller scripts must define:
#   PHASE19_LABEL
#   TOP_MODULE
#   REPORT_ROOT
#   PHASE19_SOURCES

if {![info exists PHASE19_LABEL]} {
    error "PHASE19_LABEL is not set"
}
if {![info exists TOP_MODULE]} {
    error "TOP_MODULE is not set"
}
if {![info exists REPORT_ROOT]} {
    error "REPORT_ROOT is not set"
}
if {![info exists PHASE19_SOURCES]} {
    error "PHASE19_SOURCES is not set"
}

set FPGA_PART "xc7a35tcpg236-1"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/constraints
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/route
file mkdir $REPORT_ROOT/checkpoints
file mkdir $REPORT_ROOT/bitstreams

puts "Phase 19 MMCM implementation"
puts "  Label:   $PHASE19_LABEL"
puts "  Top:     $TOP_MODULE"
puts "  Reports: $REPORT_ROOT"

foreach src $PHASE19_SOURCES {
    read_verilog -sv $src
}

set phase19_xdc "$REPORT_ROOT/constraints/phase19_basys3.xdc"
set xdc [open $phase19_xdc "w"]
puts $xdc {set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]}
puts $xdc {create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports clk]}
puts $xdc {set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst_btn]}
puts $xdc {set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]}
puts $xdc {set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V3 IOSTANDARD LVCMOS33 } [get_ports {led[9]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS33 } [get_ports {led[10]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports {led[11]}]}
puts $xdc {set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports {led[12]}]}
puts $xdc {set_property -dict { PACKAGE_PIN N3 IOSTANDARD LVCMOS33 } [get_ports {led[13]}]}
puts $xdc {set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports {led[14]}]}
puts $xdc {set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {led[15]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports dp]}
puts $xdc {set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {an[0]}]}
puts $xdc {set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {an[1]}]}
puts $xdc {set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {an[2]}]}
puts $xdc {set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {an[3]}]}
close $xdc

read_xdc $phase19_xdc

synth_design -top $TOP_MODULE -part $FPGA_PART -directive PerformanceOptimized
opt_design -directive Explore
place_design -directive ExtraNetDelay_high
phys_opt_design -directive AggressiveFanoutOpt
route_design -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore

report_clocks -file $REPORT_ROOT/timing/${TOP_MODULE}_clocks.rpt
report_utilization -file $REPORT_ROOT/utilisation/${TOP_MODULE}_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/${TOP_MODULE}_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/${TOP_MODULE}_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/${TOP_MODULE}_route_status.rpt
report_power -file $REPORT_ROOT/power/${TOP_MODULE}_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/${TOP_MODULE}_impl.dcp

set setup_fails [llength [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 1]]
set hold_fails  [llength [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 1]]

if {($setup_fails == 0) && ($hold_fails == 0)} {
    write_bitstream -force $REPORT_ROOT/bitstreams/${TOP_MODULE}.bit
    puts "Phase 19 bitstream path: $REPORT_ROOT/bitstreams/${TOP_MODULE}.bit"
} else {
    puts "Phase 19 timing failed; bitstream generation skipped."
}

set timing_summary [report_timing_summary -return_string]
puts "Phase 19 timing summary excerpt:"
foreach line [split $timing_summary "\n"] {
    if {[regexp {WNS|TNS|WHS|THS} $line]} {
        puts $line
    }
}
