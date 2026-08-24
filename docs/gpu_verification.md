# GPU verification

Verified regressions include Stage 10A 26/26, Stage 10B 20/20, Stage 11
depth-6 32/32, Stage 12 46/46, Stage 14 50/50, Stage 12↔Stage 14
equivalence 10/10, and accelerator-wrapper simulation PASS. Stage 14
unchanged benchmarks are 4/20/13/13 cycles for REG_VADD/ARRAY_ADD/XOR/VSRA.
Stage 26A PING and STATUS were physically verified on COM4. Stage 26B
verified READ_MEMORY/WRITE_MEMORY round trips at addresses 0, 1, 15, and
31, adjacent-address isolation, and 100 repeated UART-driven launches.

Stage 26 hardware validation is therefore `READY FOR LOCAL HARDWARE
The exact bitstream path and measured results are recorded in
`reports/final_gpu/stage26_hardware_validation.txt`.
