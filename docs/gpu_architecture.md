# GPU architecture

The selected production core is Stage 14: four 32-bit SIMD lanes packed in
128-bit vectors, eight vector registers, a 16-bit instruction store, and a
32×128-bit synchronous vector data memory. The core is in-order and retains
two prefetch entries, two outstanding reads, one physical read issue per
cycle, and the Stage 14 independent VLOAD writeback/read overlap.

```text
Host / UART
     │ programming + start/status
     ▼
Accelerator wrapper
     │
     ├── instruction memory (16-bit)
     ├── decoder / in-order control
     ├── vector RF (8 × 128-bit, one write path)
     ├── four-lane vector ALU
     ├── two-entry prefetch / read scheduler
     └── vector data memory (32 × 128-bit, 2 RAMB36)
```
