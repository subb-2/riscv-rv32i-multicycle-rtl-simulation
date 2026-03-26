`timescale 1ns / 1ps

module tb_rv32i_multi();

    logic clk, rst;
    logic [15:0] sw, led;

    rv32I_mcu dut (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .led(led)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        sw = 0;
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        @(negedge clk);
        sw = 16'hf0f0;
        repeat(100) @(negedge clk); 
        
        //sw = 16'h00ff;
        //repeat(100) @(negedge clk);

        //sw = 16'h1234;
        //repeat(200) @(negedge clk);
        repeat(400) @(negedge clk);
        $stop;
    end

endmodule
