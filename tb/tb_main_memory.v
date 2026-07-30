`timescale 1ns/1ps

module tb_main_memory;

    reg clk;
    reg reset;
    reg mem_req;
    reg mem_write;
    reg [31:0] mem_addr;
    reg [127:0] mem_wdata;

    wire [127:0] mem_rdata;
    wire mem_ready;
    wire mem_busy;

    reg fail_flag;
    reg [127:0] read_value;

    main_memory #(
        .MEM_LATENCY(2),
        .INIT_FILE("")
    ) dut (
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_line;
        input [31:0] address;
        input [127:0] data;
        begin
            @(negedge clk);
            mem_addr  = address;
            mem_wdata = data;
            mem_write = 1'b1;
            mem_req   = 1'b1;

            @(negedge clk);
            mem_req = 1'b0;

            while (!mem_ready)
                @(negedge clk);
        end
    endtask

    task read_line;
        input [31:0] address;
        begin
            @(negedge clk);
            mem_addr  = address;
            mem_write = 1'b0;
            mem_req   = 1'b1;

            @(negedge clk);
            mem_req = 1'b0;

            while (!mem_ready)
                @(negedge clk);

            read_value = mem_rdata;
        end
    endtask

    initial begin
        reset      = 1'b1;
        mem_req    = 1'b0;
        mem_write  = 1'b0;
        mem_addr   = 32'b0;
        mem_wdata  = 128'b0;
        fail_flag  = 1'b0;
        read_value = 128'b0;

        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        reset = 1'b0;

        write_line(
            32'h0000_0100,
            128'h44444444_33333333_22222222_11111111
        );

        read_line(32'h0000_0100);

        if (read_value != 128'h44444444_33333333_22222222_11111111) begin
            $display("FAIL: line read-back is wrong: %h", read_value);
            fail_flag = 1'b1;
        end

        if (dut.memory[64] != 32'h11111111 ||
            dut.memory[65] != 32'h22222222 ||
            dut.memory[66] != 32'h33333333 ||
            dut.memory[67] != 32'h44444444) begin
            $display("FAIL: word ordering inside main memory is wrong");
            fail_flag = 1'b1;
        end

        if (fail_flag)
            $display("tb_main_memory: FAILED");
        else
            $display("tb_main_memory: PASSED");

        #20;
        $finish;
    end

endmodule
