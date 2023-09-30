`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/29 21:31:38
// Module Name: key_filter
// Description: 按键消抖模块, 当按下按键一定时长后才认为按键按下有效
//////////////////////////////////////////////////////////////////////////////////


module key_filter
#(parameter FREQ   = 28'd25_000_000) //模块输入时钟频率 
    (
        input   wire        clk     ,
        input   wire        rst_n   ,
        input   wire        key_in  ,
        
        output  reg         key_out  //高电平有效
    );
    
    reg  [18:0] cnt             ;
    wire [18:0] cnt_max         ; //cnt计数器的最大值
    
    //对输入按键信号打两拍
    reg         key_in_d1       ;
    reg         key_in_d2       ;
    
    //输入按键信号的上升沿及下降沿
    wire        key_in_fall     ;
    wire        key_in_raise    ;
    
    //计数器计数使能信号
    reg         cnt_act         ;
    
    //cnt计数器的最大值为频率/512, 此时经过的时间约为2ms
    assign cnt_max = FREQ[27:9] ;
    
    //对输入按键信号打两拍
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            key_in_d1 <= 1'b1;  //按键未按下默认低电平
            key_in_d2 <= 1'b1;
        end else begin
            key_in_d1 <= key_in;
            key_in_d2 <= key_in_d1;
        end
    end
    
    //key_in_fall
    assign key_in_fall = key_in_d2 & (~key_in_d1);
    
    //key_in_raise
    assign key_in_raise = key_in_d1 & (~key_in_d2);
    
    //cnt_act
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt_act <= 1'b0;
        end else if(key_in_fall) begin  //下降沿开始计数
            cnt_act <= 1'b1;
        end else if(key_in_raise) begin //上升沿停止计数
            cnt_act <= 1'b0;
        end else begin
            cnt_act <= cnt_act;
        end
    end
    
    //cnt
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= 19'd0;
        end else if(~cnt_act) begin //非计数状态下计数值保持为0
            cnt <= 19'd0;
        end else if(cnt_act && cnt < cnt_max) begin
            cnt <= cnt + 19'd1;
        end else begin
            cnt <= cnt;
        end
    end
    
    //key_out
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            key_out <= 1'b0;
        end else if(cnt == (cnt_max - 19'd1)) begin
            key_out <= 1'b1;
        end else begin
            key_out <= 1'b0;
        end
    end
    
endmodule
