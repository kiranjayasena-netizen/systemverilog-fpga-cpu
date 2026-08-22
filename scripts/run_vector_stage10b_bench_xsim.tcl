set proj [file normalize .stage10b_bench_xsim]
file delete -force $proj
create_project -force stage10b_bench_xsim $proj -part xc7a35tcpg236-1
set src [list rtl/vector_register_file.sv rtl/vector_alu.sv rtl/vector_execution_unit.sv rtl/vector_instruction_memory.sv rtl/vector_memory_instruction_decoder.sv rtl/vector_data_memory.sv rtl/vector_alu_prefetch_program_core.sv]
add_files -norecurse [lmap f $src {file normalize $f}]
add_files -fileset sim_1 -norecurse [file normalize tb/vector_stage10b_benchmark_tb.sv]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top vector_stage10b_benchmark_tb [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
puts "STAGE10B_BENCH_XSIM_COMPLETE"
