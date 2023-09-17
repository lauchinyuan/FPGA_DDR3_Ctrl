`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:lauchinyuan 
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/17 11:12:05
// Module Name: axi_slave_rd
// Description: AXI接口完成读操作的从机模块, 包含读地址通道和读数据通道
//////////////////////////////////////////////////////////////////////////////////


module axi_slave_rd(
        //用户端
        input   wire        clk              ,
        input   wire        rst_n            ,
        output  reg  [29:0] rd_addr          , //读首地址
        input   wire [63:0] rd_data          , //需要读的数据
        input   reg         rd_en            , //读存储器使能
        output  reg  [7:0]  rd_len           , //突发传输长度
        output  reg         rd_done          , //从机读完成标志
        
        //AXI4读地址通道
        input   wire [3:0]  s_axi_arid      , 
        input   wire [29:0] s_axi_araddr    ,
        input   wire [7:0]  s_axi_arlen     , //突发传输长度
        input   wire [2:0]  s_axi_arsize    , //突发传输大小(Byte)
        input   wire [1:0]  s_axi_arburst   , //突发类型
        input   wire        s_axi_arlock    , 
        input   wire [3:0]  s_axi_arcache   , 
        input   wire [2:0]  s_axi_arprot    ,
        input   wire [3:0]  s_axi_arqos     ,
        input   wire        s_axi_arvalid   , //读地址valid
        output  reg         s_axi_arready   , //从机准备接收读地址
        
        //读数据通道
        output  wire [63:0] s_axi_rdata     , //读数据
        output  wire [1:0]  s_axi_rresp     , //发送的读响应
        output  reg         s_axi_rlast     , //最后一个数据标志
        output  reg         s_axi_rvalid    , //读数据有效标志
        input   wire        s_axi_rready      //主机发出的读数据ready
    );
    
    parameter   IDLE    =   2'b00, //空闲状态,等待读地址握手
                R_WAIT  =   2'b01, //等待读数据
                R       =   2'b10; //读数据
    
    //回应默认是正确
    assign s_axi_rresp = 2'b0;
                
    //握手成功标志
    wire    s_axi_r_handshake;  //读数据通道握手成功
    wire    s_axi_ar_handshake; //读地址通道握手成功
    
    assign  s_axi_r_handshake  = s_axi_rvalid & s_axi_rready;
    assign  s_axi_ar_handshake = s_axi_arvalid & s_axi_arready;
                
    //状态机变量
    reg [1:0]   state       ;
    reg [1:0]   next_state  ;
    
    
    reg [7:0]   cnt_r_burst ; //读触发次数计数器
    
    
    //状态转移
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
                if(s_axi_ar_handshake) begin //读地址通道握手成功
                    next_state = R_WAIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            R_WAIT: begin
                next_state = R;
            end
            
            R: begin
                if(s_axi_r_handshake && s_axi_rlast) begin // 读数据通道握手成功,且是最后一个数据
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
    
    //读突发长度, 读地址
    //rd_len/rd_addr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_len <= 8'd0;
            rd_addr<= 30'b0;
        end else if(state == R_WAIT) begin  //读地址通道已经更新过数据了,此时再将参数寄存
            rd_len <= s_axi_arlen;
            rd_addr<= s_axi_araddr;
        end else begin
            rd_len <= rd_len;
            rd_addr<= rd_addr;
        end
    end
    
    //cnt_r_burst
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt_r_burst <= 8'd0;
        end else if(state == R_WAIT) begin
            cnt_r_burst <= 8'd0;
        end else if(state == R && s_axi_r_handshake && cnt_r_burst < rd_len) begin //每握手一次,代表一个有效数据传输完成,时计数器自增
            cnt_r_burst <= cnt_r_burst + 8'd1;
        end else begin
            cnt_r_burst <= cnt_r_burst;
        end
    end
    
    
    always@(*) begin
        if((cnt_r_burst == rd_len) && (state == R) && s_axi_r_handshake) begin //最后一个成功握手的数据
            s_axi_rlast = 1'b1;
        end else begin
            s_axi_rlast = 1'b0;
        end
    end
    
    
    //s_axi_arready
    //写地址通道ready
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_axi_arready <= 1'b1;
        end else if(state == IDLE && s_axi_ar_handshake) begin //握手成功后拉低
            s_axi_arready <= 1'b0;
        end else if(state == IDLE) begin  //在IDLE状态下默认是拉高的
            s_axi_arready <= 1'b1;
        end else begin
            s_axi_arready <= s_axi_arready;
        end
    end
    
    //读数据通道valid
    //s_axi_rvalid
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_axi_rvalid <= 1'b0;
        end else if(state == R_WAIT) begin
            s_axi_rvalid <= 1'b1;
        end else if(state == R && s_axi_r_handshake && s_axi_rlast) begin //读数据通道握手成功,且是突发传输的最后一个数据
            s_axi_rvalid <= 1'b0;
        end else begin
            s_axi_rvalid <= s_axi_rvalid;
        end
    end
    
    //存储器读使能
    assign rd_en = (state == R && s_axi_r_handshake)?1'b1:1'b0;
    
    //从机读完成标志
    //rd_done
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_done <= 1'b0;
        end else if(state == R && s_axi_r_handshake && s_axi_rlast) begin //读数据通道握手成功,且是突发传输的最后一个数据
            rd_done <= 1'b1;
        end else begin
            rd_done <= 1'b0;
        end
    end
    
    //s_axi_rdata
    assign s_axi_rdata = rd_data;
    
            
endmodule
