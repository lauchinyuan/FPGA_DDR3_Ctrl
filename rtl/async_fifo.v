`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/08 16:41:58
// Module Name: async_fifo
// Description: 异步FIFO, 支持非对称数据读写操作(读写width不一致)

// 参数依赖关系:
// RAM_ADDR_WIDTH = log2(RAM_DEPTH)
// WR_IND = WR_WIDTH/RAM_WIDTH
// RD_IND = RD_WIDTH/RAM_WIDTH
// WR_CNT_WIDTH = RAM_ADDR_WIDTH + 1 - log2(WR_IND)
// RD_CNT_WIDTH = RAM_ADDR_WIDTH + 1 - log2(RD_IND)
// WR_L2  = log2(WR_IND)
// RD_L2  = log2(RD_IND)
// RAM_RD2WR = RAM_RD_WIDTH/RAM_DATA_WIDTH
// RAM_RD_WIDTH = RAM_WIDTH * RAM_RD2WR
// RAMS_RD_WIDTH = WR_WIDTH * RAM_RD2WR


// 举例: 假设存储器深度为32, 则存储器地址线位宽(RAM_ADDR_WIDTH)为5bit
// 若FIFO读端口数据位宽为32bit, 是RAM存储单元位宽的4倍, 则需设置每进行一次读操作需要让读指针自增值WR_IND为4(Bytes)
// 若将32bit视为一个存取单元进行访问,则"数据个数计数器"只需要4bit(RAM_ADDR_WIDTH+1-2)位宽
// 即FIFO最多可以存储8个32bit数据, 而8需要4比特数据来表示
//////////////////////////////////////////////////////////////////////////////////


module async_fifo
            
#(parameter RAM_DEPTH       = 'd1024                        , //内部RAM存储器深度
            RAM_ADDR_WIDTH  = 'd10                          , //内部RAM读写地址宽度, 需与RAM_DEPTH匹配
            WR_WIDTH        = 'd64                          , //写数据位宽
            RD_WIDTH        = 'd32                          , //读数据位宽
            WR_IND          = 'd2                           , //单次写操作访问的ram_mem单元个数
            RD_IND          = 'd1                           , //单次读操作访问的ram_mem单元个数         
            RAM_WIDTH       = RD_WIDTH                      , //写端口数据位宽更小,使用写数据位宽作为RAM存储器的位宽
            WR_L2           = 'd1                           , //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
            RD_L2           = 'd0                           , //log2(RD_IND), 决定读地址有效低位
            WR_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - WR_L2  , //FIFO写端口计数器的位宽
            RD_CNT_WIDTH    = RAM_ADDR_WIDTH + 'd1 - RD_L2  , //FIFO读端口计数器的位宽  
            RAM_RD2WR       = 'd1                             //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1
)
(
        //写相关
        input   wire                        wr_clk          , //写端口时钟
        input   wire                        wr_rst_n        , //写地址复位
        input   wire                        wr_en           , //写使能
        input   wire [WR_WIDTH-1:0]         wr_data         , //写数据
        output  wire                        fifo_full       , //FIFO写满
        output  wire [WR_CNT_WIDTH-1:0]     wr_data_count   , //写端口数据个数,按写端口数据位宽计算
        //读相关
        input   wire                        rd_clk          , //读端口时钟
        input   wire                        rd_rst_n        , //读地址复位 
        input   wire                        rd_en           , //读使能
        output  wire [RD_WIDTH-1:0]         rd_data         , //读数据
        output  wire                        fifo_empty      , //FIFO读空
        output  wire [RD_CNT_WIDTH-1:0]     rd_data_count     //读端口数据个数,按读端口数据位宽计算
    );
    
    localparam  RAM_RD_WIDTH    = RAM_WIDTH * RAM_RD2WR         , //每个双端口RAM模块的读出数据位宽
                RAMS_RD_WIDTH   = WR_WIDTH * RAM_RD2WR          ;  //多个RAM构成的RAM组合单次读出的数据位宽, 是写位宽的整数倍
    
    //读指针
    wire [RAM_ADDR_WIDTH:0]     rd_ptr          ; //读时钟域下的读指针
    wire [RD_CNT_WIDTH-1:0]     rd_ptr_gray     ; //读时钟域下的读指针"高RD_CNT_WIDTH位"格雷码
    reg  [RD_CNT_WIDTH-1:0]     rd_ptr_gray_w0  ; //读指针格雷码"双锁存器同步"到写时钟域的第一拍
    reg  [RD_CNT_WIDTH-1:0]     rd_ptr_gray_w1  ; //读指针格雷码"双锁存器同步"到写时钟域的第二拍
    wire [RD_CNT_WIDTH-1:0]     rd_ptr_g2b      ; //写时钟域下同步后的读指针格雷码转为二进制
    wire [RAM_ADDR_WIDTH:0]     rd_ptr_sync     ; ///rd_ptr_g2b补全低位后的"同步读指针"
    
    //写指针
    wire [RAM_ADDR_WIDTH:0]     wr_ptr          ; //写时钟域下的写指针
    wire [WR_CNT_WIDTH-1:0]     wr_ptr_gray     ; //写时钟域下的写指针"高RD_CNT_WIDTH位"格雷码
    reg  [WR_CNT_WIDTH-1:0]     wr_ptr_gray_r0  ; //写指针格雷码"双锁存器同步"到读时钟域的第一拍
    reg  [WR_CNT_WIDTH-1:0]     wr_ptr_gray_r1  ; //写指针格雷码"双锁存器同步"到读时钟域的第二拍 
    wire [WR_CNT_WIDTH-1:0]     wr_ptr_g2b      ; //读时钟域下同步后的写指针格雷码转为二进制
    wire [RAM_ADDR_WIDTH:0]     wr_ptr_sync     ; //wr_ptr_g2b补全低位后的"同步写指针" 
    
    //使能信号中间连线
    wire                        ram_wr_en       ;
    wire                        ram_rd_en       ;
    
    //RAM读地址, 若需要支持"First Word Fall Through"模式, 则需要在有效读使能信号有效时, 读地址提前更新为下一个读取地址
    reg [RAM_ADDR_WIDTH-1:0]    ram_rd_addr     ;
    
    
    
    
    //支持"First Word Fall Through"模式, 读使能信号有效时就输出地址对应的有效数据
    //若要使有效数据在读使能信号的下一个时钟到来, 则注释掉下方define
    
    
    `define FWFT_ON
    
    //依据是否支持FWFT选择不同的RAM读取地址
    `ifdef FWFT_ON
        //ram_rd_addr
        //若支持FWFT模式, 则需要在读RAM有效时, 提前加上读地址增量RD_IND, 而不读RAM时, 读指针高位作为读地址
        always@(*) begin
            if(ram_rd_en) begin
                ram_rd_addr = rd_ptr[RAM_ADDR_WIDTH-1:0] + RD_IND; 
            end else begin
                ram_rd_addr = rd_ptr[RAM_ADDR_WIDTH-1:0];
            end
        end
    `else
        //ram_rd_addr
        //普通FIFO, 读指针高位作为读地址
        always@(*) begin
            ram_rd_addr = rd_ptr[RAM_ADDR_WIDTH-1:0];
        end        
    `endif
    
    
    
    //bin2gray
    //写指针二进制无符号数转格雷码
    //对于写指针来说, 其"高WR_CNT_WIDTH位"符合连续加1的条件 
    //只对"高WR_CNT_WIDTH位"进行格雷码转换和跨时钟域处理
    assign wr_ptr_gray = wr_ptr[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-WR_CNT_WIDTH+'d1] ^ {1'b0, wr_ptr[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-WR_CNT_WIDTH+'d2]};
    
    //读指针二进制无符号数转格雷码
    //对于读指针来说, 其"高RD_CNT_WIDTH位"符合连续加1的条件 
    //只对"高RD_CNT_WIDTH位"进行格雷码转换和跨时钟域处理
    assign rd_ptr_gray = rd_ptr[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-RD_CNT_WIDTH+'d1] ^ {1'b0, rd_ptr[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH-RD_CNT_WIDTH+'d2]};   

    //写指针同步到读时钟域
    //wr2rd_sync
    always@(posedge rd_clk or negedge rd_rst_n) begin
        if(~rd_rst_n) begin
            wr_ptr_gray_r0 <= 'd0;
            wr_ptr_gray_r1 <= 'd0;
        end else begin
            wr_ptr_gray_r0 <= wr_ptr_gray;
            wr_ptr_gray_r1 <= wr_ptr_gray_r0;
        end
    end
    
    //读指针同步到写时钟域
    //rd2wr_sync
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            rd_ptr_gray_w0 <= 'd0;
            rd_ptr_gray_w1 <= 'd0;
        end else begin
            rd_ptr_gray_w0 <= rd_ptr_gray;
            rd_ptr_gray_w1 <= rd_ptr_gray_w0;
        end
    end
    
    //读时钟域下写指针格雷码转二进制
    assign wr_ptr_g2b = wr_ptr_gray_r1 ^ {1'b0, wr_ptr_g2b[WR_CNT_WIDTH-1:1]};
    
    //写时钟域下读指针格雷码转二进制
    assign rd_ptr_g2b = rd_ptr_gray_w1 ^ {1'b0, rd_ptr_g2b[RD_CNT_WIDTH-1:1]};    
    
    
    //输入读写控制模块的同步读写指针
    //wr_ptr_sync补零个数为log2(WR_IND)
    //rd_ptr_sync补零个数为log2(RD_IND)
    assign wr_ptr_sync = wr_ptr_g2b << WR_L2;
    assign rd_ptr_sync = rd_ptr_g2b << RD_L2;

    
    //FIFO内部RAM存储器
    ram
    #(.RAM_DEPTH       (RAM_DEPTH       ), 
      .RAM_ADDR_WIDTH  (RAM_ADDR_WIDTH  ), 
      .WR_WIDTH        (WR_WIDTH        ), 
      .RD_WIDTH        (RD_WIDTH        ), 
      .RAM_WIDTH       (RAM_WIDTH       ), 
      .WR_IND          (WR_IND          ), 
      .RD_IND          (RD_IND          ),
      .WR_L2           (WR_L2           ), 
      .RD_L2           (RD_L2           ), 
      .RAM_RD2WR       (RAM_RD2WR       ), 
      .RAM_RD_WIDTH    (RAM_RD_WIDTH    ), 
      .RAMS_RD_WIDTH   (RAMS_RD_WIDTH   )  
    ) ram_inst
    (
         //写端口
        .wr_clk      (wr_clk                    ),
        .wr_en       (ram_wr_en                 ), //写使能
        .wr_addr     (wr_ptr[RAM_ADDR_WIDTH-1:0]), //写指针的低位作为RAM写地址
        .wr_data     (wr_data                   ), 
        
        //读端口
        .rd_clk      (rd_clk                    ),
        .rd_addr     (ram_rd_addr               ), //读指针的低位作为RAM读地址
        .rd_data     (rd_data                   )               
    );
    
    //写控制器
    fifo_wr_ctrl
    #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH ), 
      .WR_CNT_WIDTH   (WR_CNT_WIDTH   ), 
      .WR_IND         (WR_IND         )  
    )
    fifo_wr_ctrl_inst
    (
        .wr_clk          (wr_clk          ),
        .wr_rst_n        (wr_rst_n        ),
        .wr_en           (wr_en           ),
        .rd_ptr_sync     (rd_ptr_sync     ), //从读时钟域同步过来的读指针, 二进制
        
        .wr_ptr          (wr_ptr          ), //写指针,相比RAM访存地址扩展一位
        .fifo_full       (fifo_full       ), //FIFO写满标志
        .wr_data_count   (wr_data_count   ), //写端口数据数量计数器 
        .ram_wr_en       (ram_wr_en       )  //RAM写使能信号, 非满且wr_en输入有效时有效
    );
    
    
    //读控制器
    fifo_rd_ctrl
    #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH ), //存储器地址线位宽
      .RD_CNT_WIDTH   (RD_CNT_WIDTH   ), //读端口计数器位宽
      .RD_IND         (RD_IND         )  //每进行一次读操作,读指针需要自增的增量
     )
     fifo_rd_ctrl_inst
    (
        .rd_clk          (rd_clk          ),
        .rd_rst_n        (rd_rst_n        ),
        .rd_en           (rd_en           ), //读FIFO使能
        .wr_ptr_sync     (wr_ptr_sync     ), //从写时钟域同步过来的写指针, 二进制无符号数表示
        
        .rd_ptr          (rd_ptr          ), //读指针
        .fifo_empty      (fifo_empty      ), //FIFO读空标志
        .rd_data_count   (rd_data_count   ), //读端口数据数量计数器
        .ram_rd_en       (ram_rd_en       )  
    );
    
endmodule
