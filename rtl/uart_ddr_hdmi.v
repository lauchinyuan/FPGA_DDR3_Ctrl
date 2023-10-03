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
    #(parameter FIFO_WR_WIDTH = 'd32            ,//用户端FIFO写位宽
                FIFO_RD_WIDTH = 'd32            ,//用户端FIFO读位宽
                UART_BPS      = 'd460800        ,//串口波特率
                UART_CLK_FREQ = 'd25_000_000    ,//串口时钟频率
                UI_FREQ       = 'd160_000_000   ,//DDR3控制器输出的用户时钟频率
                FIFO_WR_BYTE  = 'd4             ,//写FIFO写端口字节数
                WR_BEG_ADDR   = 'd0             ,//写FIFO写起始地址
/*                 WR_END_ADDR   = 'd4915199       ,//写FIFO写终止地址 */
                WR_END_ADDR   = 'd1228799       ,
                WR_BURST_LEN  = 'd31            ,//写FIFO写突发长度为WR_BURST_LEN+1
                RD_BEG_ADDR   = 'd0             ,//读FIFO读起始地址
/*                 RD_END_ADDR   = 'd4915199       ,//读FIFO读终止地址 */
                RD_END_ADDR   = 'd1228799       ,
                RD_BURST_LEN  = 'd31              //读FIFO读突发长度为RD_BURST_LEN+1
    )
    (
        input   wire        clk           , //系统时钟
        input   wire        rst_n         , //系统复位
        
        //按键相关
        input   wire        key_in        , //按键输入
        output  wire        key_state_out , //按键控制状态输出,也是读存储器使能信号
        
        //RS232接口
        input   wire        rx            ,
        
        //HDMI接口
        output  wire        TMDS_Clk_p    ,
        output  wire        TMDS_Clk_n    ,
        output  wire[2 : 0] TMDS_Data_p   ,
        output  wire[2 : 0] TMDS_Data_n   ,
        
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
    //时钟复位相关连线
    wire        clk_ddr                     ;
    wire        clk_fifo                    ;
    wire        clk_hdmi                    ;
    wire        locked                      ;
    wire        locked_rst_n                ;  //和locked相与的复位信号, 作为DDR接口的真正复位信号
    wire        locked_calib_rst_n          ;  //和locked以及calib_done相与的复位信号, 为高时代表时钟稳定且DDR校准完成
    
    //UART接口相关连线
    wire [FIFO_WR_WIDTH-1:0] fifo_wr_data   ; //FIFO写数据
    wire                     fifo_wr_en     ; //FIFO写使能  

    //DDR3接口用户端连线
    wire                     rd_mem_enable  ; //读存储器使能
    wire                     rd_en          ; //读FIFO读请求
    wire [FIFO_RD_WIDTH-1:0] rd_data        ; //读FIFO读数据
    wire                     rd_valid       ; //读FIFO有效标志
    wire                     ui_clk         ;     
    wire                     ui_rst         ;     
    wire                     calib_done     ; 

    //VGA时序相关连线
    wire                     hsync          ; //行同步
    wire                     vsync          ; //场同步
    wire                     pix_valid      ; //为高时代表输出的图像是有效数据帧
    wire [23:0]              rgb_out        ; //输出的RGB图像信号
    
    //时钟生成模块,产生FIFO读写时钟及AXI读写主机工作时钟
      clk_gen clk_gen_inst(
        .clk_ddr    (clk_ddr    ),     
        .clk_fifo   (clk_fifo   ),   
        .clk_hdmi   (clk_hdmi   ),   
        // Status and control signals
        .reset      (~rst_n     ), 
        .locked     (locked     ),     
        // Clock in ports
        .clk_in1    (clk        ) //50MHz时钟输入
    ); 
    
    //衍生复位信号
    assign locked_rst_n         = rst_n & locked            ;
    assign locked_calib_rst_n   = locked_rst_n & calib_done ;
    
    //按键控制模块
    key_ctrl
    #(.FREQ(UI_FREQ)) //模块输入时钟频率, 与DDR3 AXI控制器的用户时钟相同 
    key_ctrl_inst
    (
        .clk         (ui_clk        ),
        .rst_n       (~ui_rst       ),
        .key_in      (key_in        ),
        
        .state_out   (key_state_out )   
    );
    
    assign rd_mem_enable = key_state_out; //按键控制读存储器使能
    
    //串口数据接收器
    uart_receiver
    #(
        .UART_BPS        (UART_BPS        ),   //串口波特率
        .CLK_FREQ        (UART_CLK_FREQ   ),   //时钟频率
        .FIFO_WR_WIDTH   (FIFO_WR_WIDTH   ),   //写FIFO写端口数据位宽
        .FIFO_WR_BYTE    (FIFO_WR_BYTE    )    //写FIFO写端口字节数
    ) 
    uart_receiver_inst
    (
        .clk         (clk_fifo          ), //与FIFO时钟同步
        .rst_n       (locked_calib_rst_n),
        .rx          (rx                ), //串口
        
        .fifo_wr_data(fifo_wr_data), //FIFO写数据
        .fifo_wr_en  (fifo_wr_en  )  //FIFO写使能
    );
    
    
    //VGA时序生成器
    vga_ctrl vga_ctrl_inst(
        .clk         (clk_fifo            ),
        .rst_n       (locked_calib_rst_n & rd_mem_enable),
        .rgb_in      (rd_data[31:8]       ), //输入的RGB图像信号
        
        .hsync       (hsync               ), //行同步
        .vsync       (vsync               ), //场同步
        .pix_req     (rd_en               ), //请求外部图像输入, 同时也是FIFO读请求
        .pix_valid   (pix_valid           ), //为高代表输出的图像是有效数据帧
        .rgb_out     (rgb_out             )  //输出的RGB图像信号
    );
    
    //vga to hdmi IP核
    rgb2dvi_0 rgb2dvi_0_inst (
        .TMDS_Clk_p     (TMDS_Clk_p ),  // output wire TMDS_Clk_p
        .TMDS_Clk_n     (TMDS_Clk_n ),  // output wire TMDS_Clk_n
        .TMDS_Data_p    (TMDS_Data_p),  // output wire [2 : 0] TMDS_Data_p
        .TMDS_Data_n    (TMDS_Data_n),  // output wire [2 : 0] TMDS_Data_n
        .aRst           (1'b0       ),  // input wire aRst
        .vid_pData      ({rgb_out[23:16],rgb_out[7:0],rgb_out[15:8]}),  // input wire [23 : 0] vid_pData
        .vid_pVDE       (pix_valid  ),  // input wire vid_pVDE
        .vid_pHSync     (hsync      ),  // input wire vid_pHSync
        .vid_pVSync     (vsync      ),  // input wire vid_pVSync
        .PixelClk       (clk_fifo   ),  // input wire PixelClk
        .SerialClk      (clk_hdmi   )   // input wire SerialClk
    );
    
    
    //DDR3控制接口
    ddr_interface
    #(.FIFO_WR_WIDTH(FIFO_WR_WIDTH),  //用户端FIFO读写位宽
      .FIFO_RD_WIDTH(FIFO_RD_WIDTH))
      ddr_interface_inst
        (
        .clk                 (clk_ddr                           ), //DDR3时钟, 也就是DDR3 MIG IP核参考时钟
        .rst_n               (locked_rst_n                      ), 
                                    
        //用户端                       
        .wr_clk              (clk_fifo                          ), //写FIFO写时钟
        .wr_rst              (~locked_rst_n                     ), //写复位
        .wr_beg_addr         (WR_BEG_ADDR                       ), //写起始地址
        .wr_end_addr         (WR_END_ADDR                       ), //写终止地址
        .wr_burst_len        (WR_BURST_LEN                      ), //写突发长度
        .wr_en               (fifo_wr_en                        ), //写FIFO写请求
        .wr_data             (fifo_wr_data                      ), //写FIFO写数据 
        .rd_clk              (clk_fifo                          ), //读FIFO读时钟
        .rd_rst              ((~locked_rst_n) | (~rd_mem_enable)), //读复位, 没有开始使能读时,读地址处于0
        .rd_mem_enable       (rd_mem_enable                     ), //读存储器使能,防止存储器未写先读
        .rd_beg_addr         (RD_BEG_ADDR                       ), //读起始地址
        .rd_end_addr         (RD_END_ADDR                       ), //读终止地址
        .rd_burst_len        (RD_BURST_LEN                      ), //读突发长度
        .rd_en               (rd_en                             ), //读FIFO读请求
        .rd_data             (rd_data                           ), //读FIFO读数据
        .rd_valid            (rd_valid                          ), //读FIFO有效标志
        .ui_clk              (ui_clk                            ), //MIG IP核输出的用户时钟, 用作AXI控制器时钟
        .ui_rst              (ui_rst                            ), //MIG IP核输出的复位信号, 高电平有效
        .calib_done          (calib_done                        ), //DDR3初始化完成
        
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
