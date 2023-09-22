`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/16 16:41:36
// Module Name: axi_slave_wr
// Description: AXI总线完成写功能的从机,AXI总线主机发送AXI数据到此模块
// 此模块主要用于协助axi_master_wr的仿真
//////////////////////////////////////////////////////////////////////////////////


module axi_slave_wr(
        //用户接口
        input   wire        clk             ,
        input   wire        rst_n           ,
        output  reg  [29:0] wr_addr         ,
        output  reg  [7:0]  wr_len          ,
        output  wire [63:0] wr_data         ,
        output  wire        wr_en           , //写存储器使能
        output  reg         wr_done         , //写完成

        //AXI4写地址通道
        input   wire [3:0]  s_axi_awid      , 
        input   wire [29:0] s_axi_awaddr    ,
        input   wire [7:0]  s_axi_awlen     , //突发传输长度
        input   wire [2:0]  s_axi_awsize    , //突发传输大小(Byte)
        input   wire [1:0]  s_axi_awburst   , //突发类型
        input   wire        s_axi_awlock    , 
        input   wire [3:0]  s_axi_awcache   , 
        input   wire [2:0]  s_axi_awprot    ,
        input   wire [3:0]  s_axi_awqos     ,
        input   wire        s_axi_awvalid   , //写地址valid
        output  reg         s_axi_awready   , //从机发出的写地址ready
        
        //写数据通道
        input   wire [63:0] s_axi_wdata     , //写数据
        input   wire [7:0]  s_axi_wstrb     , //写数据有效字节线
        input   wire        s_axi_wlast     , //最后一个数据标志
        input   wire        s_axi_wvalid    , //写数据有效标志
        output  reg         s_axi_wready    , //从机发出的写数据ready
        
        //写响应通道
        output  wire [3:0]  s_axi_bid       ,
        output  wire [1:0]  s_axi_bresp     , //响应信号,表征写传输是否成功
        output  reg         s_axi_bvalid    , //响应信号valid标志
        input   wire        s_axi_bready      //主机响应ready信号        
    );
    
    //状态机状态定义
    parameter   IDLE    =   3'b001  ,  //空闲状态,等待有效写地址
                W_WAIT  =   3'b010  ,  //等待写状态
                W       =   3'b011  ,  //写状态
                B       =   3'b100  ;  //响应状态
    
                
    //状态机变量
    reg [2:0]   state       ;
    reg [2:0]   next_state  ;
    
    //握手成功信号
    wire        s_axi_aw_handshake  ; //写地址通道握手成功
    wire        s_axi_w_handshake   ; //写数据通道握手成功
    wire        s_axi_b_handshake   ; //写响应通道握手成功
    
    assign  s_axi_aw_handshake = s_axi_awready & s_axi_awvalid  ;
    assign  s_axi_w_handshake  = s_axi_wready  & s_axi_wvalid   ;
    assign  s_axi_b_handshake  = s_axi_bready  & s_axi_bvalid   ;
    
    //错误标志, 接收到的数据量与预期不一致
    reg     err ;
    
    
    reg [7:0]   cnt_w_burst         ; //写突发计数器
    
    //状态转移
    //state
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    //次态
    //next_state
    always@(*) begin
        case(state) 
            IDLE: begin
                if(s_axi_aw_handshake) begin //写地址通道握手成功
                    next_state = W_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            W_WAIT: begin
                next_state = W; //W_WAIT只持续一个周期
            end
            
            W: begin
                if(s_axi_w_handshake && s_axi_wlast) begin  //写数据通道握手成功且主机已经发送wlast信号
                    next_state = B;
                end else begin
                    next_state = W;
                end
            end
            
            B: begin
                if(s_axi_b_handshake) begin //写响应通道握手成功
                    next_state = IDLE;
                end else begin
                    next_state = B;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //写地址通道写地址,写突发长度
    //wr_len, wr_addr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_len  <= 8'd0;
            wr_addr <= 30'b0;
        end else if(state == W_WAIT) begin  //在W_WAIT状态的下一个时钟周期更新wr_len和wr_addr
            wr_len  <= s_axi_awlen;
            wr_addr <= s_axi_awaddr;
        end else begin
            wr_len  <= wr_len;
            wr_addr <= wr_addr;
        end
    end
    
    //写地址通道ready
    //s_axi_awready
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_axi_awready <= 1'b1;  //默认ready信号为高,代表可以接收有效的地址和控制信号
        end else if(s_axi_aw_handshake && state == IDLE) begin //写地址通道握手成功,拉低ready信号
            s_axi_awready <= 1'b0;
        end else if(state == IDLE) begin
            s_axi_awready <= 1'b1; //在IDLE状态下等待有效的地址和控制信号
        end else begin
            s_axi_awready <= s_axi_awready;
        end
    end
    
    //写突发次数计数器,用于比对传输是否出错
    //cnt_w_burst
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt_w_burst <= 8'd0;
        end else if(state == W_WAIT) begin  
            cnt_w_burst <= 8'd0;
        end else if(s_axi_w_handshake && state == W) begin //写数据通道成功握手一次自增一个计数值
            cnt_w_burst <= cnt_w_burst + 8'd1;
        end else begin
            cnt_w_burst <= cnt_w_burst;
        end
    end
    
    //写数据通道ready
    //s_axi_wready
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            s_axi_wready <= 1'b0;
        end else if(state == W_WAIT) begin
            s_axi_wready <= 1'b1;
        end else if(s_axi_w_handshake && s_axi_wlast && state==W) begin //写通道握手成功,且是最后一个数据
            s_axi_wready <= 1'b0;
        end else begin
            s_axi_wready <= s_axi_wready;
        end
    end
    
    //err
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            err <= 1'b0;
        end else if(state == W && s_axi_wlast && s_axi_w_handshake && (cnt_w_burst!=wr_len)) begin 
        //最后一个数据到来时,发现接收到的数据不符合预期
            err <= 1'b1;
        end else if(state == B && s_axi_b_handshake) begin //写响应通道握手后拉低
            err <= 1'b0;
        end else begin
            err <= err;
        end  
    end
    
    //写响应valid信号
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_axi_bvalid <= 1'b0;
        end else if(state == W && s_axi_wlast && s_axi_w_handshake) begin //握手且是最后一个突发数据
            s_axi_bvalid <= 1'b1;
        end else if(state == B && s_axi_b_handshake) begin //写响应通道握手后拉低
            s_axi_bvalid <= 1'b0;
        end else begin
            s_axi_bvalid <= s_axi_bvalid;
        end
    end
    
    //s_axi_bresp
    assign s_axi_bresp = {err, 1'b0};
    
    //从机写完成标志
    //wr_done
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_done <= 1'b0; 
        end else if(state == B && s_axi_b_handshake) begin //写响应通道握手响应后拉高一个时钟周期
            wr_done <= 1'b1;
        end else begin
            wr_done <= 1'b0;
        end
    end
    
    assign wr_data = (s_axi_w_handshake)?s_axi_wdata:64'b0;  //握手有效时输出有效数据
    assign wr_en = s_axi_w_handshake;
    assign s_axi_bid = 4'd0;
    
    
endmodule
