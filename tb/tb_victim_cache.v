`timescale 1ns/1ps
`include "bus_defs.vh"

module tb_victim_cache;

    reg clk;
    reg reset;

    reg         cpu_req;
    reg         cpu_write;
    reg [31:0]  cpu_addr;
    reg [31:0]  cpu_wdata;
    wire [31:0] cpu_rdata;
    wire        cpu_ready;

    wire         bus_req;
    wire [2:0]   bus_cmd;
    wire [31:0]  bus_addr;
    wire [127:0] bus_wdata;
    reg          bus_grant;
    reg          bus_done;
    reg [127:0]  bus_rdata;
    reg          bus_shared;

    reg          snoop_valid;
    reg [2:0]    snoop_cmd;
    reg [31:0]   snoop_addr;
    wire         snoop_response_valid;
    wire         snoop_hit;
    wire         snoop_dirty;
    wire [127:0] snoop_data;

    localparam MOCK_IDLE  = 2'd0;
    localparam MOCK_GRANT = 2'd1;
    localparam MOCK_DONE  = 2'd2;
    localparam MOCK_REARM = 2'd3;

    reg [1:0] mock_state;
    reg [2:0] latched_bus_cmd;
    reg [31:0] latched_bus_addr;
    reg [127:0] latched_bus_wdata;

    integer bus_transaction_count;
    integer memory_transaction_count;
    integer timeout_count;

    reg [127:0] memory_lines [0:31];

    integer i;

    cache2_bus_adapter dut (
        .clk(clk),
        .reset(reset),

        .cpu_req(cpu_req),
        .cpu_write(cpu_write),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),

        .bus_req(bus_req),
        .bus_cmd(bus_cmd),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),

        .bus_grant(bus_grant),
        .bus_done(bus_done),
        .bus_rdata(bus_rdata),
        .bus_shared(bus_shared),

        .snoop_valid(snoop_valid),
        .snoop_cmd(snoop_cmd),
        .snoop_addr(snoop_addr),
        .snoop_response_valid(snoop_response_valid),
        .snoop_hit(snoop_hit),
        .snoop_dirty(snoop_dirty),
        .snoop_data(snoop_data)
    );

    always #5 clk = ~clk;

    always @(*) begin
        bus_grant  = 1'b0;
        bus_done   = 1'b0;
        bus_rdata  = 128'b0;
        bus_shared = 1'b0;

        case (mock_state)
            MOCK_GRANT: begin
                bus_grant = 1'b1;
            end

            MOCK_DONE: begin
                bus_done = 1'b1;
                if ((latched_bus_cmd == `BUS_RD) ||
                    (latched_bus_cmd == `BUS_RDX))
                    bus_rdata = memory_lines[latched_bus_addr[8:4]];
            end

            default: begin
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mock_state            <= MOCK_IDLE;
            latched_bus_cmd       <= `BUS_NONE;
            latched_bus_addr      <= 32'b0;
            latched_bus_wdata     <= 128'b0;
            bus_transaction_count    <= 0;
            memory_transaction_count <= 0;
        end
        else begin
            case (mock_state)
                MOCK_IDLE: begin
                    if (bus_req) begin
                        latched_bus_cmd       <= bus_cmd;
                        latched_bus_addr      <= bus_addr;
                        latched_bus_wdata     <= bus_wdata;
                        bus_transaction_count <= bus_transaction_count + 1;
                        if (bus_cmd != `BUS_NONE)
                            memory_transaction_count <= memory_transaction_count + 1;
                        mock_state <= MOCK_GRANT;
                    end
                end

                MOCK_GRANT: begin
                    mock_state <= MOCK_DONE;
                end

                MOCK_DONE: begin
                    if (latched_bus_cmd == `BUS_WB)
                        memory_lines[latched_bus_addr[8:4]] <= latched_bus_wdata;
                    mock_state <= MOCK_REARM;
                end

                MOCK_REARM: begin
                    mock_state <= MOCK_IDLE;
                end

                default: begin
                    mock_state <= MOCK_IDLE;
                end
            endcase
        end
    end

    task automatic issue_read;
        input [31:0] address;
        input [31:0] expected_data;
        begin
            @(negedge clk);
            cpu_req   = 1'b1;
            cpu_write = 1'b0;
            cpu_addr  = address;
            cpu_wdata = 32'b0;

            timeout_count = 0;
            while (!cpu_ready && timeout_count < 200) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (!cpu_ready) begin
                $display("tb_victim_cache: FAILED - read timeout at address %h", address);
                $fatal;
            end

            if (cpu_rdata !== expected_data) begin
                $display("tb_victim_cache: FAILED - read %h expected %h got %h",
                         address, expected_data, cpu_rdata);
                $fatal;
            end

            @(negedge clk);
            cpu_req = 1'b0;
            @(negedge clk);
        end
    endtask

    task automatic issue_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(negedge clk);
            cpu_req   = 1'b1;
            cpu_write = 1'b1;
            cpu_addr  = address;
            cpu_wdata = data;

            timeout_count = 0;
            while (!cpu_ready && timeout_count < 200) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (!cpu_ready) begin
                $display("tb_victim_cache: FAILED - write timeout at address %h", address);
                $fatal;
            end

            @(negedge clk);
            cpu_req = 1'b0;
            @(negedge clk);
        end
    endtask

    task automatic send_snoop;
        input [2:0] command;
        input [31:0] address;
        begin
            @(negedge clk);
            snoop_valid = 1'b1;
            snoop_cmd   = command;
            snoop_addr  = address;
            @(negedge clk);
            snoop_valid = 1'b0;
            snoop_cmd   = `BUS_NONE;
            snoop_addr  = 32'b0;
            @(negedge clk);
        end
    endtask

    initial begin
        clk         = 1'b0;
        reset       = 1'b1;
        cpu_req     = 1'b0;
        cpu_write   = 1'b0;
        cpu_addr    = 32'b0;
        cpu_wdata   = 32'b0;
        snoop_valid = 1'b0;
        snoop_cmd   = `BUS_NONE;
        snoop_addr  = 32'b0;

        for (i = 0; i < 32; i = i + 1)
            memory_lines[i] = {4{32'h10000000 + i}};

        #25;
        reset = 1'b0;

        issue_read(32'h00000000, 32'h10000000);
        issue_read(32'h00000040, 32'h10000004);
        issue_read(32'h00000080, 32'h10000008);
        issue_read(32'h000000C0, 32'h1000000C);
        issue_read(32'h00000100, 32'h10000010);

        if (memory_transaction_count != 5) begin
            $display("tb_victim_cache: FAILED - expected 5 compulsory memory/coherence transactions, got %0d",
                     memory_transaction_count);
            $fatal;
        end

        issue_read(32'h00000000, 32'h10000000);

        if (memory_transaction_count != 5) begin
            $display("tb_victim_cache: FAILED - victim hit accessed main memory or coherence path");
            $fatal;
        end

        issue_write(32'h00000000, 32'hDEADBEEF);

        if (memory_transaction_count != 5) begin
            $display("tb_victim_cache: FAILED - E to M write hit accessed main memory or coherence path");
            $fatal;
        end

        issue_read(32'h00000040, 32'h10000004);

        if (memory_transaction_count != 6) begin
            $display("tb_victim_cache: FAILED - modified eviction should require one writeback only");
            $fatal;
        end

        issue_read(32'h00000000, 32'hDEADBEEF);

        if (memory_transaction_count != 6) begin
            $display("tb_victim_cache: FAILED - writeback-captured victim line missed");
            $fatal;
        end

        send_snoop(`BUS_RDX, 32'h00000040);
        issue_read(32'h00000040, 32'h10000004);

        if (memory_transaction_count != 7) begin
            $display("tb_victim_cache: FAILED - snoop invalidation did not remove victim line");
            $fatal;
        end

        $display("tb_victim_cache: PASSED");
        $finish;
    end

endmodule
