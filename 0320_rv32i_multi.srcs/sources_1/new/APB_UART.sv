`timescale 1ns / 1ps

module APB_UART (
    input         PCLK,
    input         PRESET,
    input  [31:0] PADDR,
    input  [31:0] PWDATA,
    input         PENABLE,
    input         PWRITE,
    input         PSEL,
    output [31:0] PRDATA,
    output        PREADY,
    output [ 7:0] rx_data,
    output        rx_done,
    output        tx_busy,
    output        tx_done,
    output        uart_tx,
    output        b_tick
);

    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00c;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;

    logic [7:0] UART_CTL_REG, UART_STATUS_REG;
    logic [15:0] UART_BAUD_REG;
    logic [7:0] UART_TX_DATA_REG, UART_RX_DATA_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    //extantion vs padding??
    assign PRDATA = (PADDR[11:0] == UART_CTL_ADDR)  ? {16'h0000, UART_CTL_REG} : 
                    (PADDR[11:0] == UART_BAUD_ADDR) ? {16'h0000, UART_BAUD_REG} : 
                    (PADDR[11:0] == UART_STATUS_ADDR) ? {16'h0000, UART_STATUS_REG} : 
                    (PADDR[11:0] == UART_TX_DATA_ADDR) ? {16'h0000, UART_TX_DATA_REG} : 
                    (PADDR[11:0] == UART_RX_DATA_ADDR) ? {16'h0000, UART_RX_DATA_REG} : 
                    32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            UART_CTL_REG  <= 16'h0000;
            UART_BAUD_REG <= 16'h0000;
            UART_STATUS_REG <= 16'h0000;
            UART_TX_DATA_REG <= 16'h0000;
            UART_RX_DATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    UART_TX_DATA_ADDR: UART_TX_DATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    uart_rx U_UART_RX (
        .clk(),
        .rst(),
        .rx(),
        .b_tick(),
        .rx_data(),
        .rx_done()
    );

    uart_tx U_UART_TX (
        .clk(),
        .rst(),
        .tx_start(),
        .b_tick(),
        .tx_data(),
        .tx_busy(),
        .tx_done(),
        .uart_tx()
    );

    baud_tick U_BAUD_TICK (
        // 주기 : 1/9600
        .clk(),
        .rst(),
        .b_tick()
    );

endmodule
