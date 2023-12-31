`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/23 10:13:56
// Module Name: vga_ctrl
// Description: VGA控制器模块
// 发出图像数据读取请求, 并将读取的图像数据转换为符合VGA时序的图像数据流
//////////////////////////////////////////////////////////////////////////////////


module vga_ctrl(
        input   wire        clk         ,
        input   wire        rst_n       ,
        input   wire [23:0] rgb_in      , //输入的RGB图像信号
        
        output  reg         hsync       , //行同步
        output  reg         vsync       , //场同步
        output  reg         pix_req     , //请求外部图像输入
        output  wire        pix_valid   , //为高时代表输出的图像是有效数据帧
/*         output  reg  [9:0]  pix_x       , //请求图像像素的横向坐标
        output  reg  [9:0]  pix_y       , //请求图像像素的竖向坐标 */
        output  wire [23:0] rgb_out       //输出的RGB图像信号
    );
    
    //图像帧相关参数定义
    //640*480
/*     parameter   HSYNC_CNT     =   11'd96  , //行同步至同步阶段结束累计像素周期
                HSYNC_LEDGE   =   11'd144 , //行同步至左边框阶段结束累计像素周期
                HSYNC_PIX     =   11'd784 , //行同步至有效数据阶段结束累计像素周期
                HSYNC_END     =   11'd800 , //行同步扫描总周期
                VSYNC_CNT     =   11'd2   , //场同步至同步阶段结束累计行周期
                VSYNC_LEDGE   =   11'd35  , //场同步至左边框阶段结束累计行周期
                VSYNC_PIX     =   11'd515 , //场同步至有效数据阶段结束累计行周期
                VSYNC_END     =   11'd525 ; //场同步扫描总周期 */

/*     //1920*1080
    parameter   HSYNC_CNT     =   11'd112  , //行同步至同步阶段结束累计像素周期
                HSYNC_LEDGE   =   11'd360  , //行同步至左边框阶段结束累计像素周期
                HSYNC_PIX     =   11'd1640 , //行同步至有效数据阶段结束累计像素周期
                HSYNC_END     =   11'd1688 , //行同步扫描总周期
                VSYNC_CNT     =   11'd3    , //场同步至同步阶段结束累计行周期
                VSYNC_LEDGE   =   11'd41   , //场同步至左边框阶段结束累计行周期
                VSYNC_PIX     =   11'd1065 , //场同步至有效数据阶段结束累计行周期
                VSYNC_END     =   11'd1066 ; //场同步扫描总周期 */
    //1280*960           
    parameter   HSYNC_CNT     =   11'd112  , //行同步至同步阶段结束累计像素周期
                HSYNC_LEDGE   =   11'd424  , //行同步至左边框阶段结束累计像素周期
                HSYNC_PIX     =   11'd1704 , //行同步至有效数据阶段结束累计像素周期
                HSYNC_END     =   11'd1800 , //行同步扫描总周期
                VSYNC_CNT     =   11'd3    , //场同步至同步阶段结束累计行周期
                VSYNC_LEDGE   =   11'd39   , //场同步至左边框阶段结束累计行周期
                VSYNC_PIX     =   11'd999  , //场同步至有效数据阶段结束累计行周期
                VSYNC_END     =   11'd1000 ; //场同步扫描总周期
//                PIX_X         =   10'd640 , //图像横向大小
//                PIX_Y         =   10'd480 ; //图像竖向大小
    
    
    //同步释放复位信号
    reg         rst_n_sync;
    reg         rst_n_d1  ;  //同步器输出第一拍
    
    //中间辅助信号
    reg [10:0]   cnt_h   ; //依据计数值, 辅助产生行同步信号hsync
    reg [10:0]   cnt_v   ; //依据计数值, 辅助产生场同步信号vsync
    
    //本工程中输入的复位信号来自ui_clk时钟域, 本模块系统时钟为clk_fifo
    //为减缓在复位信号释放时产生亚稳态之可能性
    //采用异步复位同步释放方案, 同时在约束文件中将ui_clk至clk_fifo路径设为false_path
    //rst_n_sync
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin    //异步复位
            rst_n_d1    <= 1'b0;
            rst_n_sync  <= 1'b0;
        end else begin      //同步释放
            rst_n_d1    <= 1'b1;
            rst_n_sync  <= rst_n_d1;
        end
    end
    
    
    //cnt_h
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            cnt_h <= 11'd0;
        end else if(cnt_h == HSYNC_END - 11'd1) begin
            cnt_h <= 11'd0;
        end else begin
            cnt_h <= cnt_h + 11'd1;
        end
    end
    
    //cnt_v
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            cnt_v <= 11'd0;
        end else if(cnt_h == HSYNC_END - 11'd1 && cnt_v == VSYNC_END - 11'd1) begin  //计数到最大值
            cnt_v <= 11'd0;
        end else if(cnt_h == HSYNC_END - 11'd1) begin  //每完成一行扫描, cnt_v自增1
            cnt_v <= cnt_v + 11'd1;
        end else begin
            cnt_v <= cnt_v;
        end
    end
    
    //hsync
    always@(*) begin
        if(cnt_h < HSYNC_CNT) begin //在行扫描周期的同步阶段拉高
            hsync = 1'b1;
        end else begin
            hsync = 1'b0;
        end
    end
    
    //vsync
    always@(*) begin
        if(cnt_v < VSYNC_CNT) begin //在场扫描周期的同步阶段拉高
            vsync = 1'b1;
        end else begin
            vsync = 1'b0;
        end
    end
    
    //pix_req
    //有效图像数据将滞后请求一个时钟周期
    always@(*) begin
        if(cnt_v >= VSYNC_LEDGE && cnt_v < VSYNC_PIX && cnt_h >= (HSYNC_LEDGE - 11'd1) && cnt_h < (HSYNC_PIX - 11'd1)) begin
            pix_req = 1'b1;
        end else begin
            pix_req = 1'b0;
        end
    end
    
/*     //有效图像数据标志, 实际上是pix_req打一拍
    //pix_valid
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pix_valid <= 1'b0;
        end else begin
            pix_valid <= pix_req;
        end
    end */
    assign pix_valid = pix_req;  //由于实际使用的FIFO配置为First-word-Fall-Through模式,因此写使能即可立即获得有效数据
    
    //图像输出
    assign rgb_out = (pix_valid)?rgb_in:24'b0;  //当有效数据输出时,将输入的数据作为输出,否则输出0
    
/*     //坐标输出
    //pix_x
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pix_x <= 10'd0;
        end else if(pix_req && pix_x == (PIX_X - 1'd1)) begin  
            pix_x <= 10'd0;
        end else if(pix_req) begin //在pix_req高电平持续时计数
            pix_x <= pix_x + 10'd1;
        end else begin
            pix_x <= pix_x;
        end
    end
    
    //pix_y
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pix_y <= 10'd0;
        end else if(pix_req && pix_x == (PIX_X - 1'd1) && pix_y == (PIX_Y - 1'd1)) begin
            pix_y <= 10'd0;
        end else if(pix_req && pix_x == (PIX_X - 1'd1)) begin
            pix_y <= pix_y + 10'd1;
        end else begin
            pix_y <= pix_y;
        end
    end */
   
endmodule
