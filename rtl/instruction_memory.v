`timescale 1ns / 1ps

module instruction_memory #(
    parameter MEM_SIZE = 256
    parameter INIT_FILE = "instructions.txt"
)(
    input wire [31:0] addr,
    output reg [31:0] instruction
);

    reg [31:0] mem [0:MEM_SIZE-1];

    integer file_id;
    integer scan_result;
    integer num_instructions;
    integer i;

    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 32'b0;
        end

        file_id = $fopen(INIT_FILE, "r");
        if (file_id == 0) begin
            $display("Error: Could not open instruction file %s", INIT_FILE);
            $finish;
        end

        scan_result = $fscanf(file_id, "%d", num_instructions);
        if (scan_result != 1) begin
            $display("Error: Could not read number of instructions from file %s", INIT_FILE);
            $fclose(file_id);
            $finish;
        end

        $display("Loading %d instructions from file %s", num_instructions, INIT_FILE);

        for (i = 0;(i < num_instructions && i < MEM_SIZE); i = i + 1) begin
            scan_result = $fscanf(file_id, "%b\n", mem[i]);
            if (scan_result != 1) begin
                $display("Error: Could not read instruction %d from file %s", i, INIT_FILE);
                $fclose(file_id);
                $finish;
            end
        end

        $fclose(file_id);
    end

    always @(*) begin
        if (addr < 4 * MEM_SIZE) begin
            instruction = mem[addr>>2];
        end else begin
            instruction = 32'b0;
        end
    end
    