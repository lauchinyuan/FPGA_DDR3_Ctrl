`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/11 10:02:24
// Module Name: wr_multichan_interface
// Description: DDR多通道写接口
// 用户写接口 <---> 多通道写控制器wr_channel_ctrl <---> 写仲裁器mulchan_wr_arbiter <--> AXI写主机 --> AXI总线接口
//////////////////////////////////////////////////////////////////////////////////


module wr_multichan_interface
#(parameter FIFO_WR_WIDTH           = 'd32           , //写FIFO在用户端操作的位宽
            AXI_WIDTH               = 'd64           , //AXI总线数据位宽
            //写FIFO相关参数
            WR_FIFO_RAM_DEPTH       = 'd2048         , //写FIFO内部RAM存储器深度
            WR_FIFO_RAM_ADDR_WIDTH  = 'd11           , //写FIFO内部RAM读写地址宽度, log2(WR_FIFO_RAM_DEPTH)
            WR_FIFO_WR_IND          = 'd1            , //写FIFO单次写操作访问的ram_mem单元个数 FIFO_WR_WIDTH/WR_FIFO_RAM_WIDTH
            WR_FIFO_RD_IND          = 'd2            , //写FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/WR_FIFO_RAM_ADDR_WIDTH        
            WR_FIFO_RAM_WIDTH       = FIFO_WR_WIDTH  , //写FIFO RAM存储器的位宽
            WR_FIFO_WR_L2           = 'd0            , //log2(WR_FIFO_WR_IND)
            WR_FIFO_RD_L2           = 'd1            , //log2(WR_FIFO_RD_IND)
            WR_FIFO_RAM_RD2WR       = 'd2            , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1 

            AXI_WSTRB_W             = AXI_WIDTH >> 3 
)
(

        input   wire                        clk             , //AXI主机读写时钟
        input   wire                        rst_n           ,  
        //用户端               
        input   wire                        wr_clk          , //写FIFO写时钟
        input   wire                        wr_rst          , //写复位, 高电平有效
        input   wire [29:0]                 wr_beg_addr0    , //写通道0写起始地址
        input   wire [29:0]                 wr_beg_addr1    , //写通道1写起始地址
        input   wire [29:0]                 wr_beg_addr2    , //写通道2写起始地址
        input   wire [29:0]                 wr_beg_addr3    , //写通道3写起始地址
        input   wire [29:0]                 wr_end_addr0    , //写通道0写终止地址
        input   wire [29:0]                 wr_end_addr1    , //写通道1写终止地址
        input   wire [29:0]                 wr_end_addr2    , //写通道2写终止地址
        input   wire [29:0]                 wr_end_addr3    , //写通道3写终止地址
        input   wire [7:0]                  wr_burst_len0   , //写通道0写突发长度
        input   wire [7:0]                  wr_burst_len1   , //写通道1写突发长度
        input   wire [7:0]                  wr_burst_len2   , //写通道2写突发长度
        input   wire [7:0]                  wr_burst_len3   , //写通道3写突发长度
        input   wire                        wr_en0          , //写通道0写请求
        input   wire                        wr_en1          , //写通道1写请求
        input   wire                        wr_en2          , //写通道2写请求
        input   wire                        wr_en3          , //写通道3写请求
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data0        , //写通道0写入数据
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data1        , //写通道1写入数据
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data2        , //写通道2写入数据
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data3        , //写通道3写入数据
        
        //AXI写相关通道线
        //AXI4写地址通道
        output  wire [3:0]                  m_axi_awid      , 
        output  wire [29:0]                 m_axi_awaddr    ,
        output  wire [7:0]                  m_axi_awlen     , //突发传输长度
        output  wire [2:0]                  m_axi_awsize    , //突发传输大小(Byte)
        output  wire [1:0]                  m_axi_awburst   , //突发类型
        output  wire                        m_axi_awlock    , 
        output  wire [3:0]                  m_axi_awcache   , 
        output  wire [2:0]                  m_axi_awprot    ,
        output  wire [3:0]                  m_axi_awqos     ,
        output  wire                        m_axi_awvalid   , //写地址valid
        input   wire                        m_axi_awready   , //从机发出的写地址ready
            
        //写数据通道 
        output  wire [AXI_WIDTH-1:0]        m_axi_wdata     , //写数据
        output  wire [AXI_WSTRB_W-1:0]      m_axi_wstrb     , //写数据有效字节线
        output  wire                        m_axi_wlast     , //最后一个数据标志
        output  wire                        m_axi_wvalid    , //写数据有效标志
        input   wire                        m_axi_wready    , //从机发出的写数据ready
            
        //写响应通道 
        input   wire [3:0]                  m_axi_bid       ,
        input   wire [1:0]                  m_axi_bresp     , //响应信号,表征写传输是否成功
        input   wire                        m_axi_bvalid    , //响应信号valid标志
        output  wire                        m_axi_bready      //主机响应ready信号        
    );
    
    //写通道控制器 <-->  AXI写主机
    wire                        axi_writing     ; //AXI主机写正在进行
    wire                        axi_wr_done     ; //AXI主机完成一次写操作     

    //写通道控制器 <-->  写通道仲裁器端
    wire [3:0]                  wr_grant        ; //仲裁器发来的授权
    wire [3:0]                  wr_req          ; //发送到仲裁器的写请求
    wire [29:0]                 wr_addr[3:0]    ; //发送到仲裁器的写地址
    wire [7:0]                  wr_len[3:0]     ; //发送到仲裁器的写突发长度  
    wire [AXI_WIDTH-1:0]        wr_data[3:0]    ; //发送到仲裁器的写数据

    //写通道仲裁器 <-->  AXI写主机
    wire                        axi_wr_start    ; //仲裁后有效的写请求
    wire [29:0]                 axi_wr_addr     ; //仲裁后有效的写地址输出
    wire [7:0]                  axi_wr_len      ; //仲裁后有效的写突发长度
    wire [AXI_WIDTH-1:0]        axi_wr_data     ; //从写FIFO中读取的数据,写入AXI写主机    

    //通道0控制器
    wr_channel_ctrl
    #(.FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ), 
      .AXI_WIDTH               (AXI_WIDTH               ), 
       //写FIFO相关参数        
      .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), 
      .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), 
      .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), 
      .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), 
      .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), 
      .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), 
      .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), 
      .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  
    )
    wr_channel_ctrl_inst0
    ( 
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
        
        //用户端                   
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位,模块中是同步复位
        .wr_beg_addr     (wr_beg_addr0    ), //写起始地址
        .wr_end_addr     (wr_end_addr0    ), //写终止地址
        .wr_burst_len    (wr_burst_len0   ), //写突发长度
        .wr_en           (wr_en0          ), //写FIFO写请求
        .fifo_wr_data    (wr_data0        ), //写FIFO写数据 
        
        //AXI写主机端
        .axi_writing     (axi_writing     ), //AXI主机写正在进行
        .axi_wr_done     (axi_wr_done     ), //AXI主机完成一次写操作     

        //写通道仲裁器端
        .wr_grant        (wr_grant[0]     ), //仲裁器发来的授权
        .wr_req          (wr_req[0]       ), //发送到仲裁器的写请求
        .wr_addr         (wr_addr[0]      ), //发送到仲裁器的写地址
        .wr_len          (wr_len[0]       ), //发送到仲裁器的写突发长度
        .wr_data         (wr_data[0]      )  //从写FIFO中读取的数据,写入AXI写主机
    );   

    //通道1控制器
    wr_channel_ctrl
    #(.FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ), 
      .AXI_WIDTH               (AXI_WIDTH               ), 
       //写FIFO相关参数        
      .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), 
      .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), 
      .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), 
      .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), 
      .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), 
      .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), 
      .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), 
      .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  
    )
    wr_channel_ctrl_inst1
    ( 
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
        
        //用户端                   
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位,模块中是同步复位
        .wr_beg_addr     (wr_beg_addr1    ), //写起始地址
        .wr_end_addr     (wr_end_addr1    ), //写终止地址
        .wr_burst_len    (wr_burst_len1   ), //写突发长度
        .wr_en           (wr_en1          ), //写FIFO写请求
        .fifo_wr_data    (wr_data1        ), //写FIFO写数据 
        
        //AXI写主机端
        .axi_writing     (axi_writing     ), //AXI主机写正在进行
        .axi_wr_done     (axi_wr_done     ), //AXI主机完成一次写操作     

        //写通道仲裁器端
        .wr_grant        (wr_grant[1]     ), //仲裁器发来的授权
        .wr_req          (wr_req[1]       ), //发送到仲裁器的写请求
        .wr_addr         (wr_addr[1]      ), //发送到仲裁器的写地址
        .wr_len          (wr_len[1]       ), //发送到仲裁器的写突发长度
        .wr_data         (wr_data[1]      )  //从写FIFO中读取的数据,写入AXI写主机
    );   

    //通道2控制器
    wr_channel_ctrl
    #(.FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ), 
      .AXI_WIDTH               (AXI_WIDTH               ), 
       //写FIFO相关参数        
      .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), 
      .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), 
      .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), 
      .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), 
      .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), 
      .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), 
      .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), 
      .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  
    )
    wr_channel_ctrl_inst2
    ( 
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
        
        //用户端                   
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位,模块中是同步复位
        .wr_beg_addr     (wr_beg_addr2    ), //写起始地址
        .wr_end_addr     (wr_end_addr2    ), //写终止地址
        .wr_burst_len    (wr_burst_len2   ), //写突发长度
        .wr_en           (wr_en2          ), //写FIFO写请求
        .fifo_wr_data    (wr_data2        ), //写FIFO写数据 
        
        //AXI写主机端
        .axi_writing     (axi_writing     ), //AXI主机写正在进行
        .axi_wr_done     (axi_wr_done     ), //AXI主机完成一次写操作     

        //写通道仲裁器端
        .wr_grant        (wr_grant[2]     ), //仲裁器发来的授权
        .wr_req          (wr_req[2]       ), //发送到仲裁器的写请求
        .wr_addr         (wr_addr[2]      ), //发送到仲裁器的写地址
        .wr_len          (wr_len[2]       ), //发送到仲裁器的写突发长度
        .wr_data         (wr_data[2]      )  //从写FIFO中读取的数据,写入AXI写主机
    );   

    //通道3控制器
    wr_channel_ctrl
    #(.FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ), 
      .AXI_WIDTH               (AXI_WIDTH               ), 
       //写FIFO相关参数        
      .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), 
      .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), 
      .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), 
      .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), 
      .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), 
      .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), 
      .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), 
      .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  
    )
    wr_channel_ctrl_inst3
    ( 
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
        
        //用户端                   
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位,模块中是同步复位
        .wr_beg_addr     (wr_beg_addr3    ), //写起始地址
        .wr_end_addr     (wr_end_addr3    ), //写终止地址
        .wr_burst_len    (wr_burst_len3   ), //写突发长度
        .wr_en           (wr_en3          ), //写FIFO写请求
        .fifo_wr_data    (wr_data3        ), //写FIFO写数据 
        
        //AXI写主机端
        .axi_writing     (axi_writing     ), //AXI主机写正在进行
        .axi_wr_done     (axi_wr_done     ), //AXI主机完成一次写操作     

        //写通道仲裁器端
        .wr_grant        (wr_grant[3]     ), //仲裁器发来的授权
        .wr_req          (wr_req[3]       ), //发送到仲裁器的写请求
        .wr_addr         (wr_addr[3]      ), //发送到仲裁器的写地址
        .wr_len          (wr_len[3]       ), //发送到仲裁器的写突发长度
        .wr_data         (wr_data[3]      )  //从写FIFO中读取的数据,写入AXI写主机
    );  

    //写通道仲裁器
    multichannel_wr_arbiter multichannel_wr_arbiter(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        
        //不同写控制器输入的控制信号
        .wr_req          (wr_req          ), //wr_req[i]代表写通道i的写请求
        .wr_addr0        (wr_addr[0]      ), //写通道0发来的写地址
        .wr_addr1        (wr_addr[1]      ), //写通道1发来的写地址
        .wr_addr2        (wr_addr[2]      ), //写通道2发来的写地址
        .wr_addr3        (wr_addr[3]      ), //写通道3发来的写地址
        
        .wr_len0         (wr_len[0]       ), //通道0发来的写突发长度
        .wr_len1         (wr_len[1]       ), //通道1发来的写突发长度
        .wr_len2         (wr_len[2]       ), //通道2发来的写突发长度
        .wr_len3         (wr_len[3]       ), //通道3发来的写突发长度
        
        .wr_data0        (wr_data[0]      ), //通道0发来的写数据
        .wr_data1        (wr_data[1]      ), //通道1发来的写数据
        .wr_data2        (wr_data[2]      ), //通道2发来的写数据
        .wr_data3        (wr_data[3]      ), //通道3发来的写数据
        
        //发给各通道写控制器的写授权
        .wr_grant        (wr_grant        ), //wr_grant[i]代表写通道i的写授权
        
        //AXI写主机输入信号
        .wr_done         (axi_wr_done     ), //AXI写主机送来的一次突发传输完成标志
        
        //发送到AXI写主机的仲裁结果
        .axi_wr_start    (axi_wr_start    ), //仲裁后有效的写请求
        .axi_wr_addr     (axi_wr_addr     ), //仲裁后有效的写地址输出
        .axi_wr_data     (axi_wr_data     ), //从写FIFO中读取的数据,写入AXI写主机
        .axi_wr_len      (axi_wr_len      )  //仲裁后有效的写突发长度
    ); 

    //AXI写主机
    axi_master_wr
    #(.AXI_WIDTH     (AXI_WIDTH     ),  //AXI总线读写数据位宽
      .AXI_AXSIZE    (3'b011        ),  //AXI总线的axi_axsize, 需要与AXI_WIDTH对应
      .AXI_WSTRB_W   (AXI_WIDTH>>3  ))  //axi_wstrb的位宽, AXI_WIDTH/8 
    axi_master_wr_inst      
    (
        //用户端
        .clk              (clk            ),
        .rst_n            (rst_n          ),
        .wr_start         (axi_wr_start   ), //开始写信号
        .wr_addr          (axi_wr_addr    ), //写首地址
        .wr_data          (axi_wr_data    ),
        .wr_len           (axi_wr_len     ), //突发传输长度
        .wr_done          (axi_wr_done    ), //写完成标志
        .m_axi_w_handshake(axi_writing    ), //写通道成功握手
        .wr_ready         (               ), //写准备信号,拉高时可以发起wr_start
        
        //AXI4写地址通道
        .m_axi_awid      (m_axi_awid      ), 
        .m_axi_awaddr    (m_axi_awaddr    ),
        .m_axi_awlen     (m_axi_awlen     ), //突发传输长度
        .m_axi_awsize    (m_axi_awsize    ), //突发传输大小(Byte)
        .m_axi_awburst   (m_axi_awburst   ), //突发类型
        .m_axi_awlock    (m_axi_awlock    ), 
        .m_axi_awcache   (m_axi_awcache   ), 
        .m_axi_awprot    (m_axi_awprot    ),
        .m_axi_awqos     (m_axi_awqos     ),
        .m_axi_awvalid   (m_axi_awvalid   ), //写地址valid
        .m_axi_awready   (m_axi_awready   ), //从机发出的写地址ready
        
        //写数据通道
        .m_axi_wdata     (m_axi_wdata     ), //写数据
        .m_axi_wstrb     (m_axi_wstrb     ), //写数据有效字节线
        .m_axi_wlast     (m_axi_wlast     ), //最后一个数据标志
        .m_axi_wvalid    (m_axi_wvalid    ), //写数据有效标志
        .m_axi_wready    (m_axi_wready    ), //从机发出的写数据ready
        
        //写响应通道
        .m_axi_bid       (m_axi_bid       ),
        .m_axi_bresp     (m_axi_bresp     ), //响应信号,表征写传输是否成功
        .m_axi_bvalid    (m_axi_bvalid    ), //响应信号valid标志
        .m_axi_bready    (m_axi_bready    )  //主机响应ready信号
    );     
endmodule
