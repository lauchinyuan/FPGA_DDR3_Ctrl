`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/30 09:20:52
// Module Name: key_ctrl
// Description: 按键控制模块, 检测到按键按下时, 翻转输出的电平, 原始输出电平为0
// 在本工程中输出电平用于控制读SDRAM使能信号
//////////////////////////////////////////////////////////////////////////////////
module key_ctrl
    #(parameter FREQ   = 28'd25_000_000) //模块输入时钟频率 
    (
        input   wire        clk         ,
        input   wire        rst_n       ,
        input   wire        key_in      ,
        
        output  reg         state_out   
    );
    
    wire        key_out    ;
    
    //state_out
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state_out <= 1'b0;
        end else if(key_out) begin //每检测到一次有效的按键动作,输出电平进行一次翻转
            state_out <= ~state_out;
        end else begin
            state_out <= state_out;
        end
    end
    
    
    //按键消抖
    key_filter
    #(.FREQ(FREQ)) //模块输入时钟频率 
    key_filter_inst
    (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .key_in  (key_in  ),
        
        .key_out (key_out )  //经过滤波后的按键电平输出,高电平代表按键按下
    );    
    
endmodule
