`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/19 10:37:40
// Module Name: ram64b
// Description: 简单的RAM模块,相当于模拟DDR存储器的作用,测试axi_ddr_ctrl的逻辑功能是否正确, 支持突发读写
//////////////////////////////////////////////////////////////////////////////////


module ram64b(
        input   wire        clk             ,
        input   wire        rst_n           ,
                
        //写     
        input   wire        wr_en           ,
        input   wire [29:0] wr_addr         ,
        
        //读
        input   wire        rd_en           ,
        input   wire [29:0] rd_addr         ,
        
        //数据线
        inout   wire [63:0] data    
    );
    
    //存储空间
    reg [8:0]   mem[8191:0] ;  //配合存储器按字节寻址的特点, 存储的基本单元是Byte为单位
    
    //输出数据缓存
    reg [63:0]  data_reg    ;
    
    //写基地址, 将此地址作为首地址, 在一个时钟周期写入8Byte地址空间连续的数据, 写有效时每个时钟周期自增8Byte
    reg [29:0]  wr_base_addr;
  
    //读基地址, 将此地址作为首地址, 在一个时钟周期读取8Byte地址空间连续的数据, 读有效时每个时钟周期自增8Byte
    reg [29:0]  rd_base_addr;  
    
    //读写地址增量,用于辅助产生base_addr
    reg [29:0]  rd_addr_incr;
    reg [29:0]  wr_addr_incr;
    
    //rd_addr_incr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_addr_incr <= 29'd0;
        end else if(~rd_en) begin //读无效时增量置为0
            rd_addr_incr <= 29'd0;
        end else if(rd_en) begin  //连续读取时自增8Byte
            rd_addr_incr <= rd_addr_incr + 29'd8;
        end else begin
            rd_addr_incr <= rd_addr_incr;
        end
    end
    
    //wr_addr_incr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_addr_incr <= 29'd0;
        end else if(~wr_en) begin //写无效时增量置为0
            wr_addr_incr <= 29'd0;
        end else if(wr_en) begin //连续写入时自增8Byte
            wr_addr_incr <= wr_addr_incr + 29'd8;
        end else begin
            wr_addr_incr <= wr_addr_incr;
        end
    end
    
    //rd_base_addr
    always@(*) begin
        if(rd_en) begin //在读有效时基地址为输入首地址rd_addr加上增量rd_addr_incr
            rd_base_addr = rd_addr + rd_addr_incr;
        end else begin
            rd_base_addr = 29'd0;
        end
    end
  
    //wr_base_addr
    always@(*) begin
        if(wr_en) begin //在读有效时基地址为输入首地址rd_addr加上增量rd_addr_incr
            wr_base_addr = wr_addr + wr_addr_incr;
        end else begin
            wr_base_addr = 29'd0;
        end
    end  
    
    
    //读写过程
    genvar i;
    generate
        for(i=0;i<=7;i=i+1) begin
            always@(posedge clk) begin
                if(wr_en) begin
                    mem[wr_base_addr+i] <= data[63-8*i:56-8*i];
                    data_reg[63-8*i:56-8*i] <= 8'h0;
                end else if(rd_en) begin
                    data_reg[63-8*i:56-8*i] <= mem[rd_base_addr+i];
                end else begin
                    data_reg[63-8*i:56-8*i] <= data_reg[63-8*i:56-8*i];
                end
            end    
        end
    endgenerate

    
    //数据总线
    assign data = (wr_en)?{64{1'bz}}:data_reg;
    
endmodule
