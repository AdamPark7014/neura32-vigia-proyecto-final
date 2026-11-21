`timescale 1ns / 1ps
// ============================================================
// BANCO DE REGISTROS x0..x31 (32 bits)
// x0 cableado a cero. Dos puertos de lectura asincronos y uno de
// escritura sincrono. Si en el mismo ciclo se escribe el registro
// que se esta leyendo, la lectura entrega el valor nuevo (adelanto
// WB -> ID del pipeline).
// ============================================================
module banco_registros (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  wa,
    input  wire [31:0] wd,
    input  wire [4:0]  ra1,
    output wire [31:0] rd1,
    input  wire [4:0]  ra2,
    output wire [31:0] rd2
);
    reg [31:0] regs [0:31];

    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;

    always @(posedge clk)
        if (we && wa != 5'd0) regs[wa] <= wd;

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : ((we && wa == ra1) ? wd : regs[ra1]);
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : ((we && wa == ra2) ? wd : regs[ra2]);
endmodule
