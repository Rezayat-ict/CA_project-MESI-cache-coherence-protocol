`timescale 1ns/1ps
`include "bus_defs.vh"

module memory_subsystem #(
    parameter ADDR_WIDTH  = 32,
    parameter LINE_WIDTH  = 128,
    parameter WORD_COUNT  = 1024,
    parameter MEM_LATENCY = 2,
    parameter INIT_FILE   = ""
)(
    input  wire                  clk,
    input  wire                  reset,

    input  wire                  cache0_req,
    input  wire [`BUS_CMD_WIDTH-1:0] cache0_cmd,
    input  wire [ADDR_WIDTH-1:0] cache0_addr,
    input  wire [LINE_WIDTH-1:0] cache0_wdata,
    output wire                  cache0_grant,
    output wire                  cache0_done,
    output wire [LINE_WIDTH-1:0] cache0_rdata,
    output wire                  cache0_shared,

    input  wire                  cache1_req,
    input  wire [`BUS_CMD_WIDTH-1:0] cache1_cmd,
    input  wire [ADDR_WIDTH-1:0] cache1_addr,
    input  wire [LINE_WIDTH-1:0] cache1_wdata,
    output wire                  cache1_grant,
    output wire                  cache1_done,
    output wire [LINE_WIDTH-1:0] cache1_rdata,
    output wire                  cache1_shared,

    output wire                  cache0_snoop_valid,
    output wire [`BUS_CMD_WIDTH-1:0] cache0_snoop_cmd,
    output wire [ADDR_WIDTH-1:0] cache0_snoop_addr,
    input  wire                  cache0_snoop_response_valid,
    input  wire                  cache0_snoop_hit,
    input  wire                  cache0_snoop_dirty,
    input  wire [LINE_WIDTH-1:0] cache0_snoop_data,

    output wire                  cache1_snoop_valid,
    output wire [`BUS_CMD_WIDTH-1:0] cache1_snoop_cmd,
    output wire [ADDR_WIDTH-1:0] cache1_snoop_addr,
    input  wire                  cache1_snoop_response_valid,
    input  wire                  cache1_snoop_hit,
    input  wire                  cache1_snoop_dirty,
    input  wire [LINE_WIDTH-1:0] cache1_snoop_data,

    output wire                  bus_busy,
    output wire                  bus_owner,
    output wire [`BUS_CMD_WIDTH-1:0] debug_bus_cmd,
    output wire [ADDR_WIDTH-1:0] debug_bus_addr,
    output wire [3:0]            debug_bus_state
);

    wire                  mem_req;
    wire                  mem_write;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [LINE_WIDTH-1:0] mem_wdata;
    wire [LINE_WIDTH-1:0] mem_rdata;
    wire                  mem_ready;
    wire                  mem_busy;

    shared_bus #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH)
    ) bus_unit (
        .clk(clk),
        .reset(reset),

        .cache0_req(cache0_req),
        .cache0_cmd(cache0_cmd),
        .cache0_addr(cache0_addr),
        .cache0_wdata(cache0_wdata),
        .cache0_grant(cache0_grant),
        .cache0_done(cache0_done),
        .cache0_rdata(cache0_rdata),
        .cache0_shared(cache0_shared),

        .cache1_req(cache1_req),
        .cache1_cmd(cache1_cmd),
        .cache1_addr(cache1_addr),
        .cache1_wdata(cache1_wdata),
        .cache1_grant(cache1_grant),
        .cache1_done(cache1_done),
        .cache1_rdata(cache1_rdata),
        .cache1_shared(cache1_shared),

        .cache0_snoop_valid(cache0_snoop_valid),
        .cache0_snoop_cmd(cache0_snoop_cmd),
        .cache0_snoop_addr(cache0_snoop_addr),
        .cache0_snoop_response_valid(cache0_snoop_response_valid),
        .cache0_snoop_hit(cache0_snoop_hit),
        .cache0_snoop_dirty(cache0_snoop_dirty),
        .cache0_snoop_data(cache0_snoop_data),

        .cache1_snoop_valid(cache1_snoop_valid),
        .cache1_snoop_cmd(cache1_snoop_cmd),
        .cache1_snoop_addr(cache1_snoop_addr),
        .cache1_snoop_response_valid(cache1_snoop_response_valid),
        .cache1_snoop_hit(cache1_snoop_hit),
        .cache1_snoop_dirty(cache1_snoop_dirty),
        .cache1_snoop_data(cache1_snoop_data),

        .mem_req(mem_req),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),

        .bus_busy(bus_busy),
        .bus_owner(bus_owner),
        .debug_bus_cmd(debug_bus_cmd),
        .debug_bus_addr(debug_bus_addr),
        .debug_bus_state(debug_bus_state)
    );

    main_memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .WORD_COUNT(WORD_COUNT),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE(INIT_FILE)
    ) memory_unit (
        .clk(clk),
        .reset(reset),
        .mem_req(mem_req),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready),
        .mem_busy(mem_busy)
    );

endmodule
