`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// REGISTROS DE CONTROL Y ESTADO (Zicsr + Zicntr)
//   cycle / mcycle       ciclos de reloj desde el reset (64 bits)
//   instret / minstret   instrucciones retiradas (64 bits)
//   time                 = cycle (sin temporizador externo)
//   mscratch             registro libre de 32 bits
//   misa, mvendorid, marchid, mimpid, mhartid   identificacion (solo lectura)
//                        marcada con ".f"; tambien se puede escribir por CSR.
// Las operaciones csrrw/csrrs/csrrc se resuelven en la etapa EX.
// ============================================================
module registros_csr (
    input  wire        clk,
    input  wire        rst,

    input  wire [11:0] dir,
    input  wire        we,
    input  wire [1:0]  tipo,          // RW / RS / RC
    input  wire [31:0] dato_esc,
    output reg  [31:0] dato_lec,

    input  wire        retirar,       // una instruccion llego a WB

    output reg  [63:0] ciclos,
    output reg  [63:0] instret
);
    reg [31:0] mscratch;

    // ---- lectura ----
    always @(*) begin
        case (dir)
            `CSR_MSCRATCH:               dato_lec = mscratch;
            `CSR_MCYCLE,   `CSR_CYCLE,
            `CSR_TIME:                   dato_lec = ciclos[31:0];
            `CSR_MCYCLEH,  `CSR_CYCLEH,
            `CSR_TIMEH:                  dato_lec = ciclos[63:32];
            `CSR_MINSTRET, `CSR_INSTRET: dato_lec = instret[31:0];
            `CSR_MINSTRETH,`CSR_INSTRETH:dato_lec = instret[63:32];
            `CSR_MISA:                   dato_lec = `VALOR_MISA;
            `CSR_MVENDORID:              dato_lec = 32'd0;
            `CSR_MARCHID:                dato_lec = `VALOR_MARCHID;
            `CSR_MIMPID:                 dato_lec = `VALOR_MIMPID;
            `CSR_MHARTID:                dato_lec = 32'd0;
            default:                     dato_lec = 32'd0;
        endcase
    end

    // ---- valor que se escribiria segun el tipo de operacion ----
    reg [31:0] nuevo;
    always @(*) begin
        case (tipo)
            `CSR_RW: nuevo = dato_esc;
            `CSR_RS: nuevo = dato_lec |  dato_esc;
            `CSR_RC: nuevo = dato_lec & ~dato_esc;
            default: nuevo = dato_lec;
        endcase
    end

    // ---- escritura y contadores ----
    always @(posedge clk) begin
        if (rst) begin
            ciclos   <= 64'd0;
            instret  <= 64'd0;
            mscratch <= 32'd0;
        end else begin
            ciclos <= ciclos + 64'd1;
            if (retirar) instret <= instret + 64'd1;

            if (we) begin
                case (dir)
                    `CSR_MSCRATCH:  mscratch        <= nuevo;
                    `CSR_MCYCLE:    ciclos[31:0]    <= nuevo;
                    `CSR_MCYCLEH:   ciclos[63:32]   <= nuevo;
                    `CSR_MINSTRET:  instret[31:0]   <= nuevo;
                    `CSR_MINSTRETH: instret[63:32]  <= nuevo;
                    default: ;
                endcase
            end
        end
    end
endmodule
