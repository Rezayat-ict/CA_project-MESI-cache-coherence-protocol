`timescale 1ns/1ps
`include "bus_defs.vh"

module victim_cache #(
    parameter ENTRIES = 4
)(
    input  wire         clk,
    input  wire         reset,

    input  wire         l1_req,
    input  wire [2:0]   l1_cmd,
    input  wire [31:0]  l1_addr,
    input  wire [127:0] l1_wdata,
    input  wire         l1_cpu_write,
    input  wire [31:0]  pending_cpu_addr,

    output reg          l1_grant,
    output reg          l1_done,
    output reg  [127:0] l1_rdata,
    output reg          l1_shared,

    output reg          bus_req,
    output reg  [2:0]   bus_cmd,
    output reg  [31:0]  bus_addr,
    output reg  [127:0] bus_wdata,

    input  wire         bus_grant,
    input  wire         bus_done,
    input  wire [127:0] bus_rdata,
    input  wire         bus_shared,

    input  wire         evict_valid,
    input  wire [31:0]  evict_addr,
    input  wire [127:0] evict_data,
    input  wire [1:0]   evict_state,

    input  wire         snoop_valid,
    input  wire [2:0]   snoop_cmd,
    input  wire [31:0]  snoop_addr,

    output reg          snoop_response_valid,
    output reg          snoop_hit,
    output reg          snoop_dirty,
    output reg  [127:0] snoop_data,

    output wire         debug_hit
);

    localparam RAW_CMD_IDLE       = 3'b000;
    localparam RAW_CMD_ALLOCATE   = 3'b001;
    localparam RAW_CMD_WRITE_BACK = 3'b010;

    localparam STATE_I = 2'b00;
    localparam STATE_S = 2'b01;
    localparam STATE_E = 2'b10;
    localparam STATE_M = 2'b11;

    localparam VC_IDLE = 1'b0;
    localparam VC_WAIT = 1'b1;

    reg [27:0]  victim_tag   [0:ENTRIES-1];
    reg [127:0] victim_data  [0:ENTRIES-1];
    reg [1:0]   victim_state [0:ENTRIES-1];
    reg         victim_valid [0:ENTRIES-1];

    reg         local_state;
    reg [127:0] local_data;
    reg         local_shared_value;
    reg [1:0]   local_index;
    reg [1:0]   replace_pointer;

    reg         pending_line_valid;
    reg [27:0]  pending_line_tag;
    reg [127:0] pending_line_data;
    reg [1:0]   pending_line_state;

    reg         lookup_hit;
    reg [1:0]   lookup_index;
    reg         snoop_lookup_hit;
    reg [1:0]   snoop_lookup_index;
    reg [1:0]   evict_insert_index;
    reg         evict_insert_existing;
    reg         evict_insert_free;
    reg [1:0]   wb_insert_index;
    reg         wb_insert_existing;
    reg         wb_insert_free;
    reg         pending_target_hit;
    reg [1:0]   pending_target_index;

    wire [27:0] lookup_tag = l1_addr[31:4];
    wire [27:0] snoop_tag  = snoop_addr[31:4];

    wire snoop_blocks_local = snoop_valid && snoop_lookup_hit;

    wire local_lookup_eligible = (local_state == VC_IDLE) &&
                                 l1_req &&
                                 (l1_cmd == RAW_CMD_ALLOCATE) &&
                                 lookup_hit &&
                                 !snoop_blocks_local &&
                                 (!l1_cpu_write ||
                                  (victim_state[lookup_index] == STATE_E));

    assign debug_hit = local_lookup_eligible;

    integer i_lookup;
    integer i_snoop;
    integer i_pending;
    integer i_evict;
    integer i_wb;
    integer i_seq;

    always @(*) begin
        lookup_hit   = 1'b0;
        lookup_index = 2'b0;

        for (i_lookup = 0; i_lookup < ENTRIES; i_lookup = i_lookup + 1) begin
            if (!lookup_hit && victim_valid[i_lookup] &&
                (victim_tag[i_lookup] == lookup_tag)) begin
                lookup_hit   = 1'b1;
                lookup_index = i_lookup;
            end
        end
    end

    always @(*) begin
        snoop_lookup_hit   = 1'b0;
        snoop_lookup_index = 2'b0;

        for (i_snoop = 0; i_snoop < ENTRIES; i_snoop = i_snoop + 1) begin
            if (!snoop_lookup_hit && victim_valid[i_snoop] &&
                (victim_tag[i_snoop] == snoop_tag)) begin
                snoop_lookup_hit   = 1'b1;
                snoop_lookup_index = i_snoop;
            end
        end
    end

    always @(*) begin
        pending_target_hit   = 1'b0;
        pending_target_index = 2'b0;

        for (i_pending = 0; i_pending < ENTRIES; i_pending = i_pending + 1) begin
            if (!pending_target_hit && victim_valid[i_pending] &&
                (victim_tag[i_pending] == pending_cpu_addr[31:4])) begin
                pending_target_hit   = 1'b1;
                pending_target_index = i_pending;
            end
        end
    end

    always @(*) begin
        evict_insert_index    = replace_pointer;
        evict_insert_existing = 1'b0;
        evict_insert_free     = 1'b0;

        for (i_evict = 0; i_evict < ENTRIES; i_evict = i_evict + 1) begin
            if (!evict_insert_existing && victim_valid[i_evict] &&
                (victim_tag[i_evict] == evict_addr[31:4])) begin
                evict_insert_index    = i_evict;
                evict_insert_existing = 1'b1;
            end
        end

        if (!evict_insert_existing) begin
            for (i_evict = 0; i_evict < ENTRIES; i_evict = i_evict + 1) begin
                if (!evict_insert_free && !victim_valid[i_evict]) begin
                    evict_insert_index = i_evict;
                    evict_insert_free  = 1'b1;
                end
            end
        end
    end

    always @(*) begin
        wb_insert_index    = replace_pointer;
        wb_insert_existing = 1'b0;
        wb_insert_free     = 1'b0;

        for (i_wb = 0; i_wb < ENTRIES; i_wb = i_wb + 1) begin
            if (!wb_insert_existing && victim_valid[i_wb] &&
                (victim_tag[i_wb] == l1_addr[31:4])) begin
                wb_insert_index    = i_wb;
                wb_insert_existing = 1'b1;
            end
        end

        if (!wb_insert_existing) begin
            for (i_wb = 0; i_wb < ENTRIES; i_wb = i_wb + 1) begin
                if (!wb_insert_free && !victim_valid[i_wb]) begin
                    wb_insert_index = i_wb;
                    wb_insert_free  = 1'b1;
                end
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            local_state       <= VC_IDLE;
            local_data        <= 128'b0;
            local_shared_value <= 1'b0;
            local_index       <= 2'b0;
            replace_pointer    <= 2'b0;
            pending_line_valid <= 1'b0;
            pending_line_tag   <= 28'b0;
            pending_line_data  <= 128'b0;
            pending_line_state <= STATE_I;

            for (i_seq = 0; i_seq < ENTRIES; i_seq = i_seq + 1) begin
                victim_tag[i_seq]   <= 28'b0;
                victim_data[i_seq]  <= 128'b0;
                victim_state[i_seq] <= STATE_I;
                victim_valid[i_seq] <= 1'b0;
            end
        end
        else begin
            if ((local_state == VC_IDLE) &&
                local_lookup_eligible && bus_grant) begin
                local_data         <= victim_data[lookup_index];
                local_shared_value <= (victim_state[lookup_index] == STATE_S);
                local_index        <= lookup_index;
                local_state        <= VC_WAIT;
            end
            else if ((local_state == VC_WAIT) && bus_done) begin
                if (pending_line_valid) begin
                    victim_tag[local_index]   <= pending_line_tag;
                    victim_data[local_index]  <= pending_line_data;
                    victim_state[local_index] <= pending_line_state;
                    victim_valid[local_index] <= 1'b1;
                    pending_line_valid        <= 1'b0;
                end
                else begin
                    victim_valid[local_index] <= 1'b0;
                    victim_state[local_index] <= STATE_I;
                end
                local_state <= VC_IDLE;
            end

            if (evict_valid) begin
                if (pending_target_hit &&
                    (pending_cpu_addr[31:4] != evict_addr[31:4])) begin
                    pending_line_valid <= 1'b1;
                    pending_line_tag   <= evict_addr[31:4];
                    pending_line_data  <= evict_data;
                    pending_line_state <=
                        (evict_state == STATE_S) ? STATE_S : STATE_E;
                end
                else begin
                    victim_tag[evict_insert_index]   <= evict_addr[31:4];
                    victim_data[evict_insert_index]  <= evict_data;
                    victim_state[evict_insert_index] <=
                        (evict_state == STATE_S) ? STATE_S : STATE_E;
                    victim_valid[evict_insert_index] <= 1'b1;

                    if (!evict_insert_existing)
                        replace_pointer <= replace_pointer + 2'd1;
                end
            end

            if (l1_req && (l1_cmd == RAW_CMD_WRITE_BACK) && bus_done) begin
                if (pending_target_hit &&
                    (pending_cpu_addr[31:4] != l1_addr[31:4])) begin
                    pending_line_valid <= 1'b1;
                    pending_line_tag   <= l1_addr[31:4];
                    pending_line_data  <= l1_wdata;
                    pending_line_state <= STATE_E;
                end
                else begin
                    victim_tag[wb_insert_index]   <= l1_addr[31:4];
                    victim_data[wb_insert_index]  <= l1_wdata;
                    victim_state[wb_insert_index] <= STATE_E;
                    victim_valid[wb_insert_index] <= 1'b1;

                    if (!wb_insert_existing)
                        replace_pointer <= replace_pointer + 2'd1;
                end
            end

            if (l1_req && (l1_cmd == RAW_CMD_ALLOCATE) &&
                l1_cpu_write && lookup_hit &&
                (victim_state[lookup_index] == STATE_S) &&
                bus_grant) begin
                if (pending_line_valid) begin
                    victim_tag[lookup_index]   <= pending_line_tag;
                    victim_data[lookup_index]  <= pending_line_data;
                    victim_state[lookup_index] <= pending_line_state;
                    victim_valid[lookup_index] <= 1'b1;
                    pending_line_valid         <= 1'b0;
                end
                else begin
                    victim_valid[lookup_index] <= 1'b0;
                    victim_state[lookup_index] <= STATE_I;
                end
            end

            if (snoop_valid && snoop_lookup_hit) begin
                case (snoop_cmd)
                    `BUS_RD: begin
                        if (victim_state[snoop_lookup_index] == STATE_E)
                            victim_state[snoop_lookup_index] <= STATE_S;
                    end

                    `BUS_RDX,
                    `BUS_UPGR: begin
                        if (pending_line_valid &&
                            (snoop_lookup_index == pending_target_index)) begin
                            victim_tag[snoop_lookup_index]   <= pending_line_tag;
                            victim_data[snoop_lookup_index]  <= pending_line_data;
                            victim_state[snoop_lookup_index] <= pending_line_state;
                            victim_valid[snoop_lookup_index] <= 1'b1;
                            pending_line_valid               <= 1'b0;
                        end
                        else begin
                            victim_valid[snoop_lookup_index] <= 1'b0;
                            victim_state[snoop_lookup_index] <= STATE_I;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always @(*) begin
        l1_grant  = 1'b0;
        l1_done   = 1'b0;
        l1_rdata  = 128'b0;
        l1_shared = 1'b0;

        bus_req   = 1'b0;
        bus_cmd   = RAW_CMD_IDLE;
        bus_addr  = 32'b0;
        bus_wdata = 128'b0;

        if (local_state == VC_WAIT) begin
            bus_req   = 1'b1;
            bus_cmd   = RAW_CMD_IDLE;
            bus_addr  = l1_addr;
            bus_wdata = 128'b0;

            l1_done   = bus_done;
            l1_rdata  = local_data;
            l1_shared = local_shared_value;
        end
        else if (local_lookup_eligible) begin
            bus_req   = 1'b1;
            bus_cmd   = RAW_CMD_IDLE;
            bus_addr  = l1_addr;
            bus_wdata = 128'b0;

            l1_grant = bus_grant;
        end
        else begin
            bus_req   = l1_req;
            bus_cmd   = l1_cmd;
            bus_addr  = l1_addr;
            bus_wdata = l1_wdata;

            l1_grant  = bus_grant;
            l1_done   = bus_done;
            l1_rdata  = bus_rdata;
            l1_shared = bus_shared;
        end
    end

    always @(*) begin
        snoop_response_valid = snoop_valid;
        snoop_hit            = snoop_valid && snoop_lookup_hit;
        snoop_dirty          = 1'b0;
        snoop_data           = 128'b0;

        if (snoop_lookup_hit)
            snoop_data = victim_data[snoop_lookup_index];
    end

endmodule
