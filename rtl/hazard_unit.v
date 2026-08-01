module hazard_unit (
    input  wire [4:0] rsD, rtD, rsE, rtE,
    input  wire [4:0] write_regE, write_regM, write_regW,
    input  wire       reg_writeE, reg_writeM, reg_writeW,
    input  wire       mem_to_regE, mem_to_regM, branchD,
    input  wire       mem_readM, mem_writeM, cpu_ready,

    output reg  [1:0] forward_aE, forward_bE,
    output wire       forward_aD, forward_bD,
    output wire       stallF, stallD, stallE, stallM, stallW,
    output wire       flushE, flushD, flushW
);

    // Data Forwarding for Execute Stage
    always @(*) begin
        forward_aE = 2'b00;
        if ((rsE != 0) && (rsE == write_regM) && reg_writeM) 
            forward_aE = 2'b10; 
        else if ((rsE != 0) && (rsE == write_regW) && reg_writeW) 
            forward_aE = 2'b01; 

        forward_bE = 2'b00;
        if ((rtE != 0) && (rtE == write_regM) && reg_writeM) 
            forward_bE = 2'b10;
        else if ((rtE != 0) && (rtE == write_regW) && reg_writeW) 
            forward_bE = 2'b01;
    end

    // Data Forwarding from Memory Stage to Decode Stage (Branch resolution)
    assign forward_aD = (rsD != 0) && (rsD == write_regM) && reg_writeM;
    assign forward_bD = (rtD != 0) && (rtD == write_regM) && reg_writeM;

    // Hazard Detection
    wire lw_stall = mem_to_regE && (write_regE != 0) && ((rsD == write_regE) || (rtD == write_regE));
    
    wire branch_stall = branchD && (
        (reg_writeE && (write_regE != 0) && (write_regE == rsD || write_regE == rtD)) ||
        (mem_to_regM && (write_regM != 0) && (write_regM == rsD || write_regM == rtD))
    );

    // Cache Miss stall detection
    wire cache_stall = (mem_readM || mem_writeM) && (!cpu_ready);

    assign stallF = lw_stall || branch_stall || cache_stall;
    assign stallD = lw_stall || branch_stall || cache_stall;
    assign stallE = cache_stall;
    assign stallM = cache_stall;
    assign stallW = cache_stall; 

    assign flushD = 1'b0; 
    assign flushE = (lw_stall || branch_stall) && !cache_stall;
    assign flushW = 1'b0;
    
endmodule