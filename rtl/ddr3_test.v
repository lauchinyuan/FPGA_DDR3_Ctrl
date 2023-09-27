`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/21 11:21:52
// Module Name: ddr3_test 
// Description: DDR3读写功能测试模块, 包含DDR3接口、测试数据生成模块、时钟生成模块
// 输出线输出到DDR3物理端口, 使用在线逻辑分析仪进行DDR3逻辑功能分析
//////////////////////////////////////////////////////////////////////////////////
module ddr3_test
#(parameter WR_BEG_ADDR     = 30'd0     ,
  parameter WR_END_ADDR     = 30'd8191  ,
  parameter WR_BURST_LEN    = 8'd1      ,
  parameter RD_BEG_ADDR     = 30'd0     ,
  parameter RD_END_ADDR     = 30'd2200  ,
  parameter RD_BURST_LEN    = 8'd1      
  )
    (
        input   wire        clk           ,//50MHz时钟输入
        input   wire        rst_n         ,
        
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
    
    
    //时钟模块相关连线
    wire        clk_fifo       ; //FIFO读写时钟
    wire        clk_ddr        ; //提供给DDR MIG的参考时钟
    wire        locked         ;
    wire        locked_rst_n   ;
    
    //ddr_interface相关连线
    //关键信号线, 不进行在线调试时使用下面这一段
/*  wire        wr_en          ; //写FIFO写请求
    wire [15:0] wr_data        ; //写FIFO写数据 
    wire        rd_mem_enable  ; //读存储器使能,防止存储器未写先读
    wire        rd_en          ; //读FIFO读请求
    wire [15:0] rd_data        ; //读FIFO读数据
    wire        rd_valid       ; //读FIFO有效标志,高电平代表当前处理的数据有效
    wire        calib_done     ; //DDR3初始化完成 */
    
    //进行ILA在线调试时, 使用这一段代码
    (*mark_debug="true", dont_touch="true"*)wire        wr_en          ; //写FIFO写请求
    (*mark_debug="true", dont_touch="true"*)wire [15:0] wr_data        ; //写FIFO写数据 
    (*mark_debug="true", dont_touch="true"*)wire        rd_mem_enable  ; //读存储器使能,防
    (*mark_debug="true", dont_touch="true"*)wire        rd_en          ; //读FIFO读请求
    (*mark_debug="true", dont_touch="true"*)wire [15:0] rd_data        ; //读FIFO读数据
    (*mark_debug="true", dont_touch="true"*)wire        rd_valid       ; //读FIFO有效标志   
    (*mark_debug="true", dont_touch="true"*)wire        calib_done     ; //DDR3初始化完成    
    
    wire        ui_clk         ; //MIG IP核输出的用户时钟, 用作AXI控制器时钟
    wire        ui_rst         ; //MIG IP核输出的复位信号, 高电平有效
       
    
    //测试数据生成模块
    testdata_gen_valid testdata_gen_valid_inst(
        .clk             (clk_fifo        ),  //和FIFO时钟保持一致
        .rst_n           (locked_rst_n    ),
        .calib_done      (calib_done      ),  //DDR3初始化完成标志
            
        //写端口   
        .wr_data         (wr_data         ),   //向写FIFO中写入的数据
        .wr_en           (wr_en           ),   //写FIFO写使能
        
        //读端口
        .rd_en           (rd_en           ),   //读FIFO读使能
        .rd_mem_enable   (rd_mem_enable   ),   //读存储器使能, 为高时才能从DDR3 SDRAM中读取数据
        .rd_valid        (rd_valid        )    //读有效信号, 为高时代表读取的数据有效
        
    );
    
    
    
      //时钟生成模块,产生FIFO读写时钟及AXI读写主机工作时钟
      clk_gen clk_gen_inst(
        .clk_ddr    (clk_ddr    ),     
        .clk_fifo   (clk_fifo   ),   
        // Status and control signals
        .reset      (~rst_n     ), 
        .locked     (locked     ),     
        // Clock in ports
        .clk_in1    (clk        )      //50MHz时钟输入
    ); 
    
    assign locked_rst_n = rst_n & locked;
    
    
    //DDR3接口模块
    ddr_interface ddr_interface_inst(
        .clk                 (clk_ddr             ), //DDR3时钟, 也就是DDR3 MIG IP核参考时钟
        .rst_n               (locked_rst_n        ), 
                    
        //用户端       
        .wr_clk              (clk_fifo            ), //写FIFO写时钟
        .wr_rst              (~locked_rst_n       ), //写复位
        .wr_beg_addr         (WR_BEG_ADDR         ), //写起始地址
        .wr_end_addr         (WR_END_ADDR         ), //写终止地址
        .wr_burst_len        (WR_BURST_LEN        ), //写突发长度
        .wr_en               (wr_en               ), //写FIFO写请求
        .wr_data             (wr_data             ), //写FIFO写数据 
        .rd_clk              (clk_fifo            ), //读FIFO读时钟
        .rd_rst              (~locked_rst_n       ), //读复位
        .rd_mem_enable       (rd_mem_enable       ), //读存储器使能,防止存储器未写先读
        .rd_beg_addr         (RD_BEG_ADDR         ), //读起始地址
        .rd_end_addr         (RD_END_ADDR         ), //读终止地址
        .rd_burst_len        (RD_BURST_LEN        ), //读突发长度
        .rd_en               (rd_en               ), //读FIFO读请求
        .rd_data             (rd_data             ), //读FIFO读数据
        .rd_valid            (rd_valid            ), //读FIFO有效标志,高电平代表当前处理的数据有效
        .ui_clk              (ui_clk              ), //MIG IP核输出的用户时钟, 用作AXI控制器时钟
        .ui_rst              (ui_rst              ), //MIG IP核输出的复位信号, 高电平有效
        .calib_done          (calib_done          ), //DDR3初始化完成
        
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
