set PHASE19_LABEL "Phase 19B pipeline6 150.000 MHz"
set TOP_MODULE "fpga_top_phase19b_pipeline6_mmcm_150"
set REPORT_ROOT "reports/phase19b_pipeline6_mmcm_impl/150"
set PHASE19_SOURCES {
    rtl/cpu_defs_pkg.sv
    rtl/bram_instr_mem.sv
    rtl/bram_data_mem.sv
    rtl/cpu_core_pipeline6.sv
    rtl/fpga_top_phase19b_pipeline6_mmcm_mips.sv
}
source scripts/run_vivado_impl_phase19_mmcm_common.tcl
