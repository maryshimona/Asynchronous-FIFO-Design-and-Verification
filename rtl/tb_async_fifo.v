// =============================================================================
// Testbench  : tb_async_fifo
// DUT        : async_fifo (DATA_WIDTH=8, ADDR_WIDTH=4 → 16 entries)
//
// Test cases covered
//   TC0 - Power-on reset
//   TC1 - Basic sequential write then read
//   TC2 - FULL flag: fill FIFO completely, verify wfull asserts
//   TC3 - Write-while-full is ignored (no data corruption)
//   TC4 - EMPTY flag: drain FIFO completely, verify rempty asserts
//   TC5 - Read-while-empty is ignored
//   TC6 - Simultaneous write & read (different clock rates)
//   TC7 - Back-to-back burst: write 8, read 8, write 8, read 8
//   TC8 - Reset during operation
//
// FIX: All regs initialised at declaration + exp_queue zeroed
//      → eliminates red X lines in XSim waveform
// Simulation run time required : 50us  (type "run 50us" in TCL console)
// =============================================================================

`timescale 1ns / 1ps

module tb_async_fifo;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH      = 1 << ADDR_WIDTH;   // 16

    // =========================================================================
    // Clock periods (intentionally different to stress CDC)
    // =========================================================================
    parameter WCLK_PERIOD = 10;   // 100 MHz write clock
    parameter RCLK_PERIOD = 13;   //  ~77 MHz read clock (incommensurate)

    // =========================================================================
    // DUT port signals - ALL initialised at declaration → no X at time 0
    // =========================================================================
    reg                   wclk   = 1'b0;
    reg                   wrst_n = 1'b0;
    reg                   winc   = 1'b0;
    reg  [DATA_WIDTH-1:0] wdata  = {DATA_WIDTH{1'b0}};
    wire                  wfull;

    reg                   rclk   = 1'b0;
    reg                   rrst_n = 1'b0;
    reg                   rinc   = 1'b0;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  rempty;

    // =========================================================================
    // Scoreboard / tracking
    // =========================================================================
    integer wr_count   = 0;
    integer rd_count   = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // Expected-data queue - zeroed to remove X crosshatch from waveform array
    reg [DATA_WIDTH-1:0] exp_queue [0:255];
    integer              exp_wr = 0;
    integer              exp_rd = 0;

    integer init_i;
    initial begin
        for (init_i = 0; init_i < 256; init_i = init_i + 1)
            exp_queue[init_i] = 8'h00;
    end

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),

        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    // =========================================================================
    // Clock generation (initialised above so no X on clocks)
    // =========================================================================
    always #(WCLK_PERIOD/2) wclk = ~wclk;
    always #(RCLK_PERIOD/2) rclk = ~rclk;

    // =========================================================================
    // Read-side monitor: check data as it comes out
    // =========================================================================
    always @(posedge rclk) begin
        if (rinc && !rempty) begin
            if (exp_rd != exp_wr) begin
                if (rdata === exp_queue[exp_rd % 256]) begin
                    $display("[PASS] rd_count=%0d  expected=0x%02h  got=0x%02h",
                             rd_count, exp_queue[exp_rd % 256], rdata);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] rd_count=%0d  expected=0x%02h  got=0x%02h  <-- MISMATCH",
                             rd_count, exp_queue[exp_rd % 256], rdata);
                    fail_count = fail_count + 1;
                end
                exp_rd   = exp_rd + 1;
                rd_count = rd_count + 1;
            end
        end
    end

    // =========================================================================
    // Task : write one word (write clock domain)
    // =========================================================================
    task write_fifo;
        input [DATA_WIDTH-1:0] d;
        begin
            @(posedge wclk);
            #1;
            if (!wfull) begin
                winc  = 1'b1;
                wdata = d;
                exp_queue[exp_wr % 256] = d;
                exp_wr   = exp_wr + 1;
                wr_count = wr_count + 1;
                @(posedge wclk); #1;
                winc  = 1'b0;
            end else begin
                $display("[INFO] Write skipped - FIFO full (data=0x%02h)", d);
                winc = 1'b0;
            end
        end
    endtask

    // =========================================================================
    // Task : read one word (read clock domain)
    // =========================================================================
    task read_fifo;
        begin
            @(posedge rclk);
            #1;
            if (!rempty) begin
                rinc = 1'b1;
                @(posedge rclk); #1;
                rinc = 1'b0;
            end else begin
                $display("[INFO] Read skipped - FIFO empty");
                rinc = 1'b0;
            end
        end
    endtask

    // =========================================================================
    // Task : apply reset to both domains
    // =========================================================================
    task apply_reset;
        begin
            wrst_n = 1'b0; rrst_n = 1'b0;
            winc   = 1'b0; rinc   = 1'b0;
            wdata  = {DATA_WIDTH{1'b0}};
            repeat(4) @(posedge wclk);
            repeat(4) @(posedge rclk);
            wrst_n = 1'b1; rrst_n = 1'b1;
            repeat(2) @(posedge wclk);
        end
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    integer i;

    initial begin
        $display("============================================================");
        $display("  Async FIFO Testbench  (DEPTH=%0d, DATA=%0d-bit)", DEPTH, DATA_WIDTH);
        $display("  WCLK=%0d ns   RCLK=%0d ns", WCLK_PERIOD, RCLK_PERIOD);
        $display("  Run 'run 50us' in TCL console for full simulation");
        $display("============================================================");

        // ---- TC0 : Power-on reset ----------------------------------------
        $display("\n-- TC0: Power-on reset --");
        apply_reset;
        $display("    rempty=%b  wfull=%b  (expect 1 / 0)", rempty, wfull);

        // ---- TC1 : Basic write then read ---------------------------------
        $display("\n-- TC1: Basic write-then-read (8 words) --");
        for (i = 0; i < 8; i = i+1)
            write_fifo(8'hA0 + i[7:0]);
        repeat(6) @(posedge rclk);
        for (i = 0; i < 8; i = i+1)
            read_fifo;
        repeat(6) @(posedge rclk);

        // ---- TC2 : Fill FIFO completely (test wfull) ---------------------
        $display("\n-- TC2: Fill FIFO - expect wfull to assert --");
        for (i = 0; i < DEPTH + 3; i = i+1)
            write_fifo(8'hB0 + i[7:0]);
        repeat(6) @(posedge wclk);
        $display("    wfull=%b  (expect 1)", wfull);

        // ---- TC3 : Write-while-full (no corruption) ----------------------
        $display("\n-- TC3: Write-while-full (data should be ignored) --");
        @(posedge wclk); #1;
        winc  = 1'b1;
        wdata = 8'hDE;
        @(posedge wclk); #1;
        winc  = 1'b0;

        // ---- TC4 : Drain FIFO (test rempty) ------------------------------
        $display("\n-- TC4: Drain FIFO - expect rempty to assert --");
        repeat(DEPTH + 4) read_fifo;
        repeat(6) @(posedge rclk);
        $display("    rempty=%b  (expect 1)", rempty);

        // ---- TC5 : Read-while-empty (no corruption) ----------------------
        $display("\n-- TC5: Read-while-empty (should be ignored) --");
        @(posedge rclk); #1;
        rinc = 1'b1;
        @(posedge rclk); #1;
        rinc = 1'b0;
        $display("    rempty=%b  (expect 1 - FIFO still empty)", rempty);

        // ---- TC6 : Simultaneous read & write (concurrent) ----------------
        $display("\n-- TC6: Simultaneous write & read --");
        fork
            begin : writer
                for (i = 0; i < 12; i = i+1) begin
                    @(posedge wclk); #1;
                    if (!wfull) begin
                        winc  = 1'b1;
                        wdata = 8'hC0 + i[7:0];
                        exp_queue[exp_wr % 256] = wdata;
                        exp_wr   = exp_wr + 1;
                        wr_count = wr_count + 1;
                    end else winc = 1'b0;
                    @(posedge wclk); #1;
                    winc = 1'b0;
                end
            end
            begin : reader
                repeat(4) @(posedge rclk);
                for (i = 0; i < 12; i = i+1) begin
                    @(posedge rclk); #1;
                    rinc = (!rempty) ? 1'b1 : 1'b0;
                    @(posedge rclk); #1;
                    rinc = 1'b0;
                end
            end
        join
        repeat(10) @(posedge rclk);

        // ---- TC7 : Back-to-back burst ------------------------------------
        $display("\n-- TC7: Back-to-back burst (write 8, read 8, repeat) --");
        for (i = 0; i < 8; i = i+1) write_fifo(8'hD0 + i[7:0]);
        repeat(6) @(posedge rclk);
        for (i = 0; i < 8; i = i+1) read_fifo;
        repeat(4) @(posedge rclk);
        for (i = 0; i < 8; i = i+1) write_fifo(8'hE0 + i[7:0]);
        repeat(6) @(posedge rclk);
        for (i = 0; i < 8; i = i+1) read_fifo;
        repeat(6) @(posedge rclk);

        // ---- TC8 : Reset during operation --------------------------------
        $display("\n-- TC8: Reset during operation --");
        for (i = 0; i < 5; i = i+1) write_fifo(8'hFF - i[7:0]);
        $display("    Asserting reset mid-operation...");
        wrst_n = 1'b0; rrst_n = 1'b0;
        exp_wr = 0; exp_rd = 0;
        wr_count = 0; rd_count = 0;
        repeat(4) @(posedge wclk);
        repeat(4) @(posedge rclk);
        wrst_n = 1'b1; rrst_n = 1'b1;
        repeat(2) @(posedge wclk);
        $display("    rempty=%b  wfull=%b  (expect 1 / 0 after reset)", rempty, wfull);
        for (i = 0; i < 4; i = i+1) write_fifo(8'h10 + i[7:0]);
        repeat(6) @(posedge rclk);
        for (i = 0; i < 4; i = i+1) read_fifo;
        repeat(6) @(posedge rclk);

        // ---- Summary -----------------------------------------------------
        $display("\n============================================================");
        $display("  SIMULATION COMPLETE");
        $display("  Total writes : %0d", wr_count);
        $display("  Total reads  : %0d", rd_count);
        $display("  PASSED checks: %0d", pass_count);
        $display("  FAILED checks: %0d", fail_count);
        if (fail_count == 0)
            $display("  >>> ALL CHECKS PASSED <<<");
        else
            $display("  >>> %0d CHECKS FAILED - review waveform <<<", fail_count);
        $display("============================================================\n");

        $finish;
    end

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #500000;
        $display("[TIMEOUT] Simulation exceeded 500 us - forcing stop");
        $stop;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, tb_async_fifo);
    end

endmodule