`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/02 20:30:50
// Module Name: multichannel_rd_arbiter
// Description: DDR SDRAM多通道读仲裁器, 对多个读通道的读请求进行读权限判断
// 决定当前时刻有效的读通道, 并将这个通道的有效的读请求信号和读地址发送给AXI读主机
// 仲裁方案简述: 没有获得过授权的通道请求优先, 
// 在(都没有获得过授权/都获得过授权)的通道内, 低编号优先。
// 举例: 初始化时, 所有通道都没有获得过授权的记录, 
// 若通道0、1、3都有读请求, 优先响应通道0
// 通道0一次读取完成后, 通道0的优先级变低, 首先判断其它通道是否有读请求, 有则授权其它通道
// 假设第二次授权通道2(此时通道2\0都有授权的历史), 则第三次授权判定时, 首先判断剩下的通道
// 以次类推
//////////////////////////////////////////////////////////////////////////////////
module multichannel_rd_arbiter(
        input   wire                clk             ,
        input   wire                rst_n           ,
        
        //不同读控制器输入的控制信号
        input   wire [3:0]          rd_req          , //rd_req[i]代表读通道i的读请求
        input   wire [29:0]         rd_addr0        , //读通道0发来的读地址
        input   wire [29:0]         rd_addr1        , //读通道1发来的读地址
        input   wire [29:0]         rd_addr2        , //读通道2发来的读地址
        input   wire [29:0]         rd_addr3        , //读通道3发来的读地址
        
        input   wire [7:0]          rd_len0         , //通道0发来的读突发长度
        input   wire [7:0]          rd_len1         , //通道1发来的读突发长度
        input   wire [7:0]          rd_len2         , //通道2发来的读突发长度
        input   wire [7:0]          rd_len3         , //通道3发来的读突发长度
        
        //发给各通道读控制器的读授权
        output  wire [3:0]          rd_grant        , //rd_grant[i]代表读通道i的读授权
        
        //AXI读主机输入信号
        input   wire                rd_done         , //AXI读主机送来的一次突发传输完成标志
        
        //发送到AXI读主机的仲裁结果
        output  reg                 axi_rd_start    , //仲裁后有效的读请求
        output  reg [29:0]          axi_rd_addr     , //仲裁后有效的读地址输出
        output  reg [7:0]           axi_rd_len        //仲裁后有效的读突发长度
    );
    
    //状态机状态定义
    parameter   IDLE    =   5'b00001    , // IDLE状态, 没有通道获得授权
                S0      =   5'b00010    , // 通道0获得授权
                S1      =   5'b00100    , // 通道1获得授权
                S2      =   5'b01000    , // 通道2获得授权
                S3      =   5'b10000    ; // 通道3获得授权
    
    
    //中间变量
    reg [3:0]           rd_req_d        ; //rd_req打一拍, 用于生成rd_req_acti信号
    wire                rd_req_acti     ; //rd_req_acti信号为高, 则代表有读通道开始发出rd_req读请求
//    reg                 rd_req_acti_reg ; //对rd_req_acti信号进行锁存, 直到acti_valid信号有效为止
    reg                 acti_valid      ; //对rd_req_acti的响应状态(有效或者无效), 防止当前通道没有读完, 因为rd_req发生突变而提前转换通道
    
    //通道使用历史记录变量
    reg [3:0]           rd_record       ; //rd_record[i]代表在这一轮, 通道i已经发送过读请求
    
    //用到多次的中间变量复用, 省资源
    wire[3:0]           rd_req_non_grant; //当通道i有读请求且无授权历史时rd_req_non_grant[i]为高
    
    //状态机变量
    reg [4:0]           state           ;
    reg [4:0]           next_state      ;
    
    //输入读请求信号打拍
    //rd_req打拍
    //rd_req_d
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req_d <= 'b0;
        end else begin
            rd_req_d <= rd_req;
        end
    end
    
    //rd_req_acti, rd_req从0变化为非零值
    assign rd_req_acti = ((rd_req_d == 4'b0000) && (rd_req != 4'b0000))?1'b1:1'b0;
    
    //acti_valid
    //只有在每一个读请求都收到rd_done信号后, 才允许响应新的rd_req_acti_reg
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            acti_valid <= 1'b1;         //复位时处于有效响应状态
        end else if(axi_rd_start) begin //发送读请求, 则拉低有效状态
            acti_valid <= 1'b0;
        end else if(rd_done) begin      //接收到rd_done
            acti_valid <= 1'b1;
        end else begin
            acti_valid <= acti_valid;
        end
    end
    
/*     //rd_req_acti_reg
    //锁存rd_req_acti, 直到acti_valid有效则释放
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_req_acti_reg <= 1'b1; //复位后首先是有效状态
        end else if(rd_req_acti_reg && acti_valid) begin //释放
            rd_req_acti_reg <= 1'b0;
        end else if(rd_req_acti) begin
            rd_req_acti_reg <= 1'b1;
        end else begin
            rd_req_acti_reg <= rd_req_acti_reg;
        end
    end */

    //状态机状态转移
    //state
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //无授权历史的读请求
    //rd_req_non_grant
    assign rd_req_non_grant = rd_req & (~rd_record);
    
    
    //状态机次态
    always@(*) begin
        case(state) 
            IDLE: begin
                //通道优先级: 0 > 1 > 2 > 3
                if(rd_req[0]) begin
                    next_state = S0;
                end else if(rd_req[1]) begin
                    next_state = S1;
                end else if(rd_req[2]) begin
                    next_state = S2;
                end else if(rd_req[3]) begin
                    next_state = S3; 
                end else begin
                    next_state = IDLE;
                end               
            end
            
            S0: begin  
                //通道优先级: [1 > 2 > 3] > [1 > 2 > 3] > 0
                //            (无授权历史)  (有授权历史)
                if(rd_done || (rd_req_acti && acti_valid)) begin 
                    if(rd_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(rd_req_non_grant[1]) begin //通道1有本轮未经授权过的读请求
                        next_state = S1;
                    end else if(rd_req_non_grant[2]) begin //通道2有本轮未经授权过的读请求
                        next_state = S2;
                    end else if(rd_req_non_grant[3]) begin //通道3有本轮未经授权过的读请求
                        next_state = S3;
                    end else if(rd_req[1]) begin 
                        next_state = S1;
                    end else if(rd_req[2]) begin
                        next_state = S2;
                    end else if(rd_req[3]) begin
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
                if(rd_done || (rd_req_acti && acti_valid)) begin
                    if(rd_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(rd_req_non_grant[2]) begin //通道2有本轮未经授权过的读请求
                        next_state = S2;
                    end else if(rd_req_non_grant[3]) begin //通道3有本轮未经授权过的读请求
                        next_state = S3;
                    end else if(rd_req_non_grant[0]) begin //通道0有本轮未经授权过的读请求
                        next_state = S0;
                    end else if(rd_req[2]) begin 
                        next_state = S2;
                    end else if(rd_req[3]) begin
                        next_state = S3;
                    end else if(rd_req[0]) begin
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
                if(rd_done || (rd_req_acti && acti_valid)) begin
                    if(rd_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(rd_req_non_grant[3]) begin //通道2有本轮未经授权过的读请求
                        next_state = S3;
                    end else if(rd_req_non_grant[0]) begin //通道3有本轮未经授权过的读请求
                        next_state = S0;
                    end else if(rd_req_non_grant[1]) begin //通道0有本轮未经授权过的读请求
                        next_state = S1;
                    end else if(rd_req[3]) begin 
                        next_state = S3;
                    end else if(rd_req[0]) begin
                        next_state = S0;
                    end else if(rd_req[1]) begin
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
                if(rd_done || (rd_req_acti && acti_valid)) begin //在读完后进行通道切换判断, 或者在较长时间后在rd_req激活时进行通道切换判断
                    if(rd_record == 4'b1111) begin //对所有通道都已经授权过一轮, 重新回到IDLE状态
                        next_state = IDLE;
                    end else if(rd_req_non_grant[0]) begin //通道2有本轮未经授权过的读请求
                        next_state = S0;
                    end else if(rd_req_non_grant[1]) begin //通道3有本轮未经授权过的读请求
                        next_state = S1;
                    end else if(rd_req_non_grant[2]) begin //通道0有本轮未经授权过的读请求
                        next_state = S2;
                    end else if(rd_req[0]) begin 
                        next_state = S0;
                    end else if(rd_req[1]) begin
                        next_state = S1;
                    end else if(rd_req[2]) begin
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
    
    //rd_record[0]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_record[0] <= 1'b0;
        end else if(rd_record == 4'b1111 && rd_done) begin //将回到IDLE状态, 通道授权记录清零
            rd_record[0] <= 1'b0;
        end else if(next_state == S0) begin //将进入S0, 则将进入的状态记录起来
            rd_record[0] <= 1'b1;
        end else begin
            rd_record[0] <= rd_record[0];
        end
    end
    
    //rd_record[1]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_record[1] <= 1'b0;
        end else if(rd_record == 4'b1111 && rd_done) begin //将回到IDLE状态, 通道授权记录清零
            rd_record[1] <= 1'b0;
        end else if(next_state == S1) begin //将进入S1, 则将进入的状态记录起来
            rd_record[1] <= 1'b1;
        end else begin
            rd_record[1] <= rd_record[1];
        end
    end   
    
    //rd_record[2]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_record[2] <= 1'b0;
        end else if(rd_record == 4'b1111 && rd_done) begin //将回到IDLE状态, 通道授权记录清零
            rd_record[2] <= 1'b0;
        end else if(next_state == S2) begin //将进入S2, 则将进入的状态记录起来
            rd_record[2] <= 1'b1;
        end else begin
            rd_record[2] <= rd_record[2];
        end
    end   
    
    //rd_record[3]
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_record[3] <= 1'b0;
        end else if(rd_record == 4'b1111 && rd_done) begin //将回到IDLE状态, 通道授权记录清零
            rd_record[3] <= 1'b0;
        end else if(next_state == S3) begin //将进入S3, 则将进入的状态记录起来
            rd_record[3] <= 1'b1;
        end else begin
            rd_record[3] <= rd_record[3];
        end
    end 

    //rd_grant
    assign rd_grant[0] = (state == S0)?1'b1:1'b0;
    assign rd_grant[1] = (state == S1)?1'b1:1'b0;
    assign rd_grant[2] = (state == S2)?1'b1:1'b0;
    assign rd_grant[3] = (state == S3)?1'b1:1'b0;
    
    //仲裁器发出的仲裁结果
    //axi_rd_addr & axi_rd_start
    always@(*) begin
        case(state) 
            IDLE: begin
                axi_rd_addr  = 'b0;
                axi_rd_start = 'b0;
                axi_rd_len   = 'b0;
            end
            S0: begin
                axi_rd_addr  = rd_addr0;
                axi_rd_start = rd_req[0];
                axi_rd_len   = rd_len0;
            end
            S1: begin
                axi_rd_addr  = rd_addr1;
                axi_rd_start = rd_req[1];
                axi_rd_len   = rd_len1;
            end
            S2: begin
                axi_rd_addr  = rd_addr2;
                axi_rd_start = rd_req[2];
                axi_rd_len   = rd_len2;
            end
            S3: begin
                axi_rd_addr  = rd_addr3;
                axi_rd_start = rd_req[3];
                axi_rd_len   = rd_len3;
            end
            default: begin
                axi_rd_addr  = 'b0;
                axi_rd_start = 'b0;
                axi_rd_len   = 'b0;
            end
        endcase
    end
    
    
endmodule
