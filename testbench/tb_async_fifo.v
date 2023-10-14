`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/11 14:18:39
// Module Name: tb_async_fifo
// Description: testbench for async_fifo module 
//////////////////////////////////////////////////////////////////////////////////


module tb_async_fifo(

    );
    
/*     //参数(写位宽大于读位宽)
    parameter RAM_DEPTH       = 'd128                         , //内部RAM存储器深度
              RAM_ADDR_WIDTH  = 'd7                           , //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
              WR_WIDTH        = 'd16                          , //写数据位宽
              RD_WIDTH        = 'd8                           , //读数据位宽
              WR_IND          = 'd2                           , //单次写操作访问的ram_mem单元个数
              RD_IND          = 'd1                           , //单次读操作访问的ram_mem单元个数         
              RAM_WIDTH       = RD_WIDTH                      , //写端口数据位宽更小,使用写数据位宽作为RAM存储器的位宽
              WR_L2           = 'd1                           , //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
              RD_L2           = 'd0                           , //log2(RD_IND), 决定读地址有效低位
              WR_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - WR_L2  , //FIFO写端口计数器的位宽
              RD_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - RD_L2  , //FIFO读端口计数器的位宽  
              RAM_RD2WR       = 'd1                           , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1
              RAM_RD_WIDTH    = RAM_WIDTH * RAM_RD2WR         , //每个双端口RAM模块的读出数据位宽
              RAMS_RD_WIDTH   = WR_WIDTH * RAM_RD2WR          ; //多个RAM构成的RAM组合单次读出的数据位宽, 是写位宽的整数倍  */ 

    //参数(读写位宽相同)
/*     parameter RAM_DEPTH       = 'd128                         , //内部RAM存储器深度
              RAM_ADDR_WIDTH  = 'd7                           , //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
              WR_WIDTH        = 'd16                          , //写数据位宽
              RD_WIDTH        = 'd16                          , //读数据位宽
              WR_IND          = 'd2                           , //单次写操作访问的ram_mem单元个数
              RD_IND          = 'd2                           , //单次读操作访问的ram_mem单元个数         
              RAM_WIDTH       = 'd8                           , //写端口数据位宽更小,使用写数据位宽作为RAM存储器的位宽
              WR_L2           = 'd1                           , //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
              RD_L2           = 'd1                           , //log2(RD_IND), 决定读地址有效低位
              WR_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - WR_L2  , //FIFO写端口计数器的位宽
              RD_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - RD_L2  , //FIFO读端口计数器的位宽  
              RAM_RD2WR       = 'd1                           , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1
              RAM_RD_WIDTH    = RAM_WIDTH * RAM_RD2WR         , //每个双端口RAM模块的读出数据位宽
              RAMS_RD_WIDTH   = WR_WIDTH * RAM_RD2WR          ; //多个RAM构成的RAM组合单次读出的数据位宽, 是写位宽的整数倍  */
              
    //参数(读位宽大于写位宽)          
    parameter RAM_DEPTH       = 'd128                         , //内部RAM存储器深度
              RAM_ADDR_WIDTH  = 'd7                           , //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
              WR_WIDTH        = 'd16                          , //写数据位宽
              RD_WIDTH        = 'd32                          , //读数据位宽
              WR_IND          = 'd2                           , //单次写操作访问的ram_mem单元个数
              RD_IND          = 'd4                           , //单次读操作访问的ram_mem单元个数         
              RAM_WIDTH       = 'd8                           , //写端口数据位宽更小,使用写数据位宽作为RAM存储器的位宽
              WR_L2           = 'd1                           , //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
              RD_L2           = 'd2                           , //log2(RD_IND), 决定读地址有效低位
              WR_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - WR_L2  , //FIFO写端口计数器的位宽
              RD_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - RD_L2  , //FIFO读端口计数器的位宽  
              RAM_RD2WR       = 'd2                           ; //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1
              
    //连线
    //写相关
    reg                        wr_clk          ; //写端口时钟
    reg                        wr_rst_n        ; //写地址复位
    reg                        wr_en           ; //写使能
    reg [WR_WIDTH-1:0]         wr_data         ; //写数据
    wire                       fifo_full       ; //FIFO写满
    wire[WR_CNT_WIDTH-1:0]     wr_data_count   ; //写端口数据个数,按写端口数据位宽计算
    //读相关                                            
    reg                        rd_clk          ; //读端口时钟
    reg                        rd_rst_n        ; //读地址复位 
    reg                        rd_en           ; //读使能
    wire[RD_WIDTH-1:0]         rd_data         ; //读数据
    wire                       fifo_empty      ; //FIFO读空
    wire[RD_CNT_WIDTH-1:0]     rd_data_count   ; //读端口数据个数,按读端口数据位宽计算
    
    initial begin
        wr_clk = 1'b1;
        rd_clk = 1'b1;
        wr_rst_n <= 1'b0;
        rd_rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
    #20
        wr_rst_n <= 1'b1;
        rd_rst_n <= 1'b1;

        //读写同时进行的仿真
/*      wr_en <= 1'b1; 
    wait(wr_data_count >= 'd28); //数据量满足一定条件开始读
        rd_en <= 1'b1;
    wait(fifo_empty);
        rd_en <= 1'b0;  //读空后停止读
    wait(fifo_full);    //写满后停止写
        wr_en <= 1'b0;
        rd_en <= 1'b1;  //开始将FIFO读出 */
        
        //先写满, 再读取
        wr_en <= 1'b1;
        wait(fifo_full);
        wr_en <= 1'b0;
        rd_en <= 1'b1;
        wait(fifo_empty);
        rd_en <= 1'b0;
        
    end
    
    //wr_data
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            wr_data <= 'd0;
        end else if(wr_en) begin
            wr_data <= wr_data + 'd1;
        end else begin
            wr_data <= wr_data;
        end
    end
    
    always#5    wr_clk = ~wr_clk; //写时钟100MHz
    always#10   rd_clk = ~rd_clk; //读时钟50MHz

    
    async_fifo
    #(.RAM_DEPTH       (RAM_DEPTH       ), //内部RAM存储器深度
      .RAM_ADDR_WIDTH  (RAM_ADDR_WIDTH  ), //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
      .WR_WIDTH        (WR_WIDTH        ), //写数据位宽
      .RD_WIDTH        (RD_WIDTH        ), //读数据位宽
      .WR_IND          (WR_IND          ), //单次写操作访问的ram_mem单元个数
      .RD_IND          (RD_IND          ), //单次读操作访问的ram_mem单元个数         
      .RAM_WIDTH       (RAM_WIDTH       ), //写端口数据位宽更小,使用写数据位宽作为RAM存储器的位宽
      .WR_CNT_WIDTH    (WR_CNT_WIDTH    ), //FIFO写端口计数器的位宽
      .RD_CNT_WIDTH    (RD_CNT_WIDTH    ), //FIFO读端口计数器的位宽
      .WR_L2           (WR_L2           ), //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
      .RD_L2           (RD_L2           ), //log2(RD_IND), 决定读地址有效低位 
      .RAM_RD2WR       (RAM_RD2WR       )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1   
     )
    async_fifo_inst
    (
        //写相关
        .wr_clk          (wr_clk          ), //写端口时钟
        .wr_rst_n        (wr_rst_n        ), //写地址复位
        .wr_en           (wr_en           ), //写使能
        .wr_data         (wr_data         ), //写数据
        .fifo_full       (fifo_full       ), //FIFO写满
        .wr_data_count   (wr_data_count   ), //写端口数据个数,按写端口数据位宽计算
        //读相关
        .rd_clk          (rd_clk          ), //读端口时钟
        .rd_rst_n        (rd_rst_n        ), //读地址复位 
        .rd_en           (rd_en           ), //读使能
        .rd_data         (rd_data         ), //读数据
        .fifo_empty      (fifo_empty      ), //FIFO读空
        .rd_data_count   (rd_data_count   )  //读端口数据个数,按读端口数据位宽计算
    );
endmodule
