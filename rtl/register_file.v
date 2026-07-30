module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        we3,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] rf [31:0];
    integer i;

    // نوشتن با لبه کلاک
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'd0;
            end
        end else if (we3 && a3 != 5'd0) begin // رجیستر 0 همیشه صفر است
            rf[a3] <= wd3;
        end
    end

    // خواندن (به همراه Internal Forwarding برای حل مشکل خواندن/نوشتن همزمان)
    assign rd1 = (a1 != 5'd0) ? ((we3 && a1 == a3) ? wd3 : rf[a1]) : 32'd0;
    assign rd2 = (a2 != 5'd0) ? ((we3 && a2 == a3) ? wd3 : rf[a2]) : 32'd0;
endmodule