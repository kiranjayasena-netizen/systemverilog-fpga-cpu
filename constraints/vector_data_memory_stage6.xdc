set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name vector_data_clk -period 10.000 [get_ports clk]
