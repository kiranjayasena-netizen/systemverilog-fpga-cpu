# GPU benchmark results

At validated 80 MHz on Stage 14: REG_VADD = 4 cycles, ARRAY_ADD = 20
cycles (64.000 MAdds/s), XOR = 13 cycles (98.462 Melems/s), and VSRA = 13
cycles (98.462 Melems/s). Post-route core resources are 3277 LUT, 3209
logic LUT, 68 LUTRAM, 1522 FF, two RAMB36, zero RAMB18 and zero DSP.

The production UART path was exercised on Basys 3: ARRAY_ADD, XOR, VSRA,
and REG_VADD demo launches completed successfully, with 100/100 launches
passing in the repeated stability campaign. Core cycle counts remain the
simulation values; UART transaction time is not used as throughput.
