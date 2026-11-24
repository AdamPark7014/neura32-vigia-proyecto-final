`timescale 1ns / 1ps

// RAM de doble puerto
module memoria_doble_puerto #(
    parameter addr_width = 17,
    parameter data_width = 4,
    parameter palabras   = 76800
) (
    input  wire                  clk,
    input  wire                  we,
    input  wire [addr_width-1:0] dir_esc,
    input  wire [data_width-1:0] dato_esc,
    input  wire [addr_width-1:0] dir_lec,
    output reg  [data_width-1:0] dato_lec
);
    reg [data_width-1:0] memoria [0:palabras-1];

    integer i;
    // synthesis translate_off
    initial for (i = 0; i < palabras; i = i + 1) memoria[i] = {data_width{1'b0}};
    // synthesis translate_on
    always @(posedge clk)
        if (we) memoria[dir_esc] <= dato_esc;

    always @(posedge clk)
        dato_lec <= memoria[dir_lec];
endmodule
