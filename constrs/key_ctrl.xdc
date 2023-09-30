# 时钟约束
create_clock -name clk -period 20 -waveform {0 10} [get_ports clk]

# 管脚约束
set_property PACKAGE_PIN G22 [get_ports clk]
set_property PACKAGE_PIN D26 [get_ports rst_n]
set_property PACKAGE_PIN A23 [get_ports state_out]
set_property PACKAGE_PIN G25 [get_ports key_in]

# 电平标准
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports state_out]
set_property IOSTANDARD LVCMOS33 [get_ports key_in]
