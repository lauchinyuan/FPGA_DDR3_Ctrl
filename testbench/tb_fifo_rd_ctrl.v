`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/10 21:27:11
// Module Name: tb_fifo_rd_ctrl
// Description: testbench for fifo_rd_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_fifo_rd_ctrl(

    );
    
    //参数定义
    parameter RAM_ADDR_WIDTH = 'd5                        , //存储器地址线位宽
              RD_CNT_WIDTH   = RAM_ADDR_WIDTH+ 'd1- 'd2   , //读端口计数器位宽
              RD_IND         = 'd4                        ; //每进行一次读操作,读指针需要自增的增量    

    reg                         rd_clk                    ;
    reg                         rd_rst_n                  ;
    reg                         rd_en                     ; //读FIFO使能
    reg  [RAM_ADDR_WIDTH:0]     wr_ptr_sync               ; //从写时钟域同步过来的写指针, 二进制无符号数表示
           
    wire [RAM_ADDR_WIDTH:0]     rd_ptr                    ; //读指针
    wire                        fifo_empty                ; //FIFO读空标志
    wire [RD_CNT_WIDTH-1:0]     rd_data_count             ; //读端口数据数量计数器
    wire                        ram_rd_en                 ; //真实的读RAM使能信号, 依据此状态控制RAM读地址
    
    //辅助变量, 模拟写操作
    reg                        wr_en           ; //写使能,为了更新同步写指针用
    reg                        wr_clk          ; //写时钟
    reg                        wr_rst_n        ; //写复位, 与读复位同步
    reg [RAM_ADDR_WIDTH:0]     wr_ptr          ; //写时钟域的写指针  

    initial begin
        wr_clk = 1'b1;
        rd_clk = 1'b1;
        rd_rst_n <= 1'b0;
        wr_rst_n <= 1'b0;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
    #20
        rd_rst_n <= 1'b1;       
        wr_rst_n <= 1'b1; 
    #20
        wr_en <= 1'b1; //先写
    #(10*20)
        rd_en <= 1'b1; //后读
    wait(fifo_empty);
        rd_en <= 1'b0; //读空后停止读
    wait(rd_data_count == 'd8);//FIFO已满,再次开始读
        wr_en <= 1'b0;
        rd_en <= 1'b1;
    end
    
    //wr_clk
    //100Mhz
    always#5 wr_clk = ~wr_clk;
    
    //rd_clk, 50Mhz, 一个读时钟周期读取4Byte, 所以实际上读比写更快, 可以触发读空信号
    always#10 rd_clk = ~rd_clk;
    
    //模拟写时钟域的写指针
    //wr_ptr
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            wr_ptr <= 'd0;
        end else if(wr_en) begin
            wr_ptr <= wr_ptr + 'd1;
        end else begin
            wr_ptr <= wr_ptr;
        end
    end
    
    //将模拟的写时钟域写指针同步到读时钟域
    //此处只是简单打拍进行同步, 实际电路并非如此
    //wr_ptr_sync
    always@(rd_clk or negedge rd_rst_n) begin
        if(~rd_rst_n) begin
            wr_ptr_sync <= 'd0;
        end else begin
            wr_ptr_sync <= wr_ptr;
        end
    end
    
    
    //DUT例化
    fifo_rd_ctrl
    #(.RAM_ADDR_WIDTH   (RAM_ADDR_WIDTH), 
      .RD_CNT_WIDTH     (RD_CNT_WIDTH  ), 
      .RD_IND           (RD_IND        )  
                )
    fifo_rd_ctrl_inst
    (
        .rd_clk          (rd_clk          ),
        .rd_rst_n        (rd_rst_n        ),
        .rd_en           (rd_en           ), 
        .wr_ptr_sync     (wr_ptr_sync     ), 
                        
        .rd_ptr          (rd_ptr          ), 
        .fifo_empty      (fifo_empty      ), 
        .rd_data_count   (rd_data_count   ),
        .ram_rd_en       (ram_rd_en       )
    );
endmodule
