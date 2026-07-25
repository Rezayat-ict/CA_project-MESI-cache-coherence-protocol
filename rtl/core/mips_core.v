module mips_core (
    input  wire        clk,
    input  wire        rst,
    
    // Instruction Memory Interface
    output wire [31:0] instr_addr,
    input  wire [31:0] instr_data,
    
    // Data Cache Interface (Based on team agreement)
    output wire        mem_read,
    output wire        mem_write,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        cpu_ready
);

    // Pipeline Intermediate Signals
    reg  [31:0] pcF;
    wire [31:0] pc_next, pc_plus4F;
    
    reg  [31:0] instrD, pc_plus4D;
    wire [31:0] rd1D, rd2D, sign_immD, sign_imm_shiftedD, pc_branchD;
    wire [4:0]  rsD, rtD, rdD;
    wire        equalD, branch_takenD, reg_writeD, mem_to_regD, mem_writeD, mem_readD, alu_srcD, reg_dstD, branchD, bneD, jumpD;
    wire [2:0]  alu_controlD;

    reg  [31:0] rd1E, rd2E, sign_immE;
    reg  [4:0]  rsE, rtE, rdE;
    reg         reg_writeE, mem_to_regE, mem_writeE, mem_readE, alu_srcE, reg_dstE;
    reg  [2:0]  alu_controlE;
    wire [31:0] src_aE, src_bE, write_dataE, alu_outE;
    wire [4:0]  write_regE;
    
    reg         reg_writeM, mem_to_regM;
    reg  [31:0] alu_outM, write_dataM;
    reg  [4:0]  write_regM;
    reg         mem_writeM_reg, mem_readM_reg;

    reg         reg_writeW, mem_to_regW;
    reg  [31:0] alu_outW, read_dataW;
    reg  [4:0]  write_regW;
    wire [31:0] resultW;

    wire stallF, stallD, stallE, stallM, stallW;
    wire flushE, flushD, flushW;
    wire [1:0] forward_aE, forward_bE;
    wire forward_aD, forward_bD;

    // Modules
    control_unit ctrl_unit(
        .opcode(instrD[31:26]), .funct(instrD[5:0]),
        .reg_write(reg_writeD), .reg_dst(reg_dstD), .alu_src(alu_srcD),
        .branch(branchD), .bne(bneD), .mem_write(mem_writeD), .mem_read(mem_readD),
        .mem_to_reg(mem_to_regD), .jump(jumpD), .alu_control(alu_controlD)
    );

    hazard_unit hz_unit(
        .rsD(rsD), .rtD(rtD), .rsE(rsE), .rtE(rtE),
        .write_regE(write_regE), .write_regM(write_regM), .write_regW(write_regW),
        .reg_writeE(reg_writeE), .reg_writeM(reg_writeM), .reg_writeW(reg_writeW),
        .mem_to_regE(mem_to_regE), .mem_to_regM(mem_to_regM), .branchD(branchD || bneD),
        .mem_readM(mem_readM_reg), .mem_writeM(mem_writeM_reg), .cpu_ready(cpu_ready),
        .forward_aE(forward_aE), .forward_bE(forward_bE), .forward_aD(forward_aD), .forward_bD(forward_bD),
        .stallF(stallF), .stallD(stallD), .stallE(stallE), .stallM(stallM), .stallW(stallW),
        .flushE(flushE), .flushD(flushD), .flushW(flushW)
    );

    // Fetch Stage (IF)
    assign pc_next = jumpD ? {pc_plus4D[31:28], instrD[25:0], 2'b00} : (branch_takenD ? pc_branchD : pc_plus4F);
    
    always @(posedge clk) begin
        if (rst) pcF <= 32'd0;
        else if (!stallF) pcF <= pc_next; 
    end

    assign instr_addr = pcF;
    assign pc_plus4F = pcF + 32'd4; 

    always @(posedge clk) begin
        if (rst || (branch_takenD || jumpD)) begin 
            instrD <= 32'd0;
            pc_plus4D <= 32'd0;
        end else if (!stallD) begin 
            instrD <= instr_data;
            pc_plus4D <= pc_plus4F;
        end
    end

    // Decode Stage (ID)
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];
    assign sign_immD = {{16{instrD[15]}}, instrD[15:0]};

    register_file rf_inst(
        .clk(clk), .rst(rst),
        .we3(reg_writeW), .a1(rsD), .a2(rtD), .a3(write_regW), .wd3(resultW),
        .rd1(rd1D), .rd2(rd2D)
    );

    wire [31:0] eq_a = forward_aD ? alu_outM : rd1D;
    wire [31:0] eq_b = forward_bD ? alu_outM : rd2D;
    assign equalD = (eq_a == eq_b);
    assign branch_takenD = (branchD && equalD) || (bneD && !equalD);
    assign sign_imm_shiftedD = {sign_immD[29:0], 2'b00}; 
    assign pc_branchD = pc_plus4D + sign_imm_shiftedD;

    always @(posedge clk) begin
        if (rst || (flushE && !stallE)) begin
            {reg_writeE, mem_to_regE, mem_writeE, mem_readE, alu_srcE, reg_dstE, alu_controlE} <= 0;
            {rd1E, rd2E, rsE, rtE, rdE, sign_immE} <= 0;
        end else if (!stallE) begin 
            reg_writeE <= reg_writeD; mem_to_regE <= mem_to_regD;
            mem_writeE <= mem_writeD; mem_readE <= mem_readD;
            alu_srcE <= alu_srcD; reg_dstE <= reg_dstD;
            alu_controlE <= alu_controlD;
            rd1E <= rd1D; rd2E <= rd2D;
            rsE <= rsD; rtE <= rtD; rdE <= rdD;
            sign_immE <= sign_immD;
        end
    end

    // Execute Stage (EX)
    assign write_dataE = (forward_bE == 2'b10) ? alu_outM : 
                         (forward_bE == 2'b01) ? resultW : rd2E;
    assign src_aE      = (forward_aE == 2'b10) ? alu_outM : 
                         (forward_aE == 2'b01) ? resultW : rd1E;
    assign src_bE      = alu_srcE ? sign_immE : write_dataE;
    assign write_regE  = reg_dstE ? rdE : rtE;

    alu alu_inst(
        .a(src_aE), .b(src_bE), .alu_control(alu_controlE),
        .result(alu_outE), .zero() 
    );

    always @(posedge clk) begin
        if (rst) begin
            {reg_writeM, mem_to_regM, mem_writeM_reg, mem_readM_reg} <= 0;
            {alu_outM, write_dataM, write_regM} <= 0;
        end else if (!stallM) begin 
            reg_writeM <= reg_writeE;
            mem_to_regM <= mem_to_regE;
            mem_writeM_reg <= mem_writeE;
            mem_readM_reg <= mem_readE;
            alu_outM <= alu_outE;
            write_dataM <= write_dataE;
            write_regM <= write_regE;
        end
    end

    // Memory Stage (MEM)
    assign mem_read  = mem_readM_reg;
    assign mem_write = mem_writeM_reg;
    assign mem_addr  = alu_outM;
    assign mem_wdata = write_dataM;
    
    wire [31:0] read_dataM = mem_rdata;

    always @(posedge clk) begin
        if (rst || flushW) begin 
            {reg_writeW, mem_to_regW, alu_outW, read_dataW, write_regW} <= 0;
        end else if (!stallW) begin
            reg_writeW <= reg_writeM;
            mem_to_regW <= mem_to_regM;
            alu_outW <= alu_outM;
            read_dataW <= read_dataM;
            write_regW <= write_regM;
        end
    end

    // WriteBack Stage (WB)
    assign resultW = mem_to_regW ? read_dataW : alu_outW;

endmodule