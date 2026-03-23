`timescale 1ns / 1ps

module data_mem (
    input               clk,
    input               rst,
    input               dwe,
    input        [ 2:0] i_funct3,
    input        [31:0] daddr,
    input        [31:0] dwdata,
    output logic [31:0] drdata
);

     logic [31:0] dmem[0:255];  //word로 word address 

    //store 과정 
    always_ff @(posedge clk) begin
        if (dwe) begin
            case (i_funct3)
                //SB
                3'b000: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[31:2]][7:0] <= dwdata[7:0];
                        2'b01: dmem[daddr[31:2]][15:8] <= dwdata[7:0];
                        2'b10: dmem[daddr[31:2]][23:16] <= dwdata[7:0];
                        2'b11: dmem[daddr[31:2]][31:24] <= dwdata[7:0];
                    endcase
                end
                //SH 
                3'b001: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[31:2]][15:0] <= dwdata[15:0];
                        2'b10: dmem[daddr[31:2]][31:16] <= dwdata[15:0];
                    endcase
                end
                //SW
                3'b010: begin
                    dmem[daddr[31:2]] <= dwdata;  //SW
                end
            endcase
        end
    end

    //load 과정
    always_comb begin
        drdata = 32'b0;
        if (!dwe) begin
            case (i_funct3)
                //LB
                3'b000: begin
                    case (daddr[1:0])
                        2'b00: drdata = {{24{dmem[daddr[31:2]][7]}}, dmem[daddr[31:2]][7:0]};
                        2'b01: drdata = {{24{dmem[daddr[31:2]][15]}}, dmem[daddr[31:2]][15:8]};
                        2'b10: drdata = {{24{dmem[daddr[31:2]][23]}}, dmem[daddr[31:2]][23:16]};
                        2'b11: drdata = {{24{dmem[daddr[31:2]][31]}}, dmem[daddr[31:2]][31:24]};
                    endcase
                end
                //LH
                3'b001: begin
                    case (daddr[1:0])
                        2'b00: drdata = {{16{dmem[daddr[31:2]][15]}}, dmem[daddr[31:2]][15:0]};
                        2'b10: drdata = {{16{dmem[daddr[31:2]][31]}}, dmem[daddr[31:2]][31:16]};
                    endcase
                end
                //LW
                3'b010: begin
                    drdata = dmem[daddr[31:2]]; //data가 byte로 오니까 밑에 2bit 짜르기 
                end
                //LBU
                3'b100: begin
                    case (daddr[1:0])
                        2'b00: drdata = {{24{1'b0}}, dmem[daddr[31:2]][7:0]};
                        2'b01: drdata = {{24{1'b0}}, dmem[daddr[31:2]][15:8]};
                        2'b10: drdata = {{24{1'b0}}, dmem[daddr[31:2]][23:16]};
                        2'b11: drdata = {{24{1'b0}}, dmem[daddr[31:2]][31:24]};
                    endcase
                end
                //LHU
                3'b101: begin
                    case (daddr[1:0])
                        2'b00: drdata = {{16{1'b0}}, dmem[daddr[31:2]][15:0]};
                        2'b10: drdata = {{16{1'b0}}, dmem[daddr[31:2]][31:16]};
                    endcase
                end
            endcase
        end
    end

endmodule