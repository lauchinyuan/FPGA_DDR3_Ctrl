`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/10 10:56:38
// Module Name: tb_mulchan_wr_arbiter
// Description: testbench for mulchan_wr_arbiter module
//////////////////////////////////////////////////////////////////////////////////


module tb_mulchan_wr_arbiter(

    );
    parameter AXI_WIDTH = 'd64;
    
    
    //DUT连线
    reg                 clk             ;
    reg                 rst_n           ;
    
    //不同写控制器输入的控制信号
    reg  [3:0]          wr_req          ; //wr_req[i]代表写通道i的写请求
    wire [29:0]         wr_addr0        ; //写通道0发来的写地址
    wire [29:0]         wr_addr1        ; //写通道1发来的写地址
    wire [29:0]         wr_addr2        ; //写通道2发来的写地址
    wire [29:0]         wr_addr3        ; //写通道3发来的写地址
    
    wire [7:0]          wr_len0         ; //通道0发来的写突发长度
    wire [7:0]          wr_len1         ; //通道1发来的写突发长度
    wire [7:0]          wr_len2         ; //通道2发来的写突发长度
    wire [7:0]          wr_len3         ; //通道3发来的写突发长度
    
    wire [AXI_WIDTH-1:0]wr_data0        ; //通道0发来的写数据
    wire [AXI_WIDTH-1:0]wr_data1        ; //通道1发来的写数据
    wire [AXI_WIDTH-1:0]wr_data2        ; //通道2发来的写数据
    wire [AXI_WIDTH-1:0]wr_data3        ; //通道3发来的写数据    
    
    //发给各通道写控制器的写授权
    wire [3:0]          wr_grant        ; //wr_grant[i]代表写通道i的写授权
    
    //AXI写主机输入信号
    wire                wr_done         ; //AXI写主机送来的一次突发传输完成标志
    
    //发送到AXI写主机的仲裁结果
    wire                axi_wr_start    ; //仲裁后有效的写请求
    wire [29:0]         axi_wr_addr     ; //仲裁后有效的写地址输出
    wire [7:0]          axi_wr_len      ;
    wire [AXI_WIDTH-1:0]axi_wr_data     ;
    
    
    
    //用于产生wr_done信号的计数器
    reg [2:0] cnt_wr_done;
    
    //模拟axi_reading信号, 用于更新cnt_wr_done计数器的值
    reg       axi_reading;
        
    
    //时钟、复位信号初始化
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
    #20
        rst_n <= 1'b1;
    end
    
    //50Mhz时钟
    always#10 clk = ~clk;
    
    
    //DUT例化
    multichannel_wr_arbiter multichannel_wr_arbiter_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        
        //不同写控制器输入的控制信号
        .wr_req          (wr_req          ), //wr_req[i]代表写通道i的写请求
        .wr_addr0        (wr_addr0        ), //写通道0发来的写地址
        .wr_addr1        (wr_addr1        ), //写通道1发来的写地址
        .wr_addr2        (wr_addr2        ), //写通道2发来的写地址
        .wr_addr3        (wr_addr3        ), //写通道3发来的写地址
        
        .wr_len0         (wr_len0         ), //通道0发来的写突发长度
        .wr_len1         (wr_len1         ), //通道1发来的写突发长度
        .wr_len2         (wr_len2         ), //通道2发来的写突发长度
        .wr_len3         (wr_len3         ), //通道3发来的写突发长度

        .wr_data0        (wr_data0        ), //通道0发来的写数据
        .wr_data1        (wr_data1        ), //通道1发来的写数据
        .wr_data2        (wr_data2        ), //通道2发来的写数据
        .wr_data3        (wr_data3        ), //通道3发来的写数据        
        //发给各通道写控制器的写授权
        .wr_grant        (wr_grant        ), //wr_grant[i]代表写通道i的写授权
        
        //AXI写主机输入信号
        .wr_done         (wr_done         ), //AXI写主机送来的一次突发传输完成标志
        
        //发送到AXI写主机的仲裁结果
        .axi_wr_start    (axi_wr_start    ), //仲裁后有效的写请求
        .axi_wr_addr     (axi_wr_addr     ), //仲裁后有效的写地址输出
        .axi_wr_len      (axi_wr_len      ),
        .axi_wr_data     (axi_wr_data     )
        
    );
    
    //每个写通道的地址、写突发长度固定
    assign wr_addr0 = 'd0   ;
    assign wr_addr1 = 'd1   ;
    assign wr_addr2 = 'd2   ;
    assign wr_addr3 = 'd3   ;
        
        
    assign wr_len0  = 'd7   ; 
    assign wr_len1  = 'd6   ; 
    assign wr_len2  = 'd5   ; 
    assign wr_len3  = 'd4   ; 
    
    assign wr_data0 = 'd4   ;
    assign wr_data1 = 'd5   ;
    assign wr_data2 = 'd6   ;
    assign wr_data3 = 'd7   ;
    
    //axi_reading
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_reading <= 1'b0;
        end else if(axi_reading && cnt_wr_done == 'd7) begin //模拟的一轮写过程写完
            axi_reading <= 1'b0;
        end else if(axi_wr_start) begin //一轮写过程开始
            axi_reading <= 1'b1;
        end else begin
            axi_reading <= axi_reading;
        end
    end
    
    
    //cnt_wr_done
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_wr_done <= 'd0;
        end else if(axi_reading && cnt_wr_done == 'd7) begin
            cnt_wr_done <= 'd0;
        end else if(axi_reading) begin
            cnt_wr_done <= cnt_wr_done + 'd1;
        end else begin
            cnt_wr_done <= cnt_wr_done;
        end
    end
    
    //wr_done
    assign wr_done = (cnt_wr_done == 'd7)? 1'b1:1'b0;
    
    //通道0写请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req[0] <= $random();
        end else if(wr_grant[0]) begin
            wr_req[0] <= 1'b0;
        end else if(wr_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            wr_req[0] <= $random();
        end else begin
            wr_req[0] <= wr_req[0];
        end
    end
    
    //通道1写请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req[1] <= $random();
        end else if(wr_grant[1]) begin
            wr_req[1] <= 1'b0;
        end else if(wr_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            wr_req[1] <= $random();
        end else begin
            wr_req[1] <= wr_req[1];
        end
    end

    //通道2写请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req[2] <= $random();
        end else if(wr_grant[2]) begin 
            wr_req[2] <= 1'b0;
        end else if(wr_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            wr_req[2] <= $random();
        end else begin
            wr_req[2] <= wr_req[2];
        end
    end

    //通道3写请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req[3] <= $random();
        end else if(wr_grant[3]) begin
            wr_req[3] <= 1'b0;
        end else if(wr_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            wr_req[3] <= $random();
        end else begin
            wr_req[3] <= wr_req[3];
        end
    end    

    
endmodule
