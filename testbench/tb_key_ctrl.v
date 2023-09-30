`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/30 09:36:33
// Module Name: tb_key_ctrl
// Description: testbench for key_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_key_ctrl(

    );
    
    reg         clk         ;
    reg         rst_n       ;
    reg         key_in      ;
    
    wire        state_out   ;
    
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        key_in <= 1'b1;
    #20
        rst_n <= 1'b1;
    #300
        key_in <= 1'b0;
    #500
        key_in <= 1'b1;
    #300
        key_in <= 1'b0;
    #500
        key_in <= 1'b1;
    #5000
        key_in <= 1'b0;
    #2000000
        key_in <= 1'b1;
    #5000
        key_in <= 1'b0;
    #2500000
        key_in <= 1'b1;
    #60000
        key_in <= 1'b0;
    end
    
    
    
    always#10 clk = ~clk;
    
    key_ctrl
    #(.FREQ(28'd50_000_000)) //模块输入时钟频率 
    key_ctrl_inst
    (
        .clk         (clk         ),
        .rst_n       (rst_n       ),
        .key_in      (key_in      ),

        .state_out   (state_out   )
    );
    
    
endmodule
