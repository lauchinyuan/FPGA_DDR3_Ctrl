`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/11 10:47:19
// Module Name: tb_wr_multichan_interface 
// Description: testbench for wr_multichan_interface
//////////////////////////////////////////////////////////////////////////////////


module tb_wr_multichan_interface(

    );
    
    //参数定义
    parameter FIFO_WR_WIDTH           = 'd32           , //写FIFO在用户端操作的位宽
              AXI_WIDTH               = 'd64           , //AXI总线数据位宽
              //写FIFO相关参数
              WR_FIFO_RAM_DEPTH       = 'd2048         , //写FIFO内部RAM存储器深度
              WR_FIFO_RAM_ADDR_WIDTH  = 'd11           , //写FIFO内部RAM读写地址宽度, log2(WR_FIFO_RAM_DEPTH)
              WR_FIFO_WR_IND          = 'd1            , //写FIFO单次写操作访问的ram_mem单元个数 FIFO_WR_WIDTH/WR_FIFO_RAM_WIDTH
              WR_FIFO_RD_IND          = 'd2            , //写FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/WR_FIFO_RAM_ADDR_WIDTH        
              WR_FIFO_RAM_WIDTH       = FIFO_WR_WIDTH  , //写FIFO RAM存储器的位宽
              WR_FIFO_WR_L2           = 'd0            , //log2(WR_FIFO_WR_IND)
              WR_FIFO_RD_L2           = 'd1            , //log2(WR_FIFO_RD_IND)
              WR_FIFO_RAM_RD2WR       = 'd2            ,

              AXI_WSTRB_W             = AXI_WIDTH >> 3 ; 

    //时钟、复位
    reg                         clk                 ; //AXI主机读写时钟
    reg                         rst_n               ;   
        
    //写接口用户端   
    reg                         wr_clk              ; //写FIFO写时钟
    reg                         wr_rst              ; //写复位, 高电平有效
    
    //各个读通道特殊的控制信号
    wire [29:0]                 wr_beg_addr [3:0]   ; //写起始地址
    wire [29:0]                 wr_end_addr [3:0]   ; //写终止地址
    wire [7:0]                  wr_burst_len[3:0]   ; //写突发长度
    reg  [3:0]                  fifo_wr_en          ; //写FIFO写请求
    reg  [AXI_WIDTH-1:0]        fifo_wr_data[3:0]   ; //写FIFO数据
    

    //多通道接口 <--> AXI写从机
    //AXI4写地址通道
    wire [3:0]                  w_axi_awid      ; 
    wire [29:0]                 w_axi_awaddr    ;
    wire [7:0]                  w_axi_awlen     ; //突发传输长度
    wire [2:0]                  w_axi_awsize    ; //突发传输大小(Byte)
    wire [1:0]                  w_axi_awburst   ; //突发类型
    wire                        w_axi_awlock    ; 
    wire [3:0]                  w_axi_awcache   ; 
    wire [2:0]                  w_axi_awprot    ;
    wire [3:0]                  w_axi_awqos     ;
    wire                        w_axi_awvalid   ; //写地址valid
    wire                        w_axi_awready   ; //从机发出的写地址ready
    //写数据通道             
    wire [AXI_WIDTH-1:0]        w_axi_wdata     ; //写数据
    wire [AXI_WSTRB_W-1:0]      w_axi_wstrb     ; //写数据有效字节线
    wire                        w_axi_wlast     ; //最后一个数据标志
    wire                        w_axi_wvalid    ; //写数据有效标志
    wire                        w_axi_wready    ; //从机发出的写数据ready
    //写响应通道             
    wire [3:0]                  w_axi_bid       ;
    wire [1:0]                  w_axi_bresp     ; //响应信号,表征写传输是否成功
    wire                        w_axi_bvalid    ; //响应信号valid标志
    wire                        w_axi_bready    ; //主机响应ready信号

    //AXI从机输出
    wire [7:0]                  s_wr_len        ; //突发传输长度
    wire                        s_wr_done       ; //从机写完成标志
        
    //AXI从机 <--> 存储器    
    wire [29:0]                 s_wr_addr       ; //写首地址
    wire [63:0]                 s_wr_data       ; //需要写的数据
    wire                        s_wr_en         ; //写存储器使能               
    //辅助变量
    //计数器, 每32个时钟周期切换写通道(fifo_wr_en)
    reg [4:0]                   cnt             ;
    
    
    //时钟、复位
    initial begin
        clk = 1'b1;
        wr_clk = 1'b1;
        rst_n <= 1'b0;
        wr_rst <= 1'b1;
    #20
        rst_n <= 1'b1;
        wr_rst <= 1'b0;
    end
    
    always#40 wr_clk = ~wr_clk;
    always#10 clk = ~clk; 
    
    //cnt
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 'd0;
        end else if(cnt == 'd31) begin
            cnt <= 'd0;
        end else begin
            cnt <= cnt + 'd1;
        end
    end
    
    
    //各个写通道特殊的控制信号赋值
    //起始地址
    assign wr_beg_addr[0]   =   30'd0       ;
    assign wr_beg_addr[1]   =   30'd1024    ;
    assign wr_beg_addr[2]   =   30'd2048    ;
    assign wr_beg_addr[3]   =   30'd3072    ;
    
    //终止地址
    assign wr_end_addr[0]   =   30'd1023    ;
    assign wr_end_addr[1]   =   30'd2047    ;
    assign wr_end_addr[2]   =   30'd3071    ;
    assign wr_end_addr[3]   =   30'd4095    ;    
    
    //burst_len
    assign wr_burst_len[0]  =   8'd7        ;
    assign wr_burst_len[1]  =   8'd3        ;
    assign wr_burst_len[2]  =   8'd1        ;
    assign wr_burst_len[3]  =   8'd0        ;
    
    //fifo写使能
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_wr_en <= 'd0;
        end else if(cnt == 'd31) begin
            fifo_wr_en <= $random(); //随机写入不同的通道
        end else begin
            fifo_wr_en <= fifo_wr_en;
        end
    end
    
    //写数据通道0起始数据为0, 随后连续自增
    //fifo_wr_data[0]
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_wr_data[0] <= 'd0;
        end else if(fifo_wr_en[0]) begin
            fifo_wr_data[0] <= fifo_wr_data[0] + 'd1;
        end else begin
            fifo_wr_data[0] <= fifo_wr_data[0];
        end
    end

    //写数据通道1起始数据为1, 随后连续自增
    //fifo_wr_data[1]
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_wr_data[1] <= 'd1;
        end else if(fifo_wr_en[1]) begin
            fifo_wr_data[1] <= fifo_wr_data[1] + 'd1;
        end else begin
            fifo_wr_data[1] <= fifo_wr_data[1];
        end
    end
    
    //写数据通道2起始数据为2, 随后连续自增
    //fifo_wr_data[2]
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_wr_data[2] <= 'd2;
        end else if(fifo_wr_en[2]) begin
            fifo_wr_data[2] <= fifo_wr_data[2] + 'd1;
        end else begin
            fifo_wr_data[2] <= fifo_wr_data[2];
        end
    end

    //写数据通道3起始数据为3, 随后连续自增
    //fifo_wr_data[3]
    always@(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_wr_data[3] <= 'd3;
        end else if(fifo_wr_en[3]) begin
            fifo_wr_data[3] <= fifo_wr_data[3] + 'd1;
        end else begin
            fifo_wr_data[3] <= fifo_wr_data[3];
        end
    end    
    
    
    //多通道写接口例化
    wr_multichan_interface
    #(.FIFO_WR_WIDTH           (FIFO_WR_WIDTH           ), //写FIFO在用户端操作的位宽
      .AXI_WIDTH               (AXI_WIDTH               ), //AXI总线数据位宽
      //写FIFO相关参数         
      .WR_FIFO_RAM_DEPTH       (WR_FIFO_RAM_DEPTH       ), //写FIFO内部RAM存储器深度
      .WR_FIFO_RAM_ADDR_WIDTH  (WR_FIFO_RAM_ADDR_WIDTH  ), //写FIFO内部RAM读写地址宽度, log2(WR_FIFO_RAM_DEPTH)
      .WR_FIFO_WR_IND          (WR_FIFO_WR_IND          ), //写FIFO单次写操作访问的ram_mem单元个数 FIFO_WR_WIDTH/WR_FIFO_RAM_WIDTH
      .WR_FIFO_RD_IND          (WR_FIFO_RD_IND          ), //写FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/WR_FIFO_RAM_ADDR_WIDTH        
      .WR_FIFO_RAM_WIDTH       (WR_FIFO_RAM_WIDTH       ), //写FIFO RAM存储器的位宽
      .WR_FIFO_WR_L2           (WR_FIFO_WR_L2           ), //log2(WR_FIFO_WR_IND)
      .WR_FIFO_RD_L2           (WR_FIFO_RD_L2           ), //log2(WR_FIFO_RD_IND)
      .WR_FIFO_RAM_RD2WR       (WR_FIFO_RAM_RD2WR       )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1   
    )
    wr_multichan_interface_inst
    (
    
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),  
        //用户端               
        .wr_clk          (wr_clk          ), //写FIFO写时钟
        .wr_rst          (wr_rst          ), //写复位, 高电平有效
        .wr_beg_addr0    (wr_beg_addr[0]  ), //写通道0写起始地址
        .wr_beg_addr1    (wr_beg_addr[1]  ), //写通道1写起始地址
        .wr_beg_addr2    (wr_beg_addr[2]  ), //写通道2写起始地址
        .wr_beg_addr3    (wr_beg_addr[3]  ), //写通道3写起始地址
        .wr_end_addr0    (wr_end_addr[0]  ), //写通道0写终止地址
        .wr_end_addr1    (wr_end_addr[1]  ), //写通道1写终止地址
        .wr_end_addr2    (wr_end_addr[2]  ), //写通道2写终止地址
        .wr_end_addr3    (wr_end_addr[3]  ), //写通道3写终止地址
        .wr_burst_len0   (wr_burst_len[0] ), //写通道0写突发长度
        .wr_burst_len1   (wr_burst_len[1] ), //写通道1写突发长度
        .wr_burst_len2   (wr_burst_len[2] ), //写通道2写突发长度
        .wr_burst_len3   (wr_burst_len[3] ), //写通道3写突发长度
        .wr_en0          (fifo_wr_en[0]   ), //写通道0写请求
        .wr_en1          (fifo_wr_en[1]   ), //写通道1写请求
        .wr_en2          (fifo_wr_en[2]   ), //写通道2写请求
        .wr_en3          (fifo_wr_en[3]   ), //写通道3写请求
        .wr_data0        (fifo_wr_data[0] ), //写通道0写入数据
        .wr_data1        (fifo_wr_data[1] ), //写通道1写入数据
        .wr_data2        (fifo_wr_data[2] ), //写通道2写入数据
        .wr_data3        (fifo_wr_data[3] ), //写通道3写入数据
        
        //AXI写相关通道线
        //AXI4写地址通道
        .m_axi_awid      (w_axi_awid      ), 
        .m_axi_awaddr    (w_axi_awaddr    ),
        .m_axi_awlen     (w_axi_awlen     ), //突发传输长度
        .m_axi_awsize    (w_axi_awsize    ), //突发传输大小(Byte)
        .m_axi_awburst   (w_axi_awburst   ), //突发类型
        .m_axi_awlock    (w_axi_awlock    ), 
        .m_axi_awcache   (w_axi_awcache   ), 
        .m_axi_awprot    (w_axi_awprot    ),
        .m_axi_awqos     (w_axi_awqos     ),
        .m_axi_awvalid   (w_axi_awvalid   ), //写地址valid
        .m_axi_awready   (w_axi_awready   ), //从机发出的写地址ready
            
        //写数据通道 
        .m_axi_wdata     (w_axi_wdata     ), //写数据
        .m_axi_wstrb     (w_axi_wstrb     ), //写数据有效字节线
        .m_axi_wlast     (w_axi_wlast     ), //最后一个数据标志
        .m_axi_wvalid    (w_axi_wvalid    ), //写数据有效标志
        .m_axi_wready    (w_axi_wready    ), //从机发出的写数据ready
            
        //写响应通道 
        .m_axi_bid       (w_axi_bid       ),
        .m_axi_bresp     (w_axi_bresp     ), //响应信号,表征写传输是否成功
        .m_axi_bvalid    (w_axi_bvalid    ), //响应信号valid标志
        .m_axi_bready    (w_axi_bready    )  //主机响应ready信号        
    );
    
    //AXI从机
    axi_slave_wr axi_slave_wr_inst(
        //用户接口
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .wr_addr         (s_wr_addr       ),
        .wr_len          (s_wr_len        ),
        .wr_data         (s_wr_data       ),
        .wr_en           (s_wr_en         ), //写存储器使能
        .wr_done         (s_wr_done       ), //写完成

        //AXI4写地址通道
        .s_axi_awid      (w_axi_awid      ), 
        .s_axi_awaddr    (w_axi_awaddr    ),
        .s_axi_awlen     (w_axi_awlen     ), //突发传输长度
        .s_axi_awsize    (w_axi_awsize    ), //突发传输大小(Byte)
        .s_axi_awburst   (w_axi_awburst   ), //突发类型
        .s_axi_awlock    (w_axi_awlock    ), 
        .s_axi_awcache   (w_axi_awcache   ), 
        .s_axi_awprot    (w_axi_awprot    ),
        .s_axi_awqos     (w_axi_awqos     ),
        .s_axi_awvalid   (w_axi_awvalid   ), //写地址valid
        .s_axi_awready   (w_axi_awready   ), //从机发出的写地址ready
        
        //写数据通道
        .s_axi_wdata     (w_axi_wdata     ), //写数据
        .s_axi_wstrb     (w_axi_wstrb     ), //写数据有效字节线
        .s_axi_wlast     (w_axi_wlast     ), //最后一个数据标志
        .s_axi_wvalid    (w_axi_wvalid    ), //写数据有效标志
        .s_axi_wready    (w_axi_wready    ), //从机发出的写数据ready
        
        //写响应通道
        .s_axi_bid       (w_axi_bid       ),
        .s_axi_bresp     (w_axi_bresp     ), //响应信号,表征写传输是否成功
        .s_axi_bvalid    (w_axi_bvalid    ), //响应信号valid标志
        .s_axi_bready    (w_axi_bready    )  //主机响应ready信号        
    );    
    
    //模拟的RAM(模拟DDR存储空间)
    ram64b ram64_inst(
        .clk             (clk            ),
        .rst_n           (rst_n          ),
                
        //写, 本案例中未使用     
        .wr_en           (s_wr_en        ),
        .wr_addr         (s_wr_addr      ),
        
        //读
        .rd_en           (1'b0           ),
        .rd_addr         ('d0            ),
        
        //数据线
        .data            (s_wr_data      )    
    );        
    
endmodule
