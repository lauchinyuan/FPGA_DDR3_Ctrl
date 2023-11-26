# 时钟约束
create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]

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
set_clock_groups -name clk_groups -asynchronous -group [get_clocks {clk clk_hdmi_clk_gen clk_fifo_clk_gen}] -group [get_clocks {clk_ddr_clk_gen clk_pll_i}]

# 用于程序固化的SPI配置
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

# SD CARD
set_property -dict {PACKAGE_PIN E23 IOSTANDARD LVCMOS33} [get_ports sdclk]
set_property -dict {PACKAGE_PIN G24 IOSTANDARD LVCMOS33} [get_ports sdcmd]
set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVCMOS33} [get_ports sddat0]
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS33} [get_ports sddat1]
set_property -dict {PACKAGE_PIN F25 IOSTANDARD LVCMOS33} [get_ports sddat2]
set_property -dict {PACKAGE_PIN F24 IOSTANDARD LVCMOS33} [get_ports sddat3]
# LED_state for sd card
set_property -dict {PACKAGE_PIN A24 IOSTANDARD LVCMOS33} [get_ports rd_file_done]



