`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/10 15:25:57
// Module Name: tb_fifo_wr_ctrl
// Description: testbench for fifo_wr_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_fifo_wr_ctrl(

    );

    parameter RAM_ADDR_WIDTH = 'd5, //存储器地址线位宽
              WR_CNT_WIDTH   = 'd6, //写端口计数器位宽
              WR_IND         = 'd1; //每进行一次写操作,写指针需要自增的增量   

    reg                        wr_clk          ;
    reg                        wr_rst_n        ;
    reg                        wr_en           ;
    reg [RAM_ADDR_WIDTH:0]     rd_ptr_sync     ; //从读时钟域同步过来的读指针, 二进制表示
    
    wire                       fifo_full       ; //FIFO写满标志
    wire[WR_CNT_WIDTH-1:0]     wr_data_count   ; //写端口数据数量计数器 
    wire                       ram_wr_en       ; //RAM写使能信号, 非满且wr_en输入有效时有效  
    wire[RAM_ADDR_WIDTH:0]     wr_ptr          ; //写时钟域写指针

    //辅助变量, 模拟读操作
    reg                        rd_en           ; //读使能,为了更新同步读地址用
    reg                        rd_clk          ; //读时钟
    wire                       rd_rst_n        ; //读复位, 与写复位同步
    reg [RAM_ADDR_WIDTH:0]     rd_ptr          ; //读时钟域的读指针
    
    assign rd_rst_n = wr_rst_n;
    
    
    initial begin
        wr_clk = 1'b1;
        rd_clk = 1'b1;
        wr_rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
    #20
        wr_rst_n <= 1'b1;
    #30
        wr_en <= 1'b1; //开始写
    #(20*8)
        rd_en <= 1'b1; //开始读
    wait(fifo_full);
        wr_en <= 1'b0;
    wait(wr_data_count <= 'd12); //FIFO中数据低于12个,再次开始写
        rd_en <= 1'b0;
        wr_en <= 1'b1;
    end
    
    //50MHz时钟
    always#10 wr_clk = ~wr_clk;
    
    //20MHz读时钟, 读得较慢
    always#25 rd_clk = ~rd_clk;
    
    //模拟读时钟域的读指针
    always@(posedge rd_clk or negedge rd_rst_n) begin
        if(~rd_rst_n) begin
            rd_ptr <= 'd0;
        end else if(rd_en) begin
            rd_ptr <= rd_ptr + 'd1;
        end else begin
            rd_ptr <= rd_ptr;
        end
    end

    //模拟从读时钟域同步过来的读指针
    //这里只是简单打拍将读指针同步到写时钟域, 实际电路并非如此
    //rd_ptr_sync
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            rd_ptr_sync <= 'd0;
        end else begin
            rd_ptr_sync <= rd_ptr;
        end
    end
    
    
    
    
    
    //DUT例化
    fifo_wr_ctrl
    #(.RAM_ADDR_WIDTH(RAM_ADDR_WIDTH    ), //存储器地址线位宽
      .WR_CNT_WIDTH  (WR_CNT_WIDTH      ), //写端口计数器位宽
      .WR_IND        (WR_IND            )  //每进行一次写操作,写指针需要自增的增量
                )
    fifo_wr_ctrl_inst
    (
        .wr_clk          (wr_clk          ),
        .wr_rst_n        (wr_rst_n        ),
        .wr_en           (wr_en           ),
        .rd_ptr_sync     (rd_ptr_sync     ), //从读时钟域同步过来的读指针, 二进制表示

        .wr_ptr          (wr_ptr          ), //写指针,相比RAM访存地址扩展一位
        .fifo_full       (fifo_full       ), //FIFO写满标志
        .wr_data_count   (wr_data_count   ), //写端口数据数量计数器 
        .ram_wr_en       (ram_wr_en       )  //RAM写使能信号, 非满且wr_en输入有效时有效
    );
    
    
endmodule
