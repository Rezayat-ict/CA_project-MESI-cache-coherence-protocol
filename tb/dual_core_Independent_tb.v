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

    // Instantiate the dual-core system with independent test programs
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

    always #5 clk = ~clk; // clock period is 10ns

    initial begin

        clk = 0;
        reset = 1;

        #20;
        reset = 0;
        
        $display("--------------------------------------------------");
        $display("Simulation Started: dual_core_Independent Testbench");
        $display("--------------------------------------------------");

        // Run simulation for enough cycles for vector processing and loops to complete
        #5000; // Adjust this value based on the expected execution time of the programs

        $display("--------------------------------------------------");
        $display("Checking Register Values at the End of Simulation:");
        $display("--------------------------------------------------");

        // Checking Core 0 registers based on assembly program:
        $display("Core 0 Register Check (Vector Processing):");
        $display("  $t1 (R9)  = %0d (Expected: 5)",  dut.core0.rf_inst.rf[9]);
        $display("  $t2 (R10) = %0d (Expected: 5)",  dut.core0.rf_inst.rf[10]);
        $display("  $t3 (R11) = %0d (Expected: 5)",  dut.core0.rf_inst.rf[11]);
        $display("  $t4 (R12) = %0d (Expected: 0)",  dut.core0.rf_inst.rf[12]);
        $display("  $t5 (R13) = %0d (Expected: 0)",  dut.core0.rf_inst.rf[13]);
        $display("  $t6 (R14) = %0d (Expected: 0)",  dut.core0.rf_inst.rf[14]);
        $display("  $s0 (R16) = %0d (Expected: 5)",  dut.core0.rf_inst.rf[16]);
        $display("  $s1 (R17) = %0d (Expected: 5)",  dut.core0.rf_inst.rf[17]);
        $display("  $s2 (R18) = %0d (Expected: 5)",  dut.core0.rf_inst.rf[18]);

        // Checking Core 1 registers based on assembly program:
        $display("--------------------------------------------------");
        $display("Core 1 Register Check (Vector Loop Processing):");
        $display("  $s4 (R20) = %0d (Expected: 0)",  dut.core1.rf_inst.rf[20]);
        $display("  $t7 (R15) = %0d (Expected: 1)",  dut.core1.rf_inst.rf[15]);
        $display("  $s1 (R17) = %0d (Expected: 33)", dut.core1.rf_inst.rf[17]);
        $display("  $s2 (R18) = %0d (Expected: 1)",  dut.core1.rf_inst.rf[18]);
        $display("  $t0 (R8)  = %0d (Expected: 0)",  dut.core1.rf_inst.rf[8]);
        $display("  $t1 (R9)  = %0d (Expected: 1)",  dut.core1.rf_inst.rf[9]);
        $display("  $t2 (R10) = %0d (Expected: 0)",  dut.core1.rf_inst.rf[10]);
        $display("  $t3 (R11) = %0d (Expected: 1)",  dut.core1.rf_inst.rf[11]);
        $display("--------------------------------------------------");

        $display("Simulation Finished.");
        $finish;
    end

    // Monitor bus activity during the independent execution of both cores
    initial begin
        $monitor("Time=%0t | Reset=%b | Bus_Busy=%b | Bus_Owner=%b", 
                 $time, reset, bus_busy, bus_owner);
    end

endmodule