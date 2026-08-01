`timescale 1ns / 1ps

module core_tb;

    reg         clk;
    reg         rst;
    wire [31:0] instr_addr;
    reg  [31:0] instr_data;
    wire        mem_read;
    wire        mem_write;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;  
    reg         cpu_ready;

    reg [2:0] wait_cycles;
    integer i;

    mips_core uut (
        .clk(clk),
        .rst(rst),
        .instr_addr(instr_addr),
        .instr_data(instr_data),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .cpu_ready(cpu_ready)
    );

    reg [31:0] instr_mem [0:63];
    reg [31:0] data_mem  [0:63];

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    always @(*) begin
        instr_data = instr_mem[instr_addr >> 2];
    end

    always @(posedge clk) begin
        if (rst) begin
            wait_cycles <= 0;
        end 
        else begin
            if (mem_read || mem_write) begin
                if (wait_cycles == 0) wait_cycles <= 3;
                else if (wait_cycles > 0) wait_cycles <= wait_cycles - 1;
                
                if (wait_cycles == 1) begin
                    if (mem_write) begin
                        data_mem[mem_addr >> 2] <= mem_wdata;
                        $display("Time: %0t | WRITE: mem[%0d] = %0d", $time, mem_addr, mem_wdata);
                    end
                    if (mem_read) begin
                        $display("Time: %0t | READ : mem[%0d] = %0d", $time, mem_addr, data_mem[mem_addr >> 2]);
                    end
                end
            end else begin
                wait_cycles <= 0;
            end
        end
    end

    always @(*) begin
        if ((mem_read || mem_write) && (wait_cycles != 1))
            cpu_ready = 1'b0;
        else
            cpu_ready = 1'b1;
    end

    assign mem_rdata = (mem_read && wait_cycles == 1) ? data_mem[mem_addr >> 2] : 32'd0;

    always @(posedge clk) begin
        if (!rst) begin
            $display("T=%0t | PC=%h Instr=%h | stallM=%b stallW=%b cpu_ready=%b",
                     $time, uut.pcF, uut.instrD, uut.stallM, uut.stallW, cpu_ready);
        end
    end

    initial begin
        for (i = 0; i < 64; i = i + 1) data_mem[i] = 0;

        instr_mem[0] = 32'h2001000f; // addi $1, $0, 15
        instr_mem[1] = 32'hac010004; // sw   $1, 4($0)
        instr_mem[2] = 32'h8c020004; // lw   $2, 4($0)
        instr_mem[3] = 32'h00221820; // add  $3, $1, $2
        instr_mem[4] = 32'h08000004; // j    0x10 

        rst = 1;
        #15;
        rst = 0;

        #300; 

        $display("========================================");
        $display("Time: %0t | Test Finished.", $time);
        $display("Final register values:");
        $display("$1 = %0d", uut.rf_inst.rf[1]);
        $display("$2 = %0d", uut.rf_inst.rf[2]);
        $display("$3 = %0d", uut.rf_inst.rf[3]);
        $display("========================================");

        if (uut.rf_inst.rf[3] == 32'd30)
            $display("Test PASSED: $3 = 30");
        else
            $display("Test FAILED: $3 = %0d (expected 30)", uut.rf_inst.rf[3]);

        $stop;
    end
endmodule