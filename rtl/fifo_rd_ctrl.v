`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/10 20:17:09
// Module Name: fifo_rd_ctrl
// Description: FIFO读控制器
// 产生FIFO读空标志fifo_empty和读数据计数器rd_data_count,控制RAM读指针

// 参数设置说明:
// RAM_ADDR_WIDTH = log2(RAM_DEPTH)
// RD_IND = RD_WIDTH/RAM_WIDTH
// RD_CNT_WIDTH = RAM_ADDR_WIDTH + 1 - log2(RD_IND)

// 举例: 假设存储器深度为32, 则存储器地址线位宽(RAM_ADDR_WIDTH)为5bit
// 若FIFO读端口数据位宽为32bit, 是RAM存储单元位宽的4倍, 则需设置每进行一次读操作需要让读指针自增值WR_IND为4(Bytes)
// 若将32bit视为一个存取单元进行访问,则"数据个数计数器"只需要4bit(RAM_ADDR_WIDTH+1-2)位宽
// 即FIFO最多可以存储8个32bit数据, 而8需要4比特数据来表示
//////////////////////////////////////////////////////////////////////////////////


module fifo_rd_ctrl
#(parameter RAM_ADDR_WIDTH = 'd5                        , //存储器地址线位宽
            RD_CNT_WIDTH   = RAM_ADDR_WIDTH+ 'd1- 'd2   , //读端口计数器位宽
            RD_IND         = 'd4                          //每进行一次读操作,读指针需要自增的增量
            )
(
        input   wire                        rd_clk          ,
        input   wire                        rd_rst_n        ,
        input   wire                        rd_en           , //读FIFO使能
        input   wire [RAM_ADDR_WIDTH:0]     wr_ptr_sync     , //从写时钟域同步过来的写指针, 二进制无符号数表示

        output  reg  [RAM_ADDR_WIDTH:0]     rd_ptr          , //读指针
        output  reg                         fifo_empty      , //FIFO读空标志
        output  wire [RD_CNT_WIDTH-1:0]     rd_data_count   , //读端口数据数量计数器
        output  wire                        ram_rd_en         //实际有效的RAM读使能信号,有效时读指针自增
    );
    
    reg [RAM_ADDR_WIDTH:0] rd_ram_cnt ;//存储单元中存储有效数据的单元数, 读写指针进行减法后的结果
    
    
    //读空标志
    //fifo_empty
    always@(*) begin
        if(wr_ptr_sync[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-RD_CNT_WIDTH+'d1] == rd_ptr[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-RD_CNT_WIDTH+'d1]) begin
        //当读写指针高RD_CNT_WIDTH位相同时, 认为是读空
            fifo_empty = 1'b1;
        end else begin
            fifo_empty = 1'b0;
        end
    end
    
    //RAM读使能信号, 非空且rd_en有效时有效
    //ram_rd_en
    assign ram_rd_en = (rd_en && !fifo_empty)?1'b1:1'b0;
    
    //读指针
    //rd_ptr
    always@(posedge rd_clk or negedge rd_rst_n) begin
        if(~rd_rst_n) begin
            rd_ptr <= 'd0;
        end else if(ram_rd_en) begin
            rd_ptr <= rd_ptr + RD_IND;
        end else begin
            rd_ptr <= rd_ptr;
        end
    end
    
    //rd_ram_cnt
    always@(*) begin
        if(rd_ptr[RAM_ADDR_WIDTH] == wr_ptr_sync[RAM_ADDR_WIDTH]) begin
            //读写指针的最高位相同,说明读写指针在同一轮RAM地址空间中
            //写指针的值减去读指针的值即RAM中存有有效数据的存储单元个数
            rd_ram_cnt = wr_ptr_sync - rd_ptr;
        end else if(rd_ptr[RAM_ADDR_WIDTH] != wr_ptr_sync[RAM_ADDR_WIDTH]) begin
            //读写指针不在同一轮RAM地址空间中
            //写指针一定比读指针大,对最高位不同的情况,让写指针的最高位为1,读指针的最高位为0
            rd_ram_cnt = {1'b1, wr_ptr_sync[RAM_ADDR_WIDTH-1:0]} - {1'b0, rd_ptr[RAM_ADDR_WIDTH-1:0]};
        end else begin
            rd_ram_cnt = rd_ram_cnt;
        end    
    end
    
    //可读数据个数
    //存储单元个数的高RD_CNT_WIDTH位即为可读取数据个数
    assign rd_data_count = rd_ram_cnt[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH + 'd1 - RD_CNT_WIDTH];
    
endmodule
