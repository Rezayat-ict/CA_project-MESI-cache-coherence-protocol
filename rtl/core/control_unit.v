module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output wire       reg_write,
    output wire       reg_dst,
    output wire       alu_src,
    output wire       branch,
    output wire       bne,
    output wire       mem_write,
    output wire       mem_read,
    output wire       mem_to_reg,
    output wire       jump,
    output reg  [2:0] alu_control
);
    wire [1:0] alu_op; 
    // Main Decoder
    assign {reg_write, reg_dst, alu_src, branch, bne, mem_write, mem_read, mem_to_reg, jump, alu_op[1], alu_op[0]} = 
        (opcode == 6'b000000) ? 11'b11000000010 : // R-Type (add, sub, and, or, slt)
        (opcode == 6'b001000) ? 11'b10100000000 : // addi
        (opcode == 6'b001101) ? 11'b10100000011 : // ori
        (opcode == 6'b100011) ? 11'b10100011000 : // lw
        (opcode == 6'b101011) ? 11'b00100100000 : // sw
        (opcode == 6'b000100) ? 11'b00010000001 : // beq
        (opcode == 6'b000101) ? 11'b00001000001 : // bne
        (opcode == 6'b000010) ? 11'b00000000100 : // j
                                11'b00000000000;  // Default

    // ALU Decoder
    always @(*) begin
        case (alu_op)
            2'b00: alu_control = 3'b010; // ADD (lw, sw, addi)
            2'b01: alu_control = 3'b110; // SUB (beq, bne)
            2'b11: alu_control = 3'b001; // OR (ori)
            2'b10: begin // R-Type
                case (funct)
                    6'b100000: alu_control = 3'b010; // add
                    6'b100010: alu_control = 3'b110; // sub
                    6'b100100: alu_control = 3'b000; // and
                    6'b100101: alu_control = 3'b001; // or
                    6'b101010: alu_control = 3'b111; // slt
                    default:   alu_control = 3'b010;
                endcase
            end
            default: alu_control = 3'b010;
        endcase
    end
endmodule