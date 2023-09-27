`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/18 13:09:46
// Module Name: axi_ctrl
// Description: AXI控制器, 依据AXI读写主机发来的读写信号, 自动产生AXI读写请求、读写地址以及读写突发长度
//////////////////////////////////////////////////////////////////////////////////

module axi_ctrl(
        input   wire        clk             , //AXI读写主机时钟
        input   wire        rst_n           , 
                
        //用户端    
        input   wire        wr_clk          , //写FIFO写时钟
        input   wire        wr_rst          , //写复位
        input   wire [29:0] wr_beg_addr     , //写起始地址
        input   wire [29:0] wr_end_addr     , //写终止地址
        input   wire [7:0]  wr_burst_len    , //写突发长度
        input   wire        wr_en           , //写FIFO写请求
        input   wire [15:0] wr_data         , //写FIFO写数据 
        input   wire        rd_clk          , //读FIFO读时钟
        input   wire        rd_rst          , //读复位
        input   wire        rd_mem_enable   , //读存储器使能,防止存储器未写先读
        input   wire [29:0] rd_beg_addr     , //读起始地址
        input   wire [29:0] rd_end_addr     , //读终止地址
        input   wire [7:0]  rd_burst_len    , //读突发长度
        input   wire        rd_en           , //读FIFO读请求
        output  wire [15:0] rd_data         , //读FIFO读数据
        output  wire        rd_valid        , //读FIFO可读标志,表示读FIFO中有数据可以对外输出
        
        //写AXI主机
        input   wire        axi_writing     , //AXI主机写正在进行
        input   wire        axi_wr_ready    , //AXI主机写准备好
        output  reg         axi_wr_start    , //AXI主机写请求
        output  wire [63:0] axi_wr_data     , //从写FIFO中读取的数据,写入AXI写主机
        output  reg  [29:0] axi_wr_addr     , //AXI主机写地址
        output  reg  [7:0]  axi_wr_len      , //AXI主机写突发长度
        
        //读AXI主机
        input   wire        axi_reading     , //AXI主机读正在进行
        input   wire        axi_rd_ready    , //AXI主机读准备好
        output  reg         axi_rd_start    , //AXI主机读请求
        input   wire [63:0] axi_rd_data     , //从AXI读主机读到的数据,写入读FIFO
        output  reg  [29:0] axi_rd_addr     , //AXI主机读地址
        output  reg  [7:0]  axi_rd_len        //AXI主机读突发长度        
    );
    
    //读写参数定义
    parameter   W_ADDR_INCR =  30'd8    ;  //8Byte数据地址增量
    parameter   R_ADDR_INCR =  30'd8    ;  //8Byte数据地址增量
        
    //FIFO数据数量计数器   
    wire [9:0]  cnt_rd_fifo_wrport      ;  //读FIFO写端口(对接AXI读主机)数据数量
    wire [9:0]  cnt_wr_fifo_rdport      ;  //写FIFO读端口(对接AXI写主机)数据数量
    

    
    wire        rd_fifo_empty           ;  //读FIFO空标志
        
    reg         axi_wr_start_d          ;  //axi_wr_start打一拍,用于上升沿提取
    reg         axi_rd_start_d          ;  //axi_rd_start打一拍,用于上升沿提取
    wire        axi_wr_start_raise      ;  //axi_wr_start上升沿
    wire        axi_rd_start_raise      ;  //axi_rd_start上升沿
    
    //读写地址余量
    wire [29:0] wr_addr_margin          ;  //写地址余量, 设定的写终止地址与当前突发传输的首地址之间的差值
    wire [29:0] rd_addr_margin          ;  //读地址余量, 设定的读终止地址与当前突发传输的首地址之间的差值
    
    //真实的读写突发长度
    wire  [7:0] real_wr_len             ;  //真实的写突发长度,是wr_burst_len+1
    wire  [7:0] real_rd_len             ;  //真实的读突发长度,是rd_burst_len+1
    
    //wr_addr_margin
    assign wr_addr_margin = wr_end_addr - axi_wr_addr + 30'd1;
    
    //rd_addr_margin
    assign rd_addr_margin = rd_end_addr - axi_rd_addr + 30'd1;    
    
    //real_wr_len
    assign real_wr_len = wr_burst_len + 8'd1;
    
    //real_rd_len
    assign real_rd_len = rd_burst_len + 8'd1;
    
    //AXI读主机开始读标志
    //axi_rd_start
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_rd_start <= 1'b0;
        end else if(~axi_rd_ready) begin  //axi_rd_ready低,代表AXI读主机正在进行数据读取, start信号已经被响应
            axi_rd_start <= 1'b0;
        end else if(rd_mem_enable && cnt_rd_fifo_wrport < real_rd_len && axi_rd_ready) begin //为了让FIFO能保持一定数据量,此处条件放宽
            //读FIFO中的数据存量不足, AXI读主机已经准备好, 且允许读存储器
            axi_rd_start <= 1'b1;
        end else begin
            axi_rd_start <= axi_rd_start;
        end
    end
    
    //AXI写主机开始写标志
    //axi_wr_start
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
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
    
    //axi_wr_start打拍
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_wr_start_d <= 1'b0;
        end else begin
            axi_wr_start_d <= axi_wr_start;
        end
    end
    
    //axi_rd_start打拍
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_rd_start_d <= 1'b0;
        end else begin
            axi_rd_start_d <= axi_rd_start;
        end
    end
   
    
    //axi_wr_start上升沿提取
    assign axi_wr_start_raise = (~axi_wr_start_d) & axi_wr_start;
    
    //axi_rd_start上升沿提取
    assign axi_rd_start_raise = (~axi_rd_start_d) & axi_rd_start;
    
/*     //rd_fifo_wr_en
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_fifo_wr_en <= 1'b0;
        end else begin
            rd_fifo_wr_en <= axi_reading;
        end
    end */
    
    //AXI写地址
    //axi_wr_addr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_wr_addr <= wr_beg_addr;  //初始化为起始地址
        end else if(wr_rst) begin
            axi_wr_addr <= wr_beg_addr;
/*         end else if(axi_writing && (axi_wr_addr + {W_ADDR_INCR[28:0], 1'b0}) > wr_end_addr) begin 
        //如果继续增加8, 下一个写首地址已经不够再填一次突发传输的数据了, 位拼接的作用是×2 */
           end else if(axi_writing && (wr_addr_margin < {W_ADDR_INCR[28:0], 1'b0})) begin 
        //如果继续增加8, 下一个写首地址已经不够再填一次突发传输的数据了, 位拼接的作用是×2
            axi_wr_addr <= wr_beg_addr;
        end else if(axi_writing) begin //在AXI主机写的过程中更新地址
            axi_wr_addr <= axi_wr_addr + W_ADDR_INCR;
        end else begin
            axi_wr_addr <= axi_wr_addr;
        end
    end
    
    //AXI读地址
    //axi_rd_addr
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            axi_rd_addr <= rd_beg_addr;  //初始化为起始地址
        end else if(rd_rst) begin
            axi_rd_addr <= rd_beg_addr;
/*         end else if(axi_reading && (axi_rd_addr + {R_ADDR_INCR[28:0], 1'b0}) > rd_end_addr) begin 
        //如果继续增加8, 下一个读首地址已经不够一次突发传输的数据了, 位拼接的作用是×2 */
        end else if(axi_reading && (rd_addr_margin < {R_ADDR_INCR[28:0], 1'b0})) begin 
        //如果继续增加8, 下一个读首地址已经不够一次突发传输的数据了, 位拼接的作用是×2
            axi_rd_addr <= rd_beg_addr;
        end else if(axi_reading) begin //在AXI主机读的过程中更新地址
            axi_rd_addr <= axi_rd_addr + R_ADDR_INCR;
        end else begin
            axi_rd_addr <= axi_rd_addr;
        end
    end
    
    //AXI写突发长度
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
    end

    //AXI读突发长度
    //axi_rd_len 
    always@(posedge clk or negedge rst_n) begin
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
    end    

    
    //读FIFO, 从SDRAM中读出的数据先暂存于此
	rd_fifo rd_fifo_inst (
        .rst                (~rst_n             ),  
        .wr_clk             (clk                ),  //写端口时钟是AXI主机时钟, 从axi_master_rd模块写入数据
        .rd_clk             (rd_clk             ),  //读端口时钟
        .din                (axi_rd_data        ),  //从axi_master_rd模块写入数据
        .wr_en              (axi_reading        ),  //axi_master_rd正在读时,FIFO也在写入
        .rd_en              (rd_en              ),  //读FIFO读使能
        .dout               (rd_data            ),  //读FIFO读取的数据
        .full               (                   ),  
        .almost_full        (                   ),  
        .empty              (rd_fifo_empty      ),  
        .almost_empty       (                   ),  
        .rd_data_count      (                   ),  
        .wr_data_count      (cnt_rd_fifo_wrport ),  //读FIFO写端口(对接AXI读主机)数据数量
        .wr_rst_busy        (                   ),     
        .rd_rst_busy        (                   )      
);

    //写FIFO, 待写入SDRAM的数据先暂存于此
    wr_fifo wr_fifo_inst (
        .rst                (~rst_n             ),  
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
    
    //读FIFO可读标志,表示读FIFO中有数据可以对外输出
    assign rd_valid = ~rd_fifo_empty;
    
endmodule
