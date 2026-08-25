# Final resource and timing report

Stage 14 core at 80 MHz: setup WNS +0.221 ns, hold WHS +0.185 ns, zero
failing endpoints. Worst setup path is current-PC/instruction/lookahead to
the vector register file, 12.131 ns total (2.038 ns logic, 10.093 ns
routing, 83.2% routing, nine logic levels). The board-top synthesis flow
elaborates and synthesizes successfully; board implementation and hardware
validation remain separate release checks.
