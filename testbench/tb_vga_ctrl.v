`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/23 18:54:53
// Module Name: tb_vga_ctrl
// Description: testbench for vga_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_vga_ctrl(

    );

    reg         clk         ;
    reg         rst_n       ;
    reg  [23:0] rgb_in      ; //RGB图像信号
                            
    wire        hsync       ; //行同步
    wire        vsync       ; //场同步
    wire        pix_req     ; //请求外部图像输入
    wire        pix_valid   ; //为高时代表输出的图像是有效数据帧
    wire [9:0]  pix_x       ; //请求图像像素的横向坐标
    wire [9:0]  pix_y       ; //请求图像像素的竖向坐标
    wire [23:0] rgb_out     ; //待测试输出的RGB图像信号

    
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
    #20
        rst_n <= 1'b1;
    end
    
    always#20 clk = ~clk; //25MHz时钟

    //rgb_in
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rgb_in <= 24'b0;
        end else if(pix_valid) begin
            rgb_in <= rgb_in + 24'd1;
        end else begin
            rgb_in <= rgb_in;
        end
    end
    
    //待测模块例化
    vga_ctrl vga_ctrl_inst(
        .clk         (clk         ),
        .rst_n       (rst_n       ),
        .rgb_in      (rgb_in      ), //输入的RGB图像信号

        .hsync       (hsync       ), //行同步
        .vsync       (vsync       ), //场同步
        .pix_req     (pix_req     ), //请求外部图像输入
        .pix_valid   (pix_valid   ), //为高时代表输出的图像是有效数据帧
        .pix_x       (pix_x       ), //请求图像像素的横向坐标
        .pix_y       (pix_y       ), //请求图像像素的竖向坐标
        .rgb_out     (rgb_out     )  //输出的RGB图像信号
    );
endmodule
