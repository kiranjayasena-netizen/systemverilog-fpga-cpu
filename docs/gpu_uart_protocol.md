# UART control protocol

The Basys 3 controller uses 8-N-1 UART at 115200 baud from the 80 MHz GPU
clock (`CLKS_PER_BIT=694`). Commands are single-byte framed and little
endian:

| Command | Payload | Meaning |
|---|---|---|
| `01` | none | PING; replies `81` |
| `02` | none | reset GPU |
| `03` | addr, data_hi, data_lo | write one instruction |
| `04` | length | set program length |
| `05` | addr, 16 data bytes | write one vector-memory word, LSB byte first |
| `06` | none | start when idle |
| `07` | none | status reply: bit0 busy, bit1 done |

Unknown commands reply `E0`. Host writes are ignored by the core while it
is running. The protocol is intentionally small and deterministic; a host
must wait for command completion before issuing the next frame.
