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
| `08` | addr | read one vector-memory word; returns 16 LSB-first bytes |

Unknown commands reply `E0`. Host writes are ignored by the core while it
is running. The protocol is intentionally small and deterministic; a host
must wait for command completion before issuing the next frame.

`WRITE_MEMORY` accepts an address followed by 16 little-endian bytes.
`READ_MEMORY` returns the same byte order. Reads while the GPU is busy
return the single-byte error `E1`; unknown commands return `E0`.

## Physical UART validation

The Basys 3 pin mapping is FPGA `B18 -> uart_rx` and `A18 -> uart_tx`.
The receiver confirms the midpoint of the start bit, samples eight LSB-first
data bits, and validates the stop bit. With the release-candidate bitstream
these checks passed on COM4: PING returned `81`, and ten consecutive STATUS
requests returned `00` without empty reads or timeouts.
