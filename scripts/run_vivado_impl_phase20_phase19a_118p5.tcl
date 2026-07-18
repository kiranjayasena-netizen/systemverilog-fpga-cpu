set PHASE19_LABEL "Phase 20 Phase 19A extension original forward-timing 118.500 MHz"
set TOP_MODULE "fpga_top_phase20_phase19a_118p5"
set REPORT_ROOT "reports/phase20_phase19a_frequency_extension_impl/118p5"
set PHASE19_SOURCES {
    rtl/cpu_defs_pkg.sv
    rtl/bram_instr_mem.sv
    rtl/bram_data_mem.sv
    rtl/cpu_core_pipeline_forwardtiming.sv
    rtl/fpga_top_phase19a_forwardtiming_mmcm_mips.sv
    rtl/fpga_top_phase20_phase19a_frequency_targets.sv
}
source scripts/run_vivado_impl_phase19_mmcm_common.tcl
