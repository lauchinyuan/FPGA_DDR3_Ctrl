`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/21 16:34:06 
// Module Name: tb_testdata_gen_valid
// Description: testbench for testdata_gen_valid module
//////////////////////////////////////////////////////////////////////////////////


module tb_testdata_gen_valid(

    );
    reg         clk              ;
    reg         rst_n            ;
    reg         calib_done       ;

    //模块连线
    //FIFO写端口   
    wire [15:0]  wr_data         ;   //向写FIFO中写入的数据
    wire         wr_en           ;   //写FIFO写使能
                                 
    //FIFO读端口                
    wire         rd_en           ;   //读FIFO读使能
    wire         rd_mem_enable   ;   //读存储器使能, 为高时才能从DDR3 SDRAM中读取数据
    wire         fifo_empty      ;
    wire [15:0]  rd_data         ;   //从读FIFO中读取的数据
    
    //数据一致性标志
    wire         wr_correct      ;   //读取的数据和写入的数据一致标志
    
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        calib_done <= 1'b0;
    #20
        rst_n <= 1'b1;
    #600
        calib_done <= 1'b1;
    end
    
    always#10 clk = ~clk;
    
   
    //测试数据生成和验证模块
    testdata_gen_valid testdata_gen_valid_inst(
        .clk             (clk             ),  //和FIFO时钟保持一致
        .rst_n           (rst_n           ),
        .calib_done      (calib_done      ),  //DDR3初始化完成标志
            
        //写端口   
        .wr_data         (wr_data         ),   //向写FIFO中写入的数据
        .wr_en           (wr_en           ),   //写FIFO写使能
        
        //读端口
        .rd_en           (rd_en           ),   //读FIFO读使能
        .rd_mem_enable   (rd_mem_enable   ),   //读存储器使能, 为高时才能从DDR3 SDRAM中读取数据
        .rd_valid        (~fifo_empty     ),   //读有效信号, 为高时代表读取的数据有效
        .rd_data         (rd_data         ),   //从读FIFO中读取的数据
        
        //数据一致性标志
        .wr_correct      (wr_correct      )    //当读取的数据和写入的数据一致时, 判断DDR3 SDRAM的读写控制逻辑正确
    );
    
    //模拟存储器读FIFO、写FIFO接口的FIFO IP核
    //数据生成模块生成数据后, 将数据写入次FIFO, 接着从FIFO读端口读出数据
    testdata_fifo testdata_fifo_inst (
        .clk        (clk            ),      // input wire clk
        .srst       (~rst_n         ),      // input wire srst
        .din        (wr_data        ),      // input wire [15 : 0] din
        .wr_en      (wr_en          ),      // input wire wr_en
        .rd_en      (rd_en          ),      // input wire rd_en
        .dout       (rd_data        ),      // output wire [15 : 0] dout
        .full       (               ),      // output wire full
        .empty      (fifo_empty     )       // output wire empty
    );
endmodule
