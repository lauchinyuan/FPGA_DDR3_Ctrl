`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/21 11:27:10
// Module Name: testdata_gen_valid
// Description: 生成DDR3测试数据, 发送读写FIFO请求, 并最终验证从读FIFO中读取的数据是否与生成的数据一致
//////////////////////////////////////////////////////////////////////////////////


module testdata_gen_valid
    #(parameter FIFO_WR_WIDTH = 5'd16)  //用户端FIFO写位宽
    (
        input   wire                        clk             ,  //和FIFO时钟保持一致
        input   wire                        rst_n           ,
        input   wire                        calib_done      ,  //DDR3初始化完成标志
            
        //写端口   
        output  reg [FIFO_WR_WIDTH-1:0]     wr_data         ,   //向写FIFO中写入的数据
        output  reg                         wr_en           ,   //写FIFO写使能
                        
        //读端口               
        output  reg                         rd_en           ,   //读FIFO读使能
        output  reg                         rd_mem_enable   ,   //读存储器使能, 为高时才能从DDR3 SDRAM中读取数据
        input   wire                        rd_valid            //读有效信号, 为高时代表读取的数据有效
    );
    
    //wr_en
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_en <= 1'b0;
        end else if(wr_data >= 16'd1299) begin //写完最后一个数据
            wr_en <= 1'b0;
        end else if(calib_done) begin  //DDR3初始化完成后, 开始向写FIFO中写数据
            wr_en <= 1'b1;
        end else begin
            wr_en <= wr_en;
        end
    end
    
    //wr_data
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_data <= 'd0;
        end else if(wr_en) begin  //每次写入FIFO的时候数据自增一
            wr_data <= wr_data + 'd1;
        end else begin
            wr_data <= wr_data;
        end
    end
    
    //rd_mem_enable 
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_mem_enable <= 1'b0;
        end else if(wr_data == 'd1300) begin  //数据已经写完, 可以确保DDR3 SDRAM中已经有数据
            rd_mem_enable <= 1'b1;
        end else begin
            rd_mem_enable <= rd_mem_enable;
        end
    
    end
    
    //rd_en
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_en <= 1'b0;
        end else if(rd_mem_enable && rd_valid) begin  //允许读存储器, 且读FIFO有数据, 且没有读够1000个数据
            rd_en <= 1'b1;
        end else begin
            rd_en <= 1'b0;
        end 
    end
    
endmodule
