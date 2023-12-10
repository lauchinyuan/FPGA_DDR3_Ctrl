`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/09 18:45:41
// Module Name: rd_multichan_interface
// Description: DDR多通道读接口
// 用户读接口 <---> 多通道读控制器rd_channel_ctrl <---> 读仲裁器mulchan_rd_arbiter <--> AXI读主机 --> AXI总线接口
//////////////////////////////////////////////////////////////////////////////////


module rd_multichan_interface
    #(parameter FIFO_RD_WIDTH           = 'd32              , //读FIFO在用户端操作的位宽
                AXI_WIDTH               = 'd64              , //AXI总线数据位宽
                                                            
                //读FIFO相关参数                            
                RD_FIFO_RAM_DEPTH       = 'd2048            , //读FIFO内部RAM存储器深度
                RD_FIFO_RAM_ADDR_WIDTH  = 'd11              , //读FIFO内部RAM读写地址宽度, log2(RD_FIFO_RAM_DEPTH)
                RD_FIFO_WR_IND          = 'd2               , //读FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/RD_FIFO_RAM_WIDTH
                RD_FIFO_RD_IND          = 'd1               , //读FIFO单次读操作访问的ram_mem单元个数 FIFO_RD_WIDTH/RD_FIFO_RAM_ADDR_WIDTH        
                RD_FIFO_RAM_WIDTH       = FIFO_RD_WIDTH     , //读FIFO RAM存储器的位宽
                RD_FIFO_WR_L2           = 'd1               , //log2(RD_FIFO_WR_IND)
                RD_FIFO_RD_L2           = 'd0               , //log2(RD_FIFO_RD_IND)
                RD_FIFO_RAM_RD2WR       = 'd1                 //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1  
                )
    (
        input   wire                        clk             , //AXI主机读写时钟
        input   wire                        rst_n           ,   
                        
        //用户端               
        input   wire                        rd_clk          , //读FIFO读时钟
        input   wire                        rd_rst          , //读复位, 高电平有效
        input   wire                        rd_mem_enable   , //读存储器使能, 防止存储器未写先读
        input   wire [29:0]                 rd_beg_addr0    , //读通道0读起始地址
        input   wire [29:0]                 rd_beg_addr1    , //读通道1读起始地址
        input   wire [29:0]                 rd_beg_addr2    , //读通道2读起始地址
        input   wire [29:0]                 rd_beg_addr3    , //读通道3读起始地址
        input   wire [29:0]                 rd_end_addr0    , //读通道0读终止地址
        input   wire [29:0]                 rd_end_addr1    , //读通道1读终止地址
        input   wire [29:0]                 rd_end_addr2    , //读通道2读终止地址
        input   wire [29:0]                 rd_end_addr3    , //读通道3读终止地址
        input   wire [7:0]                  rd_burst_len0   , //读通道0读突发长度
        input   wire [7:0]                  rd_burst_len1   , //读通道1读突发长度
        input   wire [7:0]                  rd_burst_len2   , //读通道2读突发长度
        input   wire [7:0]                  rd_burst_len3   , //读通道3读突发长度
        input   wire                        rd_en0          , //读通道0读请求
        input   wire                        rd_en1          , //读通道1读请求
        input   wire                        rd_en2          , //读通道2读请求
        input   wire                        rd_en3          , //读通道3读请求
        
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data0        , //读通道0读出数据
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data1        , //读通道1读出数据
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data2        , //读通道2读出数据
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data3        , //读通道3读出数据
        output  wire                        rd_valid0       , //读通道0FIFO可读标志          
        output  wire                        rd_valid1       , //读通道1FIFO可读标志          
        output  wire                        rd_valid2       , //读通道2FIFO可读标志          
        output  wire                        rd_valid3       , //读通道3FIFO可读标志      

        //MIG IP核 AXI接口(连接至AXI从机)
        //AXI4读地址通道
        output  wire [3:0]                  m_axi_arid      , 
        output  wire [29:0]                 m_axi_araddr    ,
        output  wire [7:0]                  m_axi_arlen     , //突发传输长度
        output  wire [2:0]                  m_axi_arsize    , //突发传输大小(Byte)
        output  wire [1:0]                  m_axi_arburst   , //突发类型
        output  wire                        m_axi_arlock    , 
        output  wire [3:0]                  m_axi_arcache   , 
        output  wire [2:0]                  m_axi_arprot    ,
        output  wire [3:0]                  m_axi_arqos     ,
        output  wire                        m_axi_arvalid   , //读地址valid
        input   wire                        m_axi_arready   , //从机准备接收读地址
            
        //读数据通道 
        input   wire [AXI_WIDTH-1:0]        m_axi_rdata     , //读数据
        input   wire [1:0]                  m_axi_rresp     , //收到的读响应
        input   wire                        m_axi_rlast     , //最后一个数据标志
        input   wire                        m_axi_rvalid    , //读数据有效标志
        output  wire                        m_axi_rready      //主机发出的读数据ready
    );
    
    //中间连线
    //读通道控制<--->读通道仲裁器  
    wire[3:0]                   rd_grant            ; //仲裁器发来的授权
    wire[3:0]                   rd_req              ; //发送到仲裁器的读请求
    wire[29:0]                  rd_addr    [3:0]    ; //发送到仲裁器的读地址
    wire[7:0]                   rd_len     [3:0]    ; //发送到仲裁器的读突发长度

    //读仲裁器<---->AXI读主机
    wire                        axi_rd_start        ; //仲裁后有效的读请求
    wire[29:0]                  axi_rd_addr         ; //仲裁后有效的读地址输出
    wire[7:0]                   axi_rd_len          ; //仲裁后有效的读突发长度
    
    //读通道控制器<--->AXI读主机端           
    wire                        axi_reading         ; //AXI主机读正在进行
    wire [AXI_WIDTH-1:0]        axi_rd_data         ; //从AXI读主机读到的数据,写入读FIFO
    wire                        axi_rd_done         ; //AXI主机完成一次写操作
    
    
    //例化多个读控制器rd_channel_ctrl
    rd_channel_ctrl
    #(  .FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ), 
        .AXI_WIDTH               (AXI_WIDTH               ), 
                        
        //读FIFO相关参数 
        .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), 
        .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), 
        .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), 
        .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), 
        .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), 
        .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), 
        .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), 
        .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )   
    )
    rd_channel_ctrl_inst0
    (
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
                        
        //用户端               
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr0    ), //读起始地址
        .rd_end_addr     (rd_end_addr0    ), //读终止地址
        .rd_burst_len    (rd_burst_len0   ), //读突发长度
        .rd_en           (rd_en0          ), //读FIFO读请求
        .rd_data         (rd_data0        ), //读FIFO读数据
        .rd_valid        (rd_valid0       ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出    
    
        //AXI读主机端           
        .axi_reading     (axi_reading     ), //AXI主机读正在进行
        .axi_rd_data     (axi_rd_data     ), //从AXI读主机读到的数据,写入读FIFO
        .axi_rd_done     (axi_rd_done     ), //AXI主机完成一次写操作
        
        //读通道仲裁器端
        .rd_grant        (rd_grant[0]     ), //仲裁器发来的授权
        .rd_req          (rd_req[0]       ), //发送到仲裁器的读请求
        .rd_addr         (rd_addr[0]      ), //发送到仲裁器的读地址
        .rd_len          (rd_len[0]       )  //发送到仲裁器的读突发长度
    
    ); 


    
    rd_channel_ctrl
    #(  .FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ), 
        .AXI_WIDTH               (AXI_WIDTH               ), 
                        
        //读FIFO相关参数 
        .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), 
        .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), 
        .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), 
        .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), 
        .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), 
        .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), 
        .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), 
        .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )   
    )
    rd_channel_ctrl_inst1
    (
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
                        
        //用户端               
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr1    ), //读起始地址
        .rd_end_addr     (rd_end_addr1    ), //读终止地址
        .rd_burst_len    (rd_burst_len1   ), //读突发长度
        .rd_en           (rd_en1          ), //读FIFO读请求
        .rd_data         (rd_data1        ), //读FIFO读数据
        .rd_valid        (rd_valid1       ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出    
    
        //AXI读主机端           
        .axi_reading     (axi_reading     ), //AXI主机读正在进行
        .axi_rd_data     (axi_rd_data     ), //从AXI读主机读到的数据,写入读FIFO
        .axi_rd_done     (axi_rd_done     ), //AXI主机完成一次写操作
        
        //读通道仲裁器端
        .rd_grant        (rd_grant[1]     ), //仲裁器发来的授权
        .rd_req          (rd_req[1]       ), //发送到仲裁器的读请求
        .rd_addr         (rd_addr[1]      ), //发送到仲裁器的读地址
        .rd_len          (rd_len[1]       )  //发送到仲裁器的读突发长度
    
    ); 

    rd_channel_ctrl
    #(  .FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ), 
        .AXI_WIDTH               (AXI_WIDTH               ), 
                        
        //读FIFO相关参数 
        .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), 
        .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), 
        .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), 
        .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), 
        .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), 
        .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), 
        .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), 
        .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )     
    )
    rd_channel_ctrl_inst2
    (
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
                        
        //用户端               
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr2    ), //读起始地址
        .rd_end_addr     (rd_end_addr2    ), //读终止地址
        .rd_burst_len    (rd_burst_len2   ), //读突发长度
        .rd_en           (rd_en2          ), //读FIFO读请求
        .rd_data         (rd_data2        ), //读FIFO读数据
        .rd_valid        (rd_valid2       ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出    
    
        //AXI读主机端           
        .axi_reading     (axi_reading     ), //AXI主机读正在进行
        .axi_rd_data     (axi_rd_data     ), //从AXI读主机读到的数据,写入读FIFO
        .axi_rd_done     (axi_rd_done     ), //AXI主机完成一次写操作
        
        //读通道仲裁器端
        .rd_grant        (rd_grant[2]     ), //仲裁器发来的授权
        .rd_req          (rd_req[2]       ), //发送到仲裁器的读请求
        .rd_addr         (rd_addr[2]      ), //发送到仲裁器的读地址
        .rd_len          (rd_len[2]       )  //发送到仲裁器的读突发长度
    
    ); 


    rd_channel_ctrl
    #(  .FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ), 
        .AXI_WIDTH               (AXI_WIDTH               ), 
                        
        //读FIFO相关参数 
        .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), 
        .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), 
        .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), 
        .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), 
        .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), 
        .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), 
        .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), 
        .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )  
    )
    rd_channel_ctrl_inst3
    (
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
                        
        //用户端               
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr3    ), //读起始地址
        .rd_end_addr     (rd_end_addr3    ), //读终止地址
        .rd_burst_len    (rd_burst_len3   ), //读突发长度
        .rd_en           (rd_en3          ), //读FIFO读请求
        .rd_data         (rd_data3        ), //读FIFO读数据
        .rd_valid        (rd_valid3       ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出    
    
        //AXI读主机端           
        .axi_reading     (axi_reading     ), //AXI主机读正在进行
        .axi_rd_data     (axi_rd_data     ), //从AXI读主机读到的数据,写入读FIFO
        .axi_rd_done     (axi_rd_done     ), //AXI主机完成一次写操作
        
        //读通道仲裁器端
        .rd_grant        (rd_grant[3]     ), //仲裁器发来的授权
        .rd_req          (rd_req[3]       ), //发送到仲裁器的读请求
        .rd_addr         (rd_addr[3]      ), //发送到仲裁器的读地址
        .rd_len          (rd_len[3]       )  //发送到仲裁器的读突发长度
    
    ); 
    
    //读仲裁器
    multichannel_rd_arbiter multichannel_rd_arbiter_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        
        //不同读控制器输入的控制信号
        .rd_req          (rd_req          ), //rd_req[i]代表读通道i的读请求
        .rd_addr0        (rd_addr[0]      ), //读通道0发来的读地址
        .rd_addr1        (rd_addr[1]      ), //读通道1发来的读地址
        .rd_addr2        (rd_addr[2]      ), //读通道2发来的读地址
        .rd_addr3        (rd_addr[3]      ), //读通道3发来的读地址
        
        .rd_len0         (rd_len[0]       ), //通道0发来的读突发长度
        .rd_len1         (rd_len[1]       ), //通道1发来的读突发长度
        .rd_len2         (rd_len[2]       ), //通道2发来的读突发长度
        .rd_len3         (rd_len[3]       ), //通道3发来的读突发长度
        
        //发给各通道读控制器的读授权
        .rd_grant        (rd_grant        ), //rd_grant[i]代表读通道i的读授权
        
        //AXI读主机输入信号
        .rd_done         (axi_rd_done     ), //AXI读主机送来的一次突发传输完成标志
        
        //发送到AXI读主机的仲裁结果
        .axi_rd_start    (axi_rd_start    ), //仲裁后有效的读请求
        .axi_rd_addr     (axi_rd_addr     ), //仲裁后有效的读地址输出
        .axi_rd_len      (axi_rd_len      )  //仲裁后有效的读突发长度
    );
   
   
    //AXI读主机
    axi_master_rd
    #(.AXI_WIDTH(AXI_WIDTH),  //AXI总线读写数据位宽
      .AXI_AXSIZE(3'b011 ) )  //AXI总线的axi_axsize, 需要与AXI_WIDTH对应
      axi_master_rd_inst
    (
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .rd_start         (axi_rd_start     ), //开始读信号
        .rd_addr          (axi_rd_addr      ), //读首地址
        .rd_data          (axi_rd_data      ), //读出的数据
        .rd_len           (axi_rd_len       ), //突发传输长度
        .rd_done          (axi_rd_done      ), //读完成标志
        .rd_ready         (                 ), //准备好读标志, 此处不用, 仲裁机制可以保证只有在axi_master ready时才可发出start信号
        .m_axi_r_handshake(axi_reading      ), //读通道成功握手, 也是读取数据有效标志
        
        //AXI4读地址通道
        .m_axi_arid       (m_axi_arid       ), 
        .m_axi_araddr     (m_axi_araddr     ),
        .m_axi_arlen      (m_axi_arlen      ), //突发传输长度
        .m_axi_arsize     (m_axi_arsize     ), //突发传输大小(Byte)
        .m_axi_arburst    (m_axi_arburst    ), //突发类型
        .m_axi_arlock     (m_axi_arlock     ), 
        .m_axi_arcache    (m_axi_arcache    ), 
        .m_axi_arprot     (m_axi_arprot     ),
        .m_axi_arqos      (m_axi_arqos      ),
        .m_axi_arvalid    (m_axi_arvalid    ), //读地址valid
        .m_axi_arready    (m_axi_arready    ), //从机准备接收读地址
        
        //读数据通道
        .m_axi_rdata      (m_axi_rdata      ), //读数据
        .m_axi_rresp      (m_axi_rresp      ), //收到的读响应
        .m_axi_rlast      (m_axi_rlast      ), //最后一个数据标志
        .m_axi_rvalid     (m_axi_rvalid     ), //读数据有效标志
        .m_axi_rready     (m_axi_rready     )  //主机发出的读数据ready
    );
    
    
endmodule
