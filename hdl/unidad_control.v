`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// UNIDAD DE CONTROL PRINCIPAL (Practica 5)
// case sobre opcode, con case anidado sobre funct3 (y funct7 / imm12
// donde hace falta). Todas las senales reciben un valor por defecto
// al inicio del bloque para que no se infieran latches.
// La operacion de la ALU la decide la propia ALU con opcode, funct3 y
// funct7 (alu_riscv.v); aqui salen las senales del camino de datos.
// ============================================================
module unidad_control (
    input  wire [31:0] instr,

    output reg         reg_write,     // escribe el banco de registros
    output reg         sel_a_pc,      // operando A = PC (auipc) en vez de rs1
    output reg         alu_src_b,     // operando B = inmediato (1) o rs2 (0)
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  res_sel,       // ALU / MEM / PC+4 / CSR
    output reg         branch,
    output reg         jump,
    output reg         jalr,          // destino = rs1 + inm (si no, PC + inm)
    output reg         csr_we,
    output reg  [1:0]  csr_tipo,      // RW / RS / RC
    output reg         csr_imm,       // fuente CSR = uimm de 5 bits
    output reg         es_fin,        // ecall / ebreak: detiene el procesador
    output reg         ilegal,
    output reg  [2:0]  tipo_inm
);
    wire [6:0]  opcode = instr[6:0];
    wire [2:0]  funct3 = instr[14:12];
    wire [6:0]  funct7 = instr[31:25];
    wire [4:0]  rs1    = instr[19:15];
    wire [11:0] imm12  = instr[31:20];

    always @(*) begin
        // ---- valores por defecto (equivalen a un NOP) ----
        reg_write    = 1'b0;
        sel_a_pc     = 1'b0;
        alu_src_b    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        res_sel      = `RES_ALU;
        branch       = 1'b0;
        jump         = 1'b0;
        jalr         = 1'b0;
        csr_we       = 1'b0;
        csr_tipo     = 2'd0;
        csr_imm      = 1'b0;
        es_fin       = 1'b0;
        ilegal       = 1'b0;
        tipo_inm     = `INM_I;

        case (opcode)
            // ---------------- TIPO U ----------------
            `OP_LUI: begin
                reg_write = 1'b1; alu_src_b = 1'b1; tipo_inm = `INM_U;
            end
            `OP_AUIPC: begin
                reg_write = 1'b1; sel_a_pc = 1'b1; alu_src_b = 1'b1; tipo_inm = `INM_U;
            end

            // ---------------- SALTOS INCONDICIONALES ----------------
            `OP_JAL: begin
                reg_write = 1'b1; jump = 1'b1; res_sel = `RES_PC4; tipo_inm = `INM_J;
            end
            `OP_JALR: begin
                reg_write = 1'b1; jump = 1'b1; jalr = 1'b1; res_sel = `RES_PC4; tipo_inm = `INM_I;
                if (funct3 != 3'b000) ilegal = 1'b1;
            end

            // ---------------- TIPO B ----------------
            `OP_BRANCH: begin
                branch = 1'b1; tipo_inm = `INM_B;                       // la ALU resta y deja las banderas
                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: ;   // beq bne blt bge bltu bgeu
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- CARGAS ----------------
            `OP_LOAD: begin
                reg_write = 1'b1; alu_src_b = 1'b1; mem_read = 1'b1; res_sel = `RES_MEM; tipo_inm = `INM_I;
                case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: ;          // lb lh lw lbu lhu
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- ALMACENAMIENTOS ----------------
            `OP_STORE: begin
                alu_src_b = 1'b1; mem_write = 1'b1; tipo_inm = `INM_S;
                case (funct3)
                    3'b000, 3'b001, 3'b010: ;                          // sb sh sw
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- TIPO I (aritmetica con inmediato) ----------------
            `OP_IMM: begin
                // addi slti sltiu xori ori andi slli srli srai y, de Zbb, clz ctz cpop
                // sext.b sext.h rori rev8. Que la combinacion funct3/funct7 exista lo
                // revisa la ALU.
                reg_write = 1'b1; alu_src_b = 1'b1; tipo_inm = `INM_I;
            end

            // ---------------- TIPO R (RV32I + RV32M + Zbb) ----------------
            `OP_R: begin
                reg_write = 1'b1;
                case (funct7)
                    7'b0000000,                                       // base
                    7'b0100000,                                       // sub, sra, andn, orn, xnor
                    7'b0000001,                                       // extension M
                    7'b0000101,                                       // min, minu, max, maxu
                    7'b0110000,                                       // rol, ror
                    7'b0000100: ;                                     // zext.h
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- INSTRUCCIONES DE LA CLASE (custom-0) ----------------
            // Formato R, como en la ROM de instrucciones del laboratorio:
            //   funct3 = 000 nota rd, rs1       (rd = ~rs1)
            //   funct3 = 001 passb rd, rs2      (rd = rs2)
            //   funct3 = 010 sla rd, rs1, rs2   (corrimiento aritmetico a la izquierda)
            `OP_CUSTOM0: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000, 3'b001, 3'b010: if (funct7 != 7'b0000000) ilegal = 1'b1;
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- PROPIAS DEL PROYECTO: Xneura (custom-1) ----------------
            // Formato R, igual que las de la clase:
            //   funct3 = 000 x.abs   rd, rs1        (rd = |rs1|)
            //   funct3 = 001 x.sgt   rd, rs1, rs2   (rd = 1 si rs1 > rs2, con signo)
            //   funct3 = 010 x.clamp rd, rs1, rs2   (rd = rs1 limitado entre 0 y rs2)
            `OP_CUSTOM1: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000, 3'b001, 3'b010: if (funct7 != 7'b0000000) ilegal = 1'b1;
                    default: ilegal = 1'b1;
                endcase
            end

            // ---------------- fence / fence.i: sin efecto (un solo nucleo) ----------------
            `OP_MISC_MEM: ;

            // ---------------- SYSTEM: ecall / ebreak / CSR ----------------
            `OP_SYSTEM: begin
                case (funct3)
                    3'b000: begin
                        case (imm12)
                            12'h000, 12'h001: es_fin = 1'b1;           // ecall, ebreak
                            default:          ilegal = 1'b1;           // mret, wfi, ... no implementados
                        endcase
                    end
                    3'b001: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = 1'b1;          csr_tipo = `CSR_RW; end                 // csrrw
                    3'b010: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = (rs1 != 5'd0); csr_tipo = `CSR_RS; end                 // csrrs
                    3'b011: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = (rs1 != 5'd0); csr_tipo = `CSR_RC; end                 // csrrc
                    3'b101: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = 1'b1;          csr_tipo = `CSR_RW; csr_imm = 1'b1; tipo_inm = `INM_Z; end // csrrwi
                    3'b110: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = (rs1 != 5'd0); csr_tipo = `CSR_RS; csr_imm = 1'b1; tipo_inm = `INM_Z; end // csrrsi
                    3'b111: begin reg_write = 1'b1; res_sel = `RES_CSR; csr_we = (rs1 != 5'd0); csr_tipo = `CSR_RC; csr_imm = 1'b1; tipo_inm = `INM_Z; end // csrrci
                    default: ilegal = 1'b1;
                endcase
            end

            default: ilegal = 1'b1;
        endcase

        // Una instruccion ilegal no debe tener efectos
        if (ilegal) begin
            reg_write = 1'b0; mem_read = 1'b0; mem_write = 1'b0;
            branch = 1'b0; jump = 1'b0; csr_we = 1'b0; es_fin = 1'b0;
        end
    end
endmodule
