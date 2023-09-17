`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/15 16:50:47
// Module Name: axi_master_wr
// Description: AIX4接口主机写模块,包含AXI4总线Master端的写数据通道、写地址通道和写响应通道
//////////////////////////////////////////////////////////////////////////////////


module axi_master_wr(
        //用户端
        input   wire        clk              ,
        input   wire        rst_n            ,
        input   wire        wr_start         , //开始写信号
        input   wire [29:0] wr_addr          , //写首地址
        input   wire [63:0] wr_data          ,
        input   wire [7:0]  wr_len           , //突发传输长度
        output  reg         wr_done          , //写完成标志
        output  wire        m_axi_w_handshake, //写通道成功握手
        output  wire        wr_ready         , //写准备信号,拉高时可以发起wr_start
        
        //AXI4写地址通道
        output  wire [3:0]  m_axi_awid      , 
        output  reg  [29:0] m_axi_awaddr    ,
        output  reg  [7:0]  m_axi_awlen     , //突发传输长度
        output  wire [2:0]  m_axi_awsize    , //突发传输大小(Byte)
        output  wire [1:0]  m_axi_awburst   , //突发类型
        output  wire        m_axi_awlock    , 
        output  wire [3:0]  m_axi_awcache   , 
        output  wire [2:0]  m_axi_awprot    ,
        output  wire [3:0]  m_axi_awqos     ,
        output  reg         m_axi_awvalid   , //写地址valid
        input   wire        m_axi_awready   , //从机发出的写地址ready
        
        //写数据通道
        output  wire [63:0] m_axi_wdata     , //写数据
        output  wire [7:0]  m_axi_wstrb     , //写数据有效字节线
        output  reg         m_axi_wlast     , //最后一个数据标志
        output  reg         m_axi_wvalid    , //写数据有效标志
        input   wire        m_axi_wready    , //从机发出的写数据ready
        
        //写响应通道
        output  wire [3:0]  m_axi_bid       ,
        input   wire [1:0]  m_axi_bresp     , //响应信号,表征写传输是否成功
        input   wire        m_axi_bvalid    , //响应信号valid标志
        output  reg         m_axi_bready      //主机响应ready信号
    );
    
    //写数据相关参数定义
    parameter   M_AXI_AWID      =  4'd0     ,
                M_AXI_AWSIZE    =  3'b011   , //8Byte
                M_AXI_AWBURST   =  2'b10   , //突发类型, INCR
                M_AXI_AWLOCK    =  1'b0     , //不锁定
                M_AXI_AWCACHE   =  4'b0010  , //存储器类型, 选择Normal Non-cacheable Non-bufferable
                M_AXI_AWPROT    =  3'b0     ,
                M_AXI_AWQOS     =  4'b0     ,
                M_AXI_WSTRB     =  8'hff    ,
                M_AXI_BID       =  4'b0     ;
                
                
    
    
    //状态机状态定义
    parameter   IDLE    =   3'b000,  //空闲状态
                WA_WAIT =   3'b001,  //等待写地址
                WA      =   3'b010,  //写地址有效
                W_WAIT  =   3'b011,  //等待写数据
                W       =   3'b100,  //写数据有效
                B_WAIT  =   3'b101,  //等待写响应
                B       =   3'b110;  //准备接收写响应
                
    //状态机变量
    reg [2:0]   state       ;
    reg [2:0]   next_state  ;
    
    //握手成功标志
    wire        m_axi_aw_handshake;  //写地址通道握手成功
    wire        m_axi_b_handshake;   //写响应通道握手成功
    
    //中间辅助变量
    reg [7:0]   cnt_w_burst     ;    //突发次数计数器,用于辅助生成m_axi_wlast信号
    
    //握手成功标志
    assign      m_axi_aw_handshake  = m_axi_awready & m_axi_awvalid ;
    assign      m_axi_w_handshake   = m_axi_wready  & m_axi_wvalid  ;
    assign      m_axi_b_handshake   = m_axi_bready  & m_axi_bvalid  ;   
    
    
    //写参数赋值
    assign  m_axi_awid    = M_AXI_AWID      ;
    assign  m_axi_awsize  = M_AXI_AWSIZE    ;
    assign  m_axi_awburst = M_AXI_AWBURST   ;
    assign  m_axi_awlock  = M_AXI_AWLOCK    ;
    assign  m_axi_awcache = M_AXI_AWCACHE   ;
    assign  m_axi_awprot  = M_AXI_AWPROT    ;
    assign  m_axi_awqos   = M_AXI_AWQOS     ;
    assign  m_axi_wstrb   = M_AXI_WSTRB     ;
    assign  m_axi_bid     = M_AXI_BID       ;
    
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
                if(wr_start) begin
                    next_state = WA_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            WA_WAIT: begin
                next_state = WA;
            end
            
            WA: begin
                if(m_axi_aw_handshake) begin //写地址通道握手成功
                    next_state = W_WAIT;
                end else begin
                    next_state = WA;
                end
            end
            
            W_WAIT: begin
                next_state = W;
            end
            
            W: begin
                if(m_axi_w_handshake && m_axi_wlast) begin //写数据通道握手成功, 且已经是突发传输的最后一个数据
                    next_state = B_WAIT;
                end else begin
                    next_state = W;
                end
            end
            
            B_WAIT: begin
                next_state = B;
            end
            
            B: begin
                if(m_axi_b_handshake) begin  //写响应通道握手成功
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
    
    //写地址通道valid
    //m_axi_awvalid
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_awvalid <= 1'b0;
        end else if(state == WA_WAIT) begin //在WA_WAIT状态的下一个时钟周期拉高m_axi_awvalid
            m_axi_awvalid <= 1'b1;
        end else if(m_axi_aw_handshake) begin //写地址通道握手成功,拉低valid信号
            m_axi_awvalid <= 1'b0;
        end else begin
            m_axi_awvalid <= m_axi_awvalid;
        end
    end
    
    //写地址通道地址、突发长度
    //m_axi_awaddr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_awaddr <= 30'b0;
            m_axi_awlen  <= 8'd0;
        end else if(state == WA_WAIT) begin //在WA_WAIT状态的下一个时钟周期更新地址和突发长度
            m_axi_awaddr <= wr_addr;
            m_axi_awlen  <= wr_len;
        end else begin
            m_axi_awaddr <= m_axi_awaddr;
            m_axi_awlen  <= m_axi_awlen;
        end
    end
    
    
    //突发次数计数器
    //cnt_w_burst
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt_w_burst <= 8'd0;
        end else if(state == W_WAIT) begin //在W_WAIT状态的下一个时钟周期清零
            cnt_w_burst <= 8'd0;
        end else if(state == W && m_axi_w_handshake && cnt_w_burst < wr_len) begin //每握手成功一次,更新一次计数值,直到wr_len
            cnt_w_burst <= cnt_w_burst + 8'd1;
        end else begin
            cnt_w_burst <= cnt_w_burst;
        end
    end
    
    //最后一次突发标志
    //m_axi_wlast
    always@(*) begin
        if((cnt_w_burst == m_axi_awlen) && m_axi_w_handshake && (state == W)) begin //最后一个有效数据
            m_axi_wlast = 1'b1;
        end else begin
            m_axi_wlast = 1'b0;
        end
    end
    
    
    //写通道valid
    //m_axi_wvalid
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_wvalid <= 1'b0;
        end else if(state == W_WAIT) begin
            m_axi_wvalid <= 1'b1;
        end else if(state == W && m_axi_w_handshake && m_axi_wlast) begin //写通道握手成功且是最后一个数据
            m_axi_wvalid <= 1'b0;
        end else begin
            m_axi_wvalid <= m_axi_wvalid;
        end
    end
    
    //写通道数据
    //m_axi_wdata
    assign m_axi_wdata = wr_data;
    
    //写响应通道ready
    //m_axi_bready
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_bready <= 1'b0;
        end else if(state == B_WAIT) begin  //在B_WAIT的下一个状态拉高bready信号,准备接收从机发来的响应
            m_axi_bready <= 1'b1;
        end else if(state == B && m_axi_b_handshake) begin //响应通道握手成功后拉低
            m_axi_bready <= 1'b0;
        end else begin
            m_axi_bready <= m_axi_bready;
        end
    end
    
    //写完成标志
    //wr_done
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_done <= 1'b0;
        end else if(m_axi_b_handshake && state == B) begin //在B状态下成功握手,代表一次突发传输已经完成
            wr_done <= 1'b1;
        end else begin
            wr_done <= 1'b0;
        end
    end
    
    //wr_ready
    assign wr_ready = (state == IDLE)?1'b1:1'b0;  //在IDLE状态下准备好写
        
endmodule
