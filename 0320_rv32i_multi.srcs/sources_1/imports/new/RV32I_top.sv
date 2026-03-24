`timescale 1ns / 1ps

module rv32I_mcu (
    input clk,
    input rst
);
    logic bus_wreq, bus_rreq, bus_ready;
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;

    instruction_mem U_INSTRUCTION_MEM (.*);

    RV32I_cpu U_RV32I (
        .*,
        .o_funct3 (o_funct3) 
    );

    APB_Master U_APB_MASTER (
        .PCLK(clk),  // 반클럭 차이 나겠지만 괜찮음 
        .PRESETn(rst),
        .Addr(bus_addr),  // from cpu
        .Wdata(bus_wdata),  // from cpu
        .WREQ(bus_wreq),  // from cpu, Write request, signal cpu : dwe
        .RREQ(bus_rreq),  // from cpu, Read request, signal cpu : dre 
        .Rdata(bus_rdata),
        .Ready(bus_ready)
        //.PADDR(),  // need register
        //.PWDATA(),  // need register
        //.PENABLE(),  // logic 으로 출력 나가야 함 
        //.PWRITE(),  // logic으로 출력 나가야 함 
        //.PSEL0(),  //RAM
        //.PSEL1(),  //GPO
        //.PSEL2(),  //GPI
        //.PSEL3(),  //GPIO
        //.PSEL4(),  //FND
        //.PSEL5(),  //UART
        //.PRDATA0(),  // from RAM
        //.PRDATA1(),  // from GPO //왜 받을게 없어?
        //.PRDATA2(),  // from GPI
        //.PRDATA3(),  // from GPIO
        //.PRDATA4(),  // from FND //stataus를 읽을 수도 있으니까
        //.PRDATA5(),  // from UART
        //.PREADY0(),  // from RAM
        //.PREADY1(),  // from GPO
        //.PREADY2(),  // from GPI
        //.PREADY3(),  // from GPIO
        //.PREADY4(),  // from FND 
        //.PREADY5()  // from UART  
    );

    //data_mem U_DATA_MEM (
    //    .*,
    //    .i_funct3(o_funct3)
    //);


endmodule
