`timescale 1ns / 1ps

module APB_UART (
    input         PCLK,
    input         PRESET,
    input  [31:0] PADDR,
    input  [31:0] PWDATA,
    input         PENABLE,
    input         PWRITE,
    input         PSEL,
    input         uart_rx,
    output        uart_tx,
    output [31:0] PRDATA,
    output        PREADY

);

    //tx_data는 DATA REG를 통해 PWDATA를 받음
    //tx는 CTL를 통해 tx_start 신호 받음
    //status reg는 rx_done과 tx_busy 신호 받음
    //PRDATA는 DATA REG를 통해 받음 
    //BAUD RATE는 2bit로 3가지 경우 선택 -> b_tick으로 주기
    //9600, (9600*2 = 19200), (9600*12 = 115200) 

    //UART_BAUD_REG는 b_tick을 받아서 곱하기 해서 선택해서 나가도록 해야하는데

    //tx_busy와 rx_done 같은 것은 내부에서 전달되는 신호이기 때문에, 내부 선으로 선언하기 
    //rx_data와 tx_data의 경우도 REG가 대신하기 때문에 외부 포트로 뽑을 필요 없음 


    localparam [11:0] UART_CTL_ADDR = 12'h000;  //tx_start
    localparam [11:0] UART_BAUD_ADDR = 12'h004;  //2bit 할당 
    localparam [11:0] UART_STATUS_ADDR = 12'h008;  //rx_done, tx_busy
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00c;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;

    logic [7:0] UART_CTL_REG, UART_STATUS_REG;
    logic [15:0] UART_BAUD_REG;
    logic [ 7:0] UART_TX_DATA_REG;

    logic tx_busy, tx_start, b_tick;

    logic [7:0] rx_data;
    logic       rx_done;
    logic       rx_done_flag;
    logic [7:0] UART_RX_DATA_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign UART_STATUS_REG = {rx_done_flag, 6'b000000, tx_busy};

    //extantion vs padding??
    assign PRDATA = (PADDR[11:0] == UART_CTL_ADDR)  ? {24'h0000, UART_CTL_REG} : 
                    (PADDR[11:0] == UART_BAUD_ADDR) ? {16'h0000, UART_BAUD_REG} : 
                    (PADDR[11:0] == UART_STATUS_ADDR) ? {24'h0000, UART_STATUS_REG} : 
                    (PADDR[11:0] == UART_TX_DATA_ADDR) ? {24'h0000, UART_TX_DATA_REG} : 
                    (PADDR[11:0] == UART_RX_DATA_ADDR) ? {24'h0000, UART_RX_DATA_REG} : 
                    32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            UART_CTL_REG <= 8'h00;
            UART_BAUD_REG <= 16'h0000;
            UART_TX_DATA_REG <= 8'h00;
            UART_RX_DATA_REG <= 8'h00;
            tx_start <= 1'b0;
            rx_done_flag <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    UART_CTL_ADDR: begin
                        UART_CTL_REG <= PWDATA[7:0];
                        if (PWDATA[0]) tx_start <= 1'b1;
                    end
                    UART_BAUD_ADDR: UART_BAUD_REG <= PWDATA[15:0];
                    UART_TX_DATA_ADDR: UART_TX_DATA_REG <= PWDATA[7:0];
                    //만약 CPU가 통신 속도를 설정(UART_BAUD_REG)하거나, 
                    //전송 시작 명령을 내리려면(UART_CTL_REG)
                    //해당 레지스터들도 APB 버스를 통해 값을 쓸 수 있도록 case 문에 추가
                endcase
            end
            if (rx_done) begin
                UART_RX_DATA_REG <= rx_data;
                rx_done_flag <= 1'b1;
            end
            else if (PSEL && PENABLE && !PWRITE && (PADDR[11:0] == UART_RX_DATA_ADDR)) begin
                rx_done_flag <= 1'b0;
            end
        end
    end


    uart_tx U_UART_TX (
        .clk(PCLK),
        .rst(PRESET),
        .tx_start(tx_start),
        .b_tick(b_tick),
        .tx_data(UART_TX_DATA_REG),
        .tx_busy(tx_busy),
        .tx_done(),  //필요 없음 
        .uart_tx(uart_tx)
    );

    uart_rx U_UART_RX (
        .clk(PCLK),
        .rst(PRESET),
        .rx(uart_rx),
        .b_tick(b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    baud_tick U_BAUD_TICK (
        // 주기 : 1/9600
        .clk(PCLK),
        .rst(PRESET),
        .tick_sel(UART_BAUD_REG[1:0]),
        .b_tick(b_tick)
    );

endmodule
