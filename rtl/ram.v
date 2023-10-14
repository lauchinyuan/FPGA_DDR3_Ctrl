`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/10/09 20:53:03
// Module Name: ram
// Description: FIFO RAM模块, 存储FIFO数据, 内部例化一个或多个dual_port_ram模块作为基本存储单元
// 依据写数据位宽和RAM数据位宽的比值(WR_WIDTH/RAM_WIDTH), 确定需要例化的dual_port_ram模块数
// 举例: 当写位宽为64bit, RAM数据位宽为32bit, 则需例化两个RAM模块,分别存储64bit数据的[63:32]以及[31:0]

// 当读位宽大于写位宽时, 例如WR_WIDTH = 16, RD_WIDTH = 32, RAM_WIDTH = 8
// 则存储单个写数据(wr_data)需要(WR_WIDTH/RAM_WIDTH=2)个双端口RAM, 读取单个数据, 需要访问的RAM深度为(RD_WIDTH/WR_WIDTH=2)
// 每个RAM的输出位宽为RAM_WIDTH * (RD_WIDTH/WR_WIDTH) = 16bit


// 参数依赖说明:
// RAM_ADDR_WIDTH = log2(RAM_DEPTH)
// WR_IND = WR_WIDTH/RAM_WIDTH
// RD_IND = RD_WIDTH/RAM_WIDTH
// WR_L2  = log2(WR_IND)
// RD_L2  = log2(RD_IND)
// RAM_RD2WR = RAM_RD_WIDTH/RAM_DATA_WIDTH
// RAM_RD_WIDTH = RAM_WIDTH * RAM_RD2WR
// RAMS_RD_WIDTH = WR_WIDTH * RAM_RD2WR
//////////////////////////////////////////////////////////////////////////////////


module ram
#(parameter RAM_DEPTH       = 'd64                  , //存储器深度
            RAM_ADDR_WIDTH  = 'd6                   , //读写地址宽度, 需与RAM_DEPTH匹配
            WR_WIDTH        = 'd32                  , //写数据位宽
            RD_WIDTH        = 'd64                  , //读数据位宽
            RAM_WIDTH       = 'd8                   , //RAM存储器的位宽
            WR_IND          = 'd4                   , //单次写操作访问的ram_mem单元个数
            RD_IND          = 'd8                   , //单次读操作访问的ram_mem单元个数
            WR_L2           = 'd2                   , //log2(WR_IND), 决定写地址有效数据位个数及RAM位宽
            RD_L2           = 'd3                   , //log2(RD_IND), 决定读地址有效低位
            RAM_RD2WR       = 'd2                   , //读数据位宽和写数据位宽的比, 即一次读取的RAM单元深度, RAM_RD2WR = RD_WIDTH/WR_WIDTH, 当读位宽小于等于写位宽时, 值为1
            RAM_RD_WIDTH    = RAM_WIDTH * RAM_RD2WR , //每个双端口RAM模块的读出数据位宽
            RAMS_RD_WIDTH   = WR_WIDTH * RAM_RD2WR    //多个RAM构成的RAM组合单次读出的数据位宽, 是写位宽的整数倍
)
(
        //写端口
        input   wire                        wr_clk      ,
        input   wire                        wr_en       , //写使能
        input   wire [RAM_ADDR_WIDTH-1:0]   wr_addr     , //写地址
        input   wire [WR_WIDTH-1:0]         wr_data     , //写数据
        
        //读端口
        input   wire                        rd_clk      ,
        input   wire [RAM_ADDR_WIDTH-1:0]   rd_addr     , //读地址
        output  reg  [RD_WIDTH-1:0]         rd_data       //读数据        
    );
    
    wire [RAMS_RD_WIDTH-1:0]            ram_rd_data ; //从一组RAM中读出来的原始数据
    reg  [RAM_ADDR_WIDTH-1:0]           rd_addr_d   ; //读地址在读时钟下打一拍

    //读地址在读时钟下打一拍
    //用作读数据输出选择, 使用前一拍的读地址进行数据输出判断
    always@(posedge rd_clk) begin
        rd_addr_d <= rd_addr;
    end
        
    
        
    //dual_port_ram例化
    genvar i;
    generate
        for(i=0; i<WR_IND; i=i+1) begin: dual_port_ram_inst
            dual_port_ram
            #(.RAM_DEPTH       (RAM_DEPTH >> WR_L2      ), //RAM深度, 是外部定义RAM深度除以WR_IND, 将原本定义的深度"分摊"到WR_IND个模块上了
              .RAM_ADDR_WIDTH  (RAM_ADDR_WIDTH - WR_L2  ), //读写地址宽度, 需与RAM_DEPTH匹配
              .RAM_DATA_WIDTH  (RAM_WIDTH               ), //RAM数据位宽为外部定义的位宽
              .RAM_RD2WR       (RAM_RD2WR               ),
              .RAM_RD_WIDTH    (RAM_RD_WIDTH            )  //RAM读取数据位宽
            )
            dual_port_ram_inst
            (
                //写端口
                .wr_clk          (wr_clk                                            ), //写时钟
                .wr_port_ena     (1'b1                                              ), //写端口使能, 高有效
                .wr_en           (wr_en                                             ), //写数据使能
                .wr_addr         (wr_addr[RAM_ADDR_WIDTH-1:WR_L2]                   ), //输入的写地址的高位, 作为每个RAM的写地址
                .wr_data         (wr_data[(i+1)*RAM_WIDTH-1:i*RAM_WIDTH]            ), //写数据, 每个RAM都不同,相当于将原来写数据拆分"平摊"
                            
                //读端口           
                .rd_clk          (rd_clk                                            ), //读时钟
                .rd_port_ena     (1'b1                                              ), //读端口使能, 高有效
                .rd_addr         (rd_addr[RAM_ADDR_WIDTH-1:WR_L2]                   ), //输入的读地址的高位, 作为每个RAM的读地址
                .rd_data         (ram_rd_data[(i+1)*RAM_RD_WIDTH-1:i*RAM_RD_WIDTH]  )  //读出的原始数据
            );
        
        end
    endgenerate
    
    
    //对于读位宽小于写位宽的情况
    //依据读地址的低RD_L2位, 选择最终输出的数据
    //举例说明: 若写数据width为64(WR_WIDTH), 读数据width为32(RD_WIDTH), RAM存储数据width为8(RAM_WIDTH)
    //则有: 
    //WR_WIDTH = 64
    //RD_WIDTH = 32
    //RAM_WIDTH = 8
    //WR_IND = 8
    //RD_IND = 4
    //WR_L2 = 3
    //RD_L2 = 2
    
    //则下式rd_addr_d[WR_L2-1:RD_L2] 即为rd_addr_d[2]
    //有访存表:
    //-----------------------------------------
    //|   rd_addr_d[2]  |    rd_data            |
    //-----------------------------------------
    //|      0          |  ram_rd_data[64:32]  |    
    //|      1          |  ram_rd_data[31:0]   | 
    //-----------------------------------------
    
    //rd_data
    //依据读写数据位宽情况按情况生成输出的rd_data数据
    genvar j;
    generate
        if(RAM_RD2WR == 'd1) begin  //双端口RAM模块输出数据位宽和输入数据位宽想读, 即每个dual_port_ram的读取深度都为1
            if(WR_L2 == RD_L2) begin  
                //写数据位宽和读数据位宽相同, 从RAM中读出的数据直接作为输出
                always@(*) begin
                    rd_data = ram_rd_data;
                end
                
            end else if(WR_L2 > RD_L2) begin 
                //写数据位宽大于读数据位宽, 则从RAM组中读出的数据需要分别依据情况输出
                if((WR_L2 - RD_L2) == 'd1) begin
                    //rd_addr_d[WR_L2-1:RD_L2]只有1bit两种情况
                    always@(*) begin
                            case(rd_addr_d[WR_L2-1:RD_L2])   //在此结构中,假定写位宽最多是读位宽的16倍
                            'd0 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1)                 : RAMS_RD_WIDTH - RD_WIDTH   ];
                            'd1 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - RD_WIDTH      : RAMS_RD_WIDTH - 2 *RD_WIDTH]; 
                            default: rd_data = 'd0;
                        endcase
                     end
                end else if((WR_L2 - RD_L2) == 'd2) begin
                //rd_addr_d[WR_L2-1:RD_L2]有2bit四种情况
                    always@(*) begin
                            case(rd_addr_d[WR_L2-1:RD_L2])   //在此结构中,假定写位宽最多是读位宽的16倍
                            'd0 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1)                 : RAMS_RD_WIDTH - RD_WIDTH   ];
                            'd1 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - RD_WIDTH      : RAMS_RD_WIDTH - 2 *RD_WIDTH];
                            'd2 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 2 *RD_WIDTH   : RAMS_RD_WIDTH - 3 *RD_WIDTH];
                            'd3 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 3 *RD_WIDTH   : RAMS_RD_WIDTH - 4 *RD_WIDTH]; 
                            default: rd_data = 'd0;
                        endcase
                     end                
                
                end else if((WR_L2 - RD_L2) == 'd3) begin
                //rd_addr_d[WR_L2-1:RD_L2]有3bit八种情况
                    always@(*) begin
                            case(rd_addr_d[WR_L2-1:RD_L2])   //在此结构中,假定写位宽最多是读位宽的16倍
                            'd0 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1)                 : RAMS_RD_WIDTH - RD_WIDTH   ];
                            'd1 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - RD_WIDTH      : RAMS_RD_WIDTH - 2 *RD_WIDTH];
                            'd2 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 2 *RD_WIDTH   : RAMS_RD_WIDTH - 3 *RD_WIDTH];
                            'd3 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 3 *RD_WIDTH   : RAMS_RD_WIDTH - 4 *RD_WIDTH];
                            'd4 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 4 *RD_WIDTH   : RAMS_RD_WIDTH - 5 *RD_WIDTH];
                            'd5 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 5 *RD_WIDTH   : RAMS_RD_WIDTH - 6 *RD_WIDTH];
                            'd6 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 6 *RD_WIDTH   : RAMS_RD_WIDTH - 7 *RD_WIDTH];
                            'd7 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 7 *RD_WIDTH   : RAMS_RD_WIDTH - 8 *RD_WIDTH];
                            default: rd_data = 'd0;
                        endcase
                     end                
                end else if((WR_L2 - RD_L2) == 'd4) begin
                //rd_addr_d[WR_L2-1:RD_L2]有4bit十六种种情况
                    always@(*) begin
                            case(rd_addr_d[WR_L2-1:RD_L2])   //在此结构中,假定写位宽最多是读位宽的16倍
                            'd0 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1)                 : RAMS_RD_WIDTH - RD_WIDTH   ];
                            'd1 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - RD_WIDTH      : RAMS_RD_WIDTH - 2 *RD_WIDTH];
                            'd2 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 2 *RD_WIDTH   : RAMS_RD_WIDTH - 3 *RD_WIDTH];
                            'd3 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 3 *RD_WIDTH   : RAMS_RD_WIDTH - 4 *RD_WIDTH];
                            'd4 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 4 *RD_WIDTH   : RAMS_RD_WIDTH - 5 *RD_WIDTH];
                            'd5 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 5 *RD_WIDTH   : RAMS_RD_WIDTH - 6 *RD_WIDTH];
                            'd6 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 6 *RD_WIDTH   : RAMS_RD_WIDTH - 7 *RD_WIDTH];
                            'd7 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 7 *RD_WIDTH   : RAMS_RD_WIDTH - 8 *RD_WIDTH];
                            'd8 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 8 *RD_WIDTH   : RAMS_RD_WIDTH - 9 *RD_WIDTH];
                            'd9 : rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 9 *RD_WIDTH   : RAMS_RD_WIDTH - 10*RD_WIDTH];
                            'd10: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 10*RD_WIDTH   : RAMS_RD_WIDTH - 11*RD_WIDTH];
                            'd11: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 11*RD_WIDTH   : RAMS_RD_WIDTH - 12*RD_WIDTH];
                            'd12: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 12*RD_WIDTH   : RAMS_RD_WIDTH - 13*RD_WIDTH];
                            'd13: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 13*RD_WIDTH   : RAMS_RD_WIDTH - 14*RD_WIDTH];
                            'd14: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 14*RD_WIDTH   : RAMS_RD_WIDTH - 15*RD_WIDTH];
                            'd15: rd_data = ram_rd_data[(RAMS_RD_WIDTH-1) - 15*RD_WIDTH   : RAMS_RD_WIDTH - 16*RD_WIDTH]; 
                            default: rd_data = 'd0;
                        endcase
                     end                
                end //更多情况请自行添加即可
                
                
                         
            end else begin
                //写数据位宽小于读数据位宽,而RAM_RD2WR错误配置为1(正常应配置为大于1的值),参数合理配置时, 此情况并不会出现
                always@(*) begin
                    rd_data = 'd0;
                end           
            end
        end else if(WR_L2 < RD_L2) begin //写数据位宽小于读数据位宽,且RAM_RD2WR正确配置
            //实际上此时ram_rd_data已经将数据读出, 只需要对数据进行重新排序即可
            for(i=0;i<RAM_RD2WR;i=i+1) begin: rd_depth
                for(j=0;j<WR_IND;j=j+1) begin: wr_width
                    always@(*) begin
                        rd_data[(RAMS_RD_WIDTH-1) - (j*RAM_WIDTH) - (i*WR_WIDTH): (RAMS_RD_WIDTH-RAM_WIDTH) - (j*RAM_WIDTH) - (i*WR_WIDTH)]
                        =ram_rd_data[(RAMS_RD_WIDTH-1) - (j*RAM_RD_WIDTH) - (i*RAM_WIDTH): (RAMS_RD_WIDTH-RAM_WIDTH) - (j*RAM_RD_WIDTH) - (i*RAM_WIDTH)];                   
                    end

                end
            end
        end
    
    endgenerate
    
    
   
    
   
    
endmodule
