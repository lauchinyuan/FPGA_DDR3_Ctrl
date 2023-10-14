`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/12 15:38:30
// Module Name: dual_port_ram
// Description: 简单双端口RAM, 作为FIFO的内部存储器, 读写位宽一致, 读写时钟不同
// 使用(*ram_style="block"*)标记, 可指导Vivado综合工具生成BRAM
// 参数依赖：
// RAM_ADDR_WIDTH = log2(RAM_DEPTH)
// RAM_RD2WR      = RAM_RD_WIDTH/RAM_DATA_WIDTH, 此值须是正整数
//////////////////////////////////////////////////////////////////////////////////


module dual_port_ram
#(parameter RAM_DEPTH       = 'd32     , //RAM深度
            RAM_ADDR_WIDTH  = 'd5      , //读写地址宽度, 需与RAM_DEPTH匹配
            RAM_DATA_WIDTH  = 'd8      , //RAM数据位宽
            RAM_RD_WIDTH    = 'd8      , //RAM读取数据位宽
            RAM_RD2WR       = 'd1        //读数据位宽和RAM位宽的比, 即一次读取的RAM单元数量, RAM_RD2WR = RAM_RD_WIDTH/RAM_DATA_WIDTH
            
)
    (
        //写端口
        input   wire                        wr_clk          , //写时钟
        input   wire                        wr_port_ena     , //写端口使能, 高有效
        input   wire                        wr_en           , //写数据使能
        input   wire [RAM_ADDR_WIDTH-1:0]   wr_addr         , //写地址
        input   wire [RAM_DATA_WIDTH-1:0]   wr_data         , //写数据
        
        //读端口
        input   wire                        rd_clk          , //读时钟
        input   wire                        rd_port_ena     , //读端口使能, 高有效
        input   wire [RAM_ADDR_WIDTH-1:0]   rd_addr         , //读地址
        output  reg  [RAM_RD_WIDTH-1:0]     rd_data           //读数据
    );
    
    //存储空间
    (*ram_style="block"*)reg [RAM_DATA_WIDTH-1:0] ram_mem[RAM_DEPTH-1:0];
    
    //写端口
    always@(posedge wr_clk) begin
        if(wr_port_ena && wr_en) begin
            ram_mem[wr_addr] <= wr_data;
        end else begin  
            ram_mem[wr_addr] <= ram_mem[wr_addr];
        end
    end
    
    //读端口
    //一个读时钟周期将读取RAM_RD2WR个RAM单元数据
    //rd_data低位数据来自高地址
    genvar i;
    generate
        for(i=0;i<RAM_RD2WR;i=i+1) begin: rd_data_out
            always@(posedge rd_clk) begin
                if(rd_port_ena) begin
                rd_data[RAM_RD_WIDTH-1-i*RAM_DATA_WIDTH: RAM_RD_WIDTH-(i+1)*RAM_DATA_WIDTH] <= ram_mem[rd_addr+i]; 
                end else begin
                rd_data[RAM_RD_WIDTH-1-i*RAM_DATA_WIDTH: RAM_RD_WIDTH-(i+1)*RAM_DATA_WIDTH] <= rd_data[RAM_RD_WIDTH-1-i*RAM_DATA_WIDTH: RAM_RD_WIDTH-(i+1)*RAM_DATA_WIDTH];
                end
            end        
        end
    endgenerate
    
    

    
endmodule
