# GPU verification

Verified regressions include Stage 10A 26/26, Stage 10B 20/20, Stage 11
depth-6 32/32, Stage 12 46/46, Stage 14 50/50, Stage 12↔Stage 14
equivalence 10/10, and accelerator-wrapper simulation PASS. Stage 14
unchanged benchmarks are 4/20/13/13 cycles for REG_VADD/ARRAY_ADD/XOR/VSRA.
No physical board test has been run in this environment.

Stage 26 hardware validation is therefore `READY FOR LOCAL HARDWARE
VALIDATION`, not PASS. The exact bitstream path and procedure are recorded
in `reports/final_gpu/stage26_hardware_validation.txt`.
