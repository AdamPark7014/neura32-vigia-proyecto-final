`timescale 1ns / 1ps
// ============================================================
// COMPOSICION DE LA IMAGEN VGA
// Capas, de abajo hacia arriba:
//   1. video de la camara en gris (4 bits), ampliado 2^ESCALA_LOG2 veces
//   2. silueta detectada en azul (si ver_mascara = 1)
//   3. linea virtual (cian, punteada)
//   4. zona prohibida (borde amarillo)
//   5. hasta 8 recuadros que escribe el procesador:
//        color 1 verde = persona, 2 rojo = intruso, 3 gris = no es persona
//   6. letrero "INTRUSO" (parpadea) cuando hay alarma
// Con patron = 1 (SW8) muestra barras de color: prueba el monitor sin camara.
// La rejilla de la deteccion es de 80 x 60 celdas de 8 x 8 pixeles VGA.
// Tuberia de 2 ciclos: direccion -> lectura de memorias -> color.
// ============================================================
module vga_dibujo #(
    parameter VID_ANCHO   = 320,
    parameter ESCALA_LOG2 = 1          // 320x240 -> 640x480
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
    input  wire        patron,         // SW8: barras de color para probar el monitor sin camara
    input  wire [31:0] zona,           // {y1, x1, y0, x0} en celdas
    input  wire [8:0]  linea,          // {visible, x}
    input  wire [1:0]  banner,         // {parpadeo, mostrar}
    input  wire [255:0] cajas,         // 8 x {y1, x1, y0, x0}
    input  wire [15:0] colores,        // 8 x 2 bits

    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output reg         vga_hs,
    output reg         vga_vs
);
    // ---------------- ciclo 0: direcciones ----------------
    assign vid_dir = activo_in ? ((v >> ESCALA_LOG2) * VID_ANCHO + (h >> ESCALA_LOG2)) : 17'd0;
    assign msk_dir = activo_in ? ((v >> 3) * 80 + (h >> 3)) : 13'd0;

    // ---------------- ciclo 1: llegan los datos ----------------
    reg [9:0] h1, v1;
    reg       hs1, vs1, act1;
    reg [5:0] cuadros_vga;

    always @(posedge clk) begin
        h1 <= h; v1 <= v; hs1 <= hs_in; vs1 <= vs_in; act1 <= activo_in;
        if (rst)               cuadros_vga <= 6'd0;
        else if (cuadro_nuevo) cuadros_vga <= cuadros_vga + 6'd1;
    end

    // borde de 2 pixeles de un rectangulo dado en celdas de 8 x 8
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

    // fuente de 8 x 8 para "INTRUSO" (bit 7 = columna izquierda)
    function [7:0] fuente;
        input [2:0] letra;   // 0 I, 1 N, 2 T, 3 R, 4 U, 5 S, 6 O
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

    // ---------------- capas ----------------
    wire [9:0] tx = h1 - 10'd16;          // origen del letrero en (16, 16), letras de 32 x 32
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
        if (patron) begin                                  // barras de color y escala de grises
            if (v1 < 10'd360) begin
                r = h1[8] ? 4'hF : 4'h0; g = h1[7] ? 4'hF : 4'h0; b = h1[6] ? 4'hF : 4'h0;
            end else begin
                r = h1[9:6]; g = h1[9:6]; b = h1[9:6];
            end
            if (h1 < 10'd2 || h1 > 10'd637 || v1 < 10'd2 || v1 > 10'd477) begin r = 4'hF; g = 4'hF; b = 4'hF; end
        end
        if (!act1) begin r = 4'h0; g = 4'h0; b = 4'h0; end
    end

    // ---------------- ciclo 2: salidas registradas ----------------
    always @(posedge clk) begin
        vga_r <= r; vga_g <= g; vga_b <= b;
        vga_hs <= hs1; vga_vs <= vs1;
    end
endmodule
