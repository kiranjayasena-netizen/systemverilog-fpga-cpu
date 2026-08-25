# CPU validation interface matrix

The canonical baseline (`cpu_core_pipeline_timingopt`) and DOT4ACC core
(`cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`) keep instruction and
data memories internal.  Both use synchronous instruction/data BRAM models;
the data read is registered and writes occur on the active CPU clock.

The validation derivatives add only a load-mode mux at those existing memory
boundaries.  In `validation_load_mode`, the host may write/read memories while
the core is held in reset.  In run mode the original CPU memory enables,
addresses, and registered read timing are selected unchanged.

| Item | Baseline | DOT4ACC | Validation contract |
|---|---|---|---|
| Reset/start | `rst`, `enable` | `rst`, `enable` | wrapper holds reset during load, then latches START into enable |
| Program memory | synchronous BRAM, 256 words | same | host write, 8-bit word address |
| Data memory | synchronous BRAM, 256 words | same | host write/read only while stopped |
| Completion | store retirement (`mem_wb_reg.valid && mem_wb_reg.mem_write`) | same retirement condition | derivative latches `validation_done` |
| Cycle count | existing `total_cycles` | existing `total_cycles` | exposed directly; UART time excluded |
| DOT4ACC | not implemented | opcode C, signed INT8 x4, 32-bit wrap | unchanged |

The UART controller uses 0x01 PING, 0x02 RESET, 0x03 WRITE_INSTR, 0x04
WRITE_DATA, 0x05 READ_DATA, 0x06 START, 0x07 STATUS and 0x08 READ_CYCLES.
32-bit words are big-endian on the wire.  Writes are rejected with `e1` while
the core is busy.  Physical validation remains a separate local step.
