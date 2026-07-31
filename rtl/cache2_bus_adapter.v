`timescale 1ns/1ps
`include "bus_defs.vh"


module cache2_bus_adapter (
    input  wire         clk,
    input  wire         reset,

    input  wire         cpu_req,
    input  wire         cpu_write,
    input  wire [31:0]  cpu_addr,
    input  wire [31:0]  cpu_wdata,
    output wire [31:0]  cpu_rdata,
    output wire         cpu_ready,

    output wire         bus_req,
    output reg  [2:0]   bus_cmd,
    output wire [31:0]  bus_addr,
    output wire [127:0] bus_wdata,

    input  wire         bus_grant,
    input  wire         bus_done,
    input  wire [127:0] bus_rdata,
    input  wire         bus_shared,

    input  wire         snoop_valid,
    input  wire [2:0]   snoop_cmd,
    input  wire [31:0]  snoop_addr,

    output reg          snoop_response_valid,
    output reg          snoop_hit,
    output reg          snoop_dirty,
    output reg  [127:0] snoop_data
);

    localparam WR_IDLE      = 2'd0;
    localparam WR_ACTIVE    = 2'd1;
    localparam WR_WAIT_DROP = 2'd2;

    reg [1:0] wrapper_state;
    reg       latched_write;
    reg [31:0] latched_addr;
    reg [31:0] latched_wdata;
    reg       bus_seen;
    reg       ready_pending;
    reg [31:0] result_data;
    reg       ready_pulse;

    wire raw_cpu_req;
    wire [31:0] raw_cpu_rdata;
    wire raw_cpu_ready;

    wire raw_bus_req;
    wire [2:0] raw_bus_cmd;
    wire [31:0] raw_bus_addr;
    wire [127:0] raw_bus_wdata;

    wire raw_snoop_response_valid;
    wire raw_snoop_hit;
    wire raw_snoop_dirty;
    wire [127:0] raw_snoop_data;

    assign raw_cpu_req = (wrapper_state == WR_ACTIVE);

    assign cpu_rdata = result_data;
    assign cpu_ready = ready_pulse;

    assign bus_req   = raw_bus_req;
    assign bus_addr  = {raw_bus_addr[31:4], 4'b0000};
    assign bus_wdata = raw_bus_wdata;


    always @(*) begin
        case (raw_bus_cmd)
            3'b001: bus_cmd = latched_write ? `BUS_RDX : `BUS_RD;
            3'b010: bus_cmd = `BUS_WB;
            3'b011: bus_cmd = `BUS_UPGR;
            default: bus_cmd = `BUS_NONE;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wrapper_state <= WR_IDLE;
            latched_write  <= 1'b0;
            latched_addr   <= 32'b0;
            latched_wdata  <= 32'b0;
            bus_seen       <= 1'b0;
            ready_pending  <= 1'b0;
            result_data    <= 32'b0;
            ready_pulse    <= 1'b0;
        end
        else begin
            ready_pulse <= 1'b0;

            case (wrapper_state)
                WR_IDLE: begin
                    bus_seen      <= 1'b0;
                    ready_pending <= 1'b0;

                    if (cpu_req) begin
                        latched_write <= cpu_write;
                        latched_addr  <= cpu_addr;
                        latched_wdata <= cpu_wdata;
                        wrapper_state <= WR_ACTIVE;
                    end
                end

                WR_ACTIVE: begin
                    if (raw_bus_req) begin
                        bus_seen      <= 1'b1;
                        ready_pending <= 1'b0;
                    end

                    if (raw_cpu_ready) begin
                        result_data <= raw_cpu_rdata;

                        if (bus_seen) begin
                            ready_pulse    <= 1'b1;
                            ready_pending  <= 1'b0;
                            wrapper_state  <= WR_WAIT_DROP;
                        end
                        else begin
                            // Wait one cycle to distinguish a direct hit
                            // from an S-state write that starts BUS_UPGR.
                            ready_pending <= 1'b1;
                        end
                    end

                    if (ready_pending) begin
                        if (raw_bus_req) begin
                            bus_seen      <= 1'b1;
                            ready_pending <= 1'b0;
                        end
                        else begin
                            ready_pulse    <= 1'b1;
                            ready_pending  <= 1'b0;
                            wrapper_state  <= WR_WAIT_DROP;
                        end
                    end
                end

                WR_WAIT_DROP: begin
                        wrapper_state <= WR_IDLE;
                end

                default: wrapper_state <= WR_IDLE;
            endcase
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            snoop_response_valid <= 1'b0;
            snoop_hit            <= 1'b0;
            snoop_dirty          <= 1'b0;
            snoop_data           <= 128'b0;
        end
        else begin
            snoop_response_valid <= 1'b0;

            if (snoop_valid) begin
                snoop_response_valid <= 1'b1;
                snoop_hit            <= raw_snoop_hit;
                snoop_dirty          <= raw_snoop_dirty;
                snoop_data           <= raw_snoop_data;
            end
        end
    end

    l1_cache cache_impl (
        .clk(clk),
        .reset(reset),

        .cpu_req(raw_cpu_req),
        .cpu_write(latched_write),
        .cpu_addr(latched_addr),
        .cpu_wdata(latched_wdata),
        .cpu_rdata(raw_cpu_rdata),
        .cpu_ready(raw_cpu_ready),

        .bus_req(raw_bus_req),
        .bus_cmd(raw_bus_cmd),
        .bus_addr(raw_bus_addr),
        .bus_wdata(raw_bus_wdata),

        .bus_grant(bus_grant),
        .bus_done(bus_done),
        .bus_rdata(bus_rdata),
        .bus_shared(bus_shared),

        .snoop_valid(snoop_valid),
        .snoop_cmd(snoop_cmd),
        .snoop_addr(snoop_addr),
        .snoop_response_valid(raw_snoop_response_valid),
        .snoop_hit(raw_snoop_hit),
        .snoop_dirty(raw_snoop_dirty),
        .snoop_data(raw_snoop_data)
    );

endmodule
