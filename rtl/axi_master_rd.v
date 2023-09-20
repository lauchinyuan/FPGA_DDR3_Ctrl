`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/17 09:43:12
// Module Name: axi_master_rd 
// Description: AXI4接口的主机读模块,完成读数据通道和读地址通道的功能
//////////////////////////////////////////////////////////////////////////////////


module axi_master_rd(
        //用户端
        input   wire        clk              ,
        input   wire        rst_n            ,
        input   wire        rd_start         , //开始读信号
        input   wire [29:0] rd_addr          , //读首地址
        output  wire [63:0] rd_data          , //读出的数据
        input   wire [7:0]  rd_len           , //突发传输长度
        output  reg         rd_done          , //读完成标志
        output  wire        rd_ready         , //准备好读标志
        output  wire        m_axi_r_handshake, //读通道成功握手
        
        //AXI4读地址通道
        output  wire [3:0]  m_axi_arid      , 
        output  reg  [29:0] m_axi_araddr    ,
        output  reg  [7:0]  m_axi_arlen     , //突发传输长度
        output  wire [2:0]  m_axi_arsize    , //突发传输大小(Byte)
        output  wire [1:0]  m_axi_arburst   , //突发类型
        output  wire        m_axi_arlock    , 
        output  wire [3:0]  m_axi_arcache   , 
        output  wire [2:0]  m_axi_arprot    ,
        output  wire [3:0]  m_axi_arqos     ,
        output  reg         m_axi_arvalid   , //读地址valid
        input   wire        m_axi_arready   , //从机准备接收读地址
        
        //读数据通道
        input   wire [63:0] m_axi_rdata     , //读数据
        input   wire [1:0]  m_axi_rresp     , //收到的读响应
        input   wire        m_axi_rlast     , //最后一个数据标志
        input   wire        m_axi_rvalid    , //读数据有效标志
        output  reg         m_axi_rready      //主机发出的读数据ready
    );
    
    //读数据相关参数定义
    parameter   M_AXI_ARID      =  4'd0     ,
                M_AXI_ARSIZE    =  3'b011   , //8Byte
                M_AXI_ARBURST   =  2'b10    , //突发类型, INCR
                M_AXI_ARLOCK    =  1'b0     , //不锁定
                M_AXI_ARCACHE   =  4'b0010  , //存储器类型, 选择Normal Non-cacheable Non-bufferable
                M_AXI_ARPROT    =  3'b0     ,
                M_AXI_ARQOS     =  4'b0     ;   
    
    //状态机状态定义
    parameter   IDLE    =   3'b000,  //空闲状态
                RA_WAIT =   3'b001,  //等待读地址
                RA      =   3'b010,  //读地址有效
                R_WAIT  =   3'b011,  //等待读数据
                R       =   3'b100;  //读数据有效
    
    //状态机变量
    reg [2:0]   state       ;
    reg [2:0]   next_state  ;
    
    //握手成功标志
    wire        m_axi_ar_handshake;  //读地址通道握手成功
    reg         m_axi_r_handshake_d; //读数据通道握手成功打一拍,使其高电平与读取的数据对齐
    
    assign      m_axi_ar_handshake = m_axi_arready & m_axi_arvalid;
    assign      m_axi_r_handshake  = m_axi_rready & m_axi_rvalid;
    
    
    //读参数赋值
    assign  m_axi_arid    = M_AXI_ARID      ;
    assign  m_axi_arsize  = M_AXI_ARSIZE    ;
    assign  m_axi_arburst = M_AXI_ARBURST   ;
    assign  m_axi_arlock  = M_AXI_ARLOCK    ;
    assign  m_axi_arcache = M_AXI_ARCACHE   ;
    assign  m_axi_arprot  = M_AXI_ARPROT    ;
    assign  m_axi_arqos   = M_AXI_ARQOS     ;
    
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
            IDLE: begin  //准备接收读开始信号(rd_start)
                if(rd_start) begin
                    next_state = RA_WAIT; //接收到rd_start有效
                end else begin
                    next_state = IDLE;
                end
            end
            
            RA_WAIT: begin
                next_state = RA;
            end
            
            RA: begin
                if(m_axi_ar_handshake) begin //读地址通道握手成功
                    next_state = R_WAIT;
                end else begin
                    next_state = RA;
                end
            end
            
            R_WAIT: begin
                next_state = R;
            end
            
            R: begin
                if(m_axi_r_handshake && m_axi_rlast) begin  //读通道握手成功,且是最后一个突发数据
                    next_state = IDLE;
                end else begin
                    next_state = R;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //读地址通道valid
    //m_axi_arvalid
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_arvalid <= 1'b0;
        end else if(state == RA_WAIT) begin
            m_axi_arvalid <= 1'b1;
        end else if(state == RA && m_axi_ar_handshake) begin  //写地址通道握手成功
            m_axi_arvalid <= 1'b0;
        end else begin
            m_axi_arvalid <= m_axi_arvalid;
        end
    end
    
    //读地址通道地址以及突发长度
    //m_axi_arlen / m_axi_araddr
    always@(posedge clk or negedge rst_n) begin 
        if(~rst_n) begin
            m_axi_arlen <= 8'd0;
            m_axi_araddr<= 30'd0;
        end else if(state == RA && m_axi_ar_handshake) begin //读地址通道握手成功,更新相关数据
            m_axi_arlen <= rd_len;
            m_axi_araddr<= rd_addr;
        end else begin
            m_axi_arlen <= m_axi_arlen;
            m_axi_araddr<= m_axi_araddr;
        end
    end
    
    //读数据通道ready
    //m_axi_rready
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_rready <= 1'b0;
        end else if(state == R_WAIT) begin
            m_axi_rready <= 1'b1;
        end else if(state == R && m_axi_rlast && m_axi_r_handshake) begin //读数据通道握手成功,且是最后一个数据
            m_axi_rready <= 1'b0;
        end else begin
            m_axi_rready <= m_axi_rready;
        end
    end
    
    //rd_ready
    assign rd_ready = (state == IDLE)?1'b1:1'b0;  //在IDLE状态下准备好接收读请求
    
    //rd_done
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_done <= 1'b0;
        end else if(state == R && m_axi_rlast && m_axi_r_handshake) begin //读数据通道握手成功,且是最后一个数据
            rd_done <= 1'b1;
        end else begin
            rd_done <= 1'b0;
        end
    end
    
    //m_axi_r_handshake_d
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            m_axi_r_handshake_d <= 1'b0;
        end else begin
            m_axi_r_handshake_d <= m_axi_r_handshake;
        end
    end
    
    //rd_data 
    //读通道握手成功时,为有效数据输出
    assign rd_data = (m_axi_r_handshake_d)?m_axi_rdata:64'b0;
    

endmodule
