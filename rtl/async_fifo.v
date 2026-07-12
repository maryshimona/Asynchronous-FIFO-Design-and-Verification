// =============================================================================
// Module      : async_fifo
// Description : Asynchronous FIFO using Gray-code pointer synchronisation
//               for safe clock-domain crossing (CDC).
//               Depth = 2^ADDR_WIDTH, Data width = DATA_WIDTH
//
// Parameters  : DATA_WIDTH - bit-width of each data word  (default 8)
//               ADDR_WIDTH - log2 of FIFO depth           (default 4 → 16 entries)
//
// Ports       :
//   Write domain  - wclk, wrst_n, winc, wdata, wfull
//   Read  domain  - rclk, rrst_n, rinc, rdata, rempty
// =============================================================================

`timescale 1ns / 1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4          // depth = 2^ADDR_WIDTH
)(
    // Write clock domain
    input  wire                  wclk,
    input  wire                  wrst_n,   // active-low async reset
    input  wire                  winc,     // write enable
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  wfull,

    // Read clock domain
    input  wire                  rclk,
    input  wire                  rrst_n,   // active-low async reset
    input  wire                  rinc,     // read enable
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  rempty
);

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH  :0] wptr,  rptr;       // Gray-code pointers (1 extra bit)
    wire [ADDR_WIDTH  :0] wptr_sync, rptr_sync; // synchronised pointers

    // -------------------------------------------------------------------------
    // Dual-port memory
    // -------------------------------------------------------------------------
    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_mem (
        .wclk  (wclk),
        .wen   (winc & ~wfull),
        .waddr (waddr),
        .wdata (wdata),
        .raddr (raddr),
        .rdata (rdata)
    );

    // -------------------------------------------------------------------------
    // Synchronise read pointer into write clock domain
    // -------------------------------------------------------------------------
    sync_r2w #(.ADDR_WIDTH(ADDR_WIDTH)) u_sync_r2w (
        .wclk      (wclk),
        .wrst_n    (wrst_n),
        .rptr      (rptr),
        .rptr_sync (rptr_sync)
    );

    // -------------------------------------------------------------------------
    // Synchronise write pointer into read clock domain
    // -------------------------------------------------------------------------
    sync_w2r #(.ADDR_WIDTH(ADDR_WIDTH)) u_sync_w2r (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .wptr      (wptr),
        .wptr_sync (wptr_sync)
    );

    // -------------------------------------------------------------------------
    // Write-domain logic: write pointer + full flag
    // -------------------------------------------------------------------------
    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk      (wclk),
        .wrst_n    (wrst_n),
        .winc      (winc),
        .rptr_sync (rptr_sync),
        .wptr      (wptr),
        .waddr     (waddr),
        .wfull     (wfull)
    );

    // -------------------------------------------------------------------------
    // Read-domain logic: read pointer + empty flag
    // -------------------------------------------------------------------------
    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .rinc      (rinc),
        .wptr_sync (wptr_sync),
        .rptr      (rptr),
        .raddr     (raddr),
        .rempty    (rempty)
    );

endmodule


// =============================================================================
// Module : fifo_mem  - simple dual-port synchronous-write / async-read BRAM
// =============================================================================
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,
    input  wire                  wen,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output wire [DATA_WIDTH-1:0] rdata
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialise all memory to 0 - removes red X lines in XSim waveform
    integer k;
    initial begin
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] = {DATA_WIDTH{1'b0}};
    end

    // Synchronous write
    always @(posedge wclk) begin
        if (wen)
            mem[waddr] <= wdata;
    end

    // Asynchronous read (infers distributed RAM in Vivado)
    assign rdata = mem[raddr];

endmodule


// =============================================================================
// Module : sync_r2w  - 2-FF synchroniser, read-ptr → write clock domain
// =============================================================================
module sync_r2w #(parameter ADDR_WIDTH = 4)(
    input  wire                   wclk,
    input  wire                   wrst_n,
    input  wire [ADDR_WIDTH:0]    rptr,
    output reg  [ADDR_WIDTH:0]    rptr_sync
);
    reg [ADDR_WIDTH:0] rptr_ff;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            {rptr_sync, rptr_ff} <= 0;
        else
            {rptr_sync, rptr_ff} <= {rptr_ff, rptr};
    end
endmodule


// =============================================================================
// Module : sync_w2r  - 2-FF synchroniser, write-ptr → read clock domain
// =============================================================================
module sync_w2r #(parameter ADDR_WIDTH = 4)(
    input  wire                   rclk,
    input  wire                   rrst_n,
    input  wire [ADDR_WIDTH:0]    wptr,
    output reg  [ADDR_WIDTH:0]    wptr_sync
);
    reg [ADDR_WIDTH:0] wptr_ff;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            {wptr_sync, wptr_ff} <= 0;
        else
            {wptr_sync, wptr_ff} <= {wptr_ff, wptr};
    end
endmodule


// =============================================================================
// Module : wptr_full  - write pointer (binary + Gray) and full-flag generation
// =============================================================================
module wptr_full #(parameter ADDR_WIDTH = 4)(
    input  wire                   wclk,
    input  wire                   wrst_n,
    input  wire                   winc,
    input  wire [ADDR_WIDTH:0]    rptr_sync,   // synced Gray-code read ptr
    output reg  [ADDR_WIDTH:0]    wptr,        // Gray-code write ptr (to sync)
    output reg  [ADDR_WIDTH-1:0]  waddr,       // binary write address
    output reg                    wfull
);
    reg  [ADDR_WIDTH:0] wbin;                  // binary write pointer
    wire [ADDR_WIDTH:0] wbin_next, wgray_next;
    wire                full_val;

    // Next binary & Gray values
    assign wbin_next  = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;  // binary-to-Gray

    // FULL condition: MSB and MSB-1 differ, rest equal
    // Kameyama / Cummings style: compare top 2 bits inverted, rest equal
    assign full_val = (wgray_next == {~rptr_sync[ADDR_WIDTH:ADDR_WIDTH-1],
                                       rptr_sync[ADDR_WIDTH-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= 0;
            wptr  <= 0;
            waddr <= 0;
            wfull <= 1'b0;
        end else begin
            wbin  <= wbin_next;
            wptr  <= wgray_next;
            waddr <= wbin_next[ADDR_WIDTH-1:0];
            wfull <= full_val;
        end
    end
endmodule


// =============================================================================
// Module : rptr_empty - read pointer (binary + Gray) and empty-flag generation
// =============================================================================
module rptr_empty #(parameter ADDR_WIDTH = 4)(
    input  wire                   rclk,
    input  wire                   rrst_n,
    input  wire                   rinc,
    input  wire [ADDR_WIDTH:0]    wptr_sync,   // synced Gray-code write ptr
    output reg  [ADDR_WIDTH:0]    rptr,        // Gray-code read ptr (to sync)
    output reg  [ADDR_WIDTH-1:0]  raddr,       // binary read address
    output reg                    rempty
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next, rgray_next;
    wire                empty_val;

    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // EMPTY when Gray-code read ptr == synchronised write ptr
    assign empty_val = (rgray_next == wptr_sync);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= 0;
            rptr   <= 0;
            raddr  <= 0;
            rempty <= 1'b1;    // starts empty
        end else begin
            rbin   <= rbin_next;
            rptr   <= rgray_next;
            raddr  <= rbin_next[ADDR_WIDTH-1:0];
            rempty <= empty_val;
        end
    end
endmodule