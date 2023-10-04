# 时钟约束
create_clock -name clk -period 20 -waveform {0 10} [get_ports clk]

# 引脚约束
set_property PACKAGE_PIN G22 [get_ports clk]
set_property PACKAGE_PIN D26 [get_ports rst_n]
set_property PACKAGE_PIN A23 [get_ports key_state_out]
set_property PACKAGE_PIN G25 [get_ports key_in]
set_property PACKAGE_PIN B17 [get_ports rx] 
set_property PACKAGE_PIN AC23 [get_ports {TMDS_Data_p[2]}]
set_property PACKAGE_PIN AE23 [get_ports {TMDS_Data_p[1]}]
set_property PACKAGE_PIN AF24 [get_ports {TMDS_Data_p[0]}]
set_property PACKAGE_PIN Y22 [get_ports TMDS_Clk_p]

# 电平标准约束
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports key_state_out]
set_property IOSTANDARD LVCMOS33 [get_ports key_in]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

# 设置异步时钟组
set_clock_groups -asynchronous -name clk_groups -group [get_clocks {clk clk_hdmi_clk_gen clk_fifo_clk_gen}] -group [get_clocks {clk_ddr_clk_gen clk_pll_i}]

# 用于程序固化的SPI配置
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

