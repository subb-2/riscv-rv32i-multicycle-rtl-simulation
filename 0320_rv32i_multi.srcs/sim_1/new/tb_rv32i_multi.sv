`timescale 1ns / 1ps

module tb_rv32i_multi ();

    logic clk, rst;
    logic [7:0] GPO, GPI;
    logic uart_rx, uart_tx;
    logic [ 3:0] fnd_digit;
    logic [ 7:0] fnd_data;
    wire  [15:0] GPIO;

    rv32I_mcu dut (
        .clk(clk),
        .rst(rst),
        .GPI(GPI),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .GPO(GPO),
        .GPIO(GPIO)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        GPI = 8'h00;
        //GPO = 16'h0000;
        //GPIO = 16'h0000;
        uart_rx = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        GPI = 8'haa;
        repeat (100000) @(negedge clk);

        //sw = 16'h00ff;
        //repeat(100) @(negedge clk);

        //sw = 16'h1234;
        //repeat(200) @(negedge clk);
        //repeat(400) @(negedge clk);
        $stop;
    end

endmodule
