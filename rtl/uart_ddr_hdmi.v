`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/29 11:40:03
// Module Name: uart_ddr_hdmi
// Description: SDRAM读写测试顶层模块, 从RS232串口读取32bit RGB数据
// 将其缓存到SDRAM中, 接着从SDRAM读出数据, 将其转换为VGA时序, 接着通过IP核将VGA时序转换为HDMI接口数据
// 最终实现在屏幕上输出图像
//////////////////////////////////////////////////////////////////////////////////


module uart_ddr_hdmi
    #(parameter FIFO_WR_WIDTH = 'd16        ,//用户端FIFO写位宽
                FIFO_RD_WIDTH = 'd16        ,//用户端FIFO读位宽
                UART_BPS      = 'd9600      ,//串口波特率
                UART_CLK_FREQ = 'd50_000_000,//串口时钟频率
                FIFO_WR_BYTE  = 'd4          //写FIFO写端口字节数
    )
    (
        input   wire        clk           , //系统时钟
        input   wire        rst_n         , //系统复位
        
        //RS232接口
        input   wire        rx            ,
        
        //DDR3接口                              
        output  wire [14:0] ddr3_addr     ,  
        output  wire [2:0]  ddr3_ba       ,
        output  wire        ddr3_cas_n    ,
        output  wire        ddr3_ck_n     ,
        output  wire        ddr3_ck_p     ,
        output  wire        ddr3_cke      ,
        output  wire        ddr3_ras_n    ,
        output  wire        ddr3_reset_n  ,
        output  wire        ddr3_we_n     ,
        inout   wire [31:0] ddr3_dq       ,
        inout   wire [3:0]  ddr3_dqs_n    ,
        inout   wire [3:0]  ddr3_dqs_p    ,
        output  wire        ddr3_cs_n     ,
        output  wire [3:0]  ddr3_dm       ,
        output  wire        ddr3_odt      
        
    );
    
    
    
    
    uart_receiver
    #(
        .UART_BPS        (UART_BPS        ),   //串口波特率
        .CLK_FREQ        (UART_CLK_FREQ   ),   //时钟频率
        .FIFO_WR_WIDTH   (FIFO_WR_WIDTH   ),   //写FIFO写端口数据位宽
        .FIFO_WR_BYTE    (FIFO_WR_BYTE    )    //写FIFO写端口字节数
    ) 
    uart_receiver_inst
    (
        input   wire                    clk         , //与FIFO时钟同步
        input   wire                    rst_n       ,
        .rx          (rx          ), //串口
        
        output  reg [FIFO_WR_WIDTH-1:0] fifo_wr_data, //FIFO写数据
        output  reg                     fifo_wr_en    //FIFO写使能
    );
    
    
    
    //DDR3控制接口
    ddr_interface
    #(.FIFO_WR_WIDTH(FIFO_WR_WIDTH),  //用户端FIFO读写位宽
      .FIFO_RD_WIDTH(FIFO_RD_WIDTH))
      ddr_interface_inst
        (
        input   wire        clk                 , //DDR3时钟, 也就是DDR3 MIG IP核参考时钟
        input   wire        rst_n               , 
                    
        //用户端       
        input   wire        wr_clk              , //写FIFO写时钟
        input   wire        wr_rst              , //写复位
        input   wire [29:0] wr_beg_addr         , //写起始地址
        input   wire [29:0] wr_end_addr         , //写终止地址
        input   wire [7:0]  wr_burst_len        , //写突发长度
        input   wire        wr_en               , //写FIFO写请求
        input   wire [15:0] wr_data             , //写FIFO写数据 
        input   wire        rd_clk              , //读FIFO读时钟
        input   wire        rd_rst              , //读复位
        input   wire        rd_mem_enable       , //读存储器使能,防止存储器未写先读
        input   wire [29:0] rd_beg_addr         , //读起始地址
        input   wire [29:0] rd_end_addr         , //读终止地址
        input   wire [7:0]  rd_burst_len        , //读突发长度
        input   wire        rd_en               , //读FIFO读请求
        output  wire [15:0] rd_data             , //读FIFO读数据
        output  wire        rd_valid            , //读FIFO有效标志,高电平代表当前处理的数据有效
        output  wire        ui_clk              , //MIG IP核输出的用户时钟, 用作AXI控制器时钟
        output  wire        ui_rst              , //MIG IP核输出的复位信号, 高电平有效
        output  wire        calib_done          , //DDR3初始化完成
        
        //DDR3接口                              
        .ddr3_addr           (ddr3_addr           ),  
        .ddr3_ba             (ddr3_ba             ),
        .ddr3_cas_n          (ddr3_cas_n          ),
        .ddr3_ck_n           (ddr3_ck_n           ),
        .ddr3_ck_p           (ddr3_ck_p           ),
        .ddr3_cke            (ddr3_cke            ),
        .ddr3_ras_n          (ddr3_ras_n          ),
        .ddr3_reset_n        (ddr3_reset_n        ),
        .ddr3_we_n           (ddr3_we_n           ),
        .ddr3_dq             (ddr3_dq             ),
        .ddr3_dqs_n          (ddr3_dqs_n          ),
        .ddr3_dqs_p          (ddr3_dqs_p          ),
        .ddr3_cs_n           (ddr3_cs_n           ),
        .ddr3_dm             (ddr3_dm             ),
        .ddr3_odt            (ddr3_odt            )
        
    );
    
    
    
    
endmodule
