`timescale 1ns / 1ps
// ============================================================
// RAM DE DATOS (Practica 4) — sincrona, un puerto, escritura por byte
// La direccion y el dato llegan desde la etapa EX; en el flanco se
// escribe (sb/sh/sw con habilitacion por byte) o se lee, y el dato
// leido queda listo durante la etapa MEM. Lectura y escritura sincronas
// permiten que Quartus use bloques M9K.
// Mapeada en 0x1000_0000.
//
// La memoria son cuatro arreglos de un byte (uno por carril). Es la
// forma que Quartus reconoce en Verilog para una RAM con habilitacion
// por byte: con un solo arreglo de 32 bits y escrituras parciales la
// arma con flip-flops (4096 x 32 = 131 072) y no cabe en la FPGA.
// ============================================================
module ram_datos #(
    parameter addr_width = 12,                   // 4096 palabras = 16 KB
    parameter data_width = 32
) (
    input  wire                  clk,
    input  wire [31:0]           dir,
    input  wire [data_width-1:0] dato_esc,
    input  wire [3:0]            be,             // habilitacion por byte
    input  wire                  we,
    output reg  [data_width-1:0] dato_lec
);
    reg [7:0] carril0 [0:(2**addr_width-1)];     // bits  7:0
    reg [7:0] carril1 [0:(2**addr_width-1)];     // bits 15:8
    reg [7:0] carril2 [0:(2**addr_width-1)];     // bits 23:16
    reg [7:0] carril3 [0:(2**addr_width-1)];     // bits 31:24
    wire [addr_width-1:0] idx = dir[addr_width+1:2];

    integer i;
    initial for (i = 0; i < 2**addr_width; i = i + 1) begin
        carril0[i] = 8'd0; carril1[i] = 8'd0; carril2[i] = 8'd0; carril3[i] = 8'd0;
    end

    always @(posedge clk) begin
        if (we && be[0]) carril0[idx] <= dato_esc[7:0];
        dato_lec[7:0] <= carril0[idx];
    end
    always @(posedge clk) begin
        if (we && be[1]) carril1[idx] <= dato_esc[15:8];
        dato_lec[15:8] <= carril1[idx];
    end
    always @(posedge clk) begin
        if (we && be[2]) carril2[idx] <= dato_esc[23:16];
        dato_lec[23:16] <= carril2[idx];
    end
    always @(posedge clk) begin
        if (we && be[3]) carril3[idx] <= dato_esc[31:24];
        dato_lec[31:24] <= carril3[idx];
    end

    // Vistas para los bancos de prueba: la palabra k y el byte de la direccion d
    // synthesis translate_off
    function [31:0] palabra;
        input integer k;
        palabra = {carril3[k], carril2[k], carril1[k], carril0[k]};
    endfunction

    function [7:0] octeto;
        input integer d;
        case (d % 4)
            0: octeto = carril0[d / 4];
            1: octeto = carril1[d / 4];
            2: octeto = carril2[d / 4];
            default: octeto = carril3[d / 4];
        endcase
    endfunction
    // synthesis translate_on
endmodule
