`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/10 10:14:13
// Module Name: fifo_wr_ctrl
// Description: FIFO写控制器
// 产生FIFO写满标志fifo_full和写数据计数器wr_data_count,控制RAM写指针

// 参数设置说明:
// RAM_ADDR_WIDTH = log2(RAM_DEPTH)
// WR_IND = WR_WIDTH/RAM_WIDTH
// WR_CNT_WIDTH = RAM_ADDR_WIDTH + 1 - log2(WR_IND)

// 举例: 假设存储器深度为32, 则存储器地址线位宽(RAM_ADDR_WIDTH)为5bit
// 若FIFO写端口数据位宽为8bit, 是RAM存储单元位宽的1倍, 则需设置每进行一次读操作需要让读指针自增值WR_IND为1(Bytes)
// 若将8bit视为一个存取单元进行访问,则"数据个数计数器"只需要6bit(RAM_ADDR_WIDTH+1)位宽
// 即FIFO最多可以存储32个8bit数据, 而32需要6比特数据来表示
//////////////////////////////////////////////////////////////////////////////////


module fifo_wr_ctrl
#(parameter RAM_ADDR_WIDTH = 'd5, //存储器地址线位宽
            WR_CNT_WIDTH   = RAM_ADDR_WIDTH+'d1, //写端口计数器位宽
            WR_IND         = 'd1  //每进行一次写操作,写指针需要自增的增量
            )
(
        input   wire                        wr_clk          ,
        input   wire                        wr_rst_n        ,
        input   wire                        wr_en           ,
        input   wire [RAM_ADDR_WIDTH:0]     rd_ptr_sync     , //从读时钟域同步过来的读指针, 二进制
        
        output  reg  [RAM_ADDR_WIDTH:0]     wr_ptr          , //写指针,相比RAM访存地址扩展一位
        output  reg                         fifo_full       , //FIFO写满标志
        output  wire [WR_CNT_WIDTH-1:0]     wr_data_count   , //写端口数据数量计数器 
        output  wire                        ram_wr_en         //RAM写使能信号, 非满且wr_en输入有效时有效
    );
    
    reg [RAM_ADDR_WIDTH:0] wr_ram_cnt ;  //存储单元中存储有效数据的单元数, 读写指针进行减法后的结果
    
    //写满标志
    //fifo_full
    always@(*) begin
        if((wr_ptr[RAM_ADDR_WIDTH-1:0] == rd_ptr_sync[RAM_ADDR_WIDTH-1:0]) && (wr_ptr[RAM_ADDR_WIDTH] != rd_ptr_sync[RAM_ADDR_WIDTH])) begin
        //读写指针最高位不同, 低位全部相同
            fifo_full = 1'b1;
        end else begin
            fifo_full = 1'b0;
        end
    end
    
    //ram_wr_en
    assign ram_wr_en = (wr_en && !fifo_full)?1'b1:1'b0;
    
    //写指针
    //wr_ptr
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            wr_ptr <= 'd0;
        end else if(ram_wr_en) begin
            wr_ptr <= wr_ptr + WR_IND;
        end else begin
            wr_ptr <= wr_ptr;
        end
    end
    
    
    //wr_ram_cnt
    always@(*) begin
        if(rd_ptr_sync[RAM_ADDR_WIDTH] == wr_ptr[RAM_ADDR_WIDTH]) begin
            //读写指针的最高位相同,说明读写指针在同一轮RAM地址空间中
            //写指针的值减去读指针的值即RAM中存有有效数据的存储单元个数
            wr_ram_cnt = wr_ptr - rd_ptr_sync;
        end else if(rd_ptr_sync[RAM_ADDR_WIDTH] != wr_ptr[RAM_ADDR_WIDTH]) begin
            //读写指针不在同一轮RAM地址空间中
            //写指针一定比读指针大,对最高位不同的情况,让写指针的最高位为1,读指针的最高位为0
            wr_ram_cnt = {1'b1, wr_ptr[RAM_ADDR_WIDTH-1:0]} - {1'b0, rd_ptr_sync[RAM_ADDR_WIDTH-1:0]};
        end else begin
            wr_ram_cnt = wr_ram_cnt;
        end
    end
    
    
    //写数据个数
    //wr_data_count
    //存储单元个数的高WR_CNT_WIDTH位即为写数据个数
    //举例说明:若存储器RAM位宽为8, 而写模块位宽为32, (写指针的值减去读指针的值)代表的是有多少个8bit数
    //写数据计数器以32bit作为一个最小单元, 故应舍去低2bit的个数    
    assign wr_data_count = wr_ram_cnt[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH + 'd1 -WR_CNT_WIDTH];
    
    
endmodule
