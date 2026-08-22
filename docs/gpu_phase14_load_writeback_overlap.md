# Stage 14 — Dependency-aware VLOAD miss writeback overlap

Stage 13 showed that the frozen Stage 12 ARRAY_ADD schedule is exactly 21 cycles: four ALU cycles, three hit loads, five miss issue cycles, five miss writeback cycles, and four stores. There are no idle or control bubbles. The feasibility study therefore examined the five miss/writeback pairs against the one-whole-vector-write register-file port.

Four misses are immediately followed by dependent ALU operations and cannot be advanced without stale data or forwarding: PC1 VLOAD V2,[8]→PC2 VADD, then the analogous PC5, PC9 and PC13 pairs. The first miss, PC0 VLOAD V1,[0], is followed by an independent VLOAD V2,[8]. Its read can be issued while PC0 writes V1, with no second vector-register write and no architectural reordering. The safe theoretical saving is therefore one cycle.

Stage 14 is an independent derivative, `rtl/vector_load_overlap_program_core.sv`. It keeps Stage 12's two entries, depth-6 lookahead, two outstanding reads, fixed one-cycle memory response, duplicate/store/stale protections, and one physical read per cycle. During a load writeback, it may issue the next independent architectural VLOAD read and advance to that load's writeback state. It never performs two RF writes in one cycle; `rf_double_write_attempt_count` remained zero.

Verification completed under Vivado 2026.1 XSim:

- Stage 14 functional: 50/50 PASS (46 inherited safety tests plus four overlap/RF/completion checks).
- Stage 12 ↔ Stage 14 architectural equivalence: 10/10 PASS.
- Frozen regressions: Stage 12 46/46, Stage 11 depth-6 32/32, Stage 10B 20/20, Stage 10A 26/26.

Unchanged benchmarks measured 4/20/13/13 cycles for REG_VADD/ARRAY_ADD/XOR/VSRA. ARRAY_ADD therefore improves by one cycle (21→20), 4.762%, and reaches 64.000 MAdds/s at validated 80 MHz. Counters show one successful load-writeback overlap and one saved cycle; ALU-origin useful prefetching remains active (3 overlaps, 3 hits). The cycle accounting is 20 = 4 ALU + 3 hit loads + 4 miss-issue cycles + 5 writeback-state cycles + 4 stores. The overlap removes one schedule cycle even though the writeback state remains visible for other misses.

Physical characterization also completed. Post-route resources are 3277 LUT (3209 logic LUT, 68 LUTRAM), 1522 FF, 2 RAMB36, 0 RAMB18 and 0 DSP. At 80 MHz setup WNS is +0.221 ns and hold WHS +0.185 ns, with zero failing endpoints. The worst setup path remains the PC/instruction/lookahead to vector-register-file family: `core/current_pc_reg[1]/C` to `core/eu/vector_register_file_inst/regs_reg[3][69]/D`, 12.131 ns total (2.038 ns logic, 10.093 ns routing, 83.2% routing, 9 logic levels).

Compared with Stage 12 (3247 LUT, 1522 FF, +0.348 ns setup WNS), Stage 14 adds 30 LUT (0.92%), no FF, and loses 0.127 ns setup slack while retaining 2 BRAM and 0 DSP. Array efficiency is 64/3.277 = 19.53 MAdds/s per 1000 LUT versus Stage 12's 18.77.

**Verdict:** Stage 14 is a true, bounded performance success. It hides the one feasible independent miss/writeback opportunity without a second RF write port, improves ARRAY_ADD to 20 cycles, preserves all frozen architectural regressions, and closes 80 MHz. The remaining four miss writebacks are dependency-blocked by the single-write-port/in-order model. The next experiment should be considered only after freezing this result; a forwarding or RF-write-buffer study would be a materially broader change.
