set bitstream [file normalize [file join [pwd] .final_gpu_bitstream final_gpu_bitstream.runs impl_1 basys3_vector_gpu_top.bit]]
if {![file exists $bitstream]} { error "Bitstream not found: $bitstream" }
open_hw_manager
connect_hw_server
open_hw_target
set devices [get_hw_devices]
if {[llength $devices] == 0} { error "No FPGA hardware device detected" }
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device $device
puts "FINAL_GPU_BASYS3_PROGRAMMED"
