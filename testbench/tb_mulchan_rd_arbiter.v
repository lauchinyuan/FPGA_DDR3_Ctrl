`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/03 11:16:33
// Module Name: tb_mulchan_rd_arbiter
// Description: testbench for mulchan_rd_arbiter module
//////////////////////////////////////////////////////////////////////////////////


module tb_mulchan_rd_arbiter(

    );
    
    //DUT连线
    reg                 clk             ;
    reg                 rst_n           ;
    
    //不同读控制器输入的控制信号
    reg  [3:0]          rd_req          ; //rd_req[i]代表读通道i的读请求
    wire [29:0]         rd_addr0        ; //读通道0发来的读地址
    wire [29:0]         rd_addr1        ; //读通道1发来的读地址
    wire [29:0]         rd_addr2        ; //读通道2发来的读地址
    wire [29:0]         rd_addr3        ; //读通道3发来的读地址
    
    //发给各通道读控制器的读授权
    wire [3:0]          rd_grant        ; //rd_grant[i]代表读通道i的读授权
    
    //AXI读主机输入信号
    wire                rd_done         ; //AXI读主机送来的一次突发传输完成标志
    
    //发送到AXI读主机的仲裁结果
    wire                axi_rd_start    ; //仲裁后有效的读请求
    wire [29:0]         axi_rd_addr     ; //仲裁后有效的读地址输出   
    
    
    //用于产生rd_done信号的计数器
    reg [2:0] cnt_rd_done;
    
    //模拟axi_reading信号, 用于更新cnt_rd_done计数器的值
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
    multichannel_rd_arbiter multichannel_rd_arbiter_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        
        //不同读控制器输入的控制信号
        .rd_req          (rd_req          ), //rd_req[i]代表读通道i的读请求
        .rd_addr0        (rd_addr0        ), //读通道0发来的读地址
        .rd_addr1        (rd_addr1        ), //读通道1发来的读地址
        .rd_addr2        (rd_addr2        ), //读通道2发来的读地址
        .rd_addr3        (rd_addr3        ), //读通道3发来的读地址
        
        //发给各通道读控制器的读授权
        .rd_grant        (rd_grant        ), //rd_grant[i]代表读通道i的读授权
        
        //AXI读主机输入信号
        .rd_done         (rd_done         ), //AXI读主机送来的一次突发传输完成标志
        
        //发送到AXI读主机的仲裁结果
        .axi_rd_start    (axi_rd_start    ), //仲裁后有效的读请求
        .axi_rd_addr     (axi_rd_addr     )   //仲裁后有效的读地址输出
    );
    
    //每个读通道的地址固定
    assign rd_addr0 = 'd0       ;
    assign rd_addr1 = 'd1       ;
    assign rd_addr2 = 'd2       ;
    assign rd_addr3 = 'd3       ;
    
    
    //axi_reading
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_reading <= 1'b0;
        end else if(axi_reading && cnt_rd_done == 'd7) begin //模拟的一轮读过程读完
            axi_reading <= 1'b0;
        end else if(axi_rd_start) begin //一轮读过程开始
            axi_reading <= 1'b1;
        end else begin
            axi_reading <= axi_reading;
        end
    end
    
    
    //cnt_rd_done
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_rd_done <= 'd0;
        end else if(axi_reading && cnt_rd_done == 'd7) begin
            cnt_rd_done <= 'd0;
        end else if(axi_reading) begin
            cnt_rd_done <= cnt_rd_done + 'd1;
        end else begin
            cnt_rd_done <= cnt_rd_done;
        end
    end
    
    //rd_done
    assign rd_done = (cnt_rd_done == 'd7)? 1'b1:1'b0;
    
    //通道0读请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req[0] <= $random();
        end else if(rd_grant[0]) begin
            rd_req[0] <= 1'b0;
        end else if(rd_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            rd_req[0] <= $random();
        end else begin
            rd_req[0] <= rd_req[0];
        end
    end
    
    //通道1读请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req[1] <= $random();
        end else if(rd_grant[1]) begin
            rd_req[1] <= 1'b0;
        end else if(rd_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            rd_req[1] <= $random();
        end else begin
            rd_req[1] <= rd_req[1];
        end
    end

    //通道2读请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req[2] <= $random();
        end else if(rd_grant[2]) begin 
            rd_req[2] <= 1'b0;
        end else if(rd_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            rd_req[2] <= $random();
        end else begin
            rd_req[2] <= rd_req[2];
        end
    end

    //通道3读请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req[3] <= $random();
        end else if(rd_grant[3]) begin
            rd_req[3] <= 1'b0;
        end else if(rd_req == 4'b0000) begin //四个通道都没有请求, 则重新开始新一轮请求
            rd_req[3] <= $random();
        end else begin
            rd_req[3] <= rd_req[3];
        end
    end    
    
    
endmodule
