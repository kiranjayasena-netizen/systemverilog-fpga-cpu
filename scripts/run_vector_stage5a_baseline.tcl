# Stage 5A standalone vector-program-core synthesis/implementation baseline.
# Run from repository root with:
#   vivado.bat -mode batch -source scripts/run_vector_stage5a_baseline.tcl

set PART xc7a35tcpg236-1
set TOP vector_program_core_synth_top
set OUT_DIR reports/vector_stage5a
file mkdir $OUT_DIR

read_verilog -sv rtl/vector_register_file.sv
read_verilog -sv rtl/vector_alu.sv
read_verilog -sv rtl/vector_execution_unit.sv
read_verilog -sv rtl/vector_instruction_decoder.sv
read_verilog -sv rtl/vector_instruction_execution_unit.sv
read_verilog -sv rtl/vector_instruction_memory.sv
read_verilog -sv rtl/vector_program_core.sv
read_verilog -sv rtl/vector_program_core_synth_top.sv
read_xdc constraints/vector_program_core_stage5a.xdc

synth_design -top $TOP -part $PART
report_utilization -hierarchical -file $OUT_DIR/stage5a_synth_utilization.rpt
report_timing_summary -file $OUT_DIR/stage5a_synth_timing_summary.rpt

opt_design
place_design
route_design

report_utilization -hierarchical -file $OUT_DIR/stage5a_impl_utilization.rpt
report_timing_summary -file $OUT_DIR/stage5a_impl_timing_summary.rpt
report_timing -max_paths 20 -path_type full -file $OUT_DIR/stage5a_worst_paths.rpt
report_clock_utilization -file $OUT_DIR/stage5a_clock_utilization.rpt
report_drc -file $OUT_DIR/stage5a_drc.rpt
report_methodology -file $OUT_DIR/stage5a_methodology.rpt

write_checkpoint -force $OUT_DIR/stage5a_impl.dcp
puts "STAGE5A_BASELINE_COMPLETE"
