`timescale 1ns / 1ps

module APB_FND (
    input         PCLK,
    input         PRESET,
    input  [31:0] PADDR,
    input  [31:0] PWDATA,
    input         PENABLE,
    input         PWRITE,
    input         PSEL,
    output [31:0] PRDATA,
    output        PREADY,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    localparam [11:0] FND_ADDR = 12'h000;
    logic [15:0] FND_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == FND_ADDR)  ? {16'h0000, FND_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            FND_REG <= 16'h0000;
            //GPI_IDATA_REG <= 16'h0000; 
        end else begin
            //GPI_IDATA_REG <= GPI_IDATA_NEXT;  //PREADY를 볼 필요가 없음 
            if (PREADY & PWRITE) begin
                if (PADDR[11:0] == FND_ADDR) begin
                    FND_REG <= PWDATA[15:0];
                end
            end
        end
    end

    fnd_controller U_FND_CTL (
        .clk(PCLK),
        .reset(PRESET),
        .fnd_in_data(FND_REG[13:0]),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule
