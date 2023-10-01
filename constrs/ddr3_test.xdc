# 时钟约束
create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]
# 引脚约束
set_property PACKAGE_PIN G22 [get_ports clk]
set_property PACKAGE_PIN D26 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
