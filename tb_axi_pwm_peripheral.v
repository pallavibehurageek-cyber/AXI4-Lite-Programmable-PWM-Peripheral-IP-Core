`timescale 1ns/1ps

module tb_axi4_lite_pwm;

    reg         ACLK = 0;
    reg         ARESETN = 0;

    reg  [3:0]  AWADDR;
    reg         AWVALID;
    wire        AWREADY;

    reg  [31:0] WDATA;
    reg  [3:0]  WSTRB;
    reg         WVALID;
    wire        WREADY;

    wire [1:0]  BRESP;
    wire        BVALID;
    reg         BREADY;

    reg  [3:0]  ARADDR;
    reg         ARVALID;
    wire        ARREADY;

    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    reg         RREADY;

    wire        PWM_OUT;
    wire        PWM_IRQ;

    axi4_lite_pwm dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY),
        .ARADDR(ARADDR), .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY),
        .PWM_OUT(PWM_OUT), .PWM_IRQ(PWM_IRQ)
    );

    // 100 MHz clock
    always #5 ACLK = ~ACLK;

    // ---------------- AXI write task ----------------
    task axi_write(input [3:0] addr, input [31:0] data);
    begin
        @(posedge ACLK);
        AWADDR  = addr;
        AWVALID = 1;
        WDATA   = data;
        WSTRB   = 4'hF;
        WVALID  = 1;
        BREADY  = 1;

        wait (AWREADY);
        @(posedge ACLK);
        AWVALID = 0;

        wait (WREADY);
        @(posedge ACLK);
        WVALID = 0;

        wait (BVALID);
        @(posedge ACLK);
        BREADY = 0;
    end
    endtask

    // ---------------- AXI read task ----------------
    task axi_read(input [3:0] addr);
    begin
        @(posedge ACLK);
        ARADDR  = addr;
        ARVALID = 1;
        RREADY  = 1;

        wait (ARREADY);
        @(posedge ACLK);
        ARVALID = 0;

        wait (RVALID);
        $display("[%0t] READ  addr=0x%0h  data=0x%0h", $time, addr, RDATA);
        @(posedge ACLK);
        RREADY = 0;
    end
    endtask

    initial begin
        // dump waveform
        $dumpfile("axi_pwm.vcd");
        $dumpvars(0, tb_axi4_lite_pwm);

        AWVALID = 0; WVALID = 0; BREADY = 0;
        ARVALID = 0; RREADY = 0;
        AWADDR = 0; WDATA = 0; WSTRB = 0; ARADDR = 0;

        // reset pulse
        ARESETN = 0;
        repeat (5) @(posedge ACLK);
        ARESETN = 1;

        $display("---- Configure PERIOD = 40 cycles ----");
        axi_write(4'hC, 32'd40);

        $display("---- Configure DUTY = 64 (25%% of 255) ----");
        axi_write(4'h4, 32'd64);

        $display("---- Enable PWM in fixed-duty mode (CTRL = enable, mode=0) ----");
        axi_write(4'h0, 32'b01);

        // let it run a few PWM periods so PWM_OUT toggles visibly
        repeat (150) @(posedge ACLK);

        $display("---- Read back CTRL, DUTY, PERIOD, STATUS ----");
        axi_read(4'h0);
        axi_read(4'h4);
        axi_read(4'hC);
        axi_read(4'h8);   // should show overflow_flag=1 by now (IRQ fired)

        $display("---- Clear overflow flag (write 1 to bit1 of STATUS) ----");
        axi_write(4'h8, 32'b10);
        axi_read(4'h8);

        $display("---- Switch to breathing mode (CTRL = enable, mode=1) ----");
        axi_write(4'h0, 32'b11);

        // run long enough to see breathing duty ramp
        repeat (400) @(posedge ACLK);

        $display("---- Simulation complete ----");
        $finish;
    end

endmodule
