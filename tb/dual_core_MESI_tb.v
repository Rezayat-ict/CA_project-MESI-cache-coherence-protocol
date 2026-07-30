`timescale 1ns/1ps

module dual_core_MESI_tb;

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

    // Instantiate the dual-core system
    dual_core_system #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .WORD_COUNT(WORD_COUNT),
        .MEM_LATENCY(MEM_LATENCY),
        .INIT_FILE_0("../programs/Core0_MESI_Test_decoded.txt"), // Path to decoded instruction files
        .INIT_FILE_1("../programs/Core1_MESI_Test_decoded.txt")  // Path to decoded instruction files
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
        $display("Simulation Started: dual_core_MESI Testbench");
        $display("--------------------------------------------------");

        // Run simulation for enough cycles for both cores to complete their programs
        #1500; // Adjust this value based on the expected execution time of the programs

        $display("--------------------------------------------------");
        $display("Checking Register Values at the End of Simulation:");
        $display("--------------------------------------------------");

        // Checking Core 0 registers based on assembly program:
        // $t0 (Reg 8) = 43, $t1 (Reg 9) = 0, $t2 (Reg 10) = 43
        $display("Core 0 Register Check:");
        $display("  $t0 (R8)  = %0d (Expected: 43)", dut.core0.rf_inst.rf[8]);
        $display("  $t1 (R9)  = %0d (Expected: 0)",  dut.core0.rf_inst.rf[9]);
        $display("  $t2 (R10) = %0d (Expected: 43)", dut.core0.rf_inst.rf[10]);

        // Checking Core 1 registers based on assembly program:
        // $s0 (Reg 16) = 42, $s1 (Reg 17) = 0, $s2 (Reg 18) = 0, $s3 (Reg 19) = 99, $t1 (Reg 9) = 99
        $display("--------------------------------------------------");
        $display("Core 1 Register Check:");
        $display("  $s0 (R16) = %0d (Expected: 42)", dut.core1.rf_inst.rf[16]);
        $display("  $s1 (R17) = %0d (Expected: 0)",  dut.core1.rf_inst.rf[17]);
        $display("  $s2 (R18) = %0d (Expected: 0)",  dut.core1.rf_inst.rf[18]);
        $display("  $s3 (R19) = %0d (Expected: 99)", dut.core1.rf_inst.rf[19]);
        $display("  $t1 (R9)  = %0d (Expected: 99)", dut.core1.rf_inst.rf[9]);
        $display("--------------------------------------------------");

        $display("Simulation Finished.");
        $finish;
    end

    //Monitor bus activity during the MESI protocol execution
    initial begin
        $monitor("Time=%0t | Reset=%b | Bus_Busy=%b | Bus_Owner=%b", 
                 $time, reset, bus_busy, bus_owner);
    end

endmodule