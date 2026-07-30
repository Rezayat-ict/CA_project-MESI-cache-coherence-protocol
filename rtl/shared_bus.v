`timescale 1ns/1ps
`include "bus_defs.vh"

module shared_bus #(
    parameter ADDR_WIDTH = 32,
    parameter LINE_WIDTH = 128
)(
    input  wire                  clk,
    input  wire                  reset,

    input  wire                  cache0_req,
    input  wire [`BUS_CMD_WIDTH-1:0] cache0_cmd,
    input  wire [ADDR_WIDTH-1:0] cache0_addr,
    input  wire [LINE_WIDTH-1:0] cache0_wdata,

    output reg                   cache0_grant,
    output reg                   cache0_done,
    output reg  [LINE_WIDTH-1:0] cache0_rdata,
    output reg                   cache0_shared,

    input  wire                  cache1_req,
    input  wire [`BUS_CMD_WIDTH-1:0] cache1_cmd,
    input  wire [ADDR_WIDTH-1:0] cache1_addr,
    input  wire [LINE_WIDTH-1:0] cache1_wdata,

    output reg                   cache1_grant,
    output reg                   cache1_done,
    output reg  [LINE_WIDTH-1:0] cache1_rdata,
    output reg                   cache1_shared,

    output reg                   cache0_snoop_valid,
    output reg  [`BUS_CMD_WIDTH-1:0] cache0_snoop_cmd,
    output reg  [ADDR_WIDTH-1:0] cache0_snoop_addr,

    input  wire                  cache0_snoop_response_valid,
    input  wire                  cache0_snoop_hit,
    input  wire                  cache0_snoop_dirty,
    input  wire [LINE_WIDTH-1:0] cache0_snoop_data,

    output reg                   cache1_snoop_valid,
    output reg  [`BUS_CMD_WIDTH-1:0] cache1_snoop_cmd,
    output reg  [ADDR_WIDTH-1:0] cache1_snoop_addr,

    input  wire                  cache1_snoop_response_valid,
    input  wire                  cache1_snoop_hit,
    input  wire                  cache1_snoop_dirty,
    input  wire [LINE_WIDTH-1:0] cache1_snoop_data,

    output reg                   mem_req,
    output reg                   mem_write,
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg  [LINE_WIDTH-1:0] mem_wdata,

    input  wire                  mem_ready,
    input  wire [LINE_WIDTH-1:0] mem_rdata,

    output wire                  bus_busy,
    output wire                  bus_owner,
    output wire [`BUS_CMD_WIDTH-1:0] debug_bus_cmd,
    output wire [ADDR_WIDTH-1:0] debug_bus_addr,
    output wire [3:0]            debug_bus_state
);

    localparam ST_IDLE          = 4'd0;
    localparam ST_GRANT         = 4'd1;
    localparam ST_SNOOP         = 4'd2;
    localparam ST_WAIT_SNOOP    = 4'd3;
    localparam ST_WB_REQ        = 4'd4;
    localparam ST_WB_WAIT       = 4'd5;
    localparam ST_MEM_RD_REQ    = 4'd6;
    localparam ST_MEM_RD_WAIT   = 4'd7;
    localparam ST_MEM_WR_REQ    = 4'd8;
    localparam ST_MEM_WR_WAIT   = 4'd9;
    localparam ST_COMPLETE      = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;

    reg owner;
    reg last_owner;
    reg selected_owner;

    reg [`BUS_CMD_WIDTH-1:0] request_cmd;
    reg [ADDR_WIDTH-1:0]     request_addr;
    reg [LINE_WIDTH-1:0]     request_wdata;

    reg                      shared_result;
    reg [LINE_WIDTH-1:0]     dirty_snoop_data;
    reg [LINE_WIDTH-1:0]     read_result;

    wire target_response_valid;
    wire target_hit;
    wire target_dirty;
    wire [LINE_WIDTH-1:0] target_data;

    assign target_response_valid = owner ? cache0_snoop_response_valid
                                         : cache1_snoop_response_valid;
    assign target_hit            = owner ? cache0_snoop_hit
                                         : cache1_snoop_hit;
    assign target_dirty          = owner ? cache0_snoop_dirty
                                         : cache1_snoop_dirty;
    assign target_data           = owner ? cache0_snoop_data
                                         : cache1_snoop_data;

    assign bus_busy        = (state != ST_IDLE);
    assign bus_owner       = owner;
    assign debug_bus_cmd   = request_cmd;
    assign debug_bus_addr  = request_addr;
    assign debug_bus_state = state;

    always @(*) begin
        selected_owner = 1'b0;

        if (cache0_req && !cache1_req)
            selected_owner = 1'b0;
        else if (!cache0_req && cache1_req)
            selected_owner = 1'b1;
        else if (cache0_req && cache1_req)
            selected_owner = ~last_owner;
    end

    always @(posedge clk) begin
        if (reset) begin
            state             <= ST_IDLE;
            owner             <= 1'b0;
            last_owner        <= 1'b1;
            request_cmd       <= `BUS_NONE;
            request_addr      <= {ADDR_WIDTH{1'b0}};
            request_wdata     <= {LINE_WIDTH{1'b0}};
            shared_result     <= 1'b0;
            dirty_snoop_data  <= {LINE_WIDTH{1'b0}};
            read_result       <= {LINE_WIDTH{1'b0}};
        end
        else begin
            state <= next_state;

            if ((state == ST_IDLE) && (cache0_req || cache1_req)) begin
                owner         <= selected_owner;
                shared_result <= 1'b0;
                read_result   <= {LINE_WIDTH{1'b0}};

                if (selected_owner == 1'b0) begin
                    request_cmd   <= cache0_cmd;
                    request_addr  <= {cache0_addr[ADDR_WIDTH-1:4], 4'b0000};
                    request_wdata <= cache0_wdata;
                end
                else begin
                    request_cmd   <= cache1_cmd;
                    request_addr  <= {cache1_addr[ADDR_WIDTH-1:4], 4'b0000};
                    request_wdata <= cache1_wdata;
                end
            end

            if ((state == ST_WAIT_SNOOP) && target_response_valid) begin
                shared_result    <= target_hit;
                dirty_snoop_data <= target_data;
            end

            if ((state == ST_MEM_RD_WAIT) && mem_ready)
                read_result <= mem_rdata;

            if (state == ST_COMPLETE)
                last_owner <= owner;
        end
    end

    always @(*) begin
        next_state = state;

        case (state)
            ST_IDLE: begin
                if (cache0_req || cache1_req)
                    next_state = ST_GRANT;
            end

            ST_GRANT: begin
                case (request_cmd)
                    `BUS_RD,
                    `BUS_RDX,
                    `BUS_UPGR: next_state = ST_SNOOP;

                    `BUS_WB:   next_state = ST_MEM_WR_REQ;

                    default:   next_state = ST_COMPLETE;
                endcase
            end

            ST_SNOOP: begin
                next_state = ST_WAIT_SNOOP;
            end

            ST_WAIT_SNOOP: begin
                if (target_response_valid) begin
                    if (target_dirty)
                        next_state = ST_WB_REQ;
                    else if ((request_cmd == `BUS_RD) ||
                             (request_cmd == `BUS_RDX))
                        next_state = ST_MEM_RD_REQ;
                    else
                        next_state = ST_COMPLETE;
                end
            end

            ST_WB_REQ: begin
                next_state = ST_WB_WAIT;
            end

            ST_WB_WAIT: begin
                if (mem_ready) begin
                    if ((request_cmd == `BUS_RD) ||
                        (request_cmd == `BUS_RDX))
                        next_state = ST_MEM_RD_REQ;
                    else
                        next_state = ST_COMPLETE;
                end
            end

            ST_MEM_RD_REQ: begin
                next_state = ST_MEM_RD_WAIT;
            end

            ST_MEM_RD_WAIT: begin
                if (mem_ready)
                    next_state = ST_COMPLETE;
            end

            ST_MEM_WR_REQ: begin
                next_state = ST_MEM_WR_WAIT;
            end

            ST_MEM_WR_WAIT: begin
                if (mem_ready)
                    next_state = ST_COMPLETE;
            end

            ST_COMPLETE: begin
                next_state = ST_IDLE;
            end

            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    always @(*) begin
        cache0_grant  = 1'b0;
        cache0_done   = 1'b0;
        cache0_rdata  = {LINE_WIDTH{1'b0}};
        cache0_shared = 1'b0;

        cache1_grant  = 1'b0;
        cache1_done   = 1'b0;
        cache1_rdata  = {LINE_WIDTH{1'b0}};
        cache1_shared = 1'b0;

        cache0_snoop_valid = 1'b0;
        cache0_snoop_cmd   = request_cmd;
        cache0_snoop_addr  = request_addr;

        cache1_snoop_valid = 1'b0;
        cache1_snoop_cmd   = request_cmd;
        cache1_snoop_addr  = request_addr;

        mem_req   = 1'b0;
        mem_write = 1'b0;
        mem_addr  = request_addr;
        mem_wdata = request_wdata;

        case (state)
            ST_GRANT: begin
                if (owner == 1'b0)
                    cache0_grant = 1'b1;
                else
                    cache1_grant = 1'b1;
            end

            ST_SNOOP: begin
                if (owner == 1'b0)
                    cache1_snoop_valid = 1'b1;
                else
                    cache0_snoop_valid = 1'b1;
            end

            ST_WB_REQ: begin
                mem_req   = 1'b1;
                mem_write = 1'b1;
                mem_addr  = request_addr;
                mem_wdata = dirty_snoop_data;
            end

            ST_MEM_RD_REQ: begin
                mem_req   = 1'b1;
                mem_write = 1'b0;
                mem_addr  = request_addr;
            end

            ST_MEM_WR_REQ: begin
                mem_req   = 1'b1;
                mem_write = 1'b1;
                mem_addr  = request_addr;
                mem_wdata = request_wdata;
            end

            ST_COMPLETE: begin
                if (owner == 1'b0) begin
                    cache0_done   = 1'b1;
                    cache0_rdata  = read_result;
                    cache0_shared = shared_result;
                end
                else begin
                    cache1_done   = 1'b1;
                    cache1_rdata  = read_result;
                    cache1_shared = shared_result;
                end
            end

            default: begin
            end
        endcase
    end

endmodule
