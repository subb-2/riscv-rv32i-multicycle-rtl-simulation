`timescale 1ns / 1ps

module BRAM (
    input               PCLK,
    //APB Interface Signal 
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input        [ 2:0] i_funct3,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    logic [31:0] bmem[0:1024];  //word로 word address 
    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    //store 과정 
    always_ff @(posedge PCLK) begin
        if (PSEL & PENABLE & PWRITE) begin
            case (i_funct3)
                //SB
                3'b000: begin
                    case (PADDR[1:0])
                        2'b00: bmem[PADDR[11:2]][7:0] <= PWDATA[7:0];
                        2'b01: bmem[PADDR[11:2]][15:8] <= PWDATA[7:0];
                        2'b10: bmem[PADDR[11:2]][23:16] <= PWDATA[7:0];
                        2'b11: bmem[PADDR[11:2]][31:24] <= PWDATA[7:0];
                    endcase
                end
                //SH 
                3'b001: begin
                    case (PADDR[1:0])
                        2'b00: bmem[PADDR[11:2]][15:0] <= PWDATA[15:0];
                        2'b10: bmem[PADDR[11:2]][31:16] <= PWDATA[15:0];
                    endcase
                end
                //SW
                3'b010: begin
                    bmem[PADDR[11:2]] <= PWDATA;  //SW
                end
            endcase
        end
    end

    //load 과정
    always_comb begin
        PRDATA = 32'b0;
        if (!(PSEL & PENABLE & PWRITE)) begin
            case (i_funct3)
                //LB
                3'b000: begin
                    case (PADDR[1:0])
                        2'b00:
                        PRDATA = {
                            {24{bmem[PADDR[11:2]][7]}}, bmem[PADDR[11:2]][7:0]
                        };
                        2'b01:
                        PRDATA = {
                            {24{bmem[PADDR[11:2]][15]}}, bmem[PADDR[11:2]][15:8]
                        };
                        2'b10:
                        PRDATA = {
                            {24{bmem[PADDR[11:2]][23]}},
                            bmem[PADDR[11:2]][23:16]
                        };
                        2'b11:
                        PRDATA = {
                            {24{bmem[PADDR[11:2]][31]}},
                            bmem[PADDR[11:2]][31:24]
                        };
                    endcase
                end
                //LH
                3'b001: begin
                    case (PADDR[1:0])
                        2'b00:
                        PRDATA = {
                            {16{bmem[PADDR[11:2]][15]}}, bmem[PADDR[11:2]][15:0]
                        };
                        2'b10:
                        PRDATA = {
                            {16{bmem[PADDR[11:2]][31]}},
                            bmem[PADDR[11:2]][31:16]
                        };
                    endcase
                end
                //LW
                3'b010: begin
                    PRDATA = bmem[PADDR[11:2]]; //data가 byte로 오니까 밑에 2bit 짜르기 
                end
                //LBU
                3'b100: begin
                    case (PADDR[1:0])
                        2'b00: PRDATA = {{24{1'b0}}, bmem[PADDR[11:2]][7:0]};
                        2'b01: PRDATA = {{24{1'b0}}, bmem[PADDR[11:2]][15:8]};
                        2'b10: PRDATA = {{24{1'b0}}, bmem[PADDR[11:2]][23:16]};
                        2'b11: PRDATA = {{24{1'b0}}, bmem[PADDR[11:2]][31:24]};
                    endcase
                end
                //LHU
                3'b101: begin
                    case (PADDR[1:0])
                        2'b00: PRDATA = {{16{1'b0}}, bmem[PADDR[11:2]][15:0]};
                        2'b10: PRDATA = {{16{1'b0}}, bmem[PADDR[11:2]][31:16]};
                    endcase
                end
            endcase
        end
    end


    //logic dwe;
    //assign dwe = PSEL && PENABLE && PWRITE;
//
    //data_mem(
    //    .clk(PCLK),
    //    .rst(PRESET),
    //    .dwe(dwe),
    //    .i_funct3(),
    //    .daddr(PADDR),
    //    .dwdata(PWDATA),
    //    .drdata(PRDATA)
    //);
//
    //typedef enum {
    //    IDLE,
    //    SETUP,
    //    ACCESS
    //} slave_state_e;
//
    //slave_state_e c_state, n_state;
//
    //always_ff @(posedge PCLK, posedge PRESET) begin
    //    if (PRESET) begin
    //        c_state <= IDLE;
    //    end else begin
    //        c_state <= n_state;
    //    end
    //end
//
    //always_comb begin
    //    case (c_state)
    //        IDLE: begin
    //            n_state = SETUP;
    //        end
    //        SETUP: begin
//
    //        end
    //        ACCESS: begin
//
    //        end
    //    endcase
    //end

endmodule
