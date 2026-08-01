`timescale 1ns/1ps

module dual_core_MESI_tb;

    parameter ADDR_WIDTH  = 32;
    parameter LINE_WIDTH  = 128;
    parameter WORD_COUNT  = 1024;
    parameter MEM_LATENCY = 2;

    reg clk;
    reg reset;
    wire bus_busy;
    wire bus_owner;

    integer test_pass;

    task check_reg;
        input [255:0] reg_name;
        input [31:0] actual;
        input [31:0] expected;
    begin
        if (actual === expected)
            $display("[PASS] %-12s = %0d", reg_name, actual);
        else begin
            $display("[FAIL] %-12s = %0d (Expected %0d)",
                     reg_name, actual, expected);
            test_pass = 0;
        end
    end
    endtask

    dual_core_system #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .WORD_COUNT(WORD_COUNT),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE_0("../programs/Core0_MESI_Test_decoded.txt"),
        .INIT_FILE_1("../programs/Core1_MESI_Test_decoded.txt")
    ) dut (
        .clk(clk),
        .reset(reset),
        .bus_busy(bus_busy),
        .bus_owner(bus_owner)
    );

    always #5 clk = ~clk; // clock period is 10 ns

    initial begin

        clk = 0;
        reset = 1;
        test_pass = 1;

        #20;
        reset = 0;

        $display("\n==================================================");
        $display("   Simulation Started : dual_core_MESI_tb");
        $display("==================================================");

        #5000;

        $display("");
        $display("==================================================");
        $display("Checking Core 0 Registers");
        $display("==================================================");

        check_reg("$t0 (R8)",  dut.core0.rf_inst.rf[8],  43);
        check_reg("$t1 (R9)",  dut.core0.rf_inst.rf[9],   0);
        check_reg("$t2 (R10)", dut.core0.rf_inst.rf[10], 43);

        $display("");
        $display("==================================================");
        $display("Checking Core 1 Registers");
        $display("==================================================");

        check_reg("$s0 (R16)", dut.core1.rf_inst.rf[16], 42);
        check_reg("$s1 (R17)", dut.core1.rf_inst.rf[17], 0);
        check_reg("$s2 (R18)", dut.core1.rf_inst.rf[18], 0);
        check_reg("$s3 (R19)", dut.core1.rf_inst.rf[19], 99);
        check_reg("$t1 (R9)",  dut.core1.rf_inst.rf[9],  99);

        $display("");
        $display("==================================================");

        if (test_pass)
            $display("                TEST PASSED                ");
        else
            $display("                TEST FAILED                ");

        $display("==================================================");

        $finish;
    end

endmodule