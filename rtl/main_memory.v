`timescale 1ns/1ps

module main_memory #(
    parameter ADDR_WIDTH  = 32,
    parameter LINE_WIDTH  = 128,
    parameter WORD_COUNT  = 1024,
    parameter MEM_LATENCY = 2,
    parameter INIT_FILE   = ""
)(
    input  wire                  clk,
    input  wire                  reset,

    input  wire                  mem_req,
    input  wire                  mem_write,
    input  wire [ADDR_WIDTH-1:0] mem_addr,
    input  wire [LINE_WIDTH-1:0] mem_wdata,

    output reg  [LINE_WIDTH-1:0] mem_rdata,
    output reg                   mem_ready,
    output wire                  mem_busy
);

    reg [31:0] memory [0:WORD_COUNT-1];

    reg                    busy_reg;
    reg                    latched_write;
    reg [ADDR_WIDTH-1:0]   latched_addr;
    reg [LINE_WIDTH-1:0]   latched_wdata;
    integer                cycles_left;
    integer                base_word;
    integer                i;

    assign mem_busy = busy_reg;

    initial begin
        for (i = 0; i < WORD_COUNT; i = i + 1)
            memory[i] = 32'b0;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    always @(posedge clk) begin
        if (reset) begin
            busy_reg      <= 1'b0;
            latched_write <= 1'b0;
            latched_addr  <= {ADDR_WIDTH{1'b0}};
            latched_wdata <= {LINE_WIDTH{1'b0}};
            cycles_left   <= 0;
            mem_rdata     <= {LINE_WIDTH{1'b0}};
            mem_ready     <= 1'b0;
        end
        else begin
            mem_ready <= 1'b0;

            if (!busy_reg) begin
                if (mem_req) begin
                    busy_reg      <= 1'b1;
                    latched_write <= mem_write;
                    latched_addr  <= mem_addr;
                    latched_wdata <= mem_wdata;

                    if (MEM_LATENCY < 1)
                        cycles_left <= 1;
                    else
                        cycles_left <= MEM_LATENCY;
                end
            end
            else begin
                if (cycles_left > 1) begin
                    cycles_left <= cycles_left - 1;
                end
                else begin
                    base_word = latched_addr >> 2;

                    if (latched_addr[3:0] != 4'b0000) begin
                        $display("WARNING(main_memory): address %h is not 16-byte aligned at time %0t",
                                 latched_addr, $time);
                    end

                    if ((base_word < 0) || ((base_word + 3) >= WORD_COUNT)) begin
                        $display("ERROR(main_memory): address %h is outside the implemented memory at time %0t",
                                 latched_addr, $time);
                        mem_rdata <= {LINE_WIDTH{1'b0}};
                    end
                    else if (latched_write) begin
                        memory[base_word]     <= latched_wdata[31:0];
                        memory[base_word + 1] <= latched_wdata[63:32];
                        memory[base_word + 2] <= latched_wdata[95:64];
                        memory[base_word + 3] <= latched_wdata[127:96];
                    end
                    else begin
                        mem_rdata <= {
                            memory[base_word + 3],
                            memory[base_word + 2],
                            memory[base_word + 1],
                            memory[base_word]
                        };
                    end

                    busy_reg    <= 1'b0;
                    cycles_left <= 0;
                    mem_ready   <= 1'b1;
                end
            end
        end
    end

endmodule
