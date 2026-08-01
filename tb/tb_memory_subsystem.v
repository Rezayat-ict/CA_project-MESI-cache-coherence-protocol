`timescale 1ns/1ps
`include "bus_defs.vh"

module tb_memory_subsystem;

    reg clk;
    reg reset;

    reg cache0_req;
    reg [`BUS_CMD_WIDTH-1:0] cache0_cmd;
    reg [31:0] cache0_addr;
    reg [127:0] cache0_wdata;
    wire cache0_grant;
    wire cache0_done;
    wire [127:0] cache0_rdata;
    wire cache0_shared;

    reg cache1_req;
    reg [`BUS_CMD_WIDTH-1:0] cache1_cmd;
    reg [31:0] cache1_addr;
    reg [127:0] cache1_wdata;
    wire cache1_grant;
    wire cache1_done;
    wire [127:0] cache1_rdata;
    wire cache1_shared;

    wire cache0_snoop_valid;
    wire [`BUS_CMD_WIDTH-1:0] cache0_snoop_cmd;
    wire [31:0] cache0_snoop_addr;
    reg cache0_snoop_response_valid;
    reg cache0_snoop_hit;
    reg cache0_snoop_dirty;
    reg [127:0] cache0_snoop_data;

    wire cache1_snoop_valid;
    wire [`BUS_CMD_WIDTH-1:0] cache1_snoop_cmd;
    wire [31:0] cache1_snoop_addr;
    reg cache1_snoop_response_valid;
    reg cache1_snoop_hit;
    reg cache1_snoop_dirty;
    reg [127:0] cache1_snoop_data;

    wire bus_busy;
    wire bus_owner;
    wire [`BUS_CMD_WIDTH-1:0] debug_bus_cmd;
    wire [31:0] debug_bus_addr;
    wire [3:0] debug_bus_state;

    // Configurations used by the fake snoop responders.
    reg fake0_hit;
    reg fake0_dirty;
    reg [127:0] fake0_data;

    reg fake1_hit;
    reg fake1_dirty;
    reg [127:0] fake1_data;

    reg fail_flag;
    reg [127:0] task_rdata;
    reg task_shared;
    reg first_grant_owner;
    reg second_grant_owner;

    memory_subsystem #(
        .MEM_LATENCY(2),
        .INIT_FILE("")
    ) dut (
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

        .bus_busy(bus_busy),
        .bus_owner(bus_owner),
        .debug_bus_cmd(debug_bus_cmd),
        .debug_bus_addr(debug_bus_addr),
        .debug_bus_state(debug_bus_state)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (reset) begin
            cache0_snoop_response_valid <= 1'b0;
            cache0_snoop_hit            <= 1'b0;
            cache0_snoop_dirty          <= 1'b0;
            cache0_snoop_data           <= 128'b0;
        end
        else begin
            cache0_snoop_response_valid <= 1'b0;

            if (cache0_snoop_valid) begin
                cache0_snoop_response_valid <= 1'b1;
                cache0_snoop_hit            <= fake0_hit;
                cache0_snoop_dirty          <= fake0_dirty;
                cache0_snoop_data           <= fake0_data;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            cache1_snoop_response_valid <= 1'b0;
            cache1_snoop_hit            <= 1'b0;
            cache1_snoop_dirty          <= 1'b0;
            cache1_snoop_data           <= 128'b0;
        end
        else begin
            cache1_snoop_response_valid <= 1'b0;

            if (cache1_snoop_valid) begin
                cache1_snoop_response_valid <= 1'b1;
                cache1_snoop_hit            <= fake1_hit;
                cache1_snoop_dirty          <= fake1_dirty;
                cache1_snoop_data           <= fake1_data;
            end
        end
    end

    task issue_cache0;
        input [`BUS_CMD_WIDTH-1:0] command;
        input [31:0] address;
        input [127:0] write_data;
        begin
            @(negedge clk);
            cache0_cmd   = command;
            cache0_addr  = address;
            cache0_wdata = write_data;
            cache0_req   = 1'b1;

            while (!cache0_done)
                @(negedge clk);

            task_rdata  = cache0_rdata;
            task_shared = cache0_shared;
            cache0_req   = 1'b0;

            @(negedge clk);
        end
    endtask

    task issue_cache1;
        input [`BUS_CMD_WIDTH-1:0] command;
        input [31:0] address;
        input [127:0] write_data;
        begin
            @(negedge clk);
            cache1_cmd   = command;
            cache1_addr  = address;
            cache1_wdata = write_data;
            cache1_req   = 1'b1;

            while (!cache1_done)
                @(negedge clk);

            task_rdata  = cache1_rdata;
            task_shared = cache1_shared;
            cache1_req   = 1'b0;

            @(negedge clk);
        end
    endtask

    initial begin
        reset         = 1'b1;
        cache0_req    = 1'b0;
        cache0_cmd    = `BUS_NONE;
        cache0_addr   = 32'b0;
        cache0_wdata  = 128'b0;
        cache1_req    = 1'b0;
        cache1_cmd    = `BUS_NONE;
        cache1_addr   = 32'b0;
        cache1_wdata  = 128'b0;

        fake0_hit     = 1'b0;
        fake0_dirty   = 1'b0;
        fake0_data    = 128'b0;
        fake1_hit     = 1'b0;
        fake1_dirty   = 1'b0;
        fake1_data    = 128'b0;

        fail_flag         = 1'b0;
        task_rdata        = 128'b0;
        task_shared       = 1'b0;
        first_grant_owner = 1'b0;
        second_grant_owner = 1'b0;

        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        reset = 1'b0;

        issue_cache0(
            `BUS_WB,
            32'h0000_0100,
            128'h44444444_33333333_22222222_11111111
        );

        if (dut.memory_unit.memory[64] != 32'h11111111 ||
            dut.memory_unit.memory[65] != 32'h22222222 ||
            dut.memory_unit.memory[66] != 32'h33333333 ||
            dut.memory_unit.memory[67] != 32'h44444444) begin
            $display("FAIL Test 1: BUS_WB did not update main memory");
            fail_flag = 1'b1;
        end

        fake1_hit   = 1'b0;
        fake1_dirty = 1'b0;

        issue_cache0(
            `BUS_RD,
            32'h0000_0104, // Bus must align this to 0x100.
            128'b0
        );

        if (task_rdata != 128'h44444444_33333333_22222222_11111111) begin
            $display("FAIL Test 2: BUS_RD returned wrong line: %h", task_rdata);
            fail_flag = 1'b1;
        end

        if (task_shared != 1'b0) begin
            $display("FAIL Test 2: shared must be zero when the other cache misses");
            fail_flag = 1'b1;
        end

        fake0_hit   = 1'b1;
        fake0_dirty = 1'b0;

        issue_cache1(
            `BUS_RD,
            32'h0000_0108,
            128'b0
        );

        if (task_rdata != 128'h44444444_33333333_22222222_11111111) begin
            $display("FAIL Test 3: clean shared read returned wrong data");
            fail_flag = 1'b1;
        end

        if (task_shared != 1'b1) begin
            $display("FAIL Test 3: shared must be one when the other cache hits");
            fail_flag = 1'b1;
        end

        fake0_hit   = 1'b1;
        fake0_dirty = 1'b1;
        fake0_data  = 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA;

        issue_cache1(
            `BUS_RD,
            32'h0000_0100,
            128'b0
        );

        if (task_rdata != 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA) begin
            $display("FAIL Test 4: dirty owner data was not returned correctly");
            fail_flag = 1'b1;
        end

        if (dut.memory_unit.memory[64] != 32'hAAAAAAAA ||
            dut.memory_unit.memory[65] != 32'hBBBBBBBB ||
            dut.memory_unit.memory[66] != 32'hCCCCCCCC ||
            dut.memory_unit.memory[67] != 32'hDDDDDDDD) begin
            $display("FAIL Test 4: dirty snoop data was not written back");
            fail_flag = 1'b1;
        end

        fake1_hit   = 1'b1;
        fake1_dirty = 1'b0;

        issue_cache0(
            `BUS_UPGR,
            32'h0000_0100,
            128'b0
        );

        if (task_shared != 1'b1) begin
            $display("FAIL Test 5: BUS_UPGR did not report the snoop hit");
            fail_flag = 1'b1;
        end

        // Clear fake-cache states before arbitration testing.
        fake0_hit   = 1'b0;
        fake0_dirty = 1'b0;
        fake1_hit   = 1'b0;
        fake1_dirty = 1'b0;

        @(negedge clk);
        cache0_cmd   = `BUS_RD;
        cache0_addr  = 32'h0000_0100;
        cache0_wdata = 128'b0;
        cache0_req   = 1'b1;

        cache1_cmd   = `BUS_RD;
        cache1_addr  = 32'h0000_0100;
        cache1_wdata = 128'b0;
        cache1_req   = 1'b1;

        while (!(cache0_grant || cache1_grant))
            @(negedge clk);

        first_grant_owner = cache1_grant;

        if (first_grant_owner != 1'b1) begin
            $display("FAIL Test 6: Cache 1 should win the first simultaneous request");
            fail_flag = 1'b1;
        end

        while (!(cache0_done || cache1_done))
            @(negedge clk);

        if (cache1_done)
            cache1_req = 1'b0;
        else
            cache0_req = 1'b0;

        while (!(cache0_grant || cache1_grant))
            @(negedge clk);

        second_grant_owner = cache1_grant;

        if (second_grant_owner != 1'b0) begin
            $display("FAIL Test 6: Cache 0 should receive the remaining request");
            fail_flag = 1'b1;
        end

        while (!(cache0_done || cache1_done))
            @(negedge clk);

        cache0_req = 1'b0;
        cache1_req = 1'b0;

        @(negedge clk);

        if (cache0_grant && cache1_grant) begin
            $display("FAIL: both grants are active simultaneously");
            fail_flag = 1'b1;
        end

        if (fail_flag)
            $display("tb_memory_subsystem: FAILED");
        else
            $display("tb_memory_subsystem: PASSED");

        #20;
        $finish;
    end

    always @(posedge clk) begin
        if (!reset && cache0_grant && cache1_grant) begin
            $display("FAIL: simultaneous grants at time %0t", $time);
            fail_flag <= 1'b1;
        end
    end

endmodule
