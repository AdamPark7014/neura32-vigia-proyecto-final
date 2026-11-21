`timescale 1ns / 1ps
// ============================================================
// UNIDAD DE ADELANTAMIENTO (forwarding)
// Si la instruccion en MEM o en WB va a escribir el registro que la
// instruccion en EX necesita, se toma el valor directamente del
// pipeline en lugar de esperar a que llegue al banco de registros.
//   2'b10 -> resultado de la etapa MEM (prioridad: es el mas reciente)
//   2'b01 -> resultado de la etapa WB
//   2'b00 -> valor leido del banco de registros
// ============================================================
module unidad_adelantamiento (
    input  wire [4:0] rs1_e,
    input  wire [4:0] rs2_e,
    input  wire [4:0] rd_m,
    input  wire       reg_write_m,
    input  wire [4:0] rd_w,
    input  wire       reg_write_w,
    output reg  [1:0] adel_a,
    output reg  [1:0] adel_b
);
    always @(*) begin
        if (reg_write_m && rd_m != 5'd0 && rd_m == rs1_e)      adel_a = 2'b10;
        else if (reg_write_w && rd_w != 5'd0 && rd_w == rs1_e) adel_a = 2'b01;
        else                                                    adel_a = 2'b00;

        if (reg_write_m && rd_m != 5'd0 && rd_m == rs2_e)      adel_b = 2'b10;
        else if (reg_write_w && rd_w != 5'd0 && rd_w == rs2_e) adel_b = 2'b01;
        else                                                    adel_b = 2'b00;
    end
endmodule
