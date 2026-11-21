`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// ALU RISC-V DE 32 BITS (Practica 3, version del proyecto)
//
// La ALU recibe la instruccion y decide la operacion con sus campos.
// Formato tipo R (32 bits):
//
//   | funct7 (7) | rs2 (5) | rs1 (5) | funct3 (3) | rd (5) | opcode (7) |
//     31      25   24   20   19   15   14      12   11   7   6        0
//
// rs1, rs2 y rd escogen registros (eso lo hace el banco de registros);
// aqui se usan opcode, funct3 y funct7 en tres case anidados:
//
//   case (opcode)          que tipo de instruccion es
//     case (funct3)        que operacion (3 bits)
//       case (funct7)      que variante (suma o resta, logico o aritmetico...)
//
// Solo trae las operaciones del repertorio de NEURA-32 Vigia:
//   RV32I   add sub sll slt sltu xor srl sra or and  (y las mismas con inmediato)
//   RV32M   mul mulh mulhsu mulhu   (div divu rem remu: divisor_iterativo)
//   Zbb     andn orn xnor min minu max maxu rol ror rori
//           clz ctz cpop sext.b sext.h zext.h rev8
//   clase   nota passb sla          (custom-0, las de la ROM del laboratorio)
//   Xneura  abs sgt clamp           (custom-1, las que pide el programa)
// En cargas, almacenamientos, auipc y saltos suma (direccion); en los
// saltos condicionales resta y deja las banderas; en lui deja pasar B.
// ============================================================
module alu_riscv (
    input  wire [31:0] instr,    // instruccion que esta en la etapa EX
    input  wire [31:0] A,        // operando A: rs1 (o el PC)
    input  wire [31:0] B,        // operando B: rs2 (o el inmediato)

    output reg  [31:0] result,
    output reg         ilegal,   // esa combinacion de funct3 / funct7 no existe
    output wire        C,        // acarreo (en la resta: 1 si no hubo prestamo)
    output wire        O,        // desbordamiento con signo
    output wire        Z,        // resultado cero
    output wire        N         // resultado negativo
);

// ---------------- campos de la instruccion ----------------
wire [6:0] funct7 = instr[31:25];
wire [4:0] rs2    = instr[24:20];   // en clz/ctz/cpop/sext y rev8 dice cual es
wire [2:0] funct3 = instr[14:12];
wire [6:0] opcode = instr[6:0];

// valores de funct7
localparam F7_BASE   = 7'b0000000;  // RV32I
localparam F7_NEG    = 7'b0100000;  // sub, sra y las negadas de Zbb
localparam F7_MUL    = 7'b0000001;  // RV32M
localparam F7_MINMAX = 7'b0000101;  // Zbb: min, minu, max, maxu
localparam F7_ROT    = 7'b0110000;  // Zbb: rol, ror y las de un operando
localparam F7_ZEXT   = 7'b0000100;  // Zbb: zext.h
localparam F7_REV8   = 7'b0110100;  // Zbb: rev8

// ---------------- sumas y productos ----------------
wire [4:0]  shamt = B[4:0];

// 33 bits: el bit 32 es el acarreo. La resta es A + ~B + 1, asi que su
// bit 32 vale 1 cuando no hubo prestamo (A >= B).
wire [32:0] add_ext = {1'b0, A} + {1'b0, B};
wire [32:0] sub_ext = {1'b0, A} + {1'b0, ~B} + 33'd1;

wire ovf_add = (A[31] == B[31]) && (add_ext[31] != A[31]);
wire ovf_sub = (A[31] != B[31]) && (sub_ext[31] != A[31]);

wire signed [63:0] mul_ss = $signed(A) * $signed(B);
wire        [63:0] mul_uu = A * B;
wire signed [63:0] mul_su = $signed(A) * $signed({1'b0, B});

wire menor_s = ($signed(A) < $signed(B));
wire menor_u = (A < B);

wire [31:0] rota_izq = (shamt == 0) ? A : ((A << shamt) | (A >> (6'd32 - shamt)));
wire [31:0] rota_der = (shamt == 0) ? A : ((A >> shamt) | (A << (6'd32 - shamt)));

// ---------------- funciones ----------------
// Ceros a la izquierda por mitades: se pregunta por 16, 8, 4, 2 y 1 bits
function [31:0] count_leading_zeros;
    input [31:0] v;
    reg   [31:0] x;
    reg   [5:0]  n;
    begin
        x = v; n = 6'd0;
        if (x[31:16] == 16'd0) begin n = n + 6'd16; x = x << 16; end
        if (x[31:24] == 8'd0)  begin n = n + 6'd8;  x = x << 8;  end
        if (x[31:28] == 4'd0)  begin n = n + 6'd4;  x = x << 4;  end
        if (x[31:30] == 2'd0)  begin n = n + 6'd2;  x = x << 2;  end
        if (x[31]    == 1'b0)  begin n = n + 6'd1;               end
        count_leading_zeros = (v == 32'd0) ? 32'd32 : {26'd0, n};
    end
endfunction

// Ceros a la derecha: lo mismo, empezando por la mitad baja
function [31:0] count_trailing_zeros;
    input [31:0] v;
    reg   [31:0] x;
    reg   [5:0]  n;
    begin
        x = v; n = 6'd0;
        if (x[15:0] == 16'd0) begin n = n + 6'd16; x = x >> 16; end
        if (x[7:0]  == 8'd0)  begin n = n + 6'd8;  x = x >> 8;  end
        if (x[3:0]  == 4'd0)  begin n = n + 6'd4;  x = x >> 4;  end
        if (x[1:0]  == 2'd0)  begin n = n + 6'd2;  x = x >> 2;  end
        if (x[0]    == 1'b0)  begin n = n + 6'd1;               end
        count_trailing_zeros = (v == 32'd0) ? 32'd32 : {26'd0, n};
    end
endfunction

// Conteo de unos en arbol: bits por parejas, parejas por cuartetos,
// cuartetos por bytes, bytes por mitades y las dos mitades (5 niveles).
// Es la operacion que mas usa la red neuronal binaria (xnor + cpop).
function [31:0] popcount;
    input [31:0] v;
    reg   [31:0] s1, s2, s4, s8;
    begin
        s1 = (v  & 32'h55555555) + ((v  >> 1) & 32'h55555555);
        s2 = (s1 & 32'h33333333) + ((s1 >> 2) & 32'h33333333);
        s4 = (s2 & 32'h0F0F0F0F) + ((s2 >> 4) & 32'h0F0F0F0F);
        s8 = (s4 & 32'h00FF00FF) + ((s4 >> 8) & 32'h00FF00FF);
        popcount = (s8 & 32'h0000FFFF) + (s8 >> 16);
    end
endfunction

// ============================================================
// ALU PRINCIPAL: case (opcode) -> case (funct3) -> case (funct7)
// ============================================================
always @(*) begin
    result = add_ext[31:0];                 // por defecto suma
    ilegal = 1'b0;

    case (opcode)
        // ================= TIPO R: rd = rs1 (operacion) rs2 =================
        `OP_R: begin
            case (funct3)
                3'b000: begin
                    case (funct7)
                        F7_BASE: result = add_ext[31:0];              // add
                        F7_NEG:  result = sub_ext[31:0];              // sub
                        F7_MUL:  result = mul_ss[31:0];               // mul
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b001: begin
                    case (funct7)
                        F7_BASE: result = A << shamt;                 // sll
                        F7_MUL:  result = mul_ss[63:32];              // mulh
                        F7_ROT:  result = rota_izq;                   // rol
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b010: begin
                    case (funct7)
                        F7_BASE: result = menor_s ? 32'd1 : 32'd0;    // slt
                        F7_MUL:  result = mul_su[63:32];              // mulhsu
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b011: begin
                    case (funct7)
                        F7_BASE: result = menor_u ? 32'd1 : 32'd0;    // sltu
                        F7_MUL:  result = mul_uu[63:32];              // mulhu
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b100: begin
                    case (funct7)
                        F7_BASE:   result = A ^ B;                    // xor
                        F7_NEG:    result = ~(A ^ B);                 // xnor
                        F7_MUL:    result = 32'd0;                    // div  (divisor_iterativo)
                        F7_MINMAX: result = menor_s ? A : B;          // min
                        F7_ZEXT: begin                                // zext.h (rs2 = x0)
                            result = {16'b0, A[15:0]};
                            if (rs2 != 5'd0) ilegal = 1'b1;
                        end
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b101: begin
                    case (funct7)
                        F7_BASE:   result = A >> shamt;               // srl
                        F7_NEG:    result = $signed(A) >>> shamt;     // sra
                        F7_MUL:    result = 32'd0;                    // divu (divisor_iterativo)
                        F7_MINMAX: result = menor_u ? A : B;          // minu
                        F7_ROT:    result = rota_der;                 // ror
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b110: begin
                    case (funct7)
                        F7_BASE:   result = A | B;                    // or
                        F7_NEG:    result = A | ~B;                   // orn
                        F7_MUL:    result = 32'd0;                    // rem  (divisor_iterativo)
                        F7_MINMAX: result = menor_s ? B : A;          // max
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b111: begin
                    case (funct7)
                        F7_BASE:   result = A & B;                    // and
                        F7_NEG:    result = A & ~B;                   // andn
                        F7_MUL:    result = 32'd0;                    // remu (divisor_iterativo)
                        F7_MINMAX: result = menor_u ? B : A;          // maxu
                        default: ilegal = 1'b1;
                    endcase
                end
                default: ilegal = 1'b1;
            endcase
        end

        // ================= TIPO I: rd = rs1 (operacion) inmediato =================
        // En los corrimientos y en Zbb los 7 bits altos del inmediato hacen de funct7
        // y los 5 bajos (el campo rs2) son la cantidad o dicen cual instruccion es.
        `OP_IMM: begin
            case (funct3)
                3'b000: result = add_ext[31:0];                       // addi
                3'b010: result = menor_s ? 32'd1 : 32'd0;             // slti
                3'b011: result = menor_u ? 32'd1 : 32'd0;             // sltiu
                3'b100: result = A ^ B;                               // xori
                3'b110: result = A | B;                               // ori
                3'b111: result = A & B;                               // andi
                3'b001: begin
                    case (funct7)
                        F7_BASE: result = A << shamt;                 // slli
                        F7_ROT: begin                                 // Zbb de un operando
                            case (rs2)
                                5'd0:    result = count_leading_zeros(A);    // clz
                                5'd1:    result = count_trailing_zeros(A);   // ctz
                                5'd2:    result = popcount(A);               // cpop
                                5'd4:    result = {{24{A[7]}},  A[7:0]};     // sext.b
                                5'd5:    result = {{16{A[15]}}, A[15:0]};    // sext.h
                                default: ilegal = 1'b1;
                            endcase
                        end
                        default: ilegal = 1'b1;
                    endcase
                end
                3'b101: begin
                    case (funct7)
                        F7_BASE: result = A >> shamt;                 // srli
                        F7_NEG:  result = $signed(A) >>> shamt;       // srai
                        F7_ROT:  result = rota_der;                   // rori
                        F7_REV8: begin                                // rev8 (inmediato 0x698)
                            result = {A[7:0], A[15:8], A[23:16], A[31:24]};
                            if (rs2 != 5'b11000) ilegal = 1'b1;
                        end
                        default: ilegal = 1'b1;
                    endcase
                end
                default: ilegal = 1'b1;
            endcase
        end

        // ================= PROPIAS DE LA CLASE (custom-0, formato R) =================
        `OP_CUSTOM0: begin
            case (funct3)
                3'b000: result = ~A;                                  // nota  rd = ~rs1
                3'b001: result = B;                                   // passb rd = rs2
                3'b010: result = A << shamt;                          // sla   rd = rs1 << rs2
                default: ilegal = 1'b1;
            endcase
            if (funct7 != F7_BASE) ilegal = 1'b1;
        end

        // ================= Xneura: PROPIAS DEL PROYECTO (custom-1, formato R) =================
        `OP_CUSTOM1: begin
            case (funct3)
                3'b000: result = A[31] ? (~A + 1) : A;                             // x.abs   rd = |rs1|
                3'b001: result = ($signed(A) > $signed(B)) ? 32'd1 : 32'd0;        // x.sgt   rd = rs1 > rs2
                3'b010: result = A[31] ? 32'd0 : (($signed(A) > $signed(B)) ? B : A);   // x.clamp rd = limitar(rs1, 0, rs2)
                default: ilegal = 1'b1;
            endcase
            if (funct7 != F7_BASE) ilegal = 1'b1;
        end

        // ================= SALTOS CONDICIONALES: resta y banderas =================
        `OP_BRANCH: result = sub_ext[31:0];

        // ================= LUI: deja pasar el inmediato =================
        `OP_LUI: result = B;

        // cargas, almacenamientos, auipc, jal, jalr: suma (direccion)
        default: result = add_ext[31:0];
    endcase
end

// ============================================================
// BANDERAS (las de la resta deciden los saltos condicionales)
// ============================================================
wire es_resta = (opcode == `OP_BRANCH) ||
                ((opcode == `OP_R) && (funct3 == 3'b000) && (funct7 == F7_NEG));

assign Z = (result == 32'b0);
assign N = result[31];
assign C = es_resta ? sub_ext[32] : add_ext[32];
assign O = es_resta ? ovf_sub     : ovf_add;

endmodule
