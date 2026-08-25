set root [file normalize .]
create_project final_gpu_bitstream .final_gpu_bitstream -part xc7a35tcpg236-1 -force
add_files -norecurse [glob -nocomplain [file join $root rtl *.sv]]
add_files -fileset constrs_1 -norecurse [file join $root constraints basys3_vector_gpu.xdc]
set_property top basys3_vector_gpu_top [get_filesets sources_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "FINAL_GPU_BITSTREAM_COMPLETE"
