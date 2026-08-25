# GPU memory model

Vector data memory is 32 × 128 bits with one synchronous read and one
synchronous write. A read response arrives one clock after its request.
Stage 14 keeps one physical read issue per cycle and two outstanding
speculative requests. Prefetch data is discarded on store or external
invalidation hazards. Host writes are accepted only while the accelerator
is idle.
