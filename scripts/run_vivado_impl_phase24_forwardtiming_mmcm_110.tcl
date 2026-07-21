set PHASE19_LABEL "Phase 24 frontend-split copy 110.000 MHz"
set TOP_MODULE "fpga_top_phase24_forwardtiming_mmcm_110"
set REPORT_ROOT "reports/phase24_forwardtiming_mmcm_impl/110"
set PHASE19_SOURCES {
    rtl/cpu_defs_pkg.sv
    rtl/bram_instr_mem.sv
    rtl/bram_data_mem.sv
    rtl/cpu_core_pipeline_forwardtiming_phase24.sv
    rtl/fpga_top_phase24_forwardtiming_mmcm_benchmark.sv
    rtl/fpga_top_phase24_forwardtiming_mmcm_targets.sv
}
source scripts/run_vivado_impl_phase19_mmcm_common.tcl
