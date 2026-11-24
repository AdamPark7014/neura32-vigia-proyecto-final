`timescale 1ns / 1ps

// dibujo VGA
module vga_dibujo #(
    parameter VID_ANCHO   = 320,
    parameter ESCALA_LOG2 = 1
) (
    input  wire        clk,
    input  wire        rst,

    input  wire [9:0]  h,
    input  wire [9:0]  v,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        activo_in,
    input  wire        cuadro_nuevo,

    output wire [16:0] vid_dir,
    input  wire [3:0]  vid_dato,
    output wire [12:0] msk_dir,
    input  wire        msk_dato,

    input  wire        ver_mascara,
    input  wire        patron,
    input  wire [31:0] zona,
    input  wire [8:0]  linea,
    input  wire [1:0]  banner,
    input  wire [255:0] cajas,
    input  wire [15:0] colores,

    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output reg         vga_hs,
    output reg         vga_vs
);
    // ciclo 0
    assign vid_dir = activo_in ? ((v >> ESCALA_LOG2) * VID_ANCHO + (h >> ESCALA_LOG2)) : 17'd0;
    assign msk_dir = activo_in ? ((v >> 3) * 80 + (h >> 3)) : 13'd0;

    // ciclo 1
    reg [9:0] h1, v1;
    reg       hs1, vs1, act1;
    reg [5:0] cuadros_vga;

    always @(posedge clk) begin
        h1 <= h; v1 <= v; hs1 <= hs_in; vs1 <= vs_in; act1 <= activo_in;
        if (rst)               cuadros_vga <= 6'd0;
        else if (cuadro_nuevo) cuadros_vga <= cuadros_vga + 6'd1;
    end

    // borde del recuadro
    function borde;
        input [9:0] px, py;
        input [7:0] cx0, cy0, cx1, cy1;
        reg [10:0] X0, X1, Y0, Y1;
        reg dentro, interior;
        begin
            X0 = {cx0, 3'b000};  X1 = {cx1, 3'b111};
            Y0 = {cy0, 3'b000};  Y1 = {cy1, 3'b111};
            dentro   = (px >= X0) && (px <= X1) && (py >= Y0) && (py <= Y1);
            interior = (px >= X0 + 2) && (px + 2 <= X1) && (py >= Y0 + 2) && (py + 2 <= Y1);
            borde    = dentro && !interior;
        end
    endfunction

    // fuente de 8 x 8
    function [7:0] fuente;
        input [2:0] letra;
        input [2:0] fila;
        begin
            case ({letra, fila})
                6'o00: fuente = 8'h3C; 6'o01: fuente = 8'h18; 6'o02: fuente = 8'h18; 6'o03: fuente = 8'h18;
                6'o04: fuente = 8'h18; 6'o05: fuente = 8'h18; 6'o06: fuente = 8'h3C; 6'o07: fuente = 8'h00;
                6'o10: fuente = 8'hC6; 6'o11: fuente = 8'hE6; 6'o12: fuente = 8'hF6; 6'o13: fuente = 8'hDE;
                6'o14: fuente = 8'hCE; 6'o15: fuente = 8'hC6; 6'o16: fuente = 8'hC6; 6'o17: fuente = 8'h00;
                6'o20: fuente = 8'h7E; 6'o21: fuente = 8'h18; 6'o22: fuente = 8'h18; 6'o23: fuente = 8'h18;
                6'o24: fuente = 8'h18; 6'o25: fuente = 8'h18; 6'o26: fuente = 8'h18; 6'o27: fuente = 8'h00;
                6'o30: fuente = 8'hFC; 6'o31: fuente = 8'hC6; 6'o32: fuente = 8'hC6; 6'o33: fuente = 8'hFC;
                6'o34: fuente = 8'hD8; 6'o35: fuente = 8'hCC; 6'o36: fuente = 8'hC6; 6'o37: fuente = 8'h00;
                6'o40: fuente = 8'hC6; 6'o41: fuente = 8'hC6; 6'o42: fuente = 8'hC6; 6'o43: fuente = 8'hC6;
                6'o44: fuente = 8'hC6; 6'o45: fuente = 8'hC6; 6'o46: fuente = 8'h7C; 6'o47: fuente = 8'h00;
                6'o50: fuente = 8'h7C; 6'o51: fuente = 8'hC6; 6'o52: fuente = 8'hC0; 6'o53: fuente = 8'h7C;
                6'o54: fuente = 8'h06; 6'o55: fuente = 8'hC6; 6'o56: fuente = 8'h7C; 6'o57: fuente = 8'h00;
                6'o60: fuente = 8'h7C; 6'o61: fuente = 8'hC6; 6'o62: fuente = 8'hC6; 6'o63: fuente = 8'hC6;
                6'o64: fuente = 8'hC6; 6'o65: fuente = 8'hC6; 6'o66: fuente = 8'h7C; 6'o67: fuente = 8'h00;
                default: fuente = 8'h00;
            endcase
        end
    endfunction

    // capas
    wire [9:0] tx = h1 - 10'd16;
    wire [9:0] ty = v1 - 10'd16;
    wire       en_letrero = banner[0] && (h1 >= 16) && (tx < 10'd224) && (v1 >= 16) && (ty < 10'd32) &&
                            (!banner[1] || cuadros_vga[4]);
    wire [7:0] renglon    = fuente(tx[7:5], ty[4:2]);
    wire       letra_on   = renglon[3'd7 - tx[4:2]];

    wire en_zona  = borde(h1, v1, zona[7:0], zona[15:8], zona[23:16], zona[31:24]);
    wire en_linea = linea[8] && (h1[9:1] == {linea[6:0], 2'b10}) && !v1[3];

    reg [1:0] color_caja;
    integer k;
    always @(*) begin
        color_caja = 2'd0;
        for (k = 7; k >= 0; k = k - 1)
            if (colores[2*k +: 2] != 2'd0 &&
                borde(h1, v1, cajas[32*k +: 8], cajas[32*k+8 +: 8], cajas[32*k+16 +: 8], cajas[32*k+24 +: 8]))
                color_caja = colores[2*k +: 2];
    end

    reg [3:0] r, g, b;
    always @(*) begin
        r = vid_dato; g = vid_dato; b = vid_dato;
        if (ver_mascara && msk_dato) begin r = vid_dato >> 1; g = vid_dato >> 1; b = 4'hF; end
        if (en_linea)               begin r = 4'h0; g = 4'hF; b = 4'hF; end
        if (en_zona)                begin r = 4'hF; g = 4'hF; b = 4'h0; end
        case (color_caja)
            2'd1: begin r = 4'h0; g = 4'hF; b = 4'h0; end
            2'd2: begin r = 4'hF; g = 4'h0; b = 4'h0; end
            2'd3: begin r = 4'h8; g = 4'h8; b = 4'h8; end
            default: ;
        endcase
        if (en_letrero) begin
            if (letra_on) begin r = 4'hF; g = 4'hF; b = 4'hF; end
            else          begin r = 4'hA; g = 4'h0; b = 4'h0; end
        end
        if (patron) begin
            if (v1 < 10'd360) begin
                r = h1[8] ? 4'hF : 4'h0; g = h1[7] ? 4'hF : 4'h0; b = h1[6] ? 4'hF : 4'h0;
            end else begin
                r = h1[9:6]; g = h1[9:6]; b = h1[9:6];
            end
            if (h1 < 10'd2 || h1 > 10'd637 || v1 < 10'd2 || v1 > 10'd477) begin r = 4'hF; g = 4'hF; b = 4'hF; end
        end
        if (!act1) begin r = 4'h0; g = 4'h0; b = 4'h0; end
    end

    // ciclo 2
    always @(posedge clk) begin
        vga_r <= r; vga_g <= g; vga_b <= b;
        vga_hs <= hs1; vga_vs <= vs1;
    end
endmodule
