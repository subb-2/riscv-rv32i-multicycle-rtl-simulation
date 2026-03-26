`timescale 1ns / 1ps

module GPO_Slave (
    input         PCLK,
    input         PRESET,   //ram이 아니기 때문에 rst 필요 
    input  [31:0] PADDR,
    input  [31:0] PWDATA,
    input         PENABLE,
    input         PWRITE,
    input         PSEL,
    output [31:0] PRDATA,
    output        PREADY,
    output [15:0] GPO_OUT
);
    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_DATA_ADDR = 12'h004;
    logic [15:0] GPO_DATA_REG, GPO_CTL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    //extantion vs padding??
    assign PRDATA = (PADDR[11:0] == GPO_CTL_ADDR)  ? {16'h0000, GPO_CTL_REG} : 
                    (PADDR[11:0] == GPO_DATA_ADDR) ? {16'h0000, GPO_DATA_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPO_CTL_REG  <= 16'h0000;
            GPO_DATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPO_CTL_ADDR:  GPO_CTL_REG <= PWDATA[15:0];
                    GPO_DATA_ADDR: GPO_DATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    //비트 하나 씩 제어하려고 했는데, OR로 만들어버림
    //OR면 하나라도 1이면 1이 되어버리니까 의도대로 안됨
    //assign GPO_OUT = (GPO_CTL_REG) ? GPO_DATA_REG : 16'hzzzz;
    //generate가 assign 반복 시키는 거야?
    //always comb 반복 보다 간단 
    genvar i;
    generate
        for(i = 0; i < 16; i++) begin
            assign GPO_OUT[i] = (GPO_CTL_REG[i]) ? GPO_DATA_REG[i] : 1'bz;
        end
    endgenerate

endmodule
