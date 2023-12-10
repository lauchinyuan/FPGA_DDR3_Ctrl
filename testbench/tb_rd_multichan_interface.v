`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/12/09 19:30:15
// Module Name: tb_rd_multichan_interface
// Description: testbench for rd_multichan_interface module
//////////////////////////////////////////////////////////////////////////////////


module tb_rd_multichan_interface(

    );
    
    
    //参数定义
    parameter FIFO_RD_WIDTH           = 'd32              , //读FIFO在用户端操作的位宽
              AXI_WIDTH               = 'd64              , //AXI总线数据位宽
                                                          
              //读FIFO相关参数                            
              RD_FIFO_RAM_DEPTH       = 'd2048            , //读FIFO内部RAM存储器深度
              RD_FIFO_RAM_ADDR_WIDTH  = 'd11              , //读FIFO内部RAM读写地址宽度, log2(RD_FIFO_RAM_DEPTH)
              RD_FIFO_WR_IND          = 'd2               , //读FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/RD_FIFO_RAM_WIDTH
              RD_FIFO_RD_IND          = 'd1               , //读FIFO单次读操作访问的ram_mem单元个数 FIFO_RD_WIDTH/RD_FIFO_RAM_ADDR_WIDTH        
              RD_FIFO_RAM_WIDTH       = FIFO_RD_WIDTH     , //读FIFO RAM存储器的位宽
              RD_FIFO_WR_L2           = 'd1               , //log2(RD_FIFO_WR_IND)
              RD_FIFO_RD_L2           = 'd0               , //log2(RD_FIFO_RD_IND)
              RD_FIFO_RAM_RD2WR       = 'd1               ; //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1 
    
    
    //时钟、复位
    reg                         clk                 ; //AXI主机读写时钟
    reg                         rst_n               ;   
        
    //读控制器用户端   
    reg                         rd_clk              ; //读FIFO读时钟
    reg                         rd_rst              ; //读复位, 高电平有效
    reg                         rd_mem_enable       ; //读存储器使能, 防止存储器未写先读
    
    //各个读通道特殊的控制信号
    wire [29:0]                 rd_beg_addr [3:0]   ; //读起始地址
    wire [29:0]                 rd_end_addr [3:0]   ; //读终止地址
    wire [7:0]                  rd_burst_len[3:0]   ; //读突发长度
    reg  [3:0]                  fifo_rd_en          ; //读FIFO读请求
    wire [FIFO_RD_WIDTH-1:0]    rd_data     [3:0]   ; //读FIFO读数据
    wire                        rd_valid    [3:0]   ; //读FIFO可读标志,表示读FIFO中有数据可以对外输出 
    
    //AXI主机 <---> AXI从机
    //AXI4读地址通道
    wire [3:0]                  w_axi_arid          ; 
    wire [29:0]                 w_axi_araddr        ;
    wire [7:0]                  w_axi_arlen         ; //突发传输长度
    wire [2:0]                  w_axi_arsize        ; //突发传输大小(Byte)
    wire [1:0]                  w_axi_arburst       ; //突发类型
    wire                        w_axi_arlock        ; 
    wire [3:0]                  w_axi_arcache       ; 
    wire [2:0]                  w_axi_arprot        ;
    wire [3:0]                  w_axi_arqos         ;
    wire                        w_axi_arvalid       ; //读地址valid
    wire                        w_axi_arready       ; //从机准备接收读地址
    //读数据通道
    wire [AXI_WIDTH-1:0]        w_axi_rdata         ; //读数据
    wire [1:0]                  w_axi_rresp         ; //收到的读响应
    wire                        w_axi_rlast         ; //最后一个数据标志
    wire                        w_axi_rvalid        ; //读数据有效标志
    wire                        w_axi_rready        ; //主机发出的读数据ready

    //AXI从机输出
    wire [7:0]              s_rd_len        ; //突发传输长度
    wire                    s_rd_done       ; //从机读完成标志
    
    //AXI从机 <--> 存储器
    wire [29:0]             s_rd_addr       ; //读首地址
    wire [63:0]             s_rd_data       ; //需要读的数据
    wire                    s_rd_en         ; //读存储器使能

    
    //辅助变量
    //计数器, 每32个时钟周期切换读通道(fifo_rd_en)
    reg [4:0]                   cnt                 ;
    
    //时钟、复位
    initial begin
        clk = 1'b1;
        rd_clk = 1'b1;
        rst_n <= 1'b0;
        rd_rst <= 1'b1;
        rd_mem_enable <= 1'b0;
    #20
        rst_n <= 1'b1;
        rd_rst <= 1'b0;
        rd_mem_enable <= 1'b1;
    end
    
    always#40 rd_clk = ~rd_clk;
    always#5  clk = ~clk; 
    
    
    //cnt
    always@(posedge rd_clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 'd0;
        end else if(cnt == 'd31) begin
            cnt <= 'd0;
        end else begin
            cnt <= cnt + 'd1;
        end
    end
    
    
    //各个读通道特殊的控制信号赋值
    //起始地址
    assign rd_beg_addr[0]   =   30'd0       ;
    assign rd_beg_addr[1]   =   30'd1024    ;
    assign rd_beg_addr[2]   =   30'd2048    ;
    assign rd_beg_addr[3]   =   30'd3072    ;
    
    //终止地址
    assign rd_end_addr[0]   =   30'd1023    ;
    assign rd_end_addr[1]   =   30'd2047    ;
    assign rd_end_addr[2]   =   30'd3071    ;
    assign rd_end_addr[3]   =   30'd4095    ;    
    
    //burst_len
    assign rd_burst_len[0]  =   8'd15       ;
    assign rd_burst_len[1]  =   8'd15       ;
    assign rd_burst_len[2]  =   8'd15       ;
    assign rd_burst_len[3]  =   8'd15       ;    

    //fifo读使能
    always@(posedge rd_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_rd_en <= 'd0;
        end else if(cnt == 'd31) begin
            fifo_rd_en <= $random(); //随机读取不同的通道
        end else begin
            fifo_rd_en <= fifo_rd_en;
        end
    end    
    
    //DUT例化
    rd_multichan_interface
    #(.FIFO_RD_WIDTH           (FIFO_RD_WIDTH           ), //读FIFO在用户端操作的位宽
      .AXI_WIDTH               (AXI_WIDTH               ), //AXI总线数据位宽
                              
       //读FIFO相关参数
      .RD_FIFO_RAM_DEPTH       (RD_FIFO_RAM_DEPTH       ), //读FIFO内部RAM存储器深度
      .RD_FIFO_RAM_ADDR_WIDTH  (RD_FIFO_RAM_ADDR_WIDTH  ), //读FIFO内部RAM读写地址宽度, log2(RD_FIFO_RAM_DEPTH)
      .RD_FIFO_WR_IND          (RD_FIFO_WR_IND          ), //读FIFO单次写操作访问的ram_mem单元个数 AXI_WIDTH/RD_FIFO_RAM_WIDTH
      .RD_FIFO_RD_IND          (RD_FIFO_RD_IND          ), //读FIFO单次读操作访问的ram_mem单元个数 FIFO_RD_WIDTH/RD_FIFO_RAM_ADDR_WIDTH        
      .RD_FIFO_RAM_WIDTH       (RD_FIFO_RAM_WIDTH       ), //读FIFO RAM存储器的位宽
      .RD_FIFO_WR_L2           (RD_FIFO_WR_L2           ), //log2(RD_FIFO_WR_IND)
      .RD_FIFO_RD_L2           (RD_FIFO_RD_L2           ), //log2(RD_FIFO_RD_IND)
      .RD_FIFO_RAM_RD2WR       (RD_FIFO_RAM_RD2WR       )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1  
    )
    rd_multichan_interface_inst           
    (
        .clk             (clk             ), //AXI主机读写时钟
        .rst_n           (rst_n           ),   
                        
        //用户端               
        .rd_clk          (rd_clk          ), //读FIFO读时钟
        .rd_rst          (rd_rst          ), //读复位, 高电平有效
        .rd_mem_enable   (rd_mem_enable   ), //读存储器使能, 防止存储器未写先读
        .rd_beg_addr0    (rd_beg_addr[0]  ), //读通道0读起始地址
        .rd_beg_addr1    (rd_beg_addr[1]  ), //读通道1读起始地址
        .rd_beg_addr2    (rd_beg_addr[2]  ), //读通道2读起始地址
        .rd_beg_addr3    (rd_beg_addr[3]  ), //读通道3读起始地址
        .rd_end_addr0    (rd_end_addr[0]  ), //读通道0读终止地址
        .rd_end_addr1    (rd_end_addr[1]  ), //读通道1读终止地址
        .rd_end_addr2    (rd_end_addr[2]  ), //读通道2读终止地址
        .rd_end_addr3    (rd_end_addr[3]  ), //读通道3读终止地址
        .rd_burst_len0   (rd_burst_len[0] ), //读通道0读突发长度
        .rd_burst_len1   (rd_burst_len[1] ), //读通道1读突发长度
        .rd_burst_len2   (rd_burst_len[2] ), //读通道2读突发长度
        .rd_burst_len3   (rd_burst_len[3] ), //读通道3读突发长度
        .rd_en0          (fifo_rd_en[0]   ), //读通道0读请求
        .rd_en1          (fifo_rd_en[1]   ), //读通道1读请求
        .rd_en2          (fifo_rd_en[2]   ), //读通道2读请求
        .rd_en3          (fifo_rd_en[3]   ), //读通道3读请求
        
        .rd_data0        (rd_data[0]      ), //读通道0读出数据
        .rd_data1        (rd_data[1]      ), //读通道1读出数据
        .rd_data2        (rd_data[2]      ), //读通道2读出数据
        .rd_data3        (rd_data[3]      ), //读通道3读出数据
        .rd_valid0       (rd_valid[0]     ), //读通道0FIFO可读标志          
        .rd_valid1       (rd_valid[1]     ), //读通道1FIFO可读标志          
        .rd_valid2       (rd_valid[2]     ), //读通道2FIFO可读标志          
        .rd_valid3       (rd_valid[3]     ), //读通道3FIFO可读标志      

        //MIG IP核 AXI接口(连接至AXI从机)
        //AXI4读地址通道
        .m_axi_arid      (w_axi_arid      ), 
        .m_axi_araddr    (w_axi_araddr    ),
        .m_axi_arlen     (w_axi_arlen     ), //突发传输长度
        .m_axi_arsize    (w_axi_arsize    ), //突发传输大小(Byte)
        .m_axi_arburst   (w_axi_arburst   ), //突发类型
        .m_axi_arlock    (w_axi_arlock    ), 
        .m_axi_arcache   (w_axi_arcache   ), 
        .m_axi_arprot    (w_axi_arprot    ),
        .m_axi_arqos     (w_axi_arqos     ),
        .m_axi_arvalid   (w_axi_arvalid   ), //读地址valid
        .m_axi_arready   (w_axi_arready   ), //从机准备接收读地址
            
        //读数据通道 
        .m_axi_rdata     (w_axi_rdata     ), //读数据
        .m_axi_rresp     (w_axi_rresp     ), //收到的读响应
        .m_axi_rlast     (w_axi_rlast     ), //最后一个数据标志
        .m_axi_rvalid    (w_axi_rvalid    ), //读数据有效标志
        .m_axi_rready    (w_axi_rready    )  //主机发出的读数据ready
    );
    
    //AXI读从机
    axi_slave_rd axi_slave_rd_inst(
        //用户端
        .clk             (clk              ),
        .rst_n           (rst_n            ),
        .rd_addr         (s_rd_addr        ), //读首地址
        .rd_data         (s_rd_data        ), //需要读的数据
        .rd_en           (s_rd_en          ), //读存储器使能
        .rd_len          (s_rd_len         ), //突发传输长度
        .rd_done         (s_rd_done        ), //从机读完成标志
        
        //AXI4读地址通道
        .s_axi_arid      (w_axi_arid      ), 
        .s_axi_araddr    (w_axi_araddr    ),
        .s_axi_arlen     (w_axi_arlen     ), //突发传输长度
        .s_axi_arsize    (w_axi_arsize    ), //突发传输大小(Byte)
        .s_axi_arburst   (w_axi_arburst   ), //突发类型
        .s_axi_arlock    (w_axi_arlock    ), 
        .s_axi_arcache   (w_axi_arcache   ), 
        .s_axi_arprot    (w_axi_arprot    ),
        .s_axi_arqos     (w_axi_arqos     ),
        .s_axi_arvalid   (w_axi_arvalid   ), //读地址valid
        .s_axi_arready   (w_axi_arready   ), //从机准备接收读地址
        
        //读数据通道
        .s_axi_rdata     (w_axi_rdata     ), //读数据
        .s_axi_rresp     (w_axi_rresp     ), //发送的读响应
        .s_axi_rlast     (w_axi_rlast     ), //最后一个数据标志
        .s_axi_rvalid    (w_axi_rvalid    ), //读数据有效标志
        .s_axi_rready    (w_axi_rready    )  //主机发出的读数据ready
    );    
    
    //模拟的RAM(模拟DDR存储空间)
    ram64b ram64_inst(
        .clk             (clk            ),
        .rst_n           (rst_n          ),
                
        //写, 本案例中未使用     
        .wr_en           (1'b0           ),
        .wr_addr         ('d0            ),
        
        //读
        .rd_en           (s_rd_en        ),
        .rd_addr         (s_rd_addr      ),
        
        //数据线
        .data            (s_rd_data      )    
    );

    //为存储器写入初始化的数据
    initial begin
        $readmemh("C:/Users/123/Desktop/test/ram_mem.txt", ram64_inst.mem);
    end    
    
    
    
    
endmodule
