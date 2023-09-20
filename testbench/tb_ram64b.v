`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/19 11:04:53
// Module Name: tb_ram64b
// Description: testbench for ram64b module
//////////////////////////////////////////////////////////////////////////////////


module tb_ram64b(

    );
    
    reg clk, rst_n;
    
    //100MHz时钟
    always#5 clk = ~clk;
    
    //模块连线
    reg        wr_en   ;
    wire[29:0] wr_addr ; //写首地址
    reg [63:0] wr_data ;
    reg        rd_en   ;
    wire[29:0] rd_addr ; //读首地址
    wire[63:0] data    ;
    
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;   
    #20
        rst_n <= 1'b1;
    #20
        wr_en <= 1'b1; //写使能
    #10100
        wr_en <= 1'b0;
    #20
        rd_en <= 1'b1; //读使能
    #10100
        rd_en <= 1'b0;
    end
    
    //读写地址, 只要给定一个首地址即可
    //wr_addr & wr_data
    assign wr_addr = 30'd7;
    assign rd_addr = 30'd7;
   
    //写入存储器的数据,每个Byte作为一个基本数据单位进行生成
    genvar i;
    generate
        for(i=0;i<=7;i=i+1) begin
            always@(posedge clk or negedge rst_n) begin
                if(~rst_n) begin
                    wr_data[63-i*8:56-8*i] <= 8'b0+i;  //初始化时64bit数据为64'h0706050403020100
                end else if(wr_en) begin
                    wr_data[63-i*8:56-8*i] <= wr_data[63-i*8:56-8*i] + 8'd8;  //每个Byte都自增8        
                end else begin
                    wr_data[63-i*8:56-8*i] <= wr_data[63-i*8:56-8*i];
                end
            end
        end
    endgenerate

    //RAM例化
    ram64b ram64b_inst(
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .wr_en   (wr_en   ),
        .wr_addr (wr_addr ),
        .rd_en   (rd_en   ),
        .rd_addr (rd_addr ),
        .data    (data    )
    );
    
    //写使能时数据线为需要写入的数据, 否则置为高阻态
    assign data = (wr_en)?wr_data:{64{1'bz}};
endmodule
