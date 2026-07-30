`timescale 1ns/1ps
`include "bus_defs.vh"

module tb_person3_extended;

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

    reg fake0_hit;
    reg fake0_dirty;
    reg [127:0] fake0_data;
    reg fake1_hit;
    reg fake1_dirty;
    reg [127:0] fake1_data;

    reg [`BUS_CMD_WIDTH-1:0] last_snoop_cmd0;
    reg [`BUS_CMD_WIDTH-1:0] last_snoop_cmd1;
    reg [31:0] last_snoop_addr0;
    reg [31:0] last_snoop_addr1;

    reg fail_flag;
    reg [127:0] task_rdata;
    reg task_shared;
    integer guard;

    person3_subsystem #(
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
            cache0_snoop_hit <= 1'b0;
            cache0_snoop_dirty <= 1'b0;
            cache0_snoop_data <= 128'b0;
            last_snoop_cmd0 <= `BUS_NONE;
            last_snoop_addr0 <= 32'b0;
        end
        else begin
            cache0_snoop_response_valid <= 1'b0;
            if (cache0_snoop_valid) begin
                cache0_snoop_response_valid <= 1'b1;
                cache0_snoop_hit <= fake0_hit;
                cache0_snoop_dirty <= fake0_dirty;
                cache0_snoop_data <= fake0_data;
                last_snoop_cmd0 <= cache0_snoop_cmd;
                last_snoop_addr0 <= cache0_snoop_addr;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            cache1_snoop_response_valid <= 1'b0;
            cache1_snoop_hit <= 1'b0;
            cache1_snoop_dirty <= 1'b0;
            cache1_snoop_data <= 128'b0;
            last_snoop_cmd1 <= `BUS_NONE;
            last_snoop_addr1 <= 32'b0;
        end
        else begin
            cache1_snoop_response_valid <= 1'b0;
            if (cache1_snoop_valid) begin
                cache1_snoop_response_valid <= 1'b1;
                cache1_snoop_hit <= fake1_hit;
                cache1_snoop_dirty <= fake1_dirty;
                cache1_snoop_data <= fake1_data;
                last_snoop_cmd1 <= cache1_snoop_cmd;
                last_snoop_addr1 <= cache1_snoop_addr;
            end
        end
    end

    task issue_cache0;
        input [`BUS_CMD_WIDTH-1:0] command;
        input [31:0] address;
        input [127:0] write_data;
        begin
            @(negedge clk);
            cache0_cmd = command;
            cache0_addr = address;
            cache0_wdata = write_data;
            cache0_req = 1'b1;

            guard = 0;
            while (!cache0_done && guard < 100) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (!cache0_done) begin
                $display("FAIL Extended: timeout waiting for Cache 0 done");
                fail_flag = 1'b1;
                task_rdata = 128'bx;
                task_shared = 1'bx;
            end
            else begin
                task_rdata = cache0_rdata;
                task_shared = cache0_shared;
            end

            cache0_req = 1'b0;
            @(negedge clk);
        end
    endtask

    task issue_cache1;
        input [`BUS_CMD_WIDTH-1:0] command;
        input [31:0] address;
        input [127:0] write_data;
        begin
            @(negedge clk);
            cache1_cmd = command;
            cache1_addr = address;
            cache1_wdata = write_data;
            cache1_req = 1'b1;

            guard = 0;
            while (!cache1_done && guard < 100) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (!cache1_done) begin
                $display("FAIL Extended: timeout waiting for Cache 1 done");
                fail_flag = 1'b1;
                task_rdata = 128'bx;
                task_shared = 1'bx;
            end
            else begin
                task_rdata = cache1_rdata;
                task_shared = cache1_shared;
            end

            cache1_req = 1'b0;
            @(negedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        cache0_req = 1'b0;
        cache0_cmd = `BUS_NONE;
        cache0_addr = 32'b0;
        cache0_wdata = 128'b0;
        cache1_req = 1'b0;
        cache1_cmd = `BUS_NONE;
        cache1_addr = 32'b0;
        cache1_wdata = 128'b0;

        fake0_hit = 1'b0;
        fake0_dirty = 1'b0;
        fake0_data = 128'b0;
        fake1_hit = 1'b0;
        fake1_dirty = 1'b0;
        fake1_data = 128'b0;

        fail_flag = 1'b0;
        task_rdata = 128'b0;
        task_shared = 1'b0;
        guard = 0;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        issue_cache0(
            `BUS_WB,
            32'h0000_0200,
            128'h44444444_33333333_22222222_11111111
        );

        fake1_hit = 1'b1;
        fake1_dirty = 1'b0;

        issue_cache0(`BUS_RDX, 32'h0000_0204, 128'b0);

        if (task_rdata !== 128'h44444444_33333333_22222222_11111111) begin
            $display("FAIL Extended A: BUS_RDX clean case returned wrong line");
            fail_flag = 1'b1;
        end
        if (task_shared !== 1'b1) begin
            $display("FAIL Extended A: BUS_RDX clean case must report snoop hit");
            fail_flag = 1'b1;
        end
        if (last_snoop_cmd1 !== `BUS_RDX || last_snoop_addr1 !== 32'h0000_0200) begin
            $display("FAIL Extended A: wrong BUS_RDX snoop command or aligned address");
            fail_flag = 1'b1;
        end

        fake0_hit = 1'b1;
        fake0_dirty = 1'b1;
        fake0_data = 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA;

        issue_cache1(`BUS_RDX, 32'h0000_020C, 128'b0);

        if (task_rdata !== 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA) begin
            $display("FAIL Extended B: BUS_RDX dirty case returned wrong line");
            fail_flag = 1'b1;
        end
        if (task_shared !== 1'b1) begin
            $display("FAIL Extended B: BUS_RDX dirty case must report snoop hit");
            fail_flag = 1'b1;
        end
        if (dut.memory_unit.memory[128] !== 32'hAAAAAAAA ||
            dut.memory_unit.memory[129] !== 32'hBBBBBBBB ||
            dut.memory_unit.memory[130] !== 32'hCCCCCCCC ||
            dut.memory_unit.memory[131] !== 32'hDDDDDDDD) begin
            $display("FAIL Extended B: dirty BUS_RDX data was not written to memory");
            fail_flag = 1'b1;
        end
        if (last_snoop_cmd0 !== `BUS_RDX || last_snoop_addr0 !== 32'h0000_0200) begin
            $display("FAIL Extended B: wrong dirty BUS_RDX snoop command/address");
            fail_flag = 1'b1;
        end

        fake1_hit = 1'b0;
        fake1_dirty = 1'b0;

        issue_cache0(`BUS_RDX, 32'h0000_0208, 128'b0);

        if (task_rdata !== 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA) begin
            $display("FAIL Extended C: BUS_RDX miss returned wrong memory line");
            fail_flag = 1'b1;
        end
        if (task_shared !== 1'b0) begin
            $display("FAIL Extended C: BUS_RDX miss must report shared=0");
            fail_flag = 1'b1;
        end

        @(negedge clk);
        cache0_cmd = `BUS_RD;
        cache0_addr = 32'h0000_0200;
        cache0_wdata = 128'b0;
        cache0_req = 1'b1;

        guard = 0;
        while ((debug_bus_state != 4'd7) && guard < 50) begin
            @(negedge clk);
            guard = guard + 1;
        end

        if (guard >= 50) begin
            $display("FAIL Extended D: transaction did not reach memory-read wait state");
            fail_flag = 1'b1;
        end

        reset = 1'b1;
        cache0_req = 1'b0;
        repeat (2) @(negedge clk);

        if (bus_busy !== 1'b0 || cache0_grant !== 1'b0 ||
            cache1_grant !== 1'b0 || cache0_done !== 1'b0 ||
            cache1_done !== 1'b0) begin
            $display("FAIL Extended D: reset did not return bus to idle outputs");
            fail_flag = 1'b1;
        end

        reset = 1'b0;
        fake1_hit = 1'b0;
        fake1_dirty = 1'b0;
        issue_cache0(`BUS_RD, 32'h0000_0200, 128'b0);

        if (task_rdata !== 128'hDDDDDDDD_CCCCCCCC_BBBBBBBB_AAAAAAAA) begin
            $display("FAIL Extended D: bus did not recover correctly after reset");
            fail_flag = 1'b1;
        end

        if (fail_flag)
            $display("tb_person3_extended: FAILED");
        else
            $display("tb_person3_extended: PASSED");

        #20;
        $finish;
    end

    always @(posedge clk) begin
        if (!reset && cache0_grant && cache1_grant) begin
            $display("FAIL Extended: simultaneous grants at time %0t", $time);
            fail_flag <= 1'b1;
        end
    end

    initial begin
        #5000;
        $display("tb_person3_extended: FAILED (global timeout)");
        $finish;
    end

endmodule
