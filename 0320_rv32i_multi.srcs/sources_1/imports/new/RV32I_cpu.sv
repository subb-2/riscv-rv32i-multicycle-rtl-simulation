`timescale 1ns / 1ps
`include "define.vh"

module RV32I_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output        dwe,
    output [ 2:0] o_funct3,
    output [31:0] daddr,
    output [31:0] dwdata 
);

    logic pc_en, rf_we, alu_src, branch, jal, jalr;
    logic [2:0] rfwd_src;
    logic [31:0] alu_result, alu_pc_out;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .opcode     (instr_data[6:0]),
        .pc_en      (pc_en),
        .rf_we      (rf_we),
        .alu_src    (alu_src),
        .alu_control(alu_control),
        .rfwd_src   (rfwd_src),
        .o_funct3   (o_funct3),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .dwe        (dwe)
    );

    rv32i_datapath U_DATAPATH (.*);


endmodule



module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       pc_en,
    output logic       rf_we,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic       dwe
);

    typedef enum logic [2:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        //posedge rst 하는 이유는 버튼을 rst로 이용하기 때문에,
        //버튼은 상승, 하강 모두 상관 없음 
        //칩의 환경이 어떨지 모르기 때문에, edge 기준은 하라는 대로 하면 됨
        //대신 모두 맞춰서 써야함 아니면 타이밍 오차 생김 
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    //next CL 
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `I_TYPE, `LUI_TYPE, `AUIPC_TYPE, `J_TYPE, `JL_TYPE: begin
                        n_state = WB;
                    end 
                    `B_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE, `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `IL_TYPE: begin
                        n_state = WB;
                    end
                    `S_TYPE: begin
                        n_state = FETCH;
                    end
                endcase
            end
            WB: begin
                n_state = FETCH;
            end
        endcase
    end

    //output CL 
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        alu_src     = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 3'd0;
        o_funct3    = 3'b000;
        dwe         = 1'b0;
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin

            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) begin
                            alu_control = {funct7[5], funct3};  //SRL, SRA
                        end else begin
                            alu_control = {1'b0, funct3};
                        end
                    end
                    `B_TYPE: begin
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                        branch      = 1'b1;
                    end
                    `S_TYPE: begin
                        alu_control = 4'b0000;
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `LUI_TYPE: begin

                    end
                    `AUIPC_TYPE: begin

                    end
                    `J_TYPE, `JL_TYPE: begin
                        jal = 1'b1;
                        if (opcode == `JL_TYPE) jalr = 1'b1;
                        else jalr = 1'b0;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        o_funct3 = funct3;
                        dwe      = 1'b1;
                    end
                    `IL_TYPE: begin
                        o_funct3 = funct3;
                        dwe      = 1'b0;
                    end
                endcase
            end
            WB: begin
                case (opcode)
                    `R_TYPE: begin  // R-type, to write register file,
                        rf_we    = 1'b1;
                        rfwd_src = 3'd0;
                    end
                    `B_TYPE: begin  // R-type, to write register file,
                        rf_we    = 1'b0;
                        rfwd_src = 3'd0;
                    end
                    `S_TYPE: begin
                        rf_we = 1'b0;
                    end
                    `IL_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'd1;
                    end
                    `I_TYPE: begin
                        rf_we = 1'b1;
                        rfwd_src = 3'd0;
                    end
                    `LUI_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'd2;
                    end
                    `AUIPC_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'd3;
                    end
                    `J_TYPE, `JL_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'd4;
                    end
                endcase
            end
        endcase
    end

    //    EXE_R,
    //    EXE_I,
    //    EXE_S,
    //    EXE_B,
    //    EXE_L,
    //    EXE_J,
    //    EXE_JL,
    //    EXE_U,
    //    EXE_UA,
    //    MEM_S,
    //    MEM_L,

    //    always_comb begin
    //        rf_we       = 1'b0;
    //        alu_src     = 1'b0;
    //        alu_control = 4'b0000;
    //        rfwd_src    = 3'd0;
    //        o_funct3    = 3'b000;
    //        branch      = 1'b0;
    //        jal         = 1'b0;
    //        jalr        = 1'b0;
    //        dwe         = 1'b0;
    //        case (opcode)
    //            `R_TYPE: begin // R-type, to write register file, alu_control == {funct7[5], funct3}
    //                rf_we       = 1'b1;
    //                alu_src     = 1'b0;
    //                alu_control = {funct7[5], funct3};
    //                rfwd_src    = 3'd0;
    //                o_funct3    = 3'b000;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b0;
    //            end
    //            `B_TYPE: begin // R-type, to write register file, alu_control == {funct7[5], funct3}
    //                rf_we       = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = {1'b0, funct3};
    //                rfwd_src    = 3'd0;
    //                o_funct3    = 3'b000;
    //                branch      = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b0;
    //            end
    //            `S_TYPE: begin
    //                rf_we       = 1'b0;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'd0;
    //                o_funct3    = funct3;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b1;
    //            end
    //            `IL_TYPE: begin
    //                rf_we       = 1'b1;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'd1;
    //                o_funct3    = funct3;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b0;
    //            end
    //            `I_TYPE: begin
    //                rf_we   = 1'b1;
    //                alu_src = 1'b1;
    //                if (funct3 == 3'b101) begin
    //                    alu_control = {funct7[5], funct3};
    //                end else begin
    //                    alu_control = {1'b0, funct3};
    //                end
    //                rfwd_src = 3'd0;
    //                o_funct3 = funct3;
    //                branch   = 1'b0;
    //                jal      = 1'b0;
    //                jalr     = 1'b0;
    //                dwe      = 1'b0;
    //            end
    //            `LUI_TYPE: begin
    //                rf_we       = 1'b1;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'd2;
    //                o_funct3    = 3'b000;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b0;
    //            end
    //            `AUIPC_TYPE: begin
    //                rf_we       = 1'b1;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'd3;
    //                o_funct3    = 3'b000;
    //                branch      = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                dwe         = 1'b0;
    //            end
    //            `J_TYPE, `JL_TYPE: begin
    //                rf_we       = 1'b1;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'd4;
    //                o_funct3    = 3'b000;  //이것도 funct3 아니지 않나?
    //                branch      = 1'b0;
    //                jal         = 1'b1;
    //                if (opcode == `JL_TYPE) jalr = 1'b1;
    //                else jalr = 1'b0;
    //                dwe = 1'b0;
    //            end
    //        endcase
    //    end

endmodule