`timescale 1ns / 1ps
`include "define.vh"

module RV32I_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [ 2:0] o_funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
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
        .ready      (bus_ready),
        .pc_en      (pc_en),              //for multi cycle Fetch : pc
        .rf_we      (rf_we),
        .alu_src    (alu_src),
        .alu_control(alu_control),
        .rfwd_src   (rfwd_src),
        .o_funct3   (o_funct3),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .dwe        (bus_wreq),
        .dre        (bus_rreq)
    );

    rv32i_datapath U_DATAPATH (
        .*
    );


endmodule



module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       rf_we,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic       dwe,
    output logic       dre
);

// ============================================================
// [DEBUG] Opcode 디버깅용 enum
// ============================================================
typedef enum logic [6:0] {
    DBG_R_TYPE   = `R_TYPE,
    DBG_I_TYPE   = `I_TYPE,
    DBG_S_TYPE   = `S_TYPE,
    DBG_B_TYPE   = `B_TYPE,
    DBG_IL_TYPE  = `IL_TYPE,
    DBG_LUI_TYPE = `LUI_TYPE,
    DBG_AUIPC_TYPE = `AUIPC_TYPE,
    DBG_J_TYPE   = `J_TYPE,
    DBG_JL_TYPE  = `JL_TYPE
} opcode_dbg_e;

// waveform에 띄울 신호
opcode_dbg_e dbg_opcode;

// casting
assign dbg_opcode = opcode_dbg_e'(opcode);

// ============================================================
// [DEBUG] ALU Control 디버깅용 enum (R/I 타입)
// ============================================================
typedef enum logic [3:0] {
    DBG_ADD  = 4'b0000,
    DBG_SUB  = 4'b1000,
    DBG_SLL  = 4'b0001,
    DBG_SLT  = 4'b0010,
    DBG_SLTU = 4'b0011,
    DBG_XOR  = 4'b0100,
    DBG_SRL  = 4'b0101,
    DBG_SRA  = 4'b1101,
    DBG_OR   = 4'b0110,
    DBG_AND  = 4'b0111
} alu_ctrl_dbg_e;

// B-type 전용 (겹침 방지)
typedef enum logic [3:0] {
    DBG_BEQ  = 4'b0000,
    DBG_BNE  = 4'b0001,
    DBG_BLT  = 4'b0100,
    DBG_BGE  = 4'b0101,
    DBG_BLTU = 4'b0110,
    DBG_BGEU = 4'b0111
} alu_ctrl_dbg_btype_e;

// waveform용 신호
alu_ctrl_dbg_e       dbg_alu_ctrl;
alu_ctrl_dbg_btype_e dbg_alu_ctrl_btype;

// casting
assign dbg_alu_ctrl       = alu_ctrl_dbg_e'(alu_control);
assign dbg_alu_ctrl_btype = alu_ctrl_dbg_btype_e'(alu_control);



    //control unit multi cycle stage 
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
                    `R_TYPE, `I_TYPE, `B_TYPE, `LUI_TYPE, `AUIPC_TYPE, `J_TYPE, `JL_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE, `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: begin
                        if (ready) begin
                            n_state = WB;
                        end
                        //n_state = WB;
                    end
                endcase
            end
            WB: begin
                n_state = FETCH;
                //if (ready) begin
                //    n_state = FETCH;
                //end
            end
        endcase
    end

    //output CL 
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        branch      = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 3'd0;
        o_funct3    = 3'b000;  //for S type, IL type
        dwe         = 1'b0;  //for S type 
        dre         = 1'b0;  // for IL type
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin

            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;  //next state FETCH 
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we   = 1'b1;
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) begin
                            alu_control = {funct7[5], funct3};  //SRL, SRA
                        end else begin
                            alu_control = {1'b0, funct3};
                        end
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr 
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  //add for dwaddr
                        rfwd_src    = 3'd1;
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
                        jal      = 1'b1;
                        rfwd_src = 3'd4;
                        if (opcode == `JL_TYPE) jalr = 1'b1;
                        else jalr = 1'b0;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                if(opcode == `IL_TYPE) begin 
                    dre = 1'b1;
                end else if (opcode == `S_TYPE) begin
                    dwe = 1'b1;
                end
            end
            WB: begin
                //IL type 
                rf_we    = 1'b1;
                rfwd_src = 3'b001;
                //dre      = 1'b1;
            end
        endcase
    end


endmodule
