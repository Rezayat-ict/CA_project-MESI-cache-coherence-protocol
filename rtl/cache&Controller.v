module l1_cache (
    input  wire         clk,
    input  wire         reset,

    input  wire         cpu_req,
    input  wire         cpu_write,
    input  wire [31:0]  cpu_addr,
    input  wire [31:0]  cpu_wdata,
    output reg  [31:0]  cpu_rdata,
    output reg          cpu_ready,

    output reg          bus_req,
    output reg  [2:0]   bus_cmd,
    output reg  [31:0]  bus_addr,
    output reg  [127:0] bus_wdata,

    input  wire         bus_grant,
    input  wire         bus_done,
    input  wire [127:0] bus_rdata,
    input  wire         bus_shared,

    input  wire         snoop_valid,
    input  wire [2:0]   snoop_cmd,
    input  wire [31:0]  snoop_addr,

    output reg          snoop_response_valid,
    output reg          snoop_hit,
    output reg          snoop_dirty,
    output reg  [127:0] snoop_data
);


    localparam BUS_CMD_IDLE       = 3'b000;
    localparam BUS_CMD_READ       = 3'b001; // Read Miss
    localparam BUS_CMD_WRITE_BACK = 3'b010; // Evict Dirty Block
    localparam BUS_CMD_UPGRADE    = 3'b011; // Invalidate Others (S -> M)

    // MESI States
    localparam STATE_I = 2'b00; 
    localparam STATE_S = 2'b01; 
    localparam STATE_E = 2'b10; 
    localparam STATE_M = 2'b11; 

    // Main FSM States
    localparam FSM_IDLE         = 3'b000;
    localparam FSM_ALLOCATE_REQ = 3'b001;
    localparam FSM_ALLOCATE_WAIT= 3'b010;
    localparam FSM_WRITEBACK_REQ= 3'b011;
    localparam FSM_WRITEBACK_WAIT=3'b100;
    localparam FSM_UPGRADE_REQ  = 3'b101;
    localparam FSM_UPGRADE_WAIT = 3'b110;

    reg [2:0] state, next_state;

    //Cahce structure
    reg [127:0] cache_data  [0:3];
    reg [25:0]  cache_tag   [0:3];
    reg [1:0]   mesi_state  [0:3];

    wire [1:0]  cpu_index  = cpu_addr[5:4];
    wire [25:0] cpu_tag    = cpu_addr[31:6];
    wire [1:0]  snoop_index= snoop_addr[5:4];
    wire [25:0] snoop_tag  = snoop_addr[31:6];

    //This signal shows hit/miss
    wire is_hit = cpu_req && (mesi_state[cpu_index] != STATE_I) && (cache_tag[cpu_index] == cpu_tag);

    integer i;

    //MESI FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= FSM_IDLE;
            for (i = 0; i < 4; i = i + 1) begin
                mesi_state[i] <= STATE_I;
                cache_tag[i]  <= 26'b0;
                cache_data[i] <= 128'b0;
            end
        end else begin
            state <= next_state;

            if (state == FSM_IDLE && is_hit) begin
                if (cpu_write) begin
                    mesi_state[cpu_index] <= STATE_M;
                    case (cpu_addr[3:2])
                        2'b00: cache_data[cpu_index][31:0]   <= cpu_wdata;
                        2'b01: cache_data[cpu_index][63:32]  <= cpu_wdata;
                        2'b10: cache_data[cpu_index][95:64]  <= cpu_wdata;
                        2'b11: cache_data[cpu_index][127:96] <= cpu_wdata;
                    endcase
                end
            end 
			
			else if (state == FSM_ALLOCATE_WAIT && bus_done) begin
                cache_tag[cpu_index]  <= cpu_tag;
                
                if (cpu_write) begin
                    // Write Miss: Update block and set to M
                    mesi_state[cpu_index] <= STATE_M;
                    case (cpu_addr[3:2])
                        2'b00: cache_data[cpu_index] <= {bus_rdata[127:32], cpu_wdata};
                        2'b01: cache_data[cpu_index] <= {bus_rdata[127:64], cpu_wdata, bus_rdata[31:0]};
                        2'b10: cache_data[cpu_index] <= {bus_rdata[127:96], cpu_wdata, bus_rdata[63:0]};
                        2'b11: cache_data[cpu_index] <= {cpu_wdata, bus_rdata[95:0]};
                    endcase
                end 
				else begin
                    // Read Miss: Set state according to bus_shared
                    cache_data[cpu_index] <= bus_rdata;
                    mesi_state[cpu_index] <= bus_shared ? STATE_S : STATE_E;
                end
            end else if (state == FSM_UPGRADE_WAIT && bus_done) begin
                // S -> M Upgrade Complete
                mesi_state[cpu_index] <= STATE_M;
                case (cpu_addr[3:2])
                    2'b00: cache_data[cpu_index][31:0]   <= cpu_wdata;
                    2'b01: cache_data[cpu_index][63:32]  <= cpu_wdata;
                    2'b10: cache_data[cpu_index][95:64]  <= cpu_wdata;
                    2'b11: cache_data[cpu_index][127:96] <= cpu_wdata;
                endcase
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            FSM_IDLE: begin
                if (cpu_req) begin
                    if (is_hit) begin
                        if (cpu_write && mesi_state[cpu_index] == STATE_S)
                            next_state = FSM_UPGRADE_REQ; 
                        else
                            next_state = FSM_IDLE; 
                    end else begin
                        if (mesi_state[cpu_index] == STATE_M)
                            next_state = FSM_WRITEBACK_REQ;
                        else
                            next_state = FSM_ALLOCATE_REQ;
                    end
                end
            end

            // Write-Back Evicted Line
            FSM_WRITEBACK_REQ:  if (bus_grant) next_state = FSM_WRITEBACK_WAIT;
            FSM_WRITEBACK_WAIT: if (bus_done)  next_state = FSM_ALLOCATE_REQ;

            // Read / Write Allocate
            FSM_ALLOCATE_REQ:   if (bus_grant) next_state = FSM_ALLOCATE_WAIT;
            FSM_ALLOCATE_WAIT:  if (bus_done)  next_state = FSM_IDLE;

            // Upgrade State (S -> M)
            FSM_UPGRADE_REQ:    if (bus_grant) next_state = FSM_UPGRADE_WAIT;
            FSM_UPGRADE_WAIT:   if (bus_done)  next_state = FSM_IDLE;

            default: next_state = FSM_IDLE;
        endcase
    end

    // Output Signals to CPU & Bus
    always @(*) begin
        cpu_ready   = 1'b0;
        cpu_rdata   = 32'b0;
        bus_req     = 1'b0;
        bus_cmd     = BUS_CMD_IDLE;
        bus_addr    = 32'b0;
        bus_wdata   = 128'b0;

        // CPU Read Combinational Logic
        if (state == FSM_IDLE && is_hit) begin
            cpu_ready = 1'b1;
            case (cpu_addr[3:2])
                2'b00: cpu_rdata = cache_data[cpu_index][31:0];
                2'b01: cpu_rdata = cache_data[cpu_index][63:32];
                2'b10: cpu_rdata = cache_data[cpu_index][95:64];
                2'b11: cpu_rdata = cache_data[cpu_index][127:96];
            endcase
        end

        case (state)
            FSM_WRITEBACK_REQ, FSM_WRITEBACK_WAIT: begin
                bus_req   = 1'b1;
                bus_cmd   = BUS_CMD_WRITE_BACK;
                bus_addr  = {cache_tag[cpu_index], cpu_index, 4'b0000}; // Block-Aligned Evicted Address
                bus_wdata = cache_data[cpu_index];
            end
            FSM_ALLOCATE_REQ, FSM_ALLOCATE_WAIT: begin
                bus_req   = 1'b1;
                bus_cmd   = BUS_CMD_READ;
                bus_addr  = {cpu_addr[31:4], 4'b0000}; // Block-Aligned Current Address
            end
            FSM_UPGRADE_REQ, FSM_UPGRADE_WAIT: begin
                bus_req   = 1'b1;
                bus_cmd   = BUS_CMD_UPGRADE;
                bus_addr  = {cpu_addr[31:4], 4'b0000};
            end
        endcase
    end

    //snoop logic
    always @(*) begin
        snoop_response_valid = 1'b0;
        snoop_hit            = 1'b0;
        snoop_dirty          = 1'b0;
        snoop_data           = 128'b0;

        if (snoop_valid) begin
            if ((mesi_state[snoop_index] != STATE_I) && (cache_tag[snoop_index] == snoop_tag)) begin
                snoop_response_valid = 1'b1;
                snoop_hit            = 1'b1;

                if (mesi_state[snoop_index] == STATE_M) begin
                    snoop_dirty = 1'b1;
                    snoop_data  = cache_data[snoop_index];
                end
            end
        end
    end

    // Snoop State Transitions for MESI Coherence
    always @(posedge clk) begin
        if (!reset && snoop_valid) begin
            if ((mesi_state[snoop_index] != STATE_I) && (cache_tag[snoop_index] == snoop_tag)) begin
                case (snoop_cmd)
                    BUS_CMD_READ: begin
                        if (mesi_state[snoop_index] == STATE_M || mesi_state[snoop_index] == STATE_E) begin
                            mesi_state[snoop_index] <= STATE_S;
                        end
                    end
                    BUS_CMD_UPGRADE, BUS_CMD_WRITE_BACK: begin
                        mesi_state[snoop_index] <= STATE_I;
                    end
                endcase
            end
        end
    end

endmodule