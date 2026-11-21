`timescale 1ns / 1ps
// ============================================================
// TOP DE NEURA-32 VIGIA PARA LA DE10-Lite (MAX 10, 10M50DAF484C7G)
//
//   MAX10_CLK1_50  reloj de 50 MHz -> divisor entre 2 -> 25 MHz para todo el sistema
//   KEY[0]         reinicio (activo en bajo)
//   KEY[1]         borra la alarma
//   SW[1:0]        zona y linea (4 configuraciones)
//   SW[2]          sentido prohibido: 0 = izquierda->derecha, 1 = al reves
//   SW[3]          pinta la silueta detectada en azul
//   SW[4]          red neuronal con RV32IM puro, sin Zbb (para comparar)
//   LEDR9          alarma (parpadea)    LEDR8 aprendiendo el fondo
//   LEDR7          camara identificada  LEDR0 alarma
//   HEX5..HEX4     entradas   HEX3..HEX2 salidas
//   HEX1           personas en la zona  HEX0 manchas en la imagen
//   VGA            video 640x480 con zona, linea, recuadros y letrero
//
// Camara OV7670 sin FIFO en el conector GPIO (JP1), a 3.3 V:
//   GPIO[0] SIOC   GPIO[1] SIOD   GPIO[2] VSYNC  GPIO[3] HREF
//   GPIO[4] PCLK   GPIO[5] XCLK   GPIO[6..13] D7..D0
//   GPIO[14] RESET GPIO[15] PWDN  pin 29 = 3.3 V, pin 30 = GND
// ============================================================
module top_vigia (
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [9:0]  LEDR,
    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1,
    output wire [7:0]  HEX2,
    output wire [7:0]  HEX3,
    output wire [7:0]  HEX4,
    output wire [7:0]  HEX5,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    inout  wire [35:0] GPIO
);
    // ---------------- reloj de 25 MHz ----------------
    // Divisor entre 2 con un flip-flop (el .sdc lo declara como reloj generado).
    // Quartus lo sube a la red global de reloj. 25 MHz es el reloj de pixel VGA.
    reg clk25 = 1'b0;
    always @(posedge MAX10_CLK1_50) clk25 <= ~clk25;
    wire clk = clk25;
    wire pll_listo = 1'b1;

    // El mismo reloj retrasado un cuarto de ciclo (10 ns): con el y con su inverso
    // XCLK puede salir en cuatro fases (0, 90, 180 y 270 grados). La camara saca
    // PCLK a partir de XCLK con fase fija; la fase se escoge para que los flancos
    // de PCLK no caigan junto a los del reloj que lo muestrea.
    reg clk25_n = 1'b0;
    always @(negedge MAX10_CLK1_50) clk25_n <= clk25;
    wire [1:0] cam_fase;
    wire xclk = (cam_fase[0] ? clk25_n : clk25) ^ cam_fase[1];

    // ---------------- reinicio sincronizado ----------------
    reg [2:0] rst_s = 3'b111;
    always @(posedge clk) rst_s <= {rst_s[1:0], ~KEY[0] | ~pll_listo};
    wire rst = rst_s[2];

    // ---------------- camara ----------------
    wire       cam_sioc, cam_reset_n, cam_pwdn;
    wire [7:0] cam_d = {GPIO[6], GPIO[7], GPIO[8], GPIO[9], GPIO[10], GPIO[11], GPIO[12], GPIO[13]};

    assign GPIO[0]  = cam_sioc;
    assign GPIO[5]  = xclk;                    // XCLK = 25 MHz
    assign GPIO[14] = cam_reset_n;
    assign GPIO[15] = cam_pwdn;
    assign GPIO[35:16] = 20'bz;
    // GPIO[1] (SIOD) es bidireccional: lo maneja el SoC con drenador abierto

    // ---------------- SoC ----------------
    wire [23:0] hex;

    soc_neura32 #(
        .ARCHIVO_PROGRAMA("programa_vigia.txt"), .USAR_ARCHIVO(1), .SIMULACION(0),
        .VID_ANCHO(320), .VID_ALTO(240), .BLOQUE_LOG2(2), .VGA_ESCALA_LOG2(1)
    ) soc (
        .clk(clk), .clk50(MAX10_CLK1_50), .rst_ext(rst),
        .interruptores(SW), .botones(KEY),
        .leds(LEDR), .hex(hex),
        .consola_char(), .consola_we(), .control(),
        .cam_pclk(GPIO[4]), .cam_href(GPIO[3]), .cam_vsync(GPIO[2]), .cam_d(cam_d),
        .cam_sioc(cam_sioc), .cam_siod(GPIO[1]), .cam_reset_n(cam_reset_n), .cam_pwdn(cam_pwdn),
        .cam_fase(cam_fase),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .vga_hs(VGA_HS), .vga_vs(VGA_VS),
        .fin(), .instr_ilegal(), .desalineado(), .ciclos(), .instret()
    );

    // ---------------- displays de 7 segmentos (activos en bajo, punto apagado) ----------------
    function [7:0] siete_seg;
        input [3:0] n;
        case (n)
            4'h0: siete_seg = 8'hC0; 4'h1: siete_seg = 8'hF9; 4'h2: siete_seg = 8'hA4; 4'h3: siete_seg = 8'hB0;
            4'h4: siete_seg = 8'h99; 4'h5: siete_seg = 8'h92; 4'h6: siete_seg = 8'h82; 4'h7: siete_seg = 8'hF8;
            4'h8: siete_seg = 8'h80; 4'h9: siete_seg = 8'h90; 4'hA: siete_seg = 8'h88; 4'hB: siete_seg = 8'h83;
            4'hC: siete_seg = 8'hC6; 4'hD: siete_seg = 8'hA1; 4'hE: siete_seg = 8'h86; default: siete_seg = 8'h8E;
        endcase
    endfunction

    assign HEX0 = siete_seg(hex[3:0]);
    assign HEX1 = siete_seg(hex[7:4]);
    assign HEX2 = siete_seg(hex[11:8]);
    assign HEX3 = siete_seg(hex[15:12]);
    assign HEX4 = siete_seg(hex[19:16]);
    assign HEX5 = siete_seg(hex[23:20]);
endmodule
