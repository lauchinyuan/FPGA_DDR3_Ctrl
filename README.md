#### 关于

本项目在Xilinx FPGA平台上实现了对DDR3 SDRAM读写操作，并通过RS232串口将图像数据存到SDRAM存储器，接着读取存储数据内容，并通过HDMI音视频接口实现图像显示，其中DDR3读写控制器是AXI总线接口从机。

本仓库提供了所有模块的[Verilog 代码](./rtl)，其中比较关键的模块是[AXI写主机](./rtl/axi_master_wr.v)、[AXI读主机](./rtl/axi_master_rd.v)、[AXI控制器](./rtl/axi_ctrl.v)，这三个模块加上AXI总线 DDR3 MIG IP核，构成了[DDR3读写接口](./rtl/ddr_interface.v)。

[testbench](./testbench)目录提供了几乎所有子模块的仿真测试文件，[wave](./wave)目录下提供了本工程子模块的简要波形示意图，**配合波形图将有助您理解本工程的设计细节**。

[xci](./xci)目录存放了项目中用到的所有IP核文件配置信息，在Vivado中作为source添加即可，其中rgb2dvi IP核使用[Digilent开源IP核](https://github.com/Digilent/vivado-library/tree/master/ip)，需要在Vivado上添加IP核仓库。

图像数据处理方面, [matlab](./matlab)目录提供了将图像转换为16进制像素值txt文件的MATLAB脚本。而[img](./img)文件夹则是一些测试图像文件，[txt](,/txt)文件夹是转换后的数据文本文件, 可以通过串口发送。

FPGA上板实验的效果如图1-2所示，硬件实验平台使用的是博宸精芯Kintex-7基础板开发板，芯片型号为XC7K325T-2FFG676，在其它硬件平台上复现该工程时，应注意更改约束文件中的管脚约束，同时MIG IP核也应该依据所用硬件平台的SDRAM型号进行相应更改。

![](./img/README/demo_1.jpg)

<center>图1. 演示1</center>

![](./img/README/demo_2.jpg)

<center>图2. 演示2</center>

本仓库所有代码均有较为详细的注释说明，有任何问题欢迎您通过lauchinyuan@yeah.net联系我，一起探讨学习。

#### 数据流&框图

本项目的结构示意图如图3

![](./img/README/structure.jpg)

<center>图3. 系统框图</center>

处理数据的流程具体说明如下：

1. RS232串口接收上位机发送的图像像素数据。
2. 像素数据存到"写FIFO"中，进行缓存。
3. "写FIFO"中的数据数量满足设定值，向AXI写主机发送写数据请求。
4. AXI写主机收到写请求，发起AXI总线写动作，将数据发送到AXI从机(DDR3 MIG IP核)。
5. AXI从机将AXI总线上送来的数据转换为DDR3 SDRAM物理接口时序，将数据写入SDRAM中。
6. VGA模块依据VGA时序，在需要输出图像数据时，向"读FIFO"模块发出读请求，并获得“读FIFO”内存储的数据，而当“读FIFO”内数据不够时，向“AXI读主机“发送读请求。收到请求后“AXI读主机“发起AXI读操作，从AXI从机(DDR3 MIG IP核)处获取SDRAM中存储的数据。其中DDR3 MIG IP核将解析AXI总线协议，并转换为DDR3的读时序，从SDRAM读取数据。
7. VGA模块获得数据，并生成VGA时序。
8. 通过rgb2dvi IP核将VGA时序转换为HDMI TMDS时序，通过HDMI接口将图像输出到屏幕上。

