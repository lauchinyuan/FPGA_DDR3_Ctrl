`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/10 09:56:04
// Module Name: multichannel_wr_arbiter
// Description: DDR SDRAM多通道写仲裁器, 对多个写通道的写请求进行写权限判断
// 决定当前时刻有效的写通道, 并将这个通道的有效的写请求信号和写地址发送给AXI写主机
// 仲裁方案简述: 没有获得过授权的通道请求优先, 
// 在(都没有获得过授权/都获得过授权)的通道内, 低编号优先。
// 举例: 初始化时, 所有通道都没有获得过授权的记录
// 若通道0、1、3都有写请求, 优先响应通道0
// 通道0一次写完成后, 通道0的优先级变低, 首先判断其它通道是否有写请求, 有则授权其它通道
// 假设第二次授权通道2(此时通道2\0都有授权的历史), 则第三次授权判定时, 首先判断剩下的通道
// 以次类推
// 注意: 与读通道仲裁不同, 各个写通道发来的数据也需要经过仲裁
//////////////////////////////////////////////////////////////////////////////////


module multichannel_wr_arbiter
#(parameter AXI_WIDTH   =   'd64    // AXI数据通道数据位宽
)
(
        input   wire                    clk             ,
        input   wire                    rst_n           ,
        
        //不同写控制器输入的控制信号及数据
        input   wire [3:0]              wr_req          , //wr_req[i]代表写通道i的写请求
        input   wire [29:0]             wr_addr0        , //写通道0发来的写地址
        input   wire [29:0]             wr_addr1        , //写通道1发来的写地址
        input   wire [29:0]             wr_addr2        , //写通道2发来的写地址
        input   wire [29:0]             wr_addr3        , //写通道3发来的写地址
            
        input   wire [7:0]              wr_len0         , //通道0发来的写突发长度
        input   wire [7:0]              wr_len1         , //通道1发来的写突发长度
        input   wire [7:0]              wr_len2         , //通道2发来的写突发长度
        input   wire [7:0]              wr_len3         , //通道3发来的写突发长度
            
        input   wire [AXI_WIDTH-1:0]    wr_data0        , //通道0发来的写数据
        input   wire [AXI_WIDTH-1:0]    wr_data1        , //通道1发来的写数据
        input   wire [AXI_WIDTH-1:0]    wr_data2        , //通道2发来的写数据
        input   wire [AXI_WIDTH-1:0]    wr_data3        , //通道3发来的写数据
            
        //发给各通道写控制器的写授权 
        output  wire [3:0]              wr_grant        , //wr_grant[i]代表写通道i的写授权
            
        //AXI写主机输入信号    
        input   wire                    wr_done         , //AXI写主机送来的一次突发传输完成标志
            
        //发送到AXI写主机的仲裁结果    
        output  reg                     axi_wr_start    , //仲裁后有效的写请求
        output  reg [29:0]              axi_wr_addr     , //仲裁后有效的写地址输出
        output  reg [AXI_WIDTH-1:0]     axi_wr_data     , //仲裁后有效的写数据输出
        output  reg [7:0]               axi_wr_len        //仲裁后有效的写突发长度
    );
    
    //状态机状态定义
    parameter   IDLE    =   5'b00001    , // IDLE状态, 没有通道获得授权
                S0      =   5'b00010    , // 通道0获得授权
                S1      =   5'b00100    , // 通道1获得授权
                S2      =   5'b01000    , // 通道2获得授权
                S3      =   5'b10000    ; // 通道3获得授权
    
    
    //中间变量
    reg [3:0]           wr_req_d        ; //wr_req打一拍, 用于生成wr_req_acti信号
    wire                wr_req_acti     ; //wr_req_acti信号为高, 则代表有写通道开始发出wr_req写请求
    reg                 acti_valid      ; //对wr_req_acti的响应状态(有效或者无效), 防止当前通道没有写完, 因为wr_req发生突变而提前转换通道
    
    //通道使用历史记录变量
    reg [3:0]           wr_record       ; //wr_record[i]代表在这一轮, 通道i已经发送过写请求
    
    //用到多次的中间变量复用, 省资源
    wire[3:0]           wr_req_non_grant; //当通道i有写请求且无授权历史时wr_req_non_grant[i]为高
    
    //状态机变量
    reg [4:0]           state           ;
    reg [4:0]           next_state      ;    
    
    //输入写请求信号打拍
    //wr_req打拍
    //wr_req_d
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_req_d <= 'b0;
        end else begin
            wr_req_d <= wr_req;
        end
    end
    
    //wr_req_acti, wr_req从0变化为非零值
    assign wr_req_acti = ((wr_req_d == 4'b0000) && (wr_req != 4'b0000))?1'b1:1'b0;
    
    //acti_valid
    //只有在每一个写请求都收到wr_done信号后, 才允许响应新的wr_req_acti_reg
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            acti_valid <= 1'b1;         //复位时处于有效响应状态
        end else if(axi_wr_start) begin //发送写请求, 则拉低有效状态
            acti_valid <= 1'b0;
        end else if(wr_done) begin      //接收到wr_done
            acti_valid <= 1'b1;
        end else begin
            acti_valid <= acti_valid;
        end
    end   
    
    //状态机状态转移
    //state
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //无授权历史的写请求
    //wr_req_non_grant
    assign wr_req_non_grant = wr_req & (~wr_record);    
    
    //状态机次态
    always@(*) begin
        case(state) 
            IDLE: begin
                //通道优先级: 0 > 1 > 2 > 3
                if(wr_req[0]) begin
                    next_state = S0;
                end else if(wr_req[1]) begin
                    next_state = S1;
                end else if(wr_req[2]) begin
                    next_state = S2;
                end else if(wr_req[3]) begin
                    next_state = S3; 
                end else begin
                    next_state = IDLE;
                end               
            end
            
            S0: begin  
                //通道优先级: [1 > 2 > 3] > [1 > 2 > 3] > 0
                //            (无授权历史)  (有授权历史)
                if(wr_done || (wr_req_acti && acti_valid)) begin 
                    if(wr_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(wr_req_non_grant[1]) begin //通道1有本轮未经授权过的写请求
                        next_state = S1;
                    end else if(wr_req_non_grant[2]) begin //通道2有本轮未经授权过的写请求
                        next_state = S2;
                    end else if(wr_req_non_grant[3]) begin //通道3有本轮未经授权过的写请求
                        next_state = S3;
                    end else if(wr_req[1]) begin 
                        next_state = S1;
                    end else if(wr_req[2]) begin
                        next_state = S2;
                    end else if(wr_req[3]) begin
                        next_state = S3;
                    end else begin
                        next_state = state;
                    end 
                end else begin //一次突发传输未完成, 保持状态
                    next_state = state;
                end
            end
            
            S1: begin
                //通道优先级: [2 > 3 > 0] > [2 > 3 > 0] > 1
                //            (无授权历史)  (有授权历史)                
                if(wr_done || (wr_req_acti && acti_valid)) begin
                    if(wr_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(wr_req_non_grant[2]) begin //通道2有本轮未经授权过的写请求
                        next_state = S2;
                    end else if(wr_req_non_grant[3]) begin //通道3有本轮未经授权过的写请求
                        next_state = S3;
                    end else if(wr_req_non_grant[0]) begin //通道0有本轮未经授权过的写请求
                        next_state = S0;
                    end else if(wr_req[2]) begin 
                        next_state = S2;
                    end else if(wr_req[3]) begin
                        next_state = S3;
                    end else if(wr_req[0]) begin
                        next_state = S0;
                    end else begin
                        next_state = state;
                    end 
                end else begin
                    next_state = state;
                end
            end
            
            S2: begin
                //通道优先级: [3 > 0 > 1] > [3 > 0 > 1] > 2
                //            (无授权历史)  (有授权历史)                
                if(wr_done || (wr_req_acti && acti_valid)) begin
                    if(wr_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(wr_req_non_grant[3]) begin //通道2有本轮未经授权过的写请求
                        next_state = S3;
                    end else if(wr_req_non_grant[0]) begin //通道3有本轮未经授权过的写请求
                        next_state = S0;
                    end else if(wr_req_non_grant[1]) begin //通道0有本轮未经授权过的写请求
                        next_state = S1;
                    end else if(wr_req[3]) begin 
                        next_state = S3;
                    end else if(wr_req[0]) begin
                        next_state = S0;
                    end else if(wr_req[1]) begin
                        next_state = S1;
                    end else begin
                        next_state = state;
                    end 
                end else begin
                    next_state = state;
                end
            end
            
            S3: begin
                //通道优先级: [0 > 1 > 2] > [0 > 1 > 2] > 3
                //            (无授权历史)  (有授权历史)                
                if(wr_done || (wr_req_acti && acti_valid)) begin //在写完后进行通道切换判断, 或者在较长时间后在wr_req激活时进行通道切换判断
                    if(wr_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(wr_req_non_grant[0]) begin //通道2有本轮未经授权过的写请求
                        next_state = S0;
                    end else if(wr_req_non_grant[1]) begin //通道3有本轮未经授权过的写请求
                        next_state = S1;
                    end else if(wr_req_non_grant[2]) begin //通道0有本轮未经授权过的写请求
                        next_state = S2;
                    end else if(wr_req[0]) begin 
                        next_state = S0;
                    end else if(wr_req[1]) begin
                        next_state = S1;
                    end else if(wr_req[2]) begin
                        next_state = S2;
                    end else begin
                        next_state = state;
                    end 
                end else begin
                    next_state = state;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        
        endcase
    end
    
    //wr_record[0]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_record[0] <= 1'b0;
        end else if(wr_record == 4'b1111 && wr_done) begin //将回到IDLE状态, 通道授权记录清零
            wr_record[0] <= 1'b0;
        end else if(next_state == S0) begin //将进入S0, 则将进入的状态记录起来
            wr_record[0] <= 1'b1;
        end else begin
            wr_record[0] <= wr_record[0];
        end
    end
    
    //wr_record[1]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_record[1] <= 1'b0;
        end else if(wr_record == 4'b1111 && wr_done) begin //将回到IDLE状态, 通道授权记录清零
            wr_record[1] <= 1'b0;
        end else if(next_state == S1) begin //将进入S1, 则将进入的状态记录起来
            wr_record[1] <= 1'b1;
        end else begin
            wr_record[1] <= wr_record[1];
        end
    end   
    
    //wr_record[2]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_record[2] <= 1'b0;
        end else if(wr_record == 4'b1111 && wr_done) begin //将回到IDLE状态, 通道授权记录清零
            wr_record[2] <= 1'b0;
        end else if(next_state == S2) begin //将进入S2, 则将进入的状态记录起来
            wr_record[2] <= 1'b1;
        end else begin
            wr_record[2] <= wr_record[2];
        end
    end   
    
    //wr_record[3]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_record[3] <= 1'b0;
        end else if(wr_record == 4'b1111 && wr_done) begin //将回到IDLE状态, 通道授权记录清零
            wr_record[3] <= 1'b0;
        end else if(next_state == S3) begin //将进入S3, 则将进入的状态记录起来
            wr_record[3] <= 1'b1;
        end else begin
            wr_record[3] <= wr_record[3];
        end
    end 

    //wr_grant
    assign wr_grant[0] = (state == S0)?1'b1:1'b0;
    assign wr_grant[1] = (state == S1)?1'b1:1'b0;
    assign wr_grant[2] = (state == S2)?1'b1:1'b0;
    assign wr_grant[3] = (state == S3)?1'b1:1'b0;
    
    //仲裁器发出的仲裁结果
    //axi_wr_addr & axi_wr_start
    always@(*) begin
        case(state) 
            IDLE: begin
                axi_wr_addr  = 'b0;
                axi_wr_data  = 'b0;
                axi_wr_start = 'b0;
                axi_wr_len   = 'b0;
            end
            S0: begin
                axi_wr_addr  = wr_addr0;
                axi_wr_data  = wr_data0;
                axi_wr_start = wr_req[0];
                axi_wr_len   = wr_len0;
            end
            S1: begin
                axi_wr_addr  = wr_addr1;
                axi_wr_data  = wr_data1;
                axi_wr_start = wr_req[1];
                axi_wr_len   = wr_len1;
            end
            S2: begin
                axi_wr_addr  = wr_addr2;
                axi_wr_data  = wr_data2;
                axi_wr_start = wr_req[2];
                axi_wr_len   = wr_len2;
            end
            S3: begin
                axi_wr_addr  = wr_addr3;
                axi_wr_data  = wr_data3;
                axi_wr_start = wr_req[3];
                axi_wr_len   = wr_len3;
            end
            default: begin
                axi_wr_addr  = 'b0;
                axi_wr_data  = 'b0;
                axi_wr_start = 'b0;
                axi_wr_len   = 'b0;
            end
        endcase
    end    
    
    
endmodule
