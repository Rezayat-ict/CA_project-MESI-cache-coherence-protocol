module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alu_control)
            3'b000: result = a & b;                       // AND, ANDI
            3'b001: result = a | b;                       // OR, ORI
            3'b010: result = a + b;                       // ADD, ADDI, LW, SW
            3'b110: result = a - b;                       // SUB, BEQ, BNE
            3'b111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
            default: result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0);
endmodule