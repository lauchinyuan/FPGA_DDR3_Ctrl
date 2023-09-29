`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/29 10:50:25
// Module Name: tb_uart_receiver
// Description: testbench for uart_receiver module
//////////////////////////////////////////////////////////////////////////////////


module tb_uart_receiver(

    );

    reg         clk         ; //与FIFO时钟同步
    reg         rst_n       ;
    reg         rx          ; //串口数据
                         
    wire[31:0]  fifo_wr_data; //FIFO写数据    
    wire        fifo_wr_en  ; //FIFO写使能
    
    reg [31:0] mem[511: 0];  //缓存待输出数据
    
    //将32bit txt文本数据读取到缓存空间mem
    initial begin
        $readmemh("C:/Users/123/Desktop/cloud_40_30_uint32.txt", mem);  
    end
    
    //时钟、复位及数据
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        rx <= 1'b1;
    #20
        rst_n <= 1'b1;
    #3000
        //发送测试激励
        uart_test();
    end
    
    //50MHz时钟
    always#10 clk = ~clk;
    
    //产生多个32bit RS232数据激励
    task uart_test();
        integer i;
        for(i=0; i<99; i=i+1) begin
            uart_bytes(mem[i]);
        end
    endtask
    
    //模拟UART串口发送32bit
    task uart_bytes(input [31:0] data);
        integer i;
        for(i=0;i<4;i=i+1) begin  //分别将32bit数据由高至低发出
            case(i) 
                0: uart_bit(data[31:24]);
                1: uart_bit(data[23:16]);
                2: uart_bit(data[15:8]);
                3: uart_bit(data[7:0]);
                default: uart_bit(8'b0);
            endcase
        end
    endtask
    
    
    //模拟UART串口发送bit
    task uart_bit(input [7:0]   data);
        integer i;
        for(i=0;i<10;i=i+1) begin
            case(i)
                0: rx <= 1'b0;  //起始位
                1: rx <= data[0];
                2: rx <= data[1];
                3: rx <= data[2];
                4: rx <= data[3];
                5: rx <= data[4];
                6: rx <= data[5];
                7: rx <= data[6];
                8: rx <= data[7];
                9: rx <= 1'b1;
                default: rx <= 1'b0;
            endcase
        #(5207*20);  //每bit之间的时间差
        end
    endtask
    
    
    
    
    //DUT例化
    uart_receiver
    #(
        .UART_BPS      ('d9600      ),   //串口波特率
        .CLK_FREQ      ('d50_000_000),   //时钟频率
        .FIFO_WR_WIDTH ('d32        ),   //写FIFO写端口数据位宽
        .FIFO_WR_BYTE  ('d4         )    //写FIFO写端口字节数
    ) 
    uart_receiver_inst
    (
        .clk         (clk         ), //与FIFO时钟同步
        .rst_n       (rst_n       ),
        .rx          (rx          ), //串口

        .fifo_wr_data(fifo_wr_data), //FIFO写数据
        .fifo_wr_en  (fifo_wr_en  )  //FIFO写使能
    );
endmodule
