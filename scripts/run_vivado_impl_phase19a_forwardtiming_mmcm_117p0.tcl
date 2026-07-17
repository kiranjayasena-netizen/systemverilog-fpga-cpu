set PHASE19_LABEL "Phase 19A forward-timing 117.000 MHz"
set TOP_MODULE "fpga_top_phase19a_forwardtiming_mmcm_117p0"
set REPORT_ROOT "reports/phase19a_frequency_sweep_impl/117p0"
set PHASE19_SOURCES {
    rtl/cpu_defs_pkg.sv
    rtl/bram_instr_mem.sv
    rtl/bram_data_mem.sv
    rtl/cpu_core_pipeline_forwardtiming.sv
    rtl/fpga_top_phase19a_forwardtiming_mmcm_mips.sv
    rtl/fpga_top_phase19a_forwardtiming_mmcm_targets.sv
}
source scripts/run_vivado_impl_phase19_mmcm_common.tcl
