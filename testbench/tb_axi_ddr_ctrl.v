`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/18 22:10:04
// Module Name: tb_axi_ddr_ctrl
// Description: testbench for axi_ddr_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_axi_ddr_ctrl(

    );
    
    reg clk ,rst_n;
    
    //AXI连线
    //AXI4写地址通道
    wire [3:0]  axi_awid      ; 
    wire [29:0] axi_awaddr    ;
    wire [7:0]  axi_awlen     ; //突发传输长度
    wire [2:0]  axi_awsize    ; //突发传输大小(Byte)
    wire [1:0]  axi_awburst   ; //突发类型
    wire        axi_awlock    ; 
    wire [3:0]  axi_awcache   ; 
    wire [2:0]  axi_awprot    ;
    wire [3:0]  axi_awqos     ;
    wire        axi_awvalid   ; //写地址valid
    wire        axi_awready   ; //从机发出的写地址ready
                              
    //写数据通道              
    wire [63:0] axi_wdata     ; //写数据
    wire [7:0]  axi_wstrb     ; //写数据有效字节线
    wire        axi_wlast     ; //最后一个数据标志
    wire        axi_wvalid    ; //写数据有效标志
    wire        axi_wready    ; //从机发出的写数据ready
                              
    //写响应通道              
    wire [3:0]  axi_bid       ;
    wire [1:0]  axi_bresp     ; //响应信号,表征写传输是否成功
    wire        axi_bvalid    ; //响应信号valid标志
    wire        axi_bready    ; //主机响应ready信号

    //AXI4读地址通道          
    wire [3:0]  axi_arid      ; 
    wire [29:0] axi_araddr    ;
    wire [7:0]  axi_arlen     ; //突发传输长度
    wire [2:0]  axi_arsize    ; //突发传输大小(Byte)
    wire [1:0]  axi_arburst   ; //突发类型
    wire        axi_arlock    ; 
    wire [3:0]  axi_arcache   ; 
    wire [2:0]  axi_arprot    ;
    wire [3:0]  axi_arqos     ;
    wire        axi_arvalid   ; //读地址valid
    wire        axi_arready   ; //从机准备接收读地址

    //读数据通道              
    wire [63:0] axi_rdata     ; //读数据
    wire [1:0]  axi_rresp     ; //收到的读响应
    wire        axi_rlast     ; //最后一个数据标志
    wire        axi_rvalid    ; //读数据有效标志
    wire        axi_rready    ; //主机发出的读数据ready
    
    //写从机用户端接口(对接存储器)
    wire [29:0] s_wr_addr     ;
    wire [7:0]  s_wr_len      ;
    wire [63:0] s_wr_data     ;
    wire        s_wr_en       ; //写存储器使能
    wire        s_wr_done     ; //写完成
    
    
    //读从机用户端接口(对接存储器)
    wire [29:0] s_rd_addr      ; //读首地址
    wire [63:0] s_rd_data      ; //需要读的数据(存储器提供)
    wire        s_rd_en        ; //读存储器使能
    wire [7:0]  s_rd_len       ; //突发传输长度
    wire        s_rd_done      ; //从机读完成标志
    
    
    
    //AXI控制模块FIFO读写控制
    wire        fifo_rd_valid  ; //读FIFO可读标志,表示读FIFO中有数据可以对外输出
    reg         fifo_wr_en     ; //写FIFO写请求
    reg  [15:0] fifo_wr_data   ; //写FIFO写数据  
    reg         fifo_rd_en     ; //读FIFO读请求
    wire [15:0] fifo_rd_data   ; //读FIFO读数据
    
    //读存储器允许信号
    reg         rd_mem_enable  ; 
    
       
    //时钟生成模块连线
    wire        clk_ddr       ; //提供给AXI DDR控制器的时钟
    wire        clk_fifo      ; //读写FIFO读写时钟
    wire        locked        ; //时钟锁定标志
    //复位信号
    wire        locked_rst_n  ; //locked & rst_n
    
    //读写参数
    wire [29:0] wr_beg_addr   ; //写起始地址
    wire [29:0] wr_end_addr   ; //写终止地址
    wire [7:0]  wr_burst_len  ; //写突发长度
    wire [29:0] rd_beg_addr   ; //读起始地址
    wire [29:0] rd_end_addr   ; //读终止地址
    wire [7:0]  rd_burst_len  ; //读突发长度
    
    //读写参数定义
    assign wr_beg_addr   =  30'd0   ; //写起始地址
    assign wr_end_addr   =  30'd8191; //写终止地址
    assign wr_burst_len  =  8'd4    ; //写突发长度
    assign rd_beg_addr   =  30'd0   ; //读起始地址
    assign rd_end_addr   =  30'd8191; //读终止地址
    assign rd_burst_len  =  8'd4    ; //读突发长度
    
    //存储器数据接口
    wire [63:0] data    ;
    
    //写FIFO写数据,与写地址同步
    //fifo_wr_data
    always@(posedge clk_fifo or negedge locked_rst_n) begin
        if(~locked_rst_n) begin
            fifo_wr_data <= 16'd0;
        end else if(fifo_wr_en) begin
            fifo_wr_data <= fifo_wr_data + 16'd1;
        end else begin
            fifo_wr_data <= fifo_wr_data;
        end
    end
    
    //时钟、复位、读写控制
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        fifo_wr_en <= 1'b0;
        fifo_rd_en <= 1'b0;
        rd_mem_enable <= 1'b0;
    #20  
        rst_n <= 1'b1;
    #1810
        fifo_wr_en <= 1'b1;  //写FIFO
    #2590
        fifo_wr_en <= 1'b0;
    #600
        rd_mem_enable <= 1'b1; //已经向存储器中写了数据,可以开始读了
    #60
        fifo_rd_en <= 1'b1; //读FIFO
    #2600
        rd_mem_enable <= 1'b0;
        fifo_rd_en <= 1'b0;
    end
    
    
    
    //时钟生成模块,产生FIFO读写时钟及AXI读写主机工作时钟
      clk_gen clk_gen_inst(
        .clk_ddr    (clk_ddr    ),     
        .clk_fifo   (clk_fifo   ),   
        // Status and control signals
        .reset      (~rst_n     ), 
        .locked     (locked     ),     
        // Clock in ports
        .clk_in1    (clk        )      //50MHz时钟输入
    ); 
    
    always#10 clk = ~clk;  //50MHz时钟输入

    //锁定的复位信号, 作为真正有效的复位信号
    assign      locked_rst_n = locked & rst_n;
   
   
    //AXI控制模块
    axi_ddr_ctrl axi_ddr_ctrl_inst(
        .clk             (clk_ddr         ), //AXI读写主机时钟
        .rst_n           (locked_rst_n    ), 
                
        //用户端    
        .wr_clk          (clk_fifo        ), //写FIFO写时钟
        .wr_rst          (~locked_rst_n   ), //写复位
        .wr_beg_addr     (wr_beg_addr     ), //写起始地址
        .wr_end_addr     (wr_end_addr     ), //写终止地址
        .wr_burst_len    (wr_burst_len    ), //写突发长度
        .wr_en           (fifo_wr_en      ), //写FIFO写请求
        .wr_data         (fifo_wr_data    ), //写FIFO写数据 
        .rd_clk          (clk_fifo        ), //读FIFO读时钟
        .rd_rst          (~locked_rst_n   ), //读复位
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能,防止存储器未写先读
        .rd_beg_addr     (rd_beg_addr     ), //读起始地址
        .rd_end_addr     (rd_end_addr     ), //读终止地址
        .rd_burst_len    (rd_burst_len    ), //读突发长度
        .rd_en           (fifo_rd_en      ), //读FIFO读请求
        .rd_data         (fifo_rd_data    ), //读FIFO读数据
        .rd_valid        (fifo_rd_valid   ), //读FIFO可读标志,表示读FIFO中有数据可以对外输出
        
        //AXI总线
        //AXI4写地址通道
        .m_axi_awid      (axi_awid        ), 
        .m_axi_awaddr    (axi_awaddr      ),
        .m_axi_awlen     (axi_awlen       ), //突发传输长度
        .m_axi_awsize    (axi_awsize      ), //突发传输大小(Byte)
        .m_axi_awburst   (axi_awburst     ), //突发类型
        .m_axi_awlock    (axi_awlock      ), 
        .m_axi_awcache   (axi_awcache     ), 
        .m_axi_awprot    (axi_awprot      ),
        .m_axi_awqos     (axi_awqos       ),
        .m_axi_awvalid   (axi_awvalid     ), //写地址valid
        .m_axi_awready   (axi_awready     ), //从机发出的写地址ready
           
        //写数据通道
        .m_axi_wdata     (axi_wdata       ), //写数据
        .m_axi_wstrb     (axi_wstrb       ), //写数据有效字节线
        .m_axi_wlast     (axi_wlast       ), //最后一个数据标志
        .m_axi_wvalid    (axi_wvalid      ), //写数据有效标志
        .m_axi_wready    (axi_wready      ), //从机发出的写数据ready
           
        //写响应通道
        .m_axi_bid       (axi_bid         ),
        .m_axi_bresp     (axi_bresp       ), //响应信号,表征写传输是否成功
        .m_axi_bvalid    (axi_bvalid      ), //响应信号valid标志
        .m_axi_bready    (axi_bready      ), //主机响应ready信号
           
        //AXI4读地址通道
        .m_axi_arid      (axi_arid        ), 
        .m_axi_araddr    (axi_araddr      ),
        .m_axi_arlen     (axi_arlen       ), //突发传输长度
        .m_axi_arsize    (axi_arsize      ), //突发传输大小(Byte)
        .m_axi_arburst   (axi_arburst     ), //突发类型
        .m_axi_arlock    (axi_arlock      ), 
        .m_axi_arcache   (axi_arcache     ), 
        .m_axi_arprot    (axi_arprot      ),
        .m_axi_arqos     (axi_arqos       ),
        .m_axi_arvalid   (axi_arvalid     ), //读地址valid
        .m_axi_arready   (axi_arready     ), //从机准备接收读地址
           
        //读数据通道
        .m_axi_rdata     (axi_rdata       ), //读数据
        .m_axi_rresp     (axi_rresp       ), //收到的读响应
        .m_axi_rlast     (axi_rlast       ), //最后一个数据标志
        .m_axi_rvalid    (axi_rvalid      ), //读数据有效标志
        .m_axi_rready    (axi_rready      )  //主机发出的读数据ready
    );
    
    
    
    //AXI读从机
    axi_slave_rd axi_slave_rd_inst(
        //用户端
        .clk              (clk_ddr        ),
        .rst_n            (locked_rst_n   ),
        .rd_addr          (s_rd_addr      ), //读首地址
        .rd_data          (s_rd_data      ), //需要读的数据(存储器提供)
        .rd_en            (s_rd_en        ), //读存储器使能
        .rd_len           (s_rd_len       ), //突发传输长度
        .rd_done          (s_rd_done      ), //从机读完成标志
        
        //AXI4读地址通道
        .s_axi_arid       (axi_arid       ), 
        .s_axi_araddr     (axi_araddr     ),
        .s_axi_arlen      (axi_arlen      ), //突发传输长度
        .s_axi_arsize     (axi_arsize     ), //突发传输大小(Byte)
        .s_axi_arburst    (axi_arburst    ), //突发类型
        .s_axi_arlock     (axi_arlock     ), 
        .s_axi_arcache    (axi_arcache    ), 
        .s_axi_arprot     (axi_arprot     ),
        .s_axi_arqos      (axi_arqos      ),
        .s_axi_arvalid    (axi_arvalid    ), //读地址valid
        .s_axi_arready    (axi_arready    ), //从机准备接收读地址
                          
        //读数据通道      
        .s_axi_rdata      (axi_rdata      ), //读数据
        .s_axi_rresp      (axi_rresp      ), //发送的读响应
        .s_axi_rlast      (axi_rlast      ), //最后一个数据标志
        .s_axi_rvalid     (axi_rvalid     ), //读数据有效标志
        .s_axi_rready     (axi_rready     )  //主机发出的读数据ready
    );
    
    
    //AXI写从机
    axi_slave_wr axi_slave_wr_inst(
        //用户接口
        .clk             (clk_ddr         ),
        .rst_n           (locked_rst_n    ),
        .wr_addr         (s_wr_addr       ),
        .wr_len          (s_wr_len        ),
        .wr_data         (s_wr_data       ),
        .wr_en           (s_wr_en         ), //写存储器使能
        .wr_done         (s_wr_done       ), //写完成

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
    
    //存储器模块, 模拟内存映射数据传输
    ram64b ram64b_inst(
        .clk        (clk_ddr        ),
        .rst_n      (locked_rst_n   ),
        .wr_en      (s_wr_en        ),
        .wr_addr    (s_wr_addr      ),
        .rd_en      (s_rd_en        ),
        .rd_addr    (s_rd_addr      ),
    
        .data       (data           )
    );
    
    
    //在RAM读数据有效时, 将数据送到s_rd_data(AXI读从机)
    assign s_rd_data = data;
    
    //在ARM写入数据有效时, 将数据写入存储器模块
    assign data = (s_wr_en)?s_wr_data:{64{1'bz}};
    
endmodule
