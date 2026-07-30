`timescale 1ns/1ps
`include "bus_defs.vh"

module dual_core_system #(
    parameter ADDR_WIDTH  = 32,
    parameter LINE_WIDTH  = 128,
    parameter WORD_COUNT  = 1024,
    parameter MEM_LATENCY = 2,
    parameter INIT_FILE_0 = "inst0.txt",
    parameter INIT_FILE_1 = "inst1.txt"
)(
    input  wire         clk,
    input  wire         reset,

    // Auxiliary signals for external monitoring 
    output wire         bus_busy,
    output wire         bus_owner
);

    // ==========================================
    // 1. Core 0 connection wires with instruction memory and its cache
    // ==========================================
    wire [31:0] core0_pc;
    wire [31:0] core0_instruction;
    wire        core0_mem_read;
    wire        core0_mem_write;
    wire [31:0] core0_mem_addr;
    wire [31:0] core0_mem_wdata;
    wire [31:0] core0_mem_rdata;
    wire        core0_mem_ready;
    wire        core0_mem_req = core0_mem_read | core0_mem_write;

    // ==========================================
    // 2. Core 1 connection wires with instruction memory and its cache
    // ==========================================
    wire [31:0] core1_pc;
    wire [31:0] core1_instruction;
    wire        core1_mem_read;
    wire        core1_mem_write;
    wire [31:0] core1_mem_addr;
    wire [31:0] core1_mem_wdata;
    wire [31:0] core1_mem_rdata;
    wire        core1_mem_ready;
    wire        core1_mem_req = core1_mem_read | core1_mem_write;

    // ==========================================
    // 3. Connection wires between cache adapters and the shared bus subsystem
    // ==========================================
    // Cache 0 to Bus
    wire                  cache0_bus_req;
    wire [`BUS_CMD_WIDTH-1:0] cache0_bus_cmd;
    wire [ADDR_WIDTH-1:0] cache0_bus_addr;
    wire [LINE_WIDTH-1:0] cache0_bus_wdata;
    wire                  cache0_bus_grant;
    wire                  cache0_bus_done;
    wire [LINE_WIDTH-1:0] cache0_bus_rdata;
    wire                  cache0_bus_shared;

    // Snoop signals for Cache 0
    wire                  cache0_snoop_valid;
    wire [`BUS_CMD_WIDTH-1:0] cache0_snoop_cmd;
    wire [ADDR_WIDTH-1:0] cache0_snoop_addr;
    wire                  cache0_snoop_response_valid;
    wire                  cache0_snoop_hit;
    wire                  cache0_snoop_dirty;
    wire [LINE_WIDTH-1:0] cache0_snoop_data;

    // Cache 1 to Bus
    wire                  cache1_bus_req;
    wire [`BUS_CMD_WIDTH-1:0] cache1_bus_cmd;
    wire [ADDR_WIDTH-1:0] cache1_bus_addr;
    wire [LINE_WIDTH-1:0] cache1_bus_wdata;
    wire                  cache1_bus_grant;
    wire                  cache1_bus_done;
    wire [LINE_WIDTH-1:0] cache1_bus_rdata;
    wire                  cache1_bus_shared;

    // Snoop signals for Cache 1
    wire                  cache1_snoop_valid;
    wire [`BUS_CMD_WIDTH-1:0] cache1_snoop_cmd;
    wire [ADDR_WIDTH-1:0] cache1_snoop_addr;
    wire                  cache1_snoop_response_valid;
    wire                  cache1_snoop_hit;
    wire                  cache1_snoop_dirty;
    wire [LINE_WIDTH-1:0] cache1_snoop_data;


    // ==========================================
    // 4. Instantiate Processor Core 0
    // ==========================================
    mips_core core0 (
        .clk(clk),
        .rst(reset),
        .instr_addr(core0_pc),
        .instr_data(core0_instruction),
        .mem_read(core0_mem_read),
        .mem_write(core0_mem_write),
        .mem_addr(core0_mem_addr),
        .mem_wdata(core0_mem_wdata),
        .mem_rdata(core0_mem_rdata),
        .cpu_ready(core0_mem_ready)
    );

    // ==========================================
    // 5. Instantiate Instruction Memory 0
    // ==========================================
    instruction_memory #(
        .MEM_SIZE(256),
        .INIT_FILE(INIT_FILE_0)
    ) imem0 (
        .addr(core0_pc),
        .instruction(core0_instruction)
    );


    // ==========================================
    // 6. Instantiate Processor Core 1
    // ==========================================
    mips_core core1 (
        .clk(clk),
        .rst(reset),
        .instr_addr(core1_pc),
        .instr_data(core1_instruction),
        .mem_read(core1_mem_read),
        .mem_write(core1_mem_write),
        .mem_addr(core1_mem_addr),
        .mem_wdata(core1_mem_wdata),
        .mem_rdata(core1_mem_rdata),
        .cpu_ready(core1_mem_ready)
    );

    // ==========================================
    // 7. Instantiate Instruction Memory 1
    // ==========================================
    instruction_memory #(
        .MEM_SIZE(256),
        .INIT_FILE(INIT_FILE_1)
    ) imem1 (
        .addr(core1_pc),
        .instruction(core1_instruction)
    );


    // ==========================================
    // 8. Instantiate Cache Bus Adapter 0 (for Core 0)
    // ==========================================
    cache2_bus_adapter cache_adapter_0 (
        .clk(clk),
        .reset(reset),
        .cpu_req(core0_mem_req),
        .cpu_write(core0_mem_write),
        .cpu_addr(core0_mem_addr),
        .cpu_wdata(core0_mem_wdata),
        .cpu_rdata(core0_mem_rdata),
        .cpu_ready(core0_mem_ready),

        .bus_req(cache0_bus_req),
        .bus_cmd(cache0_bus_cmd),
        .bus_addr(cache0_bus_addr),
        .bus_wdata(cache0_bus_wdata),
        .bus_grant(cache0_bus_grant),
        .bus_done(cache0_bus_done),
        .bus_rdata(cache0_bus_rdata),
        .bus_shared(cache0_bus_shared),

        .snoop_valid(cache0_snoop_valid),
        .snoop_cmd(cache0_snoop_cmd),
        .snoop_addr(cache0_snoop_addr),
        .snoop_response_valid(cache0_snoop_response_valid),
        .snoop_hit(cache0_snoop_hit),
        .snoop_dirty(cache0_snoop_dirty),
        .snoop_data(cache0_snoop_data)
    );


    // ==========================================
    // 9. Instantiate Cache Bus Adapter 1 (for Core 1)
    // ==========================================
    cache2_bus_adapter cache_adapter_1 (
        .clk(clk),
        .reset(reset),
        .cpu_req(core1_mem_req),
        .cpu_write(core1_mem_write),
        .cpu_addr(core1_mem_addr),
        .cpu_wdata(core1_mem_wdata),
        .cpu_rdata(core1_mem_rdata),
        .cpu_ready(core1_mem_ready),

        .bus_req(cache1_bus_req),
        .bus_cmd(cache1_bus_cmd),
        .bus_addr(cache1_bus_addr),
        .bus_wdata(cache1_bus_wdata),
        .bus_grant(cache1_bus_grant),
        .bus_done(cache1_bus_done),
        .bus_rdata(cache1_bus_rdata),
        .bus_shared(cache1_bus_shared),

        .snoop_valid(cache1_snoop_valid),
        .snoop_cmd(cache1_snoop_cmd),
        .snoop_addr(cache1_snoop_addr),
        .snoop_response_valid(cache1_snoop_response_valid),
        .snoop_hit(cache1_snoop_hit),
        .snoop_dirty(cache1_snoop_dirty),
        .snoop_data(cache1_snoop_data)
    );


    // ==========================================
    // 10. Instantiate Memory & Bus Subsystem (Shared Bus + Main Memory)
    // ==========================================
    memory_subsystem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .WORD_COUNT(WORD_COUNT),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE("") // Initial data memory file if needed
    ) mem_bus_subsystem (
        .clk(clk),
        .reset(reset),

        // Connect Cache 0
        .cache0_req(cache0_bus_req),
        .cache0_cmd(cache0_bus_cmd),
        .cache0_addr(cache0_bus_addr),
        .cache0_wdata(cache0_bus_wdata),
        .cache0_grant(cache0_bus_grant),
        .cache0_done(cache0_bus_done),
        .cache0_rdata(cache0_bus_rdata),
        .cache0_shared(cache0_bus_shared),

        // Connect Cache 1
        .cache1_req(cache1_bus_req),
        .cache1_cmd(cache1_bus_cmd),
        .cache1_addr(cache1_bus_addr),
        .cache1_wdata(cache1_bus_wdata),
        .cache1_grant(cache1_bus_grant),
        .cache1_done(cache1_bus_done),
        .cache1_rdata(cache1_bus_rdata),
        .cache1_shared(cache1_bus_shared),

        // Snoop lines for Cache 0
        .cache0_snoop_valid(cache0_snoop_valid),
        .cache0_snoop_cmd(cache0_snoop_cmd),
        .cache0_snoop_addr(cache0_snoop_addr),
        .cache0_snoop_response_valid(cache0_snoop_response_valid),
        .cache0_snoop_hit(cache0_snoop_hit),
        .cache0_snoop_dirty(cache0_snoop_dirty),
        .cache0_snoop_data(cache0_snoop_data),

        // Snoop lines for Cache 1
        .cache1_snoop_valid(cache1_snoop_valid),
        .cache1_snoop_cmd(cache1_snoop_cmd),
        .cache1_snoop_addr(cache1_snoop_addr),
        .cache1_snoop_response_valid(cache1_snoop_response_valid),
        .cache1_snoop_hit(cache1_snoop_hit),
        .cache1_snoop_dirty(cache1_snoop_dirty),
        .cache1_snoop_data(cache1_snoop_data),

        // Bus status outputs
        .bus_busy(bus_busy),
        .bus_owner(bus_owner),
        .debug_bus_cmd(),
        .debug_bus_addr(),
        .debug_bus_state()
    );

endmodule