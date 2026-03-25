`timescale 1ns / 1ps

module tb_apb_master();

    logic PCLK, PRESETn;
    logic [31:0] Addr, Wdata, Rdata, PADDR, PWDATA;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3, PRDATA4, PRDATA5;
    logic WREQ, RREQ, Ready, PENABLE, PWRITE;
    logic PSEL0, PSEL1, PSEL2, PSEL3, PSEL4, PSEL5;
    logic PREADY0, PREADY1, PREADY2, PREADY3, PREADY4, PREADY5;
    
    APB_Master dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .Addr(Addr),   // from cpu
        .Wdata(Wdata),  // from cpu
        .WREQ(WREQ),   // from cpu, Write request, signal cpu : dwe
        .RREQ(RREQ),   // from cpu, Read request, signal cpu : dre 
        .Rdata(Rdata),
        .Ready(Ready),
        .PADDR(PADDR),    // need register
        .PWDATA(PWDATA),   // need register
        .PENABLE(PENABLE),  // logic 으로 출력 나가야 함 
        .PWRITE(PWRITE),   // logic으로 출력 나가야 함 
        .PSEL0(PSEL0),    //RAM
        .PSEL1(PSEL1),    //GPO
        .PSEL2(PSEL2),    //GPI
        .PSEL3(PSEL3),    //GPIO
        .PSEL4(PSEL4),    //FND
        .PSEL5(PSEL5),    //UART
        .PRDATA0(PRDATA0),  // from RAM
        .PRDATA1(PRDATA1),  // from GPO //왜 받을게 없어?
        .PRDATA2(PRDATA2),  // from GPI
        .PRDATA3(PRDATA3),  // from GPIO
        .PRDATA4(PRDATA4),  // from FND //stataus를 읽을 수도 있으니까
        .PRDATA5(PRDATA5),  // from UART
        .PREADY0(PREADY0),  // from RAM
        .PREADY1(PREADY1),  // from GPO
        .PREADY2(PREADY2),  // from GPI
        .PREADY3(PREADY3),  // from GPIO
        .PREADY4(PREADY4),  // from FND 
        .PREADY5(PREADY5)   // from UART 
    );

    always #5 PCLK = ~PCLK;

    initial begin
        PCLK = 0;
        PRESETn = 0;

        @(negedge PCLK);
        @(negedge PCLK);
        PRESETn = 1;

        //RAM Write Test, 0x1000_0000
        @(posedge PCLK);
        #1;
        WREQ = 1'b1;
        Addr = 32'h1000_0000;
        Wdata = 32'h0000_0041;

        // @(posedge PCLK);
        // #1;
        @(PSEL0 && PENABLE);
            PREADY0 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY0 = 1'b0;
        WREQ = 1'b0;

        //UART Read Test, 0x2000_4000, with waiting for 2cycle 
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h2000_4000;

        // @(posedge PCLK);
        // #1;
        @(PSEL5 && PENABLE);
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
            PREADY5 = 1'b1;
            PRDATA5 = 32'h0000_0041;
        @(posedge PCLK);
        #1;
        PREADY5 = 1'b0;
        RREQ = 1'b0;

        @(posedge PCLK);
        @(posedge PCLK);


        $stop;

    end


endmodule
