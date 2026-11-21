`timescale 1ns / 1ps
// ============================================================
// MEMORIA DE DOBLE PUERTO CON DOS RELOJES
// Un puerto escribe con el reloj del sistema y el otro lee con el
// reloj del JTAG (TCK). Asi la PC lee la imagen sin cruzar datos entre
// relojes con logica: el cruce lo hace el bloque M9K.
// ============================================================
module memoria_dos_relojes #(
    parameter addr_width = 17,
    parameter data_width = 8,
    parameter palabras   = 76800
) (
    input  wire                  clk_esc,
    input  wire                  we,
    input  wire [addr_width-1:0] dir_esc,
    input  wire [data_width-1:0] dato_esc,
    input  wire                  clk_lec,
    input  wire [addr_width-1:0] dir_lec,
    output reg  [data_width-1:0] dato_lec
);
    reg [data_width-1:0] memoria [0:palabras-1];

    always @(posedge clk_esc)
        if (we) memoria[dir_esc] <= dato_esc;

    always @(posedge clk_lec)
        dato_lec <= memoria[dir_lec];
endmodule
