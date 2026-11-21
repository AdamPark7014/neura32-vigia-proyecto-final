`timescale 1ns / 1ps
// ============================================================
// MODELO DE FONDO Y MASCARA DE MOVIMIENTO (80 x 60)
//
// Para cada pixel promedio I(x,y):
//   F(x,y)  fondo aprendido (8 bits, memoria M9K de un puerto)
//   d       = I - F
//   fg      = |d| > umbral                (pixel de primer plano = silueta)
//   F nuevo = F + d / 2^alfa              (promedio exponencial, con redondeo)
//             si el pixel es primer plano se usa alfa + 2: el fondo
//             aprende 4 veces mas lento donde hay alguien parado.
//   aprender = 1 copia I en F (arranque) y fuerza fg = 0.
//
// La mascara se guarda en dos bancos (doble buffer) de 1200 palabras:
// cada palabra lleva 4 pixeles, un byte por pixel (0 = fondo, 1 = silueta),
// para que el programa los lea con lbu. Al terminar un cuadro, si el CPU
// ya libero el banco anterior (ack), los bancos se intercambian y 'listo'
// avisa que hay una mascara nueva. Si el CPU sigue ocupado, el cuadro se
// descarta y se reescribe el mismo banco.
// ============================================================
module fondo_mascara #(
    parameter ANCHO = 80,
    parameter ALTO  = 60
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        px_valido,
    input  wire [6:0]  px_x,
    input  wire [5:0]  px_y,
    input  wire [7:0]  px_dato,

    input  wire [7:0]  umbral,
    input  wire [3:0]  alfa,
    input  wire        aprender,
    input  wire        ack,

    output reg         listo,
    output reg         banco_lec,
    output reg  [15:0] cuadros,
    output reg  [12:0] pixeles_fg,

    output reg         msk_we,
    output reg  [11:0] msk_dir,        // banco 0: palabras 0..1199, banco 1: 1200..2399
    output reg  [31:0] msk_dato,

    output reg         vga_we,
    output reg  [12:0] vga_dir,
    output reg         vga_dato
);
    localparam PIXELES   = ANCHO * ALTO;      // 4800
    localparam POR_FILA  = ANCHO / 4;         // 20 palabras por fila

    // ---------------- memoria del fondo ----------------
    reg [7:0]  fondo [0:PIXELES-1];
    reg [7:0]  fondo_q;
    reg [12:0] idx;
    wire       fondo_we;
    wire [7:0] fondo_nuevo;

    integer i;
    initial for (i = 0; i < PIXELES; i = i + 1) fondo[i] = 8'd0;

    always @(posedge clk) begin
        if (fondo_we) fondo[idx] <= fondo_nuevo;
        fondo_q <= fondo[idx];
    end

    // ---------------- tuberia de 3 ciclos ----------------
    //   ciclo A: llega el pixel, se calcula el indice
    //   ciclo B: se lee el fondo
    //   ciclo C: se compara, se escribe el fondo nuevo y la mascara
    reg [6:0] x1;
    reg [5:0] y1;
    reg [7:0] dato1;
    reg       etapa_b, etapa_c;

    always @(posedge clk) begin
        if (rst) begin
            etapa_b <= 1'b0; etapa_c <= 1'b0;
        end else begin
            etapa_b <= px_valido;
            etapa_c <= etapa_b;
            if (px_valido) begin
                idx   <= px_y * ANCHO + px_x;
                x1    <= px_x;
                y1    <= px_y;
                dato1 <= px_dato;
            end
        end
    end

    // ---------------- comparacion y actualizacion ----------------
    wire signed [17:0] dif     = $signed({10'd0, dato1}) - $signed({10'd0, fondo_q});
    wire        [17:0] abs_dif = dif[17] ? -dif : dif;
    wire               es_fg   = !aprender && (abs_dif > {10'd0, umbral});
    wire        [4:0]  corr    = es_fg ? {1'b0, alfa} + 5'd2 : {1'b0, alfa};
    wire signed [17:0] redondeo = (corr == 5'd0) ? 18'sd0 : (18'sd1 <<< (corr - 5'd1));
    wire signed [17:0] delta   = (dif + redondeo) >>> corr;

    assign fondo_we    = etapa_c;
    assign fondo_nuevo = aprender ? dato1 : fondo_q + delta[7:0];

    // ---------------- mascara y doble buffer ----------------
    reg        banco_esc;
    reg [23:0] previo;                        // los 3 pixeles anteriores de la palabra
    reg [12:0] cuenta_fg;
    wire       fin_cuadro = etapa_c && (x1 == ANCHO - 1) && (y1 == ALTO - 1);
    wire [10:0] palabra   = y1 * POR_FILA + x1[6:2];

    always @(posedge clk) begin
        msk_we <= 1'b0;
        vga_we <= 1'b0;
        if (rst) begin
            listo <= 1'b0; banco_esc <= 1'b0; banco_lec <= 1'b1;
            cuadros <= 16'd0; pixeles_fg <= 13'd0; cuenta_fg <= 13'd0;
        end else begin
            if (etapa_c) begin
                // mascara para el CPU: 4 pixeles por palabra, el pixel x%4 = 0 en el byte 0
                if (x1[1:0] == 2'd3) begin
                    msk_we   <= 1'b1;
                    msk_dir  <= banco_esc ? ({1'b0, palabra} + 12'd1200) : {1'b0, palabra};
                    msk_dato <= {7'd0, es_fg, previo};
                end else begin
                    previo   <= {7'd0, es_fg, previo[23:8]};
                end
                // mascara para el monitor: 1 bit por celda
                vga_we   <= 1'b1;
                vga_dir  <= idx;
                vga_dato <= es_fg;
                cuenta_fg <= fin_cuadro ? 13'd0 : cuenta_fg + es_fg;
            end

            if (fin_cuadro && !listo) begin
                banco_lec  <= banco_esc;
                banco_esc  <= ~banco_esc;
                listo      <= 1'b1;
                cuadros    <= cuadros + 16'd1;
                pixeles_fg <= cuenta_fg + es_fg;
            end else if (ack) begin
                listo <= 1'b0;
            end
        end
    end
endmodule
