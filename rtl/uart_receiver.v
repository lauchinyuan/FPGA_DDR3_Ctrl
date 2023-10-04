`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/28 16:43:49
// Module Name: uart_receiver
// Description: RS232串口数据接收器, 当判断RS232串口发来的数据满足一个写FIFO写端口位宽时
// 拉高写FIFO使能, 并将数据写到写FIFO中
//////////////////////////////////////////////////////////////////////////////////


module uart_receiver
    #(
        parameter   UART_BPS        =   'd9600         , //串口波特率
                    CLK_FREQ        =   'd50_000_000   , //串口时钟频率
                    FIFO_WR_WIDTH   =   'd16           , //FIFO写端口数据位宽
                    FIFO_WR_BYTE    =   'd2              //FIFO写端口的数据位宽对应的字节数
    )    
    (   
        input   wire                    clk         ,
        input   wire                    rst_n       ,
        input   wire                    rx          , //RS232 rx线
        
        output  reg [FIFO_WR_WIDTH-1:0] fifo_wr_data, //向FIFO写入的数据
        output  reg                     fifo_wr_en    //FIFO写使能
    );
    
    //复位信号进行异步复位同步释放处理
    reg             rst_n_sync  ;   //同步释放复位
    reg             rst_n_d1    ;
    
    //计数器,记满一个FIFO位宽的字节数时, 输出有效数据和FIFO写请求
    reg     [3:0]   cnt_byte    ;
    
    //连线
    wire    [7:0]   po_data     ;   //串转并后的8bit数据
    wire            po_flag     ;   //串转并后的数据有效标志信号
    
    
    //同步释放处理
    //rst_n_sync
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin                //异步复位
            rst_n_d1    <= 1'b0     ;
            rst_n_sync  <= 1'b0     ;
        end else begin                  //同步释放
            rst_n_d1    <= 1'b1     ;
            rst_n_sync  <= rst_n_d1 ;
        end
    end
    
    //cnt_byte
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            cnt_byte <= 4'd0;
        end else if(po_flag && cnt_byte == (FIFO_WR_BYTE-1)) begin //计数到最大值
            cnt_byte <= 4'd0;
        end else if(po_flag) begin
            cnt_byte <= cnt_byte + 4'd1;
        end else begin
            cnt_byte <= cnt_byte;
        end
    end
    
    //记满一个FIFO位宽的字节数时, 拉高写使能
    //fifo_wr_en
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            fifo_wr_en <= 1'b0;
        end else if(po_flag && cnt_byte == (FIFO_WR_BYTE-1)) begin
            fifo_wr_en <= 1'b1;
        end else begin
            fifo_wr_en <= 1'b0;
        end
    end
    

    //输出的有效写数据
    always@(posedge clk or negedge rst_n_sync) begin
        if(~rst_n_sync) begin
            fifo_wr_data <= 'd0;
        end else if(po_flag) begin  
        //uart模块每次接收到一个新的Byte, 就将移位寄存器左移移位8bit, 并在低8位加上新的到的数据
            fifo_wr_data <= {fifo_wr_data[FIFO_WR_WIDTH-9:0], po_data};
        end else begin
            fifo_wr_data <= fifo_wr_data;
        end
    end
    
    
    uart_rx
    #(
        .UART_BPS(UART_BPS),   //串口波特率
        .CLK_FREQ(CLK_FREQ)    //时钟频率
    )
    uart_rx_inst
    (
        .sys_clk     (clk         ),   //系统时钟50MHz
        .sys_rst_n   (rst_n_sync  ),   //全局复位
        .rx          (rx          ),   //串口接收数据
    
        .po_data     (po_data     ),   //串转并后的8bit数据
        .po_flag     (po_flag     )    //串转并后的数据有效标志信号
    );
endmodule
