`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// GENERADOR DE INMEDIATO (Practica 5)
// Arma el inmediato de 32 bits segun el formato y extiende el signo.
// ============================================================
module generador_inmediato (
    input  wire [31:0] instr,
    input  wire [2:0]  tipo,
    output reg  [31:0] inm
);
    always @(*) begin
        case (tipo)
            `INM_I: inm = {{20{instr[31]}}, instr[31:20]};
            `INM_S: inm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            `INM_B: inm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            `INM_U: inm = {instr[31:12], 12'b0};
            `INM_J: inm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            `INM_Z: inm = {27'b0, instr[19:15]};
            default: inm = 32'd0;
        endcase
    end
endmodule
