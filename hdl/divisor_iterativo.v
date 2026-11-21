`timescale 1ns / 1ps
// ============================================================
// DIVISOR ITERATIVO (division con restauracion, 1 bit por ciclo)
// Resuelve DIV, DIVU, REM y REMU de RV32M en 34 ciclos sin un divisor
// combinacional de 32 bits (que no cabe en un ciclo de 40 ns).
//   ciclo 0      : toma los operandos y saca su valor absoluto
//   ciclos 1..32 : resta y desplaza, un bit del cociente por ciclo
//   ciclo 33     : 'listo' = 1, el resultado corregido de signo es valido
// Casos de la norma RISC-V sin logica extra:
//   division entre cero -> cociente 0xFFFFFFFF, residuo = dividendo
//   -2^31 / -1          -> cociente -2^31, residuo 0
// ============================================================
module divisor_iterativo (
    input  wire        clk,
    input  wire        rst,
    input  wire        pedir,         // hay una division en EX
    input  wire        con_signo,     // DIV / REM
    input  wire        quiere_resto,  // REM / REMU
    input  wire [31:0] dividendo,
    input  wire [31:0] divisor,
    output wire        listo,
    output wire [31:0] resultado
);
    localparam LIBRE = 2'd0, DIVIDE = 2'd1, FIN = 2'd2;

    reg [1:0]  estado;
    reg [4:0]  cuenta;
    reg [32:0] resto;        // 33 bits: el desplazamiento no debe perder el acarreo
    reg [31:0] cociente;
    reg [31:0] div_abs;
    reg        neg_cociente, neg_resto, resto_sel;

    wire [32:0] resto_despl = {resto[31:0], cociente[31]};
    wire [32:0] resta       = resto_despl - {1'b0, div_abs};
    wire        cabe        = ~resta[32];

    always @(posedge clk) begin
        if (rst) begin
            estado <= LIBRE;
        end else begin
            case (estado)
                LIBRE: if (pedir) begin
                    cociente     <= (con_signo && dividendo[31]) ? -dividendo : dividendo;
                    div_abs      <= (con_signo && divisor[31])   ? -divisor   : divisor;
                    resto        <= 33'd0;
                    cuenta       <= 5'd0;
                    neg_cociente <= con_signo && (dividendo[31] ^ divisor[31]) && (divisor != 32'd0);
                    neg_resto    <= con_signo && dividendo[31];
                    resto_sel    <= quiere_resto;
                    estado       <= DIVIDE;
                end
                DIVIDE: begin
                    resto    <= cabe ? resta : resto_despl;
                    cociente <= {cociente[30:0], cabe};
                    cuenta   <= cuenta + 5'd1;
                    if (cuenta == 5'd31) estado <= FIN;
                end
                FIN: estado <= LIBRE;
                default: estado <= LIBRE;
            endcase
        end
    end

    assign listo = (estado == FIN);

    wire [31:0] c_final = neg_cociente ? -cociente    : cociente;
    wire [31:0] r_final = neg_resto    ? -resto[31:0] : resto[31:0];
    assign resultado = resto_sel ? r_final : c_final;
endmodule
