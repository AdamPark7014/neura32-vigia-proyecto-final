`timescale 1ns / 1ps

// tope DE10-Lite
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
    // reloj de 25 MHz
    reg clk25 = 1'b0;
    always @(posedge MAX10_CLK1_50) clk25 <= ~clk25;
    wire clk = clk25;
    wire pll_listo = 1'b1;

    // reloj desfasado 90 grados
    reg clk25_n = 1'b0;
    always @(negedge MAX10_CLK1_50) clk25_n <= clk25;
    wire [1:0] cam_fase;
    wire xclk = (cam_fase[0] ? clk25_n : clk25) ^ cam_fase[1];

    // reinicio
    reg [2:0] rst_s = 3'b111;
    always @(posedge clk) rst_s <= {rst_s[1:0], ~KEY[0] | ~pll_listo};
    wire rst = rst_s[2];

    // camara
    wire       cam_sioc, cam_reset_n, cam_pwdn;
    wire [7:0] cam_d = {GPIO[6], GPIO[7], GPIO[8], GPIO[9], GPIO[10], GPIO[11], GPIO[12], GPIO[13]};

    assign GPIO[0]  = cam_sioc;
    assign GPIO[5]  = xclk;
    assign GPIO[14] = cam_reset_n;
    assign GPIO[15] = cam_pwdn;
    assign GPIO[35:16] = 20'bz;

    // soC
    wire [23:0] hex;

    soc_neura32 #(
        .ARCHIVO_PROGRAMA("programa_vigia.txt"), .SIMULACION(0),
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
        .fin(), .instr_ilegal(), .ciclos(), .instret()
    );

    // displays
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
