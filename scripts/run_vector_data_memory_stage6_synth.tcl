set PART xc7a35tcpg236-1
set OUT_DIR reports/vector_stage6
file mkdir $OUT_DIR
read_verilog -sv rtl/vector_data_memory.sv
read_verilog -sv rtl/vector_data_memory_synth_top.sv
read_xdc constraints/vector_data_memory_stage6.xdc
synth_design -top vector_data_memory_synth_top -part $PART
report_utilization -hierarchical -file $OUT_DIR/stage6_synth_utilization.rpt
report_ram_utilization -file $OUT_DIR/stage6_ram_utilization.rpt
report_timing_summary -file $OUT_DIR/stage6_synth_timing_summary.rpt
puts "STAGE6_SYNTHESIS_COMPLETE"
