`timescale 1ns/1ps

module dual_core_Independent_tb;

    // Parameters
    parameter ADDR_WIDTH  = 32;
    parameter LINE_WIDTH  = 128;
    parameter WORD_COUNT  = 1024;
    parameter MEM_LATENCY = 2;

    // Testbench signals
    reg clk;
    reg reset;
    wire bus_busy;
    wire bus_owner;

    integer error_count;

    task check_reg;
        input [255:0] core_name;
        input [255:0] reg_name;
        input integer actual;
        input integer expected;
        begin
            if (actual == expected)
                $display("[PASS] %-6s %-10s = %0d",
                         core_name, reg_name, actual);
            else begin
                $display("[FAIL] %-6s %-10s = %0d (Expected %0d)",
                         core_name, reg_name, actual, expected);
                error_count = error_count + 1;
            end
        end
    endtask

    dual_core_system #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .WORD_COUNT(WORD_COUNT),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE_0("../programs/Core0_Independent_DualCore_Test_decoded.txt"),
        .INIT_FILE_1("../programs/Core1_Independent_DualCore_Test_decoded.txt")
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
        error_count = 0;

        #20;
        reset = 0;

        $display("\n==================================================");
        $display("   Dual Core Independent Testbench Started");
        $display("==================================================");

        #5000;

        $display("\n==================================================");
        $display("Register Verification");
        $display("==================================================");

        $display("\nCore 0:");

        check_reg("Core0","$t1(R9)" , dut.core0.rf_inst.rf[9] , 5);
        check_reg("Core0","$t2(R10)", dut.core0.rf_inst.rf[10], 5);
        check_reg("Core0","$t3(R11)", dut.core0.rf_inst.rf[11], 5);
        check_reg("Core0","$t4(R12)", dut.core0.rf_inst.rf[12], 0);
        check_reg("Core0","$t5(R13)", dut.core0.rf_inst.rf[13], 0);
        check_reg("Core0","$t6(R14)", dut.core0.rf_inst.rf[14], 0);
        check_reg("Core0","$s0(R16)", dut.core0.rf_inst.rf[16], 5);
        check_reg("Core0","$s1(R17)", dut.core0.rf_inst.rf[17], 5);
        check_reg("Core0","$s2(R18)", dut.core0.rf_inst.rf[18], 5);

        $display("\nCore 1:");

        check_reg("Core1","$s4(R20)", dut.core1.rf_inst.rf[20], 0);
        check_reg("Core1","$t7(R15)", dut.core1.rf_inst.rf[15], 1);
        check_reg("Core1","$s1(R17)", dut.core1.rf_inst.rf[17], 33);
        check_reg("Core1","$s2(R18)", dut.core1.rf_inst.rf[18], 1);
        check_reg("Core1","$t0(R8)" , dut.core1.rf_inst.rf[8] , 0);
        check_reg("Core1","$t1(R9)" , dut.core1.rf_inst.rf[9] , 1);
        check_reg("Core1","$t2(R10)", dut.core1.rf_inst.rf[10], 0);
        check_reg("Core1","$t3(R11)", dut.core1.rf_inst.rf[11], 1);

        $display("\n==================================================");

        if (error_count == 0)
            $display("*************** TEST PASSED ***************");
        else begin
           $display("*************** TEST FAILED ***************"); 
        end

        $display("Total Errors : %0d", error_count);
        $display("==================================================");

        $finish;
    end

endmodule