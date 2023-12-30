`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/17 14:36:47
// Module Name: multichan_ddr_hdmi
// Description: SDRAM读写测试顶层模块, 从SD卡读取32bit RGB数据
// 将其缓存到SDRAM中, 接着从SDRAM读出数据, 其中数据属于DDR多通道读取
// 将屏幕显示区域分为四部分, 如下, ABCD, 其中每一部分都是640*480的RGB图像, 一起组成1280*960的图像
//<-----------1280----------->
// --------------------------   -
// |           |            |   |
// |     A     |     B      |   |
// |           |            |   9
// --------------------------   6
// |           |            |   0
// |     C     |     D      |   |
// |           |            |   |
// --------------------------   -
// 其中A、B、C、D存储在DDR SDRAM中的不同存储空间, 使用不同的读通道读出数据
// 图    :   读通道
// A     :   0
// B     :   1
// C     :   2
// D     :   3
// 读出数据后, 将其转换为VGA时序, 接着通过IP核将VGA时序转换为HDMI接口数据, 最终实现在屏幕上输出图像
// sd_file_reader模块使用他人开源项目, 参见https://github.com/WangXuan95/FPGA-SDcard-Reader, 暂未对其进行优化
//////////////////////////////////////////////////////////////////////////////////
    
module multichan_ddr_hdmi
    #(parameter FIFO_WR_WIDTH           = 'd32              , //用户端FIFO写位宽
                FIFO_RD_WIDTH           = 'd32              , //用户端FIFO读位宽
                UI_FREQ                 = 'd160_000_000     , //DDR3控制器输出的用户时钟频率
                WR_BURST_LEN            = 'd31              , //写FIFO写突发长度为WR_BURST_LEN+1
                RD_BURST_LEN            = 'd31              , //读FIFO读突发长度为RD_BURST_LEN+1
                UART_BPS                = 'd1_500_000       , //串口波特率
                UART_CLK_FREQ           = 'd100_000_000     , //串口时钟频率
                                                            
                //AXI总线相关参数                           
                AXI_WIDTH               = 'd64              , //AXI总线读写数据位宽
                AXI_AXSIZE              = 3'b011            , //AXI总线的axi_axsize, 需要与AXI_WIDTH对应
                AXI_WSTRB_W             = 'd8               , //axi_wstrb的位宽, AXI_WIDTH/8
                    
                //写FIFO相关参数 
                WR_FIFO_RAM_DEPTH       = 'd2048            , //写FIFO内部RAM存储器深度
                WR_FIFO_RAM_ADDR_WIDTH  = 'd11              , //写FIFO内部RAM读写地址宽度, log2(WR_FIFO_RAM_DEPTH)
                WR_FIFO_WR_IND          = 'd1               , //写FIFO单次写操作访问的ram_mem单元个数 FIFO_WR_WIDTH/WR_FIFO_RAM_WIDTH
                WR_FIFO_RD_IND          = 'd2               , //写FIFO单次读操作访问的ram_mem单元个数 AXI_WIDTH/WR_FIFO_RAM_ADDR_WIDTH        
                WR_FIFO_RAM_WIDTH       = FIFO_WR_WIDTH     , //写FIFO RAM存储器的位宽
                WR_FIFO_WR_L2           = 'd0               , //log2(WR_FIFO_WR_IND)
                WR_FIFO_RD_L2           = 'd1               , //log2(WR_FIFO_RD_IND)
                WR_FIFO_RAM_RD2WR       = 'd2               , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1   
    
                //读FIFO相关参数 
                RD_FIFO_RAM_DEPTH       = 'd2048            , //读FIFO内部RAM存储器深度
                RD_FIFO_RAM_ADDR_WIDTH  = 'd11              , //读FIFO内部RAM读写地址宽度, log2(RD_FIFO_RAM_DEPTH)
                RD_FIFO_WR_IND          = 'd2               , //读FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/RD_FIFO_RAM_WIDTH
                RD_FIFO_RD_IND          = 'd1               , //读FIFO单次读操作访问的ram_mem单元个数 FIFO_RD_WIDTH/RD_FIFO_RAM_ADDR_WIDTH        
                RD_FIFO_RAM_WIDTH       = FIFO_RD_WIDTH     , //读FIFO RAM存储器的位宽
                RD_FIFO_WR_L2           = 'd1               , //log2(RD_FIFO_WR_IND)
                RD_FIFO_RD_L2           = 'd0               , //log2(RD_FIFO_RD_IND)
                RD_FIFO_RAM_RD2WR       = 'd1               , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1  
                    
                //像素定位计数器相关 
                CNT_H_MAX               = 'd1279            , //完整图像的横向像素数量-1, cnt_h计数器的最大值
                CNT_V_MAX               = 'd959             , //完整图像的竖向像素数量-1, cnt_v计数器的最大值
                DIV_H                   = (CNT_H_MAX+1)>>1  , //分割图像的横向坐标数
                DIV_V                   = (CNT_V_MAX+1)>>1    //分割图像的竖向坐标数
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
        output  wire[2:0]   TMDS_Data_p   ,
        output  wire[2:0]   TMDS_Data_n   ,
        
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
        
/*         //SD卡接口
        output  wire        sdclk         ,
        inout               sdcmd         ,
        input   wire        sddat0        ,            
        output  wire        sddat1        ,            
        output  wire        sddat2        ,            
        output  wire        sddat3        ,
        output  wire        rd_file_done     */
    );
    //时钟复位相关连线
    wire        clk_ddr                     ;
    wire        clk_fifo                    ;
    wire        clk_hdmi                    ;
    wire        locked                      ;
    wire        locked_rst_n                ;  //和locked相与的复位信号, 作为DDR接口的真正复位信号
    wire        locked_calib_rst_n          ;  //和locked以及calib_done相与的复位信号, 为高时代表时钟稳定且DDR校准完成
    
    //写接口相关连线
    wire [FIFO_WR_WIDTH-1:0] fifo_wr_data   ; //FIFO写数据
    wire                     fifo_wr_en     ; //FIFO写使能 

    

    //DDR3接口用户端连线
    wire                     rd_mem_enable  ; //读存储器使能
    reg  [3:0]               rd_en          ; //读FIFO读请求
    wire [FIFO_RD_WIDTH-1:0] rd_data[3:0]   ; //读FIFO读数据
    wire                     rd_valid[3:0]  ; //读FIFO有效标志
    wire                     ui_clk         ;     
    wire                     ui_rst         ;     
    wire                     calib_done     ; 

    //VGA时序相关连线
    wire                     hsync          ; //行同步
    wire                     vsync          ; //场同步
    reg  [23:0]              rgb_in         ; //输入的RGB数据信号, 从多个通道读出, 并依据通道请求状态选择其中一个通道读出数据的高24bit
    wire                     pix_valid      ; //为高时代表输出的图像是有效数据帧
    wire                     pix_req        ; //像素读请求
    wire [23:0]              rgb_out        ; //输出的RGB图像信号
    
/*     //SD卡状态变量输出, 可作为调试用
    wire [3:0]               card_stat      ;
    wire [1:0]               card_type      ;
    wire [1:0]               filesystem_type;
    wire                     file_found     ; */
    
    //图像定位坐标变量, 用于确定目前显示的显示区域
    reg [10:0]               cnt_h          ; //横向像素计数器
    reg [9:0]                cnt_v          ; //竖向像素计数器
    
    reg [27:0] cnt_rd_en    ; 
    wire       flag_rd_en   ;
    
    //cnt_rd_en
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_rd_en <= 'd0;
        end else if(cnt_rd_en == 'd99_999_999) begin //2s计数
            cnt_rd_en <= cnt_rd_en;
        end else begin
            cnt_rd_en <= cnt_rd_en + 'd1;
        end
    end
    
    assign flag_rd_en = (cnt_rd_en == 'd99_999_999)?1'b1:1'b0;
    
    
    
    //图像定位坐标更新
    //cnt_h
    always@(posedge clk_fifo or negedge locked_calib_rst_n) begin
        if(!locked_calib_rst_n) begin
            cnt_h <= 'd0;
        end else if(!rd_mem_enable) begin //在rd_mem_enable无效时需要重新技术, 防止图像显示的偏差
            cnt_h <= 'd0;
        end else if(pix_req && cnt_h == CNT_H_MAX) begin 
        //计数到最大值
            cnt_h <= 'd0;
        end else if(pix_req) begin
            cnt_h <= cnt_h + 'd1;
        end else begin
            cnt_h <= cnt_h;
        end
    end
    
    //cnt_v
    always@(posedge clk_fifo or negedge locked_calib_rst_n) begin
        if(!locked_calib_rst_n) begin
            cnt_v <= 'd0;
        end else if(!rd_mem_enable) begin
            cnt_v <= 'd0;
        end else if(pix_req && cnt_h == CNT_H_MAX && cnt_v == CNT_V_MAX) begin
        //计数到最大值
            cnt_v <= 'd0;
        end else if(pix_req && cnt_h == CNT_H_MAX) begin
        //cnt_h每计数完成一轮, cnt_v自增
            cnt_v <= cnt_v + 'd1;
        end else begin
            cnt_v <= cnt_v;
        end
    end
    
    //依据当前显示坐标, 确定各通道的读请求信号
    //rd_en
    always@(*) begin
        if(cnt_h < DIV_H && cnt_v < DIV_V) begin  //左上角: 通道0
            rd_en = {3'b0, pix_req};
        end else if(cnt_h >= DIV_H && cnt_v < DIV_V) begin //右上角: 通道1
            rd_en = {2'b0, pix_req, 1'b0};
        end else if(cnt_h < DIV_H && cnt_v >= DIV_V) begin //左下角: 通道2
            rd_en = {1'b0, pix_req, 2'b0};
        end else begin //右下角: 通道3
            rd_en = {pix_req, 3'b0};
        end
    end
    
    //rgb_in
    //依据rd_en的值, 确定VGA输入图像数据的来源
    always@(*) begin
        if(cnt_h < DIV_H && cnt_v < DIV_V) begin  //左上角: 通道0
            rgb_in = rd_data[0][31:8];
        end else if(cnt_h >= DIV_H && cnt_v < DIV_V) begin //右上角: 通道1
            rgb_in = rd_data[1][31:8];
        end else if(cnt_h < DIV_H && cnt_v >= DIV_V) begin //左下角: 通道2
            rgb_in = rd_data[2][31:8];
        end else begin //右下角: 通道3
            rgb_in = rd_data[3][31:8];
        end
    end
    
    
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
/*     key_ctrl
    #(.FREQ(UI_FREQ)) //模块输入时钟频率, 与DDR3 AXI控制器的用户时钟相同 
    key_ctrl_inst
    (
        .clk         (ui_clk        ),
        .rst_n       (~ui_rst       ),
        .key_in      (key_in        ),
        
        .state_out   (key_state_out )   
    ); */
    
    assign rd_mem_enable = flag_rd_en; //按键控制读存储器使能
    
    //串口数据接收器
    uart_receiver
    #(
        .UART_BPS        (UART_BPS          ),   //串口波特率
        .CLK_FREQ        (UART_CLK_FREQ     ),   //时钟频率
        .FIFO_WR_WIDTH   (FIFO_WR_WIDTH     ),   //写FIFO写端口数据位宽
        .FIFO_WR_BYTE    (FIFO_WR_WIDTH >> 3)    //写FIFO写端口字节数
    ) 
    uart_receiver_inst
    (
        .clk         (clk_fifo          ), //与FIFO时钟同步
        .rst_n       (locked_calib_rst_n), //SDRAM校准完成后才允许串口接收数据, 内含复位信号的同步释放处理
        .rx          (rx                ), //串口
        
        .fifo_wr_data(fifo_wr_data), //FIFO写数据
        .fifo_wr_en  (fifo_wr_en  )  //FIFO写使能
    );
    
    
    
/*     //SD读卡模块
    sd_file_reader #(
    .FILE_NAME_LEN (11           ), // length of FILE_NAME (in bytes). Since the length of "example.txt" is 11, so here is 11.
    .FILE_NAME     ("fisherg.txt"), // file name to read, ignore upper and lower case
                                    // For example, if you want to read a file named "HeLLo123.txt", this parameter can be "hello123.TXT", "HELLO123.txt" or "HEllo123.Txt"
    .CLK_DIV       (3            ) // when clk =   0~ 25MHz , set CLK_DIV = 3'd1,
                                    // when clk =  25~ 50MHz , set CLK_DIV = 3'd2,
                                    // when clk =  50~100MHz , set CLK_DIV = 3'd3,
                                    // when clk = 100~200MHz , set CLK_DIV = 3'd4,
                                    // ......
//    .SIMULATE      (0            )  // 0:normal use.         1:only for simulation
    ) 
    sd_file_reader_inst
    (
        // rstn active-low, 1:working, 0:reset
        .rstn              (locked_calib_rst_n),  //SDRAM校准完成后才允许从SD CARD读取数据
        // clock   
        .clk               (clk_fifo          ),  //和FIFO时钟同步
        // SDcard signals (connect to SDcard), this design do not use sddat1~sddat3.
        .sdclk             (sdclk             ),
        .sdcmd             (sdcmd             ),
        .sddat0            (sddat0            ),
        // status output (optional for user)
        .card_stat         (card_stat         ),  // show the sdcard initialize status
        .rd_file_done      (rd_file_done      ),  // 文件读取成功标志
        .card_type         (card_type         ),  // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
        .filesystem_type   (filesystem_type   ),  // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
        .file_found        (file_found        ),  // 0=file not found, 1=file found
        // file content data output (sync with clk)
        .outen             (                  ),  // when outen=1, a byte of file content is read out from outbyte
        .outbyte           (                  )   // a byte of file content
    );

    //使用SD卡SDIO单线模式, 将sddat1-sddat3驱动为1, 防止进入SPI模式
    assign {sddat1, sddat2, sddat3} = 3'b111; */
    
    
    //VGA时序生成器
    vga_ctrl vga_ctrl_inst(
        .clk         (clk_fifo            ),
        .rst_n       (locked_calib_rst_n & rd_mem_enable),  //模块内部会进行异步复位、同步释放处理
        .rgb_in      (rgb_in              ), //输入的RGB图像信号
        
        .hsync       (hsync               ), //行同步
        .vsync       (vsync               ), //场同步
        .pix_req     (pix_req             ), //请求外部图像输入, 同时也是FIFO读请求
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
    
    
    //DDR3多通道读写接口, 实际上1写4读
    multichan_ddr_interface
    #(  .FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ),  //用户端FIFO读写位宽
        .FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ),
        .AXI_WIDTH               (AXI_WIDTH               ),  //AXI总线读写数据位宽
        .AXI_AXSIZE              (AXI_AXSIZE              ),  //AXI总线的axi_awsize, 需要与AXI_WIDTH对应
                                
        //写FIFO相关参数        
        .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), //写FIFO内部RAM存储器深度
        .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), //写FIFO内部RAM读写地址宽度, log2(WR_FIFO_RAM_DEPTH)
        .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), //写FIFO单次写操作访问的ram_mem单元个数 FIFO_WR_WIDTH/WR_FIFO_RAM_WIDTH
        .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), //写FIFO单次读操作访问的ram_mem单元个数 AXI_WIDTH/WR_FIFO_RAM_ADDR_WIDTH        
        .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), //写FIFO RAM存储器的位宽
        .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), //log2(WR_FIFO_WR_IND)
        .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), //log2(WR_FIFO_RD_IND)
        .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       ), //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1   
                                
        //读FIFO相关参数        
        .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), //读FIFO内部RAM存储器深度
        .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), //读FIFO内部RAM读写地址宽度, log2(RD_FIFO_RAM_DEPTH)
        .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), //读FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/RD_FIFO_RAM_WIDTH
        .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), //读FIFO单次读操作访问的ram_mem单元个数 FIFO_RD_WIDTH/RD_FIFO_RAM_ADDR_WIDTH        
        .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), //读FIFO RAM存储器的位宽
        .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), //log2(RD_FIFO_WR_IND)
        .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), //log2(RD_FIFO_RD_IND)
        .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1 
    )
    multichan_ddr_interface_inst
    (
        .clk             (clk_ddr                           ), //DDR3时钟, 也就是DDR3 MIG IP核参考时钟 //AXI主机读写时钟
        .rst_n           (locked_rst_n                      ), //模块内部会进行异步复位、同步释放处理   
                        
        //用户端写接口              
        .wr_clk          (clk_fifo                          ), //写FIFO写时钟
        .wr_rst          (~locked_rst_n                     ), //写复位, 高电平有效
        .wr_beg_addr0    ('d0                               ), //写通道0写起始地址
        .wr_beg_addr1    ('d0                               ), //写通道1写起始地址
        .wr_beg_addr2    ('d0                               ), //写通道2写起始地址
        .wr_beg_addr3    ('d0                               ), //写通道3写起始地址
        .wr_end_addr0    ('d4915200*'d192-'d1               ), //写通道0写终止地址
        .wr_end_addr1    ('d0                               ), //写通道1写终止地址, 实际上未使用
        .wr_end_addr2    ('d0                               ), //写通道2写终止地址, 实际上未使用
        .wr_end_addr3    ('d0                               ), //写通道3写终止地址, 实际上未使用
        .wr_burst_len0   ('d31                              ), //写通道0写突发长度
        .wr_burst_len1   ('d31                              ), //写通道1写突发长度
        .wr_burst_len2   ('d31                              ), //写通道2写突发长度
        .wr_burst_len3   ('d31                              ), //写通道3写突发长度
        .wr_en0          (fifo_wr_en                        ), //写通道0写请求
        .wr_en1          ('d0                               ), //写通道1写请求
        .wr_en2          ('d0                               ), //写通道2写请求
        .wr_en3          ('d0                               ), //写通道3写请求
        .wr_data0        (fifo_wr_data                      ), //写通道0写入数据
        .wr_data1        ('d0                               ), //写通道1写入数据
        .wr_data2        ('d0                               ), //写通道2写入数据
        .wr_data3        ('d0                               ), //写通道3写入数据

        //用户端写接口
        .rd_clk          (clk_fifo                          ), //读FIFO读时钟
        .rd_rst          ((~locked_rst_n) | (~rd_mem_enable)), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable                     ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr0    ('d0                               ), //读通道0读起始地址
        .rd_beg_addr1    ('d1228800*'d1                     ), //读通道1读起始地址
        .rd_beg_addr2    ('d1228800*'d2                     ), //读通道2读起始地址
        .rd_beg_addr3    ('d1228800*'d3                     ), //读通道3读起始地址
        .rd_end_addr0    ('d1228800*'d1-'d1                 ), //读通道0读终止地址
        .rd_end_addr1    ('d1228800*'d2-'d1                 ), //读通道1读终止地址
        .rd_end_addr2    ('d1228800*'d3-'d1                 ), //读通道2读终止地址
        .rd_end_addr3    ('d1228800*'d4-'d1                 ), //读通道3读终止地址
        .rd_burst_len0   ('d31                              ), //读通道0读突发长度
        .rd_burst_len1   ('d31                              ), //读通道1读突发长度
        .rd_burst_len2   ('d31                              ), //读通道2读突发长度
        .rd_burst_len3   ('d31                              ), //读通道3读突发长度
        .rd_en0          (rd_en[0]                          ), //读通道0读请求
        .rd_en1          (rd_en[1]                          ), //读通道1读请求
        .rd_en2          (rd_en[2]                          ), //读通道2读请求
        .rd_en3          (rd_en[3]                          ), //读通道3读请求
        .rd_data0        (rd_data[0]                        ), //读通道0读出数据
        .rd_data1        (rd_data[1]                        ), //读通道1读出数据
        .rd_data2        (rd_data[2]                        ), //读通道2读出数据
        .rd_data3        (rd_data[3]                        ), //读通道3读出数据
        .rd_valid0       (rd_valid[0]                       ), //读通道0FIFO可读标志          
        .rd_valid1       (rd_valid[1]                       ), //读通道1FIFO可读标志          
        .rd_valid2       (rd_valid[2]                       ), //读通道2FIFO可读标志          
        .rd_valid3       (rd_valid[3]                       ), //读通道3FIFO可读标志

        //MIG IP核用户端
        .ui_clk          (ui_clk                            ), //MIG IP核输出的用户时钟, 用作AXI控制器时钟
        .ui_rst          (ui_rst                            ), //MIG IP核输出的复位信号, 高电平有效
        .calib_done      (calib_done                        ), //DDR3初始化完成
                            
        //DDR3 PHY接口                    
        .ddr3_addr       (ddr3_addr                         ),  
        .ddr3_ba         (ddr3_ba                           ),
        .ddr3_cas_n      (ddr3_cas_n                        ),
        .ddr3_ck_n       (ddr3_ck_n                         ),
        .ddr3_ck_p       (ddr3_ck_p                         ),
        .ddr3_cke        (ddr3_cke                          ),
        .ddr3_ras_n      (ddr3_ras_n                        ),
        .ddr3_reset_n    (ddr3_reset_n                      ),
        .ddr3_we_n       (ddr3_we_n                         ),
        .ddr3_dq         (ddr3_dq                           ),
        .ddr3_dqs_n      (ddr3_dqs_n                        ),
        .ddr3_dqs_p      (ddr3_dqs_p                        ),
        .ddr3_cs_n       (ddr3_cs_n                         ),
        .ddr3_dm         (ddr3_dm                           ),
        .ddr3_odt        (ddr3_odt                          )            

    );

endmodule
