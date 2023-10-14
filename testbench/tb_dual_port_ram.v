`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/12 16:06:26 
// Module Name: tb_dual_port_ram
// Description: testbench for dual_port_ram module
//////////////////////////////////////////////////////////////////////////////////


module tb_dual_port_ram(

    );
    
    //参数定义
    parameter   RAM_DEPTH       = 'd64     , //RAM深度
                RAM_ADDR_WIDTH  = 'd6      , //读写地址宽度, 需与RAM_DEPTH匹配
                RAM_DATA_WIDTH  = 'd8      , //RAM数据位宽
                RAM_RD_WIDTH    = 'd32     , //RAM读取数据位宽
                RAM_RD2WR       = 'd4      ; //读数据位宽和RAM位宽的比, 即一次读取的RAM单元数量, RAM_RD2WR = RAM_RD_WIDTH/RAM_DATA_WIDTH
                            
                
    
    //DUT输入输出
    reg                        wr_clk          ; //写时钟
    reg                        wr_port_ena     ; //写端口使能, 高有效
    reg                        wr_en           ; //写数据使能
    reg [RAM_ADDR_WIDTH-1:0]   wr_addr         ; //写地址
    reg [RAM_DATA_WIDTH-1:0]   wr_data         ; //写数据
                                               
    //读端口                                  
    reg                        rd_clk          ; //读时钟
    reg                        rd_port_ena     ; //读端口使能, 高有效
    reg [RAM_ADDR_WIDTH-1:0]   rd_addr         ; //读地址
    wire[RAM_RD_WIDTH-1:0]     rd_data         ; //读数据
    
    //复位标志
    reg                        rst_n           ;
    
    
    initial begin
        rst_n <= 1'b0;
        wr_clk = 1'b1;
        rd_clk = 1'b1;
        wr_en <= 1'b0;
        wr_port_ena <= 1'b0;
        rd_port_ena <= 1'b0;
    #20
        rst_n <= 1'b1;
        wr_port_ena <= 1'b1;
        wr_en <= 1'b1;
    #(20*20)
        wr_port_ena <= 1'b0; //写使能有效但写端口失效
    #(10*20)
        wr_en <= 1'b0;
    #(10*3) 
        rd_port_ena <= 1'b1; //读端口和读使能都有效
    end
    
    //写地址更新
    always@(posedge wr_clk) begin
        if(~rst_n) begin
            wr_addr <= 'd0;
        end else if(wr_en && wr_port_ena) begin
            wr_addr <= wr_addr + 'd1;
        end else begin
            wr_addr <= wr_addr;
        end
    end
    
    //写数据更新
    always@(posedge wr_clk) begin
        if(~rst_n) begin
            wr_data <= 'd0;
        end else if(wr_en && wr_port_ena) begin
            wr_data <= wr_data + 'd1;
        end else begin
            wr_data <= wr_data;
        end
    end   
    
    //读地址更新
    always@(posedge rd_clk) begin
        if(~rst_n) begin
            rd_addr <= 'd0;
        end else if(rd_port_ena) begin
            rd_addr <= rd_addr + RAM_RD2WR;
        end else begin
            rd_addr <= rd_addr;
        end
    end
    
    
    //wr_clk 50Mhz
    always#10 wr_clk = ~wr_clk;
    
    //rd_clk 100Mhz
    always#5 rd_clk = ~rd_clk;    
    
    
    //DUT例化
    dual_port_ram
    #(.RAM_DEPTH       (RAM_DEPTH       ), //RAM深度
      .RAM_ADDR_WIDTH  (RAM_ADDR_WIDTH  ), //读写地址宽度, 需与RAM_DEPTH匹配
      .RAM_DATA_WIDTH  (RAM_DATA_WIDTH  ), //RAM数据位宽
      .RAM_RD_WIDTH    (RAM_RD_WIDTH    ),
      .RAM_RD2WR       (RAM_RD2WR       ) 
      
      
    ) dual_port_ram_inst
    (
        //写端口
        .wr_clk          (wr_clk          ), //写时钟
        .wr_port_ena     (wr_port_ena     ), //写端口使能, 高有效
        .wr_en           (wr_en           ), //写数据使能
        .wr_addr         (wr_addr         ), //写地址
        .wr_data         (wr_data         ), //写数据
        
        //读端口
        .rd_clk          (rd_clk          ), //读时钟
        .rd_port_ena     (rd_port_ena     ), //读端口使能, 高有效
        .rd_addr         (rd_addr         ), //读地址
        .rd_data         (rd_data         )  //读数据
    );
endmodule
