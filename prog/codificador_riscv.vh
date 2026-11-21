// ============================================================
// CODIFICADOR RISC-V EN VERILOG ("ensamblador" de dos pasadas)
// Se incluye dentro de rom_instrucciones. Cada funcion devuelve la
// palabra de 32 bits de una instruccion ya codificada bit a bit segun
// los formatos R, I, S, B, U y J del manual RISC-V (Volumen I, cap. 2).
// Las tareas emiten en la ROM: 'emitir' escribe en memoria[pc_ens/4]
// y avanza pc_ens. Los programas se escriben como una tarea que se
// ejecuta dos veces: la primera fija las etiquetas, la segunda codifica
// con los desplazamientos correctos.
// ============================================================

// ---- nombres ABI de los registros ----
localparam X0 = 5'd0,  ZERO = 5'd0, RA = 5'd1,  SP = 5'd2,  GP = 5'd3,  TP = 5'd4;
localparam T0 = 5'd5,  T1 = 5'd6,   T2 = 5'd7,  S0 = 5'd8,  FP = 5'd8,  S1 = 5'd9;
localparam A0 = 5'd10, A1 = 5'd11,  A2 = 5'd12, A3 = 5'd13, A4 = 5'd14, A5 = 5'd15;
localparam A6 = 5'd16, A7 = 5'd17,  S2 = 5'd18, S3 = 5'd19, S4 = 5'd20, S5 = 5'd21;
localparam S6 = 5'd22, S7 = 5'd23,  S8 = 5'd24, S9 = 5'd25, S10 = 5'd26, S11 = 5'd27;
localparam T3 = 5'd28, T4 = 5'd29,  T5 = 5'd30, T6 = 5'd31;

// ---- formatos ----
function [31:0] fmt_r;
    input [6:0] f7; input [4:0] rs2; input [4:0] rs1; input [2:0] f3; input [4:0] rd; input [6:0] op;
    fmt_r = {f7, rs2, rs1, f3, rd, op};
endfunction

function [31:0] fmt_i;
    input integer imm; input [4:0] rs1; input [2:0] f3; input [4:0] rd; input [6:0] op;
    fmt_i = {imm[11:0], rs1, f3, rd, op};
endfunction

function [31:0] fmt_s;
    input integer imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3; input [6:0] op;
    fmt_s = {imm[11:5], rs2, rs1, f3, imm[4:0], op};
endfunction

// Control del ensamblador de dos pasadas: en la pasada 1 las etiquetas ya
// tienen su valor final y se revisa que cada salto quepa en su formato.
integer pasada_ens  = 0;
integer errores_ens = 0;
integer pc_ens;              // direccion (en bytes) de la siguiente palabra que se emite

function [31:0] fmt_b;
    input integer imm; input [4:0] rs2; input [4:0] rs1; input [2:0] f3;
    begin
        if (pasada_ens == 1 && (imm > 4094 || imm < -4096 || imm[0])) begin
            $display("ENSAMBLADOR: salto condicional fuera de rango (%0d) en 0x%04h", imm, pc_ens);
            errores_ens = errores_ens + 1;
        end
        fmt_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], `OP_BRANCH};
    end
endfunction

function [31:0] fmt_u;
    input [31:0] imm; input [4:0] rd; input [6:0] op;
    fmt_u = {imm[31:12], rd, op};
endfunction

function [31:0] fmt_j;
    input integer imm; input [4:0] rd;
    begin
        if (pasada_ens == 1 && (imm > 1048574 || imm < -1048576 || imm[0])) begin
            $display("ENSAMBLADOR: jal fuera de rango (%0d) en 0x%04h", imm, pc_ens);
            errores_ens = errores_ens + 1;
        end
        fmt_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, `OP_JAL};
    end
endfunction

// ---- RV32I: tipo R ----
function [31:0] ADD;  input [4:0] rd, rs1, rs2; ADD  = fmt_r(7'h00, rs2, rs1, 3'b000, rd, `OP_R); endfunction
function [31:0] SUB;  input [4:0] rd, rs1, rs2; SUB  = fmt_r(7'h20, rs2, rs1, 3'b000, rd, `OP_R); endfunction
function [31:0] SLL;  input [4:0] rd, rs1, rs2; SLL  = fmt_r(7'h00, rs2, rs1, 3'b001, rd, `OP_R); endfunction
function [31:0] SLT;  input [4:0] rd, rs1, rs2; SLT  = fmt_r(7'h00, rs2, rs1, 3'b010, rd, `OP_R); endfunction
function [31:0] SLTU; input [4:0] rd, rs1, rs2; SLTU = fmt_r(7'h00, rs2, rs1, 3'b011, rd, `OP_R); endfunction
function [31:0] XOR;  input [4:0] rd, rs1, rs2; XOR  = fmt_r(7'h00, rs2, rs1, 3'b100, rd, `OP_R); endfunction
function [31:0] SRL;  input [4:0] rd, rs1, rs2; SRL  = fmt_r(7'h00, rs2, rs1, 3'b101, rd, `OP_R); endfunction
function [31:0] SRA;  input [4:0] rd, rs1, rs2; SRA  = fmt_r(7'h20, rs2, rs1, 3'b101, rd, `OP_R); endfunction
function [31:0] OR;   input [4:0] rd, rs1, rs2; OR   = fmt_r(7'h00, rs2, rs1, 3'b110, rd, `OP_R); endfunction
function [31:0] AND;  input [4:0] rd, rs1, rs2; AND  = fmt_r(7'h00, rs2, rs1, 3'b111, rd, `OP_R); endfunction

// ---- RV32M ----
function [31:0] MUL;    input [4:0] rd, rs1, rs2; MUL    = fmt_r(7'h01, rs2, rs1, 3'b000, rd, `OP_R); endfunction
function [31:0] MULH;   input [4:0] rd, rs1, rs2; MULH   = fmt_r(7'h01, rs2, rs1, 3'b001, rd, `OP_R); endfunction
function [31:0] MULHSU; input [4:0] rd, rs1, rs2; MULHSU = fmt_r(7'h01, rs2, rs1, 3'b010, rd, `OP_R); endfunction
function [31:0] MULHU;  input [4:0] rd, rs1, rs2; MULHU  = fmt_r(7'h01, rs2, rs1, 3'b011, rd, `OP_R); endfunction
function [31:0] DIV;    input [4:0] rd, rs1, rs2; DIV    = fmt_r(7'h01, rs2, rs1, 3'b100, rd, `OP_R); endfunction
function [31:0] DIVU;   input [4:0] rd, rs1, rs2; DIVU   = fmt_r(7'h01, rs2, rs1, 3'b101, rd, `OP_R); endfunction
function [31:0] REM;    input [4:0] rd, rs1, rs2; REM    = fmt_r(7'h01, rs2, rs1, 3'b110, rd, `OP_R); endfunction
function [31:0] REMU;   input [4:0] rd, rs1, rs2; REMU   = fmt_r(7'h01, rs2, rs1, 3'b111, rd, `OP_R); endfunction

// ---- RV32I: tipo I ----
function [31:0] ADDI;  input [4:0] rd, rs1; input integer imm; ADDI  = fmt_i(imm, rs1, 3'b000, rd, `OP_IMM); endfunction
function [31:0] SLTI;  input [4:0] rd, rs1; input integer imm; SLTI  = fmt_i(imm, rs1, 3'b010, rd, `OP_IMM); endfunction
function [31:0] SLTIU; input [4:0] rd, rs1; input integer imm; SLTIU = fmt_i(imm, rs1, 3'b011, rd, `OP_IMM); endfunction
function [31:0] XORI;  input [4:0] rd, rs1; input integer imm; XORI  = fmt_i(imm, rs1, 3'b100, rd, `OP_IMM); endfunction
function [31:0] ORI;   input [4:0] rd, rs1; input integer imm; ORI   = fmt_i(imm, rs1, 3'b110, rd, `OP_IMM); endfunction
function [31:0] ANDI;  input [4:0] rd, rs1; input integer imm; ANDI  = fmt_i(imm, rs1, 3'b111, rd, `OP_IMM); endfunction
function [31:0] SLLI;  input [4:0] rd, rs1; input integer sh;  SLLI  = fmt_i(sh & 31,          rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] SRLI;  input [4:0] rd, rs1; input integer sh;  SRLI  = fmt_i(sh & 31,          rs1, 3'b101, rd, `OP_IMM); endfunction
function [31:0] SRAI;  input [4:0] rd, rs1; input integer sh;  SRAI  = fmt_i((sh & 31) | 1024, rs1, 3'b101, rd, `OP_IMM); endfunction

// ---- cargas: LW(rd, rs1, imm) equivale a "lw rd, imm(rs1)" ----
function [31:0] LB;  input [4:0] rd, rs1; input integer imm; LB  = fmt_i(imm, rs1, 3'b000, rd, `OP_LOAD); endfunction
function [31:0] LH;  input [4:0] rd, rs1; input integer imm; LH  = fmt_i(imm, rs1, 3'b001, rd, `OP_LOAD); endfunction
function [31:0] LW;  input [4:0] rd, rs1; input integer imm; LW  = fmt_i(imm, rs1, 3'b010, rd, `OP_LOAD); endfunction
function [31:0] LBU; input [4:0] rd, rs1; input integer imm; LBU = fmt_i(imm, rs1, 3'b100, rd, `OP_LOAD); endfunction
function [31:0] LHU; input [4:0] rd, rs1; input integer imm; LHU = fmt_i(imm, rs1, 3'b101, rd, `OP_LOAD); endfunction

// ---- almacenamientos: SW(rs2, rs1, imm) equivale a "sw rs2, imm(rs1)" ----
function [31:0] SB; input [4:0] rs2, rs1; input integer imm; SB = fmt_s(imm, rs2, rs1, 3'b000, `OP_STORE); endfunction
function [31:0] SH; input [4:0] rs2, rs1; input integer imm; SH = fmt_s(imm, rs2, rs1, 3'b001, `OP_STORE); endfunction
function [31:0] SW; input [4:0] rs2, rs1; input integer imm; SW = fmt_s(imm, rs2, rs1, 3'b010, `OP_STORE); endfunction

// ---- saltos condicionales: desplazamiento relativo al PC de la instruccion ----
function [31:0] BEQ;  input [4:0] rs1, rs2; input integer off; BEQ  = fmt_b(off, rs2, rs1, 3'b000); endfunction
function [31:0] BNE;  input [4:0] rs1, rs2; input integer off; BNE  = fmt_b(off, rs2, rs1, 3'b001); endfunction
function [31:0] BLT;  input [4:0] rs1, rs2; input integer off; BLT  = fmt_b(off, rs2, rs1, 3'b100); endfunction
function [31:0] BGE;  input [4:0] rs1, rs2; input integer off; BGE  = fmt_b(off, rs2, rs1, 3'b101); endfunction
function [31:0] BLTU; input [4:0] rs1, rs2; input integer off; BLTU = fmt_b(off, rs2, rs1, 3'b110); endfunction
function [31:0] BGEU; input [4:0] rs1, rs2; input integer off; BGEU = fmt_b(off, rs2, rs1, 3'b111); endfunction

// ---- tipo U y J ----
function [31:0] LUI;   input [4:0] rd; input [31:0] imm; LUI   = fmt_u(imm, rd, `OP_LUI);   endfunction
function [31:0] AUIPC; input [4:0] rd; input [31:0] imm; AUIPC = fmt_u(imm, rd, `OP_AUIPC); endfunction
function [31:0] JAL;   input [4:0] rd; input integer off;  JAL   = fmt_j(off, rd); endfunction
function [31:0] JALR;  input [4:0] rd, rs1; input integer imm; JALR = fmt_i(imm, rs1, 3'b000, rd, `OP_JALR); endfunction

// ---- sistema y CSR ----
function [31:0] ECALL;  input dummy; ECALL  = 32'h00000073; endfunction
function [31:0] EBREAK; input dummy; EBREAK = 32'h00100073; endfunction
function [31:0] FENCE;  input dummy; FENCE  = 32'h0FF0000F; endfunction
function [31:0] CSRRW;  input [4:0] rd; input [11:0] csr; input [4:0] rs1; CSRRW  = fmt_i(csr, rs1, 3'b001, rd, `OP_SYSTEM); endfunction
function [31:0] CSRRS;  input [4:0] rd; input [11:0] csr; input [4:0] rs1; CSRRS  = fmt_i(csr, rs1, 3'b010, rd, `OP_SYSTEM); endfunction
function [31:0] CSRRC;  input [4:0] rd; input [11:0] csr; input [4:0] rs1; CSRRC  = fmt_i(csr, rs1, 3'b011, rd, `OP_SYSTEM); endfunction
function [31:0] CSRRWI; input [4:0] rd; input [11:0] csr; input [4:0] uimm; CSRRWI = fmt_i(csr, uimm, 3'b101, rd, `OP_SYSTEM); endfunction
function [31:0] CSRRSI; input [4:0] rd; input [11:0] csr; input [4:0] uimm; CSRRSI = fmt_i(csr, uimm, 3'b110, rd, `OP_SYSTEM); endfunction
function [31:0] CSRRCI; input [4:0] rd; input [11:0] csr; input [4:0] uimm; CSRRCI = fmt_i(csr, uimm, 3'b111, rd, `OP_SYSTEM); endfunction

// ---- Zbb (manipulacion de bits, las de la ROM de instrucciones de la clase) ----
function [31:0] ANDN; input [4:0] rd, rs1, rs2; ANDN = fmt_r(7'h20, rs2, rs1, 3'b111, rd, `OP_R); endfunction
function [31:0] ORN;  input [4:0] rd, rs1, rs2; ORN  = fmt_r(7'h20, rs2, rs1, 3'b110, rd, `OP_R); endfunction
function [31:0] XNOR; input [4:0] rd, rs1, rs2; XNOR = fmt_r(7'h20, rs2, rs1, 3'b100, rd, `OP_R); endfunction
function [31:0] MIN;  input [4:0] rd, rs1, rs2; MIN  = fmt_r(7'h05, rs2, rs1, 3'b100, rd, `OP_R); endfunction
function [31:0] MINU; input [4:0] rd, rs1, rs2; MINU = fmt_r(7'h05, rs2, rs1, 3'b101, rd, `OP_R); endfunction
function [31:0] MAX;  input [4:0] rd, rs1, rs2; MAX  = fmt_r(7'h05, rs2, rs1, 3'b110, rd, `OP_R); endfunction
function [31:0] MAXU; input [4:0] rd, rs1, rs2; MAXU = fmt_r(7'h05, rs2, rs1, 3'b111, rd, `OP_R); endfunction
function [31:0] ROL;  input [4:0] rd, rs1, rs2; ROL  = fmt_r(7'h30, rs2, rs1, 3'b001, rd, `OP_R); endfunction
function [31:0] ROR;  input [4:0] rd, rs1, rs2; ROR  = fmt_r(7'h30, rs2, rs1, 3'b101, rd, `OP_R); endfunction
function [31:0] ZEXT_H; input [4:0] rd, rs1;    ZEXT_H = fmt_r(7'h04, 5'd0, rs1, 3'b100, rd, `OP_R); endfunction
function [31:0] RORI;   input [4:0] rd, rs1; input integer sh; RORI = fmt_i((sh & 31) | 32'h600, rs1, 3'b101, rd, `OP_IMM); endfunction
function [31:0] CLZ;    input [4:0] rd, rs1; CLZ    = fmt_i(32'h600, rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] CTZ;    input [4:0] rd, rs1; CTZ    = fmt_i(32'h601, rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] CPOP;   input [4:0] rd, rs1; CPOP   = fmt_i(32'h602, rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] SEXT_B; input [4:0] rd, rs1; SEXT_B = fmt_i(32'h604, rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] SEXT_H; input [4:0] rd, rs1; SEXT_H = fmt_i(32'h605, rs1, 3'b001, rd, `OP_IMM); endfunction
function [31:0] REV8;   input [4:0] rd, rs1; REV8   = fmt_i(32'h698, rs1, 3'b101, rd, `OP_IMM); endfunction

// ---- instrucciones propias de la clase (custom-0, formato R) ----
//   nota rd, rs1 = ~rs1    passb rd, rs2 = rs2    sla rd, rs1, rs2 = rs1 << rs2
// (en la ROM de la clase el campo que no se usa lleva x2 o x1; aqui tambien)
function [31:0] NOTA;  input [4:0] rd, rs1, rs2; NOTA  = fmt_r(7'h00, rs2, rs1, 3'b000, rd, `OP_CUSTOM0); endfunction
function [31:0] PASSB; input [4:0] rd, rs1, rs2; PASSB = fmt_r(7'h00, rs2, rs1, 3'b001, rd, `OP_CUSTOM0); endfunction
function [31:0] SLA;   input [4:0] rd, rs1, rs2; SLA   = fmt_r(7'h00, rs2, rs1, 3'b010, rd, `OP_CUSTOM0); endfunction

// ---- propias del proyecto, Xneura (custom-1): formato R, funct3 dice cual ----
//   XOP(XA_ABS,   rd, rs1, x0 )   rd = |rs1|
//   XOP(XA_SGT,   rd, rs1, rs2)   rd = 1 si rs1 > rs2 (con signo)
//   XOP(XA_CLAMP, rd, rs1, rs2)   rd = rs1 limitado entre 0 y rs2
localparam XA_ABS = 3'b000, XA_SGT = 3'b001, XA_CLAMP = 3'b010;
function [31:0] XOP; input [2:0] f3; input [4:0] rd, rs1, rs2; XOP = fmt_r(7'h00, rs2, rs1, f3, rd, `OP_CUSTOM1); endfunction

// ---- emision en la ROM ----

task emitir;
    input [31:0] palabra;
    begin
        memoria[pc_ens >> 2] = palabra;
        pc_ens = pc_ens + 4;
    end
endtask

// cuatro bytes consecutivos en orden little-endian (tablas de datos)
task emitir_bytes;
    input [7:0] b0, b1, b2, b3;
    emitir({b3, b2, b1, b0});
endtask

// ---- pseudoinstrucciones ----

// la: carga la direccion de una etiqueta; siempre lui + addi para que
// ocupe lo mismo en las dos pasadas
task LA;
    input [4:0] rd;
    input integer dir;
    reg [31:0] alto;
    begin
        alto = dir + 32'h800;
        emitir(LUI(rd, {alto[31:12], 12'b0}));
        emitir(ADDI(rd, rd, {{20{dir[11]}}, dir[11:0]}));
    end
endtask
task NOP;  emitir(ADDI(X0, X0, 0)); endtask
task MV;   input [4:0] rd, rs;  emitir(ADDI(rd, rs, 0));        endtask
task NOT;  input [4:0] rd, rs;  emitir(XORI(rd, rs, -1));       endtask
task NEG;  input [4:0] rd, rs;  emitir(SUB(rd, X0, rs));        endtask
task J;    input integer dest;  emitir(JAL(X0, dest - pc_ens)); endtask
task CALL; input integer dest;  emitir(JAL(RA, dest - pc_ens)); endtask
task RET;  emitir(JALR(X0, RA, 0)); endtask

// li rd, valor: una instruccion si cabe en 12 bits con signo, si no lui + addi
task LI;
    input [4:0] rd;
    input [31:0] valor;
    reg [31:0] alto;
    begin
        if ($signed(valor) >= -2048 && $signed(valor) <= 2047)
            emitir(ADDI(rd, X0, valor));
        else begin
            alto = valor + 32'h800;                 // compensa el signo de los 12 bits bajos
            emitir(LUI(rd, {alto[31:12], 12'b0}));
            if (valor[11:0] != 12'd0)
                emitir(ADDI(rd, rd, {{20{valor[11]}}, valor[11:0]}));
        end
    end
endtask

// saltos relativos a una etiqueta (direccion absoluta en bytes)
task BEQ_A;  input [4:0] rs1, rs2; input integer dest; emitir(BEQ (rs1, rs2, dest - pc_ens)); endtask
task BNE_A;  input [4:0] rs1, rs2; input integer dest; emitir(BNE (rs1, rs2, dest - pc_ens)); endtask
task BLT_A;  input [4:0] rs1, rs2; input integer dest; emitir(BLT (rs1, rs2, dest - pc_ens)); endtask
task BGE_A;  input [4:0] rs1, rs2; input integer dest; emitir(BGE (rs1, rs2, dest - pc_ens)); endtask
task BLTU_A; input [4:0] rs1, rs2; input integer dest; emitir(BLTU(rs1, rs2, dest - pc_ens)); endtask
task BGEU_A; input [4:0] rs1, rs2; input integer dest; emitir(BGEU(rs1, rs2, dest - pc_ens)); endtask
task BEQZ;   input [4:0] rs;       input integer dest; emitir(BEQ (rs,  X0,  dest - pc_ens)); endtask
task BNEZ;   input [4:0] rs;       input integer dest; emitir(BNE (rs,  X0,  dest - pc_ens)); endtask

// escribe un caracter en la consola (periferico 0xFFFF0014); rbase apunta a la pagina
task CONSOLA;
    input [4:0] rbase, rtmp;
    input [7:0] c;
    begin
        emitir(ADDI(rtmp, X0, c));
        emitir(SW(rtmp, rbase, 32'h14));
    end
endtask
