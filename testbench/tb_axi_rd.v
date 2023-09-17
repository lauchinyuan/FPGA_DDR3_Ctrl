`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/17 16:57:45
// Module Name: tb_axi_rd
// Description: testbench for axi_master_rd & axi_slave_rd modules
//////////////////////////////////////////////////////////////////////////////////


module tb_axi_rd(
        
    );
    //时钟、复位
    reg clk, rst_n;
    
    //主机用户端
    reg         m_rd_start         ; //开始读信号
    wire [29:0] m_rd_addr          ; //读首地址
    wire [63:0] m_rd_data          ; //读出的数据
    wire [7:0]  m_rd_len           ; //突发传输长度
    wire        m_rd_done          ; //读完成标志
    wire        m_rd_ready         ; //准备好读标志
    wire        m_axi_r_handshake  ; //读通道成功握手
    
    //从机用户端
    wire [29:0] s_rd_addr          ; //读首地址
    reg  [63:0] s_rd_data          ; //需要读的数据
    wire        s_rd_en            ; //读存储器使能
    wire [7:0]  s_rd_len           ; //突发传输长度
    wire        s_rd_done          ; //从机读完成标志
    

    //AXI4读地址通道
    wire [3:0]  axi_arid           ; 
    wire [29:0] axi_araddr         ;
    wire [7:0]  axi_arlen          ; //突发传输长度
    wire [2:0]  axi_arsize         ; //突发传输大小(Byte)
    wire [1:0]  axi_arburst        ; //突发类型
    wire        axi_arlock         ; 
    wire [3:0]  axi_arcache        ; 
    wire [2:0]  axi_arprot         ;
    wire [3:0]  axi_arqos          ;
    wire        axi_arvalid        ; //读地址valid
    wire        axi_arready        ; //从机准备接收读地址
    
    //读数据通道
    wire [63:0] axi_rdata          ; //读数据
    wire [1:0]  axi_rresp          ; //收到的读响应
    wire        axi_rlast          ; //最后一个数据标志
    wire        axi_rvalid         ; //读数据有效标志
    wire        axi_rready         ; //主机发出的读数据ready

    //时钟、复位、读开始信号
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        m_rd_start <= 1'b0;
    #20
        rst_n <= 1'b1;
    #600
        m_rd_start <= 1'b1; //发起一次rd_start信号
    #60
        m_rd_start <= 1'b0;
    #3000
        m_rd_start <= 1'b1; //再发起一次rd_start信号
    #20
        m_rd_start <= 1'b0;
    end
    
    
    always#10 clk = ~clk;
    
    //模拟存储器读数据
    //s_rd_data
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            s_rd_data <= 64'd0;
        end else if(s_rd_en) begin  //收到读存储器使能时数据自增
            s_rd_data <= s_rd_data + 64'd1;
        end else begin
            s_rd_data <= s_rd_data;
        end
    end
    
    //读参数赋值
    assign m_rd_addr = 30'd8;
    assign m_rd_len  = 8'd0; //突发长度是m_rd_len+1


    //读主机
    axi_master_rd axi_master_rd_inst(
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .rd_start         (m_rd_start       ), //开始读信号
        .rd_addr          (m_rd_addr        ), //读首地址
        .rd_data          (m_rd_data        ), //读出的数据
        .rd_len           (m_rd_len         ), //突发传输长度
        .rd_done          (m_rd_done        ), //读完成标志
        .rd_ready         (m_rd_ready       ), //准备好读标志
        .m_axi_r_handshake(m_axi_r_handshake), //读通道成功握手
        
        //AXI4读地址通道
        .m_axi_arid       (axi_arid         ), 
        .m_axi_araddr     (axi_araddr       ),
        .m_axi_arlen      (axi_arlen        ), //突发传输长度
        .m_axi_arsize     (axi_arsize       ), //突发传输大小(Byte)
        .m_axi_arburst    (axi_arburst      ), //突发类型
        .m_axi_arlock     (axi_arlock       ), 
        .m_axi_arcache    (axi_arcache      ), 
        .m_axi_arprot     (axi_arprot       ),
        .m_axi_arqos      (axi_arqos        ),
        .m_axi_arvalid    (axi_arvalid      ), //读地址valid
        .m_axi_arready    (axi_arready      ), //从机准备接收读地址
        
        //读数据通道
        .m_axi_rdata      (axi_rdata        ), //读数据
        .m_axi_rresp      (axi_rresp        ), //收到的读响应
        .m_axi_rlast      (axi_rlast        ), //最后一个数据标志
        .m_axi_rvalid     (axi_rvalid       ), //读数据有效标志
        .m_axi_rready     (axi_rready       )  //主机发出的读数据ready
    );
    
    //读从机
    axi_slave_rd axi_slave_rd_inst(
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .rd_addr          (s_rd_addr        ), //读首地址
        .rd_data          (s_rd_data        ), //需要读的数据
        .rd_en            (s_rd_en          ), //读存储器使能
        .rd_len           (s_rd_len         ), //突发传输长度
        .rd_done          (s_rd_done        ), //从机读完成标志
        
        //AXI4读地址通道
        .s_axi_arid       (axi_arid         ), 
        .s_axi_araddr     (axi_araddr       ),
        .s_axi_arlen      (axi_arlen        ), //突发传输长度
        .s_axi_arsize     (axi_arsize       ), //突发传输大小(Byte)
        .s_axi_arburst    (axi_arburst      ), //突发类型
        .s_axi_arlock     (axi_arlock       ), 
        .s_axi_arcache    (axi_arcache      ), 
        .s_axi_arprot     (axi_arprot       ),
        .s_axi_arqos      (axi_arqos        ),
        .s_axi_arvalid    (axi_arvalid      ), //读地址valid
        .s_axi_arready    (axi_arready      ), //从机准备接收读地址
        
        //读数据通道
        .s_axi_rdata      (axi_rdata        ), //读数据
        .s_axi_rresp      (axi_rresp        ), //收到的读响应
        .s_axi_rlast      (axi_rlast        ), //最后一个数据标志
        .s_axi_rvalid     (axi_rvalid       ), //读数据有效标志
        .s_axi_rready     (axi_rready       )  //主机发出的读数据ready
    );
endmodule
