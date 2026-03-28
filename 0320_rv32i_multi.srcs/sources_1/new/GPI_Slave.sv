`timescale 1ns / 1ps

module GPI_Slave (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input        [7:0] GPI_IN,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    localparam [11:0] GPI_CTL_ADDR = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;
    //logic [15:0] GPI_IDATA_REG, GPI_IDATA_NEXT, GPI_CTL_REG;
    logic [15:0] GPI_IDATA_REG,  GPI_CTL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;
    //assign PRDATA = {16'h0, GPI_IDATA_REG};

    assign PRDATA = (PADDR[11:0] == GPI_CTL_ADDR)  ? {16'h0000, GPI_CTL_REG} : 
                    (PADDR[11:0] == GPI_IDATA_ADDR) ? {16'h0000, GPI_IDATA_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPI_CTL_REG   <= 16'h0000;
            //GPI_IDATA_REG <= 16'h0000; 
        end else begin
            //GPI_IDATA_REG <= GPI_IDATA_NEXT;  //PREADY를 볼 필요가 없음 
            if (PREADY & PWRITE) begin
                if (PADDR[11:0] == GPI_CTL_ADDR) begin
                    GPI_CTL_REG <= PWDATA[15:0];
                end
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign GPI_IDATA_REG[i] = (GPI_CTL_REG[i]) ? GPI_IN[i] : 1'bz;
        end
    endgenerate

endmodule
