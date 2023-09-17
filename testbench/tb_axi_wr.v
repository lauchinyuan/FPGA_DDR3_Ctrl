`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/16 20:42:53
// Module Name: tb_axi_wr
// Description: testbench for axi_master_wr & axi_slave_wr
//////////////////////////////////////////////////////////////////////////////////


module tb_axi_wr(

    );
    
    //主机用户端信号
    reg         clk               ;
    reg         rst_n             ;
    reg         m_wr_start        ; //开始写信号
    wire [29:0] m_wr_addr         ; //写首地址
    reg  [63:0] m_wr_data         ;
    wire [7:0]  m_wr_len          ; //突发传输长度
    wire        m_wr_done         ; //写完成标志
    wire        m_axi_w_handshake ; //写通道成功握手
    wire        m_wr_ready        ;
    
    //从机用户端信号
    wire [29:0] s_wr_addr         ; 
    wire [63:0] s_wr_data         ;
    wire [7:0]  s_wr_len          ;
    wire        s_wr_en           ; //写存储器使能
    wire        s_wr_done         ; //写完成
    
    //主机与从机之间的AXI总线
    //AXI4写地址通道
    wire [3:0]  axi_awid          ; 
    wire [29:0] axi_awaddr        ; 
    wire [7:0]  axi_awlen         ; //突发传输长度
    wire [2:0]  axi_awsize        ; //突发传输大小(Byte)
    wire [1:0]  axi_awburst       ; //突发类型
    wire        axi_awlock        ; 
    wire [3:0]  axi_awcache       ; 
    wire [2:0]  axi_awprot        ; 
    wire [3:0]  axi_awqos         ; 
    wire        axi_awvalid       ; //写地址valid
    wire        axi_awready       ; //从机发出的写地址ready
    
    //写数据通道
    wire [63:0] axi_wdata         ; //写数据
    wire [7:0]  axi_wstrb         ; //写数据有效字节线
    wire        axi_wlast         ; //最后一个数据标志
    wire        axi_wvalid        ; //写数据有效标志
    wire        axi_wready        ; //从机发出的写数据readyady
    
    //写响应通道
    wire [3:0]  axi_bid           ;
    wire [1:0]  axi_bresp         ; //响应信号,表征写传输是否成功输是否成功
    wire        axi_bvalid        ; //响应信号valid标志
    wire        axi_bready        ; //主机响应ready信号

    //时钟和复位以及写开始信号
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        m_wr_start <= 1'b0;
    #20
        rst_n <= 1'b1;
    #600
        m_wr_start <= 1'b1;  //产生写开始信号
    #40
        m_wr_start <= 1'b0;
    #3000
        m_wr_start <= 1'b1;  //再次产生写开始信号
    #20
        m_wr_start <= 1'b0;
    end
    
    always#10 clk = ~clk;
    
    assign m_wr_addr = 30'b100; //设定写地址
    assign m_wr_len  = 8'd0; //设定突发写长度,实际突发长度是m_wr_len+1
    
    //产生写数据
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            m_wr_data <= 64'd0;
        end else if(m_axi_w_handshake) begin //写通道握手,同时更新数据
            m_wr_data <= m_wr_data + 64'd1;
        end else begin
            m_wr_data <= m_wr_data;
        end
    end
    
    
    //AXI写主机
    axi_master_wr axi_master_wr_inst(
        //用户端
        .clk              (clk              ),
        .rst_n            (rst_n            ),
        .wr_start         (m_wr_start       ), //开始写信号
        .wr_addr          (m_wr_addr        ), //写首地址
        .wr_data          (m_wr_data        ),
        .wr_len           (m_wr_len         ), //突发传输长度
        .wr_done          (m_wr_done        ), //写完成标志
        .wr_ready         (m_wr_ready       ),
        .m_axi_w_handshake(m_axi_w_handshake), //写通道成功握手
        
        //AXI4写地址通道
        .m_axi_awid       (axi_awid         ), 
        .m_axi_awaddr     (axi_awaddr       ),
        .m_axi_awlen      (axi_awlen        ), //突发传输长度
        .m_axi_awsize     (axi_awsize       ), //突发传输大小(Byte)
        .m_axi_awburst    (axi_awburst      ), //突发类型
        .m_axi_awlock     (axi_awlock       ), 
        .m_axi_awcache    (axi_awcache      ), 
        .m_axi_awprot     (axi_awprot       ),
        .m_axi_awqos      (axi_awqos        ),
        .m_axi_awvalid    (axi_awvalid      ), //写地址valid
        .m_axi_awready    (axi_awready      ), //从机发出的写地址ready
        
        //写数据通道
        .m_axi_wdata      (axi_wdata        ), //写数据
        .m_axi_wstrb      (axi_wstrb        ), //写数据有效字节线
        .m_axi_wlast      (axi_wlast        ), //最后一个数据标志
        .m_axi_wvalid     (axi_wvalid       ), //写数据有效标志
        .m_axi_wready     (axi_wready       ), //从机发出的写数据ready
        
        //写响应通道
        .m_axi_bid        (axi_bid          ),
        .m_axi_bresp      (axi_bresp        ), //响应信号,表征写传输是否成功
        .m_axi_bvalid     (axi_bvalid       ), //响应信号valid标志
        .m_axi_bready     (axi_bready       )  //主机响应ready信号
    );
    
    //AXI写从机
    axi_slave_wr axi_slave_wr_inst(
        //用户接口
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .wr_addr         (s_wr_addr       ), 
        .wr_data         (s_wr_data       ),
        .wr_en           (s_wr_en         ), //写存储器使能
        .wr_done         (s_wr_done       ), //写完成
        .wr_len          (s_wr_len        ),

        //AXI4写地址通道
        .s_axi_awid      (axi_awid        ), 
        .s_axi_awaddr    (axi_awaddr      ),
        .s_axi_awlen     (axi_awlen       ), //突发传输长度
        .s_axi_awsize    (axi_awsize      ), //突发传输大小(Byte)
        .s_axi_awburst   (axi_awburst     ), //突发类型
        .s_axi_awlock    (axi_awlock      ), 
        .s_axi_awcache   (axi_awcache     ), 
        .s_axi_awprot    (axi_awprot      ),
        .s_axi_awqos     (axi_awqos       ),
        .s_axi_awvalid   (axi_awvalid     ), //写地址valid
        .s_axi_awready   (axi_awready     ), //从机发出的写地址ready
        
        //写数据通道
        .s_axi_wdata     (axi_wdata       ), //写数据
        .s_axi_wstrb     (axi_wstrb       ), //写数据有效字节线
        .s_axi_wlast     (axi_wlast       ), //最后一个数据标志
        .s_axi_wvalid    (axi_wvalid      ), //写数据有效标志
        .s_axi_wready    (axi_wready      ), //从机发出的写数据ready
        
        //写响应通道
        .s_axi_bid       (axi_bid         ),
        .s_axi_bresp     (axi_bresp       ), //响应信号,表征写传输是否成功
        .s_axi_bvalid    (axi_bvalid      ), //响应信号valid标志
        .s_axi_bready    (axi_bready      )  //主机响应ready信号        
    );
endmodule
