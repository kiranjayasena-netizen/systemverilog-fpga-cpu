set PHASE19_LABEL "Phase 21 Phase 20E extension original forward-timing 119.500 MHz"
set TOP_MODULE "fpga_top_phase21_phase20e_119p5"
set REPORT_ROOT "reports/phase21_phase20e_frequency_extension_impl/119p5"
set PHASE19_SOURCES {
    rtl/cpu_defs_pkg.sv
    rtl/bram_instr_mem.sv
    rtl/bram_data_mem.sv
    rtl/cpu_core_pipeline_forwardtiming.sv
    rtl/fpga_top_phase19a_forwardtiming_mmcm_mips.sv
    rtl/fpga_top_phase21_phase20e_frequency_targets.sv
}
source scripts/run_vivado_impl_phase19_mmcm_common.tcl
