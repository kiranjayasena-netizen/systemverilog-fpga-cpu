# Phase 17E high-frequency MMCM MIPS-display implementation for the
# original Phase 13 forward-timing CPU.
#
# Run from the repository root:
#   vivado -mode batch -source scripts/run_vivado_impl_pipeline_forwardtiming_mmcm_mips.tcl
#
# Generated reports, checkpoints and bitstreams are written under
# reports/phase17e_mmcm_mips_impl/ and should not be committed wholesale.

set FPGA_PART "xc7a35tcpg236-1"
set TOP_MODULE "fpga_top_pipeline_forwardtiming_mmcm_mips"
set INPUT_PERIOD "10.000"
set REPORT_ROOT "reports/phase17e_mmcm_mips_impl"

file mkdir $REPORT_ROOT
file mkdir $REPORT_ROOT/constraints
file mkdir $REPORT_ROOT/utilisation
file mkdir $REPORT_ROOT/timing
file mkdir $REPORT_ROOT/power
file mkdir $REPORT_ROOT/route
file mkdir $REPORT_ROOT/checkpoints
file mkdir $REPORT_ROOT/bitstreams

puts "Phase 17E MMCM high-frequency MIPS implementation"
puts "  Top:          $TOP_MODULE"
puts "  Input period: $INPUT_PERIOD ns"
puts "  CPU clock:    115.000 MHz from RTL-instantiated MMCM"
puts "  Reports:      $REPORT_ROOT"

read_verilog -sv rtl/cpu_defs_pkg.sv
read_verilog -sv rtl/bram_instr_mem.sv
read_verilog -sv rtl/bram_data_mem.sv
read_verilog -sv rtl/cpu_core_pipeline_forwardtiming.sv
read_verilog -sv rtl/fpga_top_pipeline_forwardtiming_mmcm_mips.sv

set mmcm_xdc "$REPORT_ROOT/constraints/forwardtiming_mmcm_mips_basys3.xdc"
set xdc [open $mmcm_xdc "w"]
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

read_xdc $mmcm_xdc

synth_design -top $TOP_MODULE -part $FPGA_PART -directive PerformanceOptimized
opt_design -directive Explore
place_design -directive ExtraNetDelay_high
phys_opt_design -directive AggressiveFanoutOpt
route_design -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore

report_clocks -file $REPORT_ROOT/timing/fpga_top_pipeline_forwardtiming_mmcm_mips_clocks.rpt
report_utilization -file $REPORT_ROOT/utilisation/fpga_top_pipeline_forwardtiming_mmcm_mips_impl_utilization.rpt
report_timing_summary -file $REPORT_ROOT/timing/fpga_top_pipeline_forwardtiming_mmcm_mips_impl_timing_summary.rpt
report_timing -max_paths 10 -path_type full -file $REPORT_ROOT/timing/fpga_top_pipeline_forwardtiming_mmcm_mips_impl_worst_paths.rpt
report_route_status -file $REPORT_ROOT/route/fpga_top_pipeline_forwardtiming_mmcm_mips_route_status.rpt
report_power -file $REPORT_ROOT/power/fpga_top_pipeline_forwardtiming_mmcm_mips_impl_power.rpt

write_checkpoint -force $REPORT_ROOT/checkpoints/fpga_top_pipeline_forwardtiming_mmcm_mips_impl.dcp
write_bitstream -force $REPORT_ROOT/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit

set timing_summary [report_timing_summary -return_string]
puts "Phase 17E timing summary excerpt:"
foreach line [split $timing_summary "\n"] {
    if {[regexp {WNS|TNS|WHS|THS} $line]} {
        puts $line
    }
}

puts "Phase 17E bitstream path: $REPORT_ROOT/bitstreams/fpga_top_pipeline_forwardtiming_mmcm_mips.bit"
