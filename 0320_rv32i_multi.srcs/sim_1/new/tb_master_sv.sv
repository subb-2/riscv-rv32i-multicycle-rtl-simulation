`timescale 1ns / 1ps

interface master_interface (
    input logic PCLK
);
    logic       rst;
    logic [7:0] wdata;
    logic       push;
    logic       pop;
    logic       full;
    logic       empty;
    logic [7:0] rdata;
endinterface  //master_interface

module tb_master_sv ();

    logic PCLK;

    fifo_interface fifo_if (PCLK);
    environment env;

    APB_Master dut (
        PCLK(PCLK),
        PRESET(),
        Addr(),  // from cpu
        Wdata(),  // from cpu
        WREQ(),  // from cpu, Write request, signal cpu : dwe
        RREQ(),  // from cpu, Read request, signal cpu : dre 
        SLVERR(),
        Rdata(),
        Ready(),
        PADDR(),  // need register
        PWDATA(),  // need register
        PENABLE(),  // logic 으로 출력 나가야 함 
        PWRITE(),  // logic으로 출력 나가야 함 
        PSEL0(),  //RAM
        PSEL1(),  //GPO
        PSEL2(),  //GPI
        PSEL3(),  //GPIO
        PSEL4(),  //FND
        PSEL5(),  //UART
        PRDATA0(),  // from RAM
        PRDATA1(),  // from GPO //왜 받을게 없어?
        PRDATA2(),  // from GPI
        PRDATA3(),  // from GPIO
        PRDATA4(),  // from FND //stataus를 읽을 수도 있으니까
        PRDATA5(),  // from UART
        PREADY0(),  // from RAM
        PREADY1(),  // from GPO
        PREADY2(),  // from GPI
        PREADY3(),  // from GPIO
        PREADY4(),  // from FND 
        PREADY5()  // from UART 
    );

    always #5 PCLK = ~PCLK;

    initial begin
        PCLK = 0;
        env = new(fifo_if);
        env.run();
    end


endmodule

//==================================================
//=============        참고           ===============
//==================================================


class transaction;

    rand bit [7:0] wdata;
    rand bit       push;
    rand bit       pop;

    logic          rst;
    logic          full;
    logic          empty;
    logic    [7:0] rdata;

    function void display(string name);
        $display(
            "%t : [%s] push = %h, wdata = %2h, full = %h, pop = %h, rdata = %2h, empty = %h",
            $time, name, push, wdata, full, pop, rdata, empty);
    endfunction  //new()
endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            //assert (tr.randomize())
            //else $display("[gen] tr.randomize() error!!!");
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask  //run

endclass  //generator

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task preset();
        fifo_if.rst   = 1;
        fifo_if.wdata = 0;
        fifo_if.push  = 0;
        fifo_if.pop   = 0;
        @(negedge fifo_if.clk);
        @(negedge fifo_if.clk);
        fifo_if.rst = 0;
        @(negedge fifo_if.clk);
        //tr.display("mon_preset");
        //add assertion 
    endtask  //preset

    task push();
        //interface 해주기
        fifo_if.push  = tr.push;
        fifo_if.wdata = tr.wdata;
        fifo_if.pop   = tr.pop;  //push만 하고 싶을 때를 위해 제작 
    endtask  //push

    task pop();
        fifo_if.push  = tr.push;
        fifo_if.wdata = tr.wdata;
        fifo_if.pop   = tr.pop;
    endtask  //pop

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge fifo_if.clk);
            #1;
            tr.display("drv");
            if (tr.push) begin
                push();
            end else begin
                fifo_if.push = 0;
            end
            if (tr.pop) begin
                pop();
            end else begin
                fifo_if.pop = 0;
            end
            //fifo_if.wdata = tr.wdata;
            //fifo_if.push  = tr.push;
            //fifo_if.pop   = tr.pop;
        end
    endtask  //run


endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task run();
        forever begin
            tr = new;
            @(negedge fifo_if.clk);
            tr.push  = fifo_if.push;
            tr.pop   = fifo_if.pop;
            tr.wdata = fifo_if.wdata;
            tr.rdata = fifo_if.rdata;
            tr.full  = fifo_if.full;
            tr.empty = fifo_if.empty;
            tr.display("mon");
            mon2scb_mbox.put(tr);
        end
    endtask  //run

endclass  //monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    //queue 
    logic [7:0] fifo_queue[$:16];  //size 지정 안하면 무한대 
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");
            // push : 데이터 들어가는 것 판별 불가 
            if (tr.push & (!tr.full)) begin
                fifo_queue.push_front(tr.wdata);
            end
            // pop : data나옴 : pop할 때 판별 
            if (tr.pop & (!tr.empty)) begin
                //pass/fail
                compare_data = fifo_queue.pop_back();
                if (compare_data == tr.rdata) begin
                    $display("pass");
                end else begin
                    $display("fail");
                end
            end
            ->gen_next_ev;
        end
    endtask  //run

endclass  //scorboard

class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;

    function new(virtual fifo_interface fifo_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;

        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, fifo_if);
        mon = new(mon2scb_mbox, fifo_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $stop;
    endtask  //

endclass  //environment

