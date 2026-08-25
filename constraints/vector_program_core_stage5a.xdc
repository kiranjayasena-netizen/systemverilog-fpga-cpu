## Stage 5A standalone vector-core timing constraint.
## Only the synthetic clock is constrained; control/data ports are not board IO.
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name vector_core_clk -period 10.000 [get_ports clk]
