`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/18 21:49:34
// Module Name: axi_ddr_ctrl
// Description: AXI接口DDR控制顶层模块,集成AXI读主机、AXI写主机、AXI控制器(包含读写FIFO)
//////////////////////////////////////////////////////////////////////////////////


module axi_ddr_ctrl
    #(parameter FIFO_WR_WIDTH = 5'd16,  //用户端FIFO读写位宽
                FIFO_RD_WIDTH = 5'd16)
        (
        input   wire                        clk             , //AXI读写主机时钟
        input   wire                        rst_n           , 
                                
        //用户端                   
        input   wire                        wr_clk          , //写FIFO写时钟
        input   wire                        wr_rst          , //写复位
        input   wire [29:0]                 wr_beg_addr     , //写起始地址
        input   wire [29:0]                 wr_end_addr     , //写终止地址
        input   wire [7:0]                  wr_burst_len    , //写突发长度
        input   wire                        wr_en           , //写FIFO写请求
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data         , //写FIFO写数据 
        input   wire                        rd_clk          , //读FIFO读时钟
        input   wire                        rd_rst          , //读复位
        input   wire                        rd_mem_enable   , //读存储器使能,防止存储器未写先读
        input   wire [29:0]                 rd_beg_addr     , //读起始地址
        input   wire [29:0]                 rd_end_addr     , //读终止地址
        input   wire [7:0]                  rd_burst_len    , //读突发长度
        input   wire                        rd_en           , //读FIFO读请求
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data         , //读FIFO读数据
        output  wire                        rd_valid        , //读FIFO可读标志,表示读FIFO中有数据可以对外输出
                        
        //AXI总线             
        //AXI4写地址通道             
        input   wire [3:0]                  m_axi_awid      , 
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
        output  wire [63:0]                 m_axi_wdata     , //写数据
        output  wire [7:0]                  m_axi_wstrb     , //写数据有效字节线
        output  wire                        m_axi_wlast     , //最后一个数据标志
        output  wire                        m_axi_wvalid    , //写数据有效标志
        input   wire                        m_axi_wready    , //从机发出的写数据ready
                        
        //写响应通道             
        output  wire [3:0]                  m_axi_bid       ,
        input   wire [1:0]                  m_axi_bresp     , //响应信号,表征写传输是否成功
        input   wire                        m_axi_bvalid    , //响应信号valid标志
        output  wire                        m_axi_bready    , //主机响应ready信号
                        
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
        input   wire [63:0]                 m_axi_rdata     , //读数据
        input   wire [1:0]                  m_axi_rresp     , //收到的读响应
        input   wire                        m_axi_rlast     , //最后一个数据标志
        input   wire                        m_axi_rvalid    , //读数据有效标志
        output  wire                        m_axi_rready      //主机发出的读数据ready
    );
    
    //连线
    //AXI控制器到AXI写主机
    wire        axi_writing     ;
    wire        axi_wr_ready    ;
    wire        axi_wr_start    ;
    wire [63:0] axi_wr_data     ;
    wire [29:0] axi_wr_addr     ;
    wire [7:0]  axi_wr_len      ;
    wire        axi_wr_done     ;
    
    //读AXI主机
    wire        axi_reading     ;
    wire        axi_rd_ready    ;
    wire        axi_rd_start    ;
    wire [63:0] axi_rd_data     ;
    wire [29:0] axi_rd_addr     ;
    wire [7:0]  axi_rd_len      ;
    wire        axi_rd_done     ;
    
    //AXI控制器
    axi_ctrl 
    #(.FIFO_WR_WIDTH(FIFO_WR_WIDTH),  //用户端FIFO读写位宽
      .FIFO_RD_WIDTH(FIFO_RD_WIDTH))
      axi_ctrl_inst
    (
        .clk             (clk             ), //AXI读写主机时钟
        .rst_n           (rst_n           ), 
 
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位
        .wr_beg_addr     (wr_beg_addr     ), //写起始地址
        .wr_end_addr     (wr_end_addr     ), //写终止地址
        .wr_burst_len    (wr_burst_len    ), //写突发长度
        .wr_en           (wr_en           ), //写FIFO写请求
        .wr_data         (wr_data         ), //写FIFO写数据 
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能,防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr     ), //读起始地址
        .rd_end_addr     (rd_end_addr     ), //读终止地址
        .rd_burst_len    (rd_burst_len    ), //读突发长度
        .rd_en           (rd_en           ), //读FIFO读请求
        .rd_data         (rd_data         ), //读FIFO读数据
        .rd_valid        (rd_valid        ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出
        
        //写AXI主机
        .axi_writing     (axi_writing     ), //AXI主机写正在进行
        .axi_wr_ready    (axi_wr_ready    ), //AXI主机写准备好
        .axi_wr_start    (axi_wr_start    ), //AXI主机写请求
        .axi_wr_data     (axi_wr_data     ), //从写FIFO中读取的数据,写入AXI写主机
        .axi_wr_addr     (axi_wr_addr     ), //AXI主机写地址
        .axi_wr_len      (axi_wr_len      ), //AXI主机写突发长度
        .axi_wr_done     (axi_wr_done     ),
        
        //读AXI主机
        .axi_reading     (axi_reading     ), //AXI主机读正在进行
        .axi_rd_ready    (axi_rd_ready    ), //AXI主机读准备好
        .axi_rd_start    (axi_rd_start    ), //AXI主机读请求
        .axi_rd_data     (axi_rd_data     ), //从AXI读主机读到的数据,写入读FIFO
        .axi_rd_addr     (axi_rd_addr     ), //AXI主机读地址
        .axi_rd_len      (axi_rd_len      ), //AXI主机读突发长度   
        .axi_rd_done     (axi_rd_done     )
    );
    
    
    
    
    //AXI读主机
    axi_master_rd axi_master_rd_inst(
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .rd_start         (axi_rd_start     ), //开始读信号
        .rd_addr          (axi_rd_addr      ), //读首地址
        .rd_data          (axi_rd_data      ), //读出的数据
        .rd_len           (axi_rd_len       ), //突发传输长度
        .rd_done          (axi_rd_done      ), //读完成标志
        .rd_ready         (axi_rd_ready     ), //准备好读标志
        .m_axi_r_handshake(axi_reading      ), //读通道成功握手
        
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
    
    //AXI写主机
    axi_master_wr axi_master_wr_inst(
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .wr_start         (axi_wr_start     ), //开始写信号
        .wr_addr          (axi_wr_addr      ), //写首地址
        .wr_data          (axi_wr_data      ),
        .wr_len           (axi_wr_len       ), //突发传输长度
        .wr_done          (axi_wr_done      ), //写完成标志
        .m_axi_w_handshake(axi_writing      ), //写通道成功握手
        .wr_ready         (axi_wr_ready     ), //写准备信号,拉高时可以发起wr_start
        
        //AXI4写地址通道
        .m_axi_awid       (m_axi_awid       ), 
        .m_axi_awaddr     (m_axi_awaddr     ),
        .m_axi_awlen      (m_axi_awlen      ), //突发传输长度
        .m_axi_awsize     (m_axi_awsize     ), //突发传输大小(Byte)
        .m_axi_awburst    (m_axi_awburst    ), //突发类型
        .m_axi_awlock     (m_axi_awlock     ), 
        .m_axi_awcache    (m_axi_awcache    ), 
        .m_axi_awprot     (m_axi_awprot     ),
        .m_axi_awqos      (m_axi_awqos      ),
        .m_axi_awvalid    (m_axi_awvalid    ), //写地址valid
        .m_axi_awready    (m_axi_awready    ), //从机发出的写地址ready
                                            
        //写数据通道                        
        .m_axi_wdata      (m_axi_wdata      ), //写数据
        .m_axi_wstrb      (m_axi_wstrb      ), //写数据有效字节线
        .m_axi_wlast      (m_axi_wlast      ), //最后一个数据标志
        .m_axi_wvalid     (m_axi_wvalid     ), //写数据有效标志
        .m_axi_wready     (m_axi_wready     ), //从机发出的写数据ready
                                            
        //写响应通道                        
        .m_axi_bid        (m_axi_bid        ),
        .m_axi_bresp      (m_axi_bresp      ), //响应信号,表征写传输是否成功
        .m_axi_bvalid     (m_axi_bvalid     ), //响应信号valid标志
        .m_axi_bready     (m_axi_bready     )  //主机响应ready信号
    );
endmodule
