# Vivado/XSim functional flow for Stage 10B-A.
# Invoke from repository root with:
# vivado -mode batch -source scripts/run_vector_stage10b_xsim.tcl

set src_dir  [file normalize rtl]
set tb_dir   [file normalize tb]
set work_dir [file normalize .stage10b_xsim]

file delete -force $work_dir
file mkdir $work_dir

# launch_simulation requires a saved/disk-backed project.
create_project stage10b_xsim $work_dir \
    -part xc7a35tcpg236-1 \
    -force

set sources {}

foreach f {
    vector_register_file.sv
    vector_alu.sv
    vector_execution_unit.sv
    vector_instruction_memory.sv
    vector_memory_instruction_decoder.sv
    vector_data_memory.sv
    vector_alu_prefetch_program_core.sv
} {
    lappend sources [file join $src_dir $f]
}

add_files -norecurse $sources

add_files -fileset sim_1 -norecurse \
    [file join $tb_dir vector_alu_prefetch_program_core_tb.sv]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top vector_alu_prefetch_program_core_tb \
    [get_filesets sim_1]

set_property simulator_language Mixed [current_project]

launch_simulation -simset sim_1 -mode behavioral

run all

close_sim
close_project

puts "STAGE10B_XSIM_COMPLETE"