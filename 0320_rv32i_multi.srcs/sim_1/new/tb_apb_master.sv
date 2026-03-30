`timescale 1ns / 1ps

module tb_apb_master();

    logic PCLK, PRESET;
    logic [31:0] Addr, Wdata, Rdata, PADDR, PWDATA;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3;
    logic WREQ, RREQ, Ready, PENABLE, PWRITE;
    logic PSEL0, PSEL1, PSEL2, PSEL3;
    logic PREADY0, PREADY1, PREADY2, PREADY3;
    
    APB_Master dut (
        .PCLK(PCLK),
        .PRESET(PRESET),
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
        //.PSEL1(PSEL1),    //GPO
        //.PSEL2(PSEL2),    //GPI
        .PSEL1(PSEL1),    //GPIO
        .PSEL2(PSEL2),    //FND
        .PSEL3(PSEL3),    //UART
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
        .PREADY3(PREADY3)   // from UART 
    );

    always #5 PCLK = ~PCLK;

    initial begin
        //초기화 : x 상태 방지 
        PCLK = 0;
        PRESET = 1;
        //WREQ = 0;
        //RREQ = 0;
        //Addr = 0;
        //Wdata = 0;
//
        ////Slave 응답 신호 초기화
        //PREADY0 = 0;
        //PRDATA0 = 0;
        //PREADY1 = 0;
        //PRDATA1 = 0;
        //PREADY2 = 0;
        //PRDATA2 = 0;
        //PREADY3 = 0;
        //PRDATA3 = 0;


        @(negedge PCLK);
        @(negedge PCLK);
        PRESET = 0;
        // ========================================================
        // Case 1: RAM (PSEL0) - No wait state
        // ========================================================
        //RAM Write Test, 0x1000_0000, no wait state 
        $display("--- Case 1-1: RAM Write Start ---");
        @(posedge PCLK);
        #1;
        WREQ = 1'b1;
        Addr = 32'h1000_0000;
        Wdata = 32'h0000_0077;

        @(PSEL0 == 1'b1 && PENABLE == 1'b1);
            PREADY0 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY0 = 1'b0;
        WREQ = 1'b0;

        $display("--- Case 1-2: RAM Read Start ---");
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h1000_0000;
        
        @(PSEL0 == 1'b1 && PENABLE == 1'b1);
        PREADY0 = 1'b1;
        PRDATA0 = 32'h0000_0077;
        @(posedge PCLK);
        #1;
        PREADY0 = 1'b0;
        RREQ = 1'b0;

        // ========================================================
        // Case 2: GPIO (PSEL1) - No wait state
        // ========================================================
        //UART Read Test, 0x2000_4000, with waiting for 2cycle 
        $display("--- Case 2-1: GPIO Write Start (Mode Setting) ---");
        @(posedge PCLK);
        #1;
        WREQ = 1'b1;
        Addr = 32'h2000_0000;
        Wdata = 32'hFF00FF00;

        @(PSEL1 == 1'b1 && PENABLE == 1'b1);
        PREADY1 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY1 = 1'b0;
        WREQ = 1'b0;

        $display("--- Case 2-2: GPIO Read Start (Pin Status) ---");
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h2000_0000;
        
        @(PSEL1 == 1'b1 && PENABLE == 1'b1);
        PREADY1 = 1'b1;
        PRDATA1 = 32'h0000_00FF;
        @(posedge PCLK);
        #1;
        PREADY1 = 1'b0;
        RREQ = 1'b0;

        // ========================================================
        // Case 3: FND (PSEL2) - 1 Cycle wait state
        // ========================================================
        //UART Read Test, 0x2000_4000, with waiting for 2cycle 
        $display("--- Case 3-1: FND Write Start ---");
        @(posedge PCLK);
        #1;
        WREQ = 1'b1;
        Addr = 32'h2000_1000;
        Wdata = 32'h0000_6331;

        @(PSEL2 == 1'b1 && PENABLE == 1'b1);
        @(posedge PCLK);
        #1;
        PREADY2 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY2 = 1'b0;
        WREQ = 1'b0;
        


        $display("--- Case 3-2: FND Read Start ---");
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h2000_1000;

        @(PSEL2 == 1'b1 && PENABLE == 1'b1);
        @(posedge PCLK);
        #1;
            PREADY2 = 1'b1;
            PRDATA2 = 32'h0000_6824; // 읽은 데이터
        @(posedge PCLK);
        #1;
        PREADY2 = 1'b0;
        RREQ = 1'b0;
        

        // ========================================================
        // Case 4: UART (PSEL3) - 2 Cycle wait state
        // ========================================================
        //UART Read Test, 0x2000_4000, with waiting for 2cycle 
        $display("--- Case 4-1: UART Write Start (Tx Data) ---");
        @(posedge PCLK);
        #1;
        WREQ = 1'b1;
        Addr = 32'h2000_2000;
        Wdata = 32'h0000_6331;

        @(PSEL3 == 1'b1 && PENABLE == 1'b1);
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
        PREADY3 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY3 = 1'b0;
        WREQ = 1'b0;


        $display("--- Case 4-2: UART Read Start (Rx Data) ---");
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h2000_2000;

        @(PSEL3 == 1'b1 && PENABLE == 1'b1);
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
            PREADY3 = 1'b1;
            PRDATA3 = 32'h0000_006331; // 읽은 데이터
        @(posedge PCLK);
        #1;
        PREADY3 = 1'b0;
        RREQ = 1'b0;

        @(posedge PCLK);
        @(posedge PCLK);

        $stop;

    end


endmodule
