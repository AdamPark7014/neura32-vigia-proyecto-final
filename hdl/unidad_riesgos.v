`timescale 1ns / 1ps
// ============================================================
// UNIDAD DE RIESGOS (hazards)
//  * Riesgo de carga-uso: una carga en EX cuyo destino necesita la
//    instruccion en ID -> se detiene IF/ID un ciclo y se mete una
//    burbuja en EX (con ADELANTAR_CARGAS=1 el dato leido se adelanta
//    desde MEM y no hace falta detenerse).
//  * Salto tomado en EX -> se anulan las dos instrucciones mas jovenes
//    (IF/ID e ID/EX), que se habian traido especulativamente.
//  * Division en EX (divisor iterativo) -> se congelan IF, ID y EX
//    hasta que el divisor termina; a MEM entran burbujas.
//  * ecall/ebreak -> se congela el PC y se vacia lo que venia detras.
// ============================================================
module unidad_riesgos #(
    parameter ADELANTAR_CARGAS = 0
) (
    input  wire [4:0] rs1_d,
    input  wire [4:0] rs2_d,
    input  wire [4:0] rd_e,
    input  wire       mem_read_e,
    input  wire       salto_tomado_e,
    input  wire       detener,
    input  wire       parar_e,        // el divisor esta trabajando
    output wire       parar_f,
    output wire       parar_d,
    output wire       limpiar_d,
    output wire       limpiar_e
);
    wire riesgo_carga = (ADELANTAR_CARGAS == 0) && mem_read_e && (rd_e != 5'd0) &&
                        ((rd_e == rs1_d) || (rd_e == rs2_d));

    assign parar_f   = riesgo_carga | detener | parar_e;
    assign parar_d   = riesgo_carga | parar_e;
    assign limpiar_d = (salto_tomado_e | detener) & ~parar_e;
    assign limpiar_e = (riesgo_carga | salto_tomado_e | detener) & ~parar_e;
endmodule
