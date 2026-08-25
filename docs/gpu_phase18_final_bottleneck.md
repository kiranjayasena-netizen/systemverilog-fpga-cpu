# Stage 18 — Final bottleneck and lower bound

Stage 14 is the selected optimization endpoint. Its unchanged benchmark
schedule is fully accounted for with no idle or control bubbles. ARRAY_ADD
is 20 cycles: four ALU operations, three prefetched load hits, four miss
issue cycles, five load writeback-state observations, and four stores.

The four remaining dependent load cases cannot be shortened by simple
forwarding because the load and dependent ALU each require a vector-register
write. The one-entry result-buffer idea would defer the ALU write and does
not reduce total cycles. VSTORE also consumes a real single-port memory
write cycle. Thus 20 cycles is the current architectural lower bound
without a second RF write path, ISA fusion, or a larger retirement design.
