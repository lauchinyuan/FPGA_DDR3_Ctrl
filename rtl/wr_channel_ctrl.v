`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/04 19:46:10
// Module Name: wr_channel_ctrl
// Description: 单一写通道控制器, 内部集成写FIFO
// 当FIFO内数据量足够时, 向多通道仲裁器mulchan_wr_arbiter发出写SDRAM请求
//////////////////////////////////////////////////////////////////////////////////


module wr_channel_ctrl
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
                WR_FIFO_RAM_RD2WR       = 'd2              //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1   
    )
    ( 
        input   wire                        clk             , //AXI主机读写时钟
        input   wire                        rst_n           ,   
        
        //用户端                   
        input   wire                        wr_clk          , //写FIFO写时钟
        input   wire                        wr_rst          , //写复位,模块中是同步复位
        input   wire [29:0]                 wr_beg_addr     , //写起始地址
        input   wire [29:0]                 wr_end_addr     , //写终止地址
        input   wire [7:0]                  wr_burst_len    , //写突发长度
        input   wire                        wr_en           , //写FIFO写请求
        input   wire [FIFO_WR_WIDTH-1:0]    fifo_wr_data    , //写FIFO写数据 
        
        //AXI写主机端
        input   wire                        axi_writing     , //AXI主机写正在进行
        input   wire                        axi_wr_done     , //AXI主机完成一次写操作     

        //写通道仲裁器端
        input   wire                        wr_grant        , //仲裁器发来的授权
        output  reg                         wr_req          , //发送到仲裁器的写请求
        output  reg  [29:0]                 wr_addr         , //发送到仲裁器的写地址
        output  wire [7:0]                  wr_len          , //发送到仲裁器的写突发长度
        output  wire [AXI_WIDTH-1:0]        wr_data           //从写FIFO中读取的数据,写入AXI写主机
    );
    
    
    
    //自定义FIFO参数计算
    parameter   WR_FIFO_WR_CNT_WIDTH = WR_FIFO_RAM_ADDR_WIDTH + 'd1 - WR_FIFO_WR_L2 , //写FIFO写端口计数器的位宽   
                WR_FIFO_RD_CNT_WIDTH = WR_FIFO_RAM_ADDR_WIDTH + 'd1 - WR_FIFO_RD_L2 ; //写FIFO读端口计数器的位宽    
    
    
    //FIFO数据数量计数器   
    wire [10:0]  cnt_wr_fifo_rdport     ;  //写FIFO读端口(对接AXI写主机)数据数量    
    
    //真实的写突发长度
    wire  [7:0] real_wr_len             ;  //真实的写突发长度,是wr_burst_len+1
    
    //突发地址增量, 每次进行一次连续突发传输地址的增量, 在外边计算, 方便后续复用
    wire  [29:0]burst_wr_addr_inc       ;
    
    //复位信号处理(异步复位同步释放)
    reg     rst_n_sync  ;  //同步释放处理后的rst_n
    reg     rst_n_d1    ;  //同步释放处理rst_n, 同步器第一级输出 
    

    //rst_n相对clk同步释放
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin  //异步复位
            rst_n_d1    <= 1'b0;
            rst_n_sync  <= 1'b0;
        end else begin
            rst_n_d1    <= 1'b1;
            rst_n_sync  <= rst_n_d1;
        end
    end
       
    //真实的读写突发长度
    assign real_wr_len = wr_burst_len + 8'd1;
    
    //突发地址增量, 右移3的
    assign burst_wr_addr_inc = real_wr_len * AXI_WIDTH >> 3;
    
    
    //向AXI主机发出的读写突发长度
    assign wr_len = wr_burst_len;  

    //wr_req
    //写请求信号
    always@(posedge clk or negedge rst_n_sync) begin
        if(!rst_n_sync) begin
            wr_req <= 1'b0;
        end else if(cnt_wr_fifo_rdport > real_wr_len) begin //fifo内的数据数量足够时拉高
            wr_req <= 1'b1;
        end else if(wr_grant) begin  //被授权后拉低写请求
            wr_req <= 1'b0;
        end else begin
            wr_req <= wr_req;
        end
    end 

   
    //wr_addr
    //写地址, 注意只有grant信号有效时才进行正常的地址自增
    always@(posedge clk or negedge rst_n_sync) begin
        if(!rst_n_sync) begin
            wr_addr <= wr_beg_addr;
        end else if(wr_rst) begin
            wr_addr <= wr_beg_addr;
        end else if(wr_grant && axi_wr_done && wr_addr > (wr_end_addr - {burst_wr_addr_inc[28:0], 1'b0} + 30'd1)) begin
        //每次写完成后判断是否超限, 下一个写首地址后续的空间已经不够再进行一次突发写操作, 位拼接的作用是×2
            wr_addr <= wr_beg_addr;
        end else if(wr_grant && axi_wr_done) begin
            wr_addr <= wr_addr + burst_wr_addr_inc;
        end else begin
            wr_addr <= wr_addr;
        end
    end    
    
    
    
    
    
    //写FIFO, 待写入SDRAM的数据先暂存于此
    //使用自定义异步FIFO
    async_fifo
    #(.RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), //内部RAM存储器深度
      .RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
      .WR_WIDTH        (FIFO_WR_WIDTH           ), //写数据位宽
      .RD_WIDTH        (AXI_WIDTH               ), //读数据位宽
      .WR_IND          (WR_FIFO_WR_IND          ), //单次写操作内部RAM地址增量, WR_WIDTH/RAM_WIDTH
      .RD_IND          (WR_FIFO_RD_IND          ), //单次读操作内部RAM地址增量, RD_WIDTH/RAM_WIDTH         
      .RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), //RAM单元的位宽
      .WR_L2           (WR_FIFO_WR_L2           ), //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
      .RD_L2           (WR_FIFO_RD_L2           ), //log2(RD_IND), 决定读地址有效低位
      .WR_CNT_WIDTH    (WR_FIFO_WR_CNT_WIDTH    ), //FIFO写端口计数器的位宽RAM_ADDR_WIDTH + 'd1 - WR_L2
      .RD_CNT_WIDTH    (WR_FIFO_RD_CNT_WIDTH    ), //FIFO读端口计数器的位宽RAM_ADDR_WIDTH + 'd1 - RD_L2  
      .RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1            
    )
    wr_fifo_inst
    (
        //写相关
        .wr_clk          (wr_clk                    ), //写端口时钟
        .wr_rst_n        (rst_n_sync                ),
        .wr_en           (wr_en                     ),
        .wr_data         (fifo_wr_data              ),
        .fifo_full       (                          ), //FIFO写满
        .wr_data_count   (                          ), //写端口数据个数,按写端口数据位宽计算
        //读相关       
        .rd_clk          (clk                       ), //读端口时钟是AXI主机时钟, AXI写主机读取数据
        .rd_rst_n        (rst_n_sync                ), 
        .rd_en           (axi_writing &  wr_grant   ), //axi_master_wr正在写时,从写FIFO中不断读出数据, 只有当被授权时才读出
        .rd_data         (wr_data                   ), //读出的数据作为AXI写主机的输入数据
        .fifo_empty      (                          ), //FIFO读空
        .rd_data_count   (cnt_wr_fifo_rdport        )  //写FIFO读端口(对接AXI写主机)数据数量
    );      
    
    
    
    
endmodule
