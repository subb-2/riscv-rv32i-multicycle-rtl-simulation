`timescale 1ns / 1ps

module rv32I_mcu (
    input         clk,
    input         rst,
    input  [7:0] GPI,
    input         uart_rx,
    output        uart_tx,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data,
    output [7:0] GPO,
    inout  [15:0] GPIO 
);
//git test 
    logic bus_wreq, bus_rreq, bus_ready;
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic [31:0] PADDR, PWDATA;
    logic PENABLE, PWRITE;
    logic PSEL0, PSEL1, PSEL2, PSEL3;
    logic PREADY0, PREADY1, PREADY2, PREADY3;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3;

    instruction_mem U_INSTRUCTION_MEM (.*);

    RV32I_cpu U_RV32I (
        .*,
        .o_funct3(o_funct3)
    );

    APB_Master U_APB_MASTER (
        .PCLK(clk),  // 반클럭 차이 나겠지만 괜찮음 
        .PRESET(rst),
        .Addr(bus_addr),  // from cpu
        .Wdata(bus_wdata),  // from cpu
        .WREQ(bus_wreq),  // from cpu, Write request, signal cpu : dwe
        .RREQ(bus_rreq),  // from cpu, Read request, signal cpu : dre 
        .Rdata(bus_rdata),
        .Ready(bus_ready),
        .PADDR(PADDR),  // need register
        .PWDATA(PWDATA),  // need register
        .PENABLE(PENABLE),  // logic 으로 출력 나가야 함 
        .PWRITE(PWRITE),  // logic으로 출력 나가야 함 
        //from APB SLAVE
        .PSEL0(PSEL0),  //RAM
        //.PSEL1(PSEL1),  //GPO
        //.PSEL2(PSEL2),  //GPI
        .PSEL1(PSEL1),  //GPIO
        .PSEL2(PSEL2),  //FND
        .PSEL3(PSEL3),  //UART
        .PRDATA0(PRDATA0),  // from RAM
        //.PRDATA1(PRDATA1),  // from GPO //왜 받을게 없어?
        //.PRDATA2(PRDATA2),  // from GPI
        .PRDATA1(PRDATA1),  // from GPIO
        .PRDATA2(PRDATA2),  // from FND //stataus를 읽을 수도 있으니까
        .PRDATA3(PRDATA3),  // from UART
        .PREADY0(PREADY0),  // from RAM
        //.PREADY1(PREADY1),  // from GPO
        //.PREADY2(PREADY2),  // from GPI
        .PREADY1(PREADY1),  // from GPIO
        .PREADY2(PREADY2),  // from FND 
        .PREADY3(PREADY3)  // from UART  
    );

    BRAM U_BRAM (
        .*,
        .PCLK(clk),
        .PSEL(PSEL0),
        .PRDATA(PRDATA0),
        .PREADY(PREADY0),
        .i_funct3(o_funct3)
    );

    //GPO_Slave U_APB_GPO (
    //    .PCLK(clk),
    //    .PRESET(rst),
    //    .PADDR(PADDR),
    //    .PWDATA(PWDATA),
    //    .PENABLE(PENABLE),
    //    .PWRITE(PWRITE),
    //    .PSEL(PSEL1),
    //    .PRDATA(PRDATA1),
    //    .PREADY(PREADY1),
    //    .GPO_OUT(GPO)
    //);

    //GPI_Slave U_APB_GPI (
    //    .PCLK(clk),
    //    .PRESET(rst),
    //    .PADDR(PADDR),
    //    .PWDATA(PWDATA),
    //    .PWRITE(PWRITE),
    //    .PENABLE(PENABLE),
    //    .PSEL(PSEL2),
    //    .GPI_IN(GPI),
    //    .PRDATA(PRDATA2),
    //    .PREADY(PREADY2)
    //);

    APB_GPIO U_APB_GPIO (
        .PCLK(clk),
        .PRESET(rst),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PSEL(PSEL1),
        .PRDATA(PRDATA1),
        .PREADY(PREADY1),
        .GPIO(GPIO)
    );

    APB_FND U_APB_FND (
        .PCLK(clk),
        .PRESET(rst),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PSEL(PSEL2),
        .PRDATA(PRDATA2),
        .PREADY(PREADY2),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    APB_UART U_APB_UART (
        .PCLK(clk),
        .PRESET(rst),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PSEL(PSEL3),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .PRDATA(PRDATA3),
        .PREADY(PREADY3)

    );


    //data_mem U_DATA_MEM (
    //    .*,
    //    .i_funct3(o_funct3)
    //);


endmodule
