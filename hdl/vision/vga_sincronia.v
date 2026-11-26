`timescale 1ns / 1ps

// sincronia VGA enganchada a la camara
module vga_sincronia (
    input  wire       clk,
    input  wire       rst,
    input  wire       cam_inicio,
    output reg  [9:0] h,
    output reg  [9:0] v,
    output wire       hs,
    output wire       vs,
    output wire       activo,
    output wire       cuadro_nuevo,
    output wire       enganchado
);
    // 784 x 510: dos cuadros del monitor por cada cuadro de la camara
    localparam H_VIS = 640;  // pixeles visibles
    localparam H_FP = 16;  // pórtico frontal
    localparam H_SYNC = 96;  // pulso horizontal
    localparam H_BP = 32;  // pórtico trasero
    localparam V_VIS = 480;  // renglones visibles
    localparam V_FP = 10;  // pórtico frontal
    localparam V_SYNC = 2;  // pulso vertical
    localparam V_BP = 18;  // pórtico trasero
    localparam H_TOTAL = H_VIS + H_FP + H_SYNC + H_BP;  // ciclos por renglón
    localparam V_TOTAL = V_VIS + V_FP + V_SYNC + V_BP;  // renglones por cuadro
    localparam V_META = 16;  // renglón de enganche

    // error de fase
    wire signed [10:0] dif = $signed({1'b0, v}) - V_META;
    wire signed [10:0] err = (dif > (V_TOTAL / 2)) ? dif - V_TOTAL :
                             (dif < -(V_TOTAL / 2)) ? dif + V_TOTAL : dif;
    reg  signed [10:0] ajuste;
    reg  [1:0] buenos;
    reg        primero;
    wire fin_linea = (h == H_TOTAL - 1);
    wire fin_cuadro = fin_linea && (v == V_TOTAL - 1);

    always @(posedge clk) begin
        if (rst) begin
            h <= 10'd0; v <= 10'd0;
            ajuste <= 11'sd0; buenos <= 2'd0; primero <= 1'b1;
        end else begin
            h <= fin_linea ? 10'd0 : h + 10'd1;
            if (cam_inicio && primero) begin
                // solo el primer enganche salta
                v <= V_META;
                primero <= 1'b0;
            end else begin
                if (cam_inicio) begin
                    ajuste <= err;
                    buenos <= ((err < 11'sd3) && (err > -11'sd3)) ? ((buenos == 2'd3) ? 2'd3 : buenos + 2'd1) : 2'd0;
                end
                if (fin_cuadro) begin
                    // un renglon de mas o de menos por cuadro, sin saltos
                    if (ajuste > 11'sd0) begin
                        ajuste <= ajuste - 11'sd1;
                    end else begin
                        v <= 10'd0;
                    end
                end else if (fin_linea) begin
                    if ((v == V_TOTAL - 2) && (ajuste < 11'sd0)) begin
                        v <= 10'd0;
                        ajuste <= ajuste + 11'sd1;
                    end else begin
                        v <= v + 10'd1;
                    end
                end
            end
        end
    end

    assign hs = ~((h >= H_VIS + H_FP) && (h < H_VIS + H_FP + H_SYNC));
    assign vs = ~((v >= V_VIS + V_FP) && (v < V_VIS + V_FP + V_SYNC));
    assign activo       = (h < H_VIS) && (v < V_VIS);
    assign cuadro_nuevo = (h == 10'd0) && (v == 10'd0);
    assign enganchado   = buenos[1];
endmodule
