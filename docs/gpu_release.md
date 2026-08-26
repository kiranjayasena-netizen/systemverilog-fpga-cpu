# GPU release checklist

The verified final core is Stage 14. The core, accelerator wrapper, UART
controller, Basys 3 MMCM top, constraints, simulation scripts and bitstream
flow are checked in. Vivado synthesis, board-top implementation and
bitstream generation completed successfully on the target part. Physical Basys
3 programming and UART execution of the documented workloads completed
successfully for GPU v1.0. PING/STATUS,
program/data loading, readback, START/BUSY/DONE, all four benchmarks,
restart/consecutive operation, and 100-run stability were validated.
