`timescale 1ns / 1ps

// sincronia VGA
module vga_sincronia (
    input  wire       clk,
    input  wire       rst,
    output reg  [9:0] h,
    output reg  [9:0] v,
    output wire       hs,
    output wire       vs,
    output wire       activo,
    output wire       cuadro_nuevo
);
    localparam H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam H_TOTAL = H_VIS + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_VIS + V_FP + V_SYNC + V_BP;

    always @(posedge clk) begin
        if (rst) begin
            h <= 10'd0; v <= 10'd0;
        end else if (h == H_TOTAL - 1) begin
            h <= 10'd0;
            v <= (v == V_TOTAL - 1) ? 10'd0 : v + 10'd1;
        end else begin
            h <= h + 10'd1;
        end
    end

    assign hs = ~((h >= H_VIS + H_FP) && (h < H_VIS + H_FP + H_SYNC));
    assign vs = ~((v >= V_VIS + V_FP) && (v < V_VIS + V_FP + V_SYNC));
    // zona visible
    assign activo       = (h < H_VIS) && (v < V_VIS);
    assign cuadro_nuevo = (h == 10'd0) && (v == 10'd0);
endmodule
