# Phase 2 MAC8 Vivado Result

Vivado 2026.1 synthesized and implemented `fpga_top_pipeline` for the Basys 3
`xc7a35tcpg236-1`, with `programs/ai_dot_product_mac.mem` as the instruction
image.

Commands:

```powershell
vivado -mode batch -source scripts/run_vivado_synth_pipeline_mac.tcl
vivado -mode batch -source scripts/run_vivado_impl_pipeline_mac.tcl
```

Post-route result:

| Metric | Value |
| --- | ---: |
| LUTs | 1,454 / 20,800 (6.99%) |
| FFs | 1,507 / 41,600 (3.62%) |
| BRAM tiles | 1 / 50 (2.00%) |
| DSPs | 1 / 90 (1.11%) |
| WNS | +0.031 ns |
| TNS | 0.000 ns |
| WHS | +0.040 ns |
| THS | 0.000 ns |
| Vectorless power estimate | 0.091 W |
| Route status | Fully routed, 0 routing errors |
| Bitstream generation | Passed |

The DSP inference report identified one DSP48E1 mapped as `C + A*B`. The
worst setup path was from data BRAM through writeback/frontend control to a
fetch-buffer instruction reset input, not through the DSP. Generated reports,
checkpoints and bitstreams remain local and should not be committed.
