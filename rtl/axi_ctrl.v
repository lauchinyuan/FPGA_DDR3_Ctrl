`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/18 13:09:46
// Module Name: axi_ctrl
// Description: AXI控制器, 依据AXI读写主机发来的读写信号, 自动产生AXI读写请求、读写地址以及读写突发长度
//////////////////////////////////////////////////////////////////////////////////

module axi_ctrl
    #(parameter FIFO_WR_WIDTH = 'd32,   //用户端FIFO读写位宽
                FIFO_RD_WIDTH = 'd32,
                AXI_WIDTH     = 'd64
    )
    (
        input   wire                        clk             , //AXI读写主机时钟
        input   wire                        rst_n           , 
                                
        //用户端                   
        input   wire                        wr_clk          , //写FIFO写时钟
        input   wire                        wr_rst          , //写复位,模块中是同步复位
        input   wire [29:0]                 wr_beg_addr     , //写起始地址
        input   wire [29:0]                 wr_end_addr     , //写终止地址
        input   wire [7:0]                  wr_burst_len    , //写突发长度
        input   wire                        wr_en           , //写FIFO写请求
        input   wire [FIFO_WR_WIDTH-1:0]    wr_data         , //写FIFO写数据 
        input   wire                        rd_clk          , //读FIFO读时钟
        input   wire                        rd_rst          , //读复位,模块中是同步复位
        input   wire                        rd_mem_enable   , //读存储器使能,防止存储器未写先读
        input   wire [29:0]                 rd_beg_addr     , //读起始地址
        input   wire [29:0]                 rd_end_addr     , //读终止地址
        input   wire [7:0]                  rd_burst_len    , //读突发长度
        input   wire                        rd_en           , //读FIFO读请求
        output  wire [FIFO_RD_WIDTH-1:0]    rd_data         , //读FIFO读数据
        output  wire                        rd_valid        , //读FIFO可读标志,表示读FIFO中有数据可以对外输出
        
        //写AXI主机
        input   wire                        axi_writing     , //AXI主机写正在进行
        input   wire                        axi_wr_ready    , //AXI主机写准备好
        output  reg                         axi_wr_start    , //AXI主机写请求
        output  wire [AXI_WIDTH-1:0]        axi_wr_data     , //从写FIFO中读取的数据,写入AXI写主机
        output  reg  [29:0]                 axi_wr_addr     , //AXI主机写地址
        output  wire [7:0]                  axi_wr_len      , //AXI主机写突发长度
        input   wire                        axi_wr_done     , //AXI主机完成一次写操作
                        
        //读AXI主机                
        input   wire                        axi_reading     , //AXI主机读正在进行
        input   wire                        axi_rd_ready    , //AXI主机读准备好
        output  reg                         axi_rd_start    , //AXI主机读请求
        input   wire [AXI_WIDTH-1:0]        axi_rd_data     , //从AXI读主机读到的数据,写入读FIFO
        output  reg  [29:0]                 axi_rd_addr     , //AXI主机读地址
        output  wire [7:0]                  axi_rd_len      , //AXI主机读突发长度 
        input   wire                        axi_rd_done       //AXI主机完成一次写操作
        
    );
    
        
    //FIFO数据数量计数器   
    wire [10:0]  cnt_rd_fifo_wrport      ;  //读FIFO写端口(对接AXI读主机)数据数量
    wire [10:0]  cnt_wr_fifo_rdport      ;  //写FIFO读端口(对接AXI写主机)数据数量    
    
    wire        rd_fifo_empty           ;  //读FIFO空标志
    wire        rd_fifo_wr_rst_busy     ;  //读FIFO正在初始化,此时先不向SDRAM发出读取请求, 否则将有数据丢失
        
/*  reg         axi_wr_start_d          ;  //axi_wr_start打一拍,用于上升沿提取
    reg         axi_rd_start_d          ;  //axi_rd_start打一拍,用于上升沿提取
    wire        axi_wr_start_raise      ;  //axi_wr_start上升沿
    wire        axi_rd_start_raise      ;  //axi_rd_start上升沿 */
    
    //真实的读写突发长度
    wire  [7:0] real_wr_len             ;  //真实的写突发长度,是wr_burst_len+1
    wire  [7:0] real_rd_len             ;  //真实的读突发长度,是rd_burst_len+1
    
    //突发地址增量, 每次进行一次连续突发传输地址的增量, 在外边计算, 方便后续复用
    wire  [29:0]burst_wr_addr_inc       ;
    wire  [29:0]burst_rd_addr_inc       ;
    
    //复位信号处理(异步复位同步释放)
    reg     rst_n_sync  ;  //同步释放处理后的rst_n
    reg     rst_n_d1    ;  //同步释放处理rst_n, 同步器第一级输出 

    //读复位同步到clk
    reg     rd_rst_sync ;  //读复位打两拍
    reg     rd_rst_d1   ;  //读复位打一拍
    

    //rst_n相对clk同步释放
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin  //异步复位
            rst_n_d1    <= 1'b0;
            rst_n_sync  <= 1'b0;
        end else begin
            rst_n_d1    <= 1'b1;
            rst_n_sync  <= rst_n_d1;
        end
    end
    
    //读复位同步释放到clk, 作为读fifo的复位输入
    always@(posedge clk or posedge rd_rst) begin
        if(rd_rst) begin
            rd_rst_d1   <= 1'b1;
            rd_rst_sync <= 1'b1;
        end else begin
            rd_rst_d1   <= 1'b0;
            rd_rst_sync <= rd_rst_d1;
        end
    end
    
       
    //真实的读写突发长度
    assign real_wr_len = wr_burst_len + 8'd1;
    assign real_rd_len = rd_burst_len + 8'd1;
    
    //突发地址增量, 右移3的
    assign burst_wr_addr_inc = real_wr_len * AXI_WIDTH >> 3;
    assign burst_rd_addr_inc = real_rd_len * AXI_WIDTH >> 3;
    
    
    //向AXI主机发出的读写突发长度
    assign axi_wr_len = wr_burst_len;
    assign axi_rd_len = rd_burst_len;
    
    
    //AXI读主机开始读标志
    //axi_rd_start
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            axi_rd_start <= 1'b0;
        end else if(~axi_rd_ready) begin  //axi_rd_ready低,代表AXI读主机正在进行数据读取, start信号已经被响应
            axi_rd_start <= 1'b0;
/*         end else if(rd_mem_enable && cnt_rd_fifo_wrport < real_rd_len && axi_rd_ready) begin  */
        end else if(rd_mem_enable && cnt_rd_fifo_wrport < 512 && axi_rd_ready && ~rd_fifo_wr_rst_busy) begin 
            //读FIFO中的数据存量不足, AXI读主机已经准备好, 且允许读存储器, 读FIFO可以接收数据
            axi_rd_start <= 1'b1;
        end else begin
            axi_rd_start <= axi_rd_start;
        end
    end
    
    //AXI写主机开始写标志
    //axi_wr_start
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            axi_wr_start <= 1'b0;
        end else if(~axi_wr_ready) begin  //axi_wr_ready低,代表AXI写主机正在进行数据发送, start信号已经被响应
            axi_wr_start <= 1'b0;
        end else if(cnt_wr_fifo_rdport > real_wr_len && axi_wr_ready) begin 
            //写FIFO中的数据存量足够, AXI写主机已经准备好, 数据不在写FIFO中久留
            axi_wr_start <= 1'b1;
        end else begin
            axi_wr_start <= axi_wr_start;
        end
    end
    
/*     //axi_wr_start打拍
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_wr_start_d <= 1'b0;
        end else begin
            axi_wr_start_d <= axi_wr_start;
        end
    end */
    
/*     //axi_rd_start打拍
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_rd_start_d <= 1'b0;
        end else begin
            axi_rd_start_d <= axi_rd_start;
        end
    end */
   
    
/*     //axi_wr_start上升沿提取
    assign axi_wr_start_raise = (~axi_wr_start_d) & axi_wr_start;
    
    //axi_rd_start上升沿提取
    assign axi_rd_start_raise = (~axi_rd_start_d) & axi_rd_start; */
    
/*     //rd_fifo_wr_en
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_fifo_wr_en <= 1'b0;
        end else begin
            rd_fifo_wr_en <= axi_reading;
        end
    end */
    
    //AXI写地址,更新地址并判断是否可能超限
    //axi_wr_addr
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            axi_wr_addr <= wr_beg_addr;  //初始化为起始地址
        end else if(wr_rst) begin
            axi_wr_addr <= wr_beg_addr;
        end else if(axi_wr_done && axi_wr_addr > (wr_end_addr - {burst_wr_addr_inc[28:0], 1'b0} + 30'd1)) begin 
        //每次写完成后判断是否超限, 下一个写首地址后续的空间已经不够再进行一次突发写操作, 位拼接的作用是×2
            axi_wr_addr <= wr_beg_addr;
        end else if(axi_wr_done) begin
            axi_wr_addr <= axi_wr_addr + burst_wr_addr_inc;  //增加一个burst_len的地址
        end else begin
            axi_wr_addr <= axi_wr_addr;
        end
    end
    
    //AXI读地址
    //axi_rd_addr
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            axi_rd_addr <= rd_beg_addr;  //初始化为起始地址
        end else if(rd_rst) begin
            axi_rd_addr <= rd_beg_addr;  //人工读复位时
        end else if(axi_rd_done && axi_rd_addr > (rd_end_addr - {burst_rd_addr_inc[28:0], 1'b0} + 30'd1)) begin 
        //每次写完成后判断是否超限, 下一个写首地址后续的空间已经不够再进行一次突发写操作, 位拼接的作用是×2
            axi_rd_addr <= rd_beg_addr;
        end else if(axi_rd_done) begin
            axi_rd_addr <= axi_rd_addr + burst_rd_addr_inc;  //增加一个burst_len的地址
        end else begin
            axi_rd_addr <= axi_rd_addr;
        end
    end
    
/*     //AXI写突发长度
    //axi_wr_len 
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_wr_len <= wr_burst_len; //axi_wr_len初始化
        end else if(wr_rst) begin
            axi_wr_len <= wr_burst_len;
        end else if(axi_wr_start_raise) begin 
            //在上升沿到来时判断写地址是否超限, 若是, 则将axi_wr_len减小, 使地址恰可达wr_end_addr
            //注意地址是按照字节寻址的,而每次burst将传输8Byte
            if((axi_wr_addr + {real_wr_len[4:0],3'b0}) > wr_end_addr) begin //超限, 位拼接的作用是×8
            //axi_wr_len设置为剩下的空间大小, 位拼接的作用是÷8, 减去1是由于AXI总线定义的burst_len = 真实burst_len - 1
                axi_wr_len <= {3'b0, wr_addr_margin[7:3]} - 8'd1; 
            end else begin
                axi_wr_len <= wr_burst_len;  //未超限,则保持标准的wr_burst_len
            end
        end else begin
            axi_wr_len <= axi_wr_len;
        end
    end */

    //AXI读突发长度
    //axi_rd_len 
/*     always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_rd_len <= rd_burst_len; //axi_rd_len初始化
        end else if(rd_rst) begin
            axi_rd_len <= rd_burst_len;
        end else if(axi_rd_start_raise) begin 
            //在上升沿到来时判断写地址是否超限, 若是, 则将axi_rd_len减小, 使地址恰可达rd_end_addr
            if((axi_rd_addr + {real_rd_len[4:0],3'b0}) > rd_end_addr) begin //超限, 位拼接的作用是×8
            //设置为剩下的空间大小, 位拼接的作用是÷8, 减去1是由于AXI总线定义的burst_len = 真实burst_len - 1
                axi_rd_len <= {3'b0, rd_addr_margin[7:3]} - 8'd1; 
            end else begin
                axi_rd_len <= rd_burst_len;  //未超限,则保持标准的wr_burst_len
            end
        end else begin
            axi_rd_len <= axi_rd_len;
        end
    end    */ 

    
    //读FIFO, 从SDRAM中读出的数据先暂存于此
    //使用FIFO IP核
	rd_fifo rd_fifo_inst (
        .rst                (~rst_n_sync | rd_rst_sync  ),  //读复位时需要复位读FIFO
        .wr_clk             (clk                        ),  //写端口时钟是AXI主机时钟, 从axi_master_rd模块写入数据
        .rd_clk             (rd_clk                     ),  //读端口时钟
        .din                (axi_rd_data                ),  //从axi_master_rd模块写入数据
        .wr_en              (axi_reading                ),  //axi_master_rd正在读时,FIFO也在写入
        .rd_en              (rd_en                      ),  //读FIFO读使能
        .dout               (rd_data                    ),  //读FIFO读取的数据
        .full               (                           ),  
        .almost_full        (                           ),  
        .empty              (rd_fifo_empty              ),  
        .almost_empty       (                           ),  
        .rd_data_count      (                           ),  
        .wr_data_count      (cnt_rd_fifo_wrport         ),  //读FIFO写端口(对接AXI读主机)数据数量
        .wr_rst_busy        (rd_fifo_wr_rst_busy        ),     
        .rd_rst_busy        (                           )      
);



    //写FIFO, 待写入SDRAM的数据先暂存于此
    //使用FIFO IP核
    wr_fifo wr_fifo_inst (
        .rst                (~rst_n_sync        ),  
        .wr_clk             (wr_clk             ),  //写端口时钟
        .rd_clk             (clk                ),  //读端口时钟是AXI主机时钟, AXI写主机读取数据
        .din                (wr_data            ),  
        .wr_en              (wr_en              ),  
        .rd_en              (axi_writing        ),  //axi_master_wr正在写时,从写FIFO中不断读出数据
        .dout               (axi_wr_data        ),  //读出的数据作为AXI写主机的输入数据
        .full               (                   ),  
        .almost_full        (                   ),  
        .empty              (                   ),  
        .almost_empty       (                   ),  
        .rd_data_count      (cnt_wr_fifo_rdport ),  //写FIFO读端口(对接AXI写主机)数据数量
        .wr_data_count      (                   ),  
        .wr_rst_busy        (                   ),  
        .rd_rst_busy        (                   )   
    );

/*     //读FIFO, 从SDRAM中读出的数据先暂存于此
    //使用自行编写的异步FIFO模块
    async_fifo
    #(.RAM_DEPTH       ('d2048          ), //内部RAM存储器深度
      .RAM_ADDR_WIDTH  ('d11            ), //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
      .WR_WIDTH        (AXI_WIDTH       ), //写数据位宽
      .RD_WIDTH        (FIFO_RD_WIDTH   ), //读数据位宽
      .WR_IND          ('d2             ), //单次写操作访问的ram_mem单元个数
      .RD_IND          ('d1             ), //单次读操作访问的ram_mem单元个数         
      .RAM_WIDTH       (FIFO_RD_WIDTH   ), //读端口数据位宽更小,使用读数据位宽作为RAM存储器的位宽
      .WR_CNT_WIDTH    ('d11            ), //FIFO写端口计数器的位宽
      .RD_CNT_WIDTH    ('d12            ), //FIFO读端口计数器的位宽
      .WR_L2           ('d1             ), //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
      .RD_L2           ('d0             ), //log2(RD_IND), 决定读地址有效低位
      .RAM_RD2WR       ('d1             )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1     
                )
    rd_fifo_inst
    (
            //写相关
            .wr_clk          (clk                        ),  //写端口时钟是AXI主机时钟, 从axi_master_rd模块写入数据
            .wr_rst_n        (rst_n_sync & ~rd_rst_sync  ),  //读复位时需要复位读FIFO
            .wr_en           (axi_reading                ),  //axi_master_rd正在读时,FIFO也在写入
            .wr_data         (axi_rd_data                ),  //从axi_master_rd模块写入数据
            .fifo_full       (                           ),  //FIFO写满
            .wr_data_count   (cnt_rd_fifo_wrport         ),  //读FIFO写端口(对接AXI读主机)数据数量
            //读相关
            .rd_clk          (rd_clk                     ),  //读端口时钟
            .rd_rst_n        (rst_n_sync & ~rd_rst_sync  ),  //读复位时需要复位读FIFO 
            .rd_en           (rd_en                      ),  //读FIFO读使能
            .rd_data         (rd_data                    ),  //读FIFO读取的数据
            .fifo_empty      (rd_fifo_empty              ),  //FIFO读空
            .rd_data_count   (                           )   //读端口数据个数,按读端口数据位宽计算
    );
    //自定义FIFO没有复位busy信号
    assign rd_fifo_wr_rst_busy = 1'b0;
    
    //写FIFO, 待写入SDRAM的数据先暂存于此
    //使用自定义异步FIFO
    async_fifo
    #(.RAM_DEPTH       ('d2048       ), //内部RAM存储器深度
      .RAM_ADDR_WIDTH  ('d11         ), //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
      .WR_WIDTH        (FIFO_WR_WIDTH), //写数据位宽
      .RD_WIDTH        (AXI_WIDTH    ), //读数据位宽
      .WR_IND          ('d1          ), //单次写操作访问的ram_mem单元个数
      .RD_IND          ('d2          ), //单次读操作访问的ram_mem单元个数         
      .RAM_WIDTH       (FIFO_WR_WIDTH), //RAM单元的位宽
      .WR_L2           ('d0          ), //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
      .RD_L2           ('d1          ), //log2(RD_IND), 决定读地址有效低位
      .WR_CNT_WIDTH    ('d12         ), //FIFO写端口计数器的位宽RAM_ADDR_WIDTH + 'd1 - WR_L2
      .RD_CNT_WIDTH    ('d11         ), //FIFO读端口计数器的位宽RAM_ADDR_WIDTH + 'd1 - RD_L2  
      .RAM_RD2WR       ('d2          )  //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1            
    )
    wr_fifo_inst
    (
        //写相关
        .wr_clk          (wr_clk             ), //写端口时钟
        .wr_rst_n        (rst_n_sync         ),
        .wr_en           (wr_en              ),
        .wr_data         (wr_data            ),
        .fifo_full       (                   ), //FIFO写满
        .wr_data_count   (                   ), //写端口数据个数,按写端口数据位宽计算
        //读相关
        .rd_clk          (clk                ), //读端口时钟是AXI主机时钟, AXI写主机读取数据
        .rd_rst_n        (rst_n_sync         ), 
        .rd_en           (axi_writing        ), //axi_master_wr正在写时,从写FIFO中不断读出数据
        .rd_data         (axi_wr_data        ), //读出的数据作为AXI写主机的输入数据
        .fifo_empty      (                   ), //FIFO读空
        .rd_data_count   (cnt_wr_fifo_rdport )  //写FIFO读端口(对接AXI写主机)数据数量
    );     */
    
    //读FIFO可读标志,表示读FIFO中有数据可以对外输出
    assign rd_valid = ~rd_fifo_empty;
    
endmodule
