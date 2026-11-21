`timescale 1ns / 1ps
// ============================================================
// DECISION DE SALTO CONDICIONAL
// La ALU resta rs1 - rs2 y las banderas deciden (como en la ALU de
// 4 bits de la Practica 2):
//   Z           -> igual               beq / bne
//   N xor O     -> menor con signo     blt / bge
//   C = 0       -> hubo prestamo       bltu / bgeu  (C=1 significa rs1 >= rs2)
// ============================================================
module unidad_saltos (
    input  wire [2:0] funct3,
    input  wire       C,
    input  wire       O,
    input  wire       Z,
    input  wire       N,
    output reg        tomar
);
    wire menor_signo = N ^ O;

    always @(*) begin
        case (funct3)
            3'b000:  tomar =  Z;             // beq
            3'b001:  tomar = ~Z;             // bne
            3'b100:  tomar =  menor_signo;   // blt
            3'b101:  tomar = ~menor_signo;   // bge
            3'b110:  tomar = ~C;             // bltu
            3'b111:  tomar =  C;             // bgeu
            default: tomar = 1'b0;
        endcase
    end
endmodule
