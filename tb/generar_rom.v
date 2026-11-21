`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// GENERA LA ROM DEL PROCESADOR (no es hardware)
// Arma un programa con el ensamblador en Verilog y lo escribe con el mismo
// formato que la ROM de instrucciones de la clase (instrucciones.txt):
//   PROGRAMA = 3  NEURA-32 Vigia   -> fpga/programa_vigia.txt (la que lee Quartus)
//   PROGRAMA = 4  demostracion     -> fpga/programa_demo.txt  (se carga por JTAG)
//     002081B3 // 0000: add x3, x1, x2
// Quartus lo carga con $readmemh (los comentarios se ignoran).
// Uso: lo corre simular.ps1 antes de las pruebas.
// ============================================================
module generar_rom #(
    parameter PROGRAMA = 3
) ();

    generador_programa #(.PROGRAMA(PROGRAMA)) gen ();

    integer f, i, ultimo, fin_prog;
    reg [31:0] w;

    // nombres ABI de los registros
    function [8*4-1:0] reg_nombre;
        input [4:0] r;
        case (r)
            0: reg_nombre = "zero"; 1: reg_nombre = "ra";  2: reg_nombre = "sp";  3: reg_nombre = "gp";
            4: reg_nombre = "tp";   5: reg_nombre = "t0";  6: reg_nombre = "t1";  7: reg_nombre = "t2";
            8: reg_nombre = "s0";   9: reg_nombre = "s1";  10: reg_nombre = "a0"; 11: reg_nombre = "a1";
            12: reg_nombre = "a2";  13: reg_nombre = "a3"; 14: reg_nombre = "a4"; 15: reg_nombre = "a5";
            16: reg_nombre = "a6";  17: reg_nombre = "a7"; 18: reg_nombre = "s2"; 19: reg_nombre = "s3";
            20: reg_nombre = "s4";  21: reg_nombre = "s5"; 22: reg_nombre = "s6"; 23: reg_nombre = "s7";
            24: reg_nombre = "s8";  25: reg_nombre = "s9"; 26: reg_nombre = "s10"; 27: reg_nombre = "s11";
            28: reg_nombre = "t3";  29: reg_nombre = "t4"; 30: reg_nombre = "t5"; 31: reg_nombre = "t6";
        endcase
    endfunction

    // mnemonico de cada instruccion (lo que soporta NEURA-32)
    function [8*8-1:0] mnemonico;
        input [31:0] w;
        reg [2:0] f3;
        reg [6:0] f7;
        begin
            f3 = w[14:12]; f7 = w[31:25];
            mnemonico = "dato";
            case (w[6:0])
                `OP_LUI:    mnemonico = "lui";
                `OP_AUIPC:  mnemonico = "auipc";
                `OP_JAL:    mnemonico = "jal";
                `OP_JALR:   mnemonico = "jalr";
                `OP_BRANCH: case (f3) 0: mnemonico = "beq"; 1: mnemonico = "bne"; 4: mnemonico = "blt";
                                      5: mnemonico = "bge"; 6: mnemonico = "bltu"; 7: mnemonico = "bgeu"; endcase
                `OP_LOAD:   case (f3) 0: mnemonico = "lb"; 1: mnemonico = "lh"; 2: mnemonico = "lw";
                                      4: mnemonico = "lbu"; 5: mnemonico = "lhu"; endcase
                `OP_STORE:  case (f3) 0: mnemonico = "sb"; 1: mnemonico = "sh"; 2: mnemonico = "sw"; endcase
                `OP_IMM:    case (f3)
                                0: mnemonico = "addi"; 2: mnemonico = "slti"; 3: mnemonico = "sltiu";
                                4: mnemonico = "xori"; 6: mnemonico = "ori";  7: mnemonico = "andi";
                                1: if (f7 == 7'h30) case (w[24:20]) 0: mnemonico = "clz"; 1: mnemonico = "ctz";
                                       2: mnemonico = "cpop"; 4: mnemonico = "sext.b"; 5: mnemonico = "sext.h"; endcase
                                   else mnemonico = "slli";
                                5: mnemonico = (f7 == 7'h20) ? "srai" : (f7 == 7'h30) ? "rori" :
                                               (w[31:20] == 12'h698) ? "rev8" : "srli";
                            endcase
                `OP_R:      case (f7)
                                7'h00: case (f3) 0: mnemonico = "add"; 1: mnemonico = "sll"; 2: mnemonico = "slt";
                                           3: mnemonico = "sltu"; 4: mnemonico = "xor"; 5: mnemonico = "srl";
                                           6: mnemonico = "or"; 7: mnemonico = "and"; endcase
                                7'h20: case (f3) 0: mnemonico = "sub"; 5: mnemonico = "sra"; 4: mnemonico = "xnor";
                                           6: mnemonico = "orn"; 7: mnemonico = "andn"; endcase
                                7'h01: case (f3) 0: mnemonico = "mul"; 1: mnemonico = "mulh"; 2: mnemonico = "mulhsu";
                                           3: mnemonico = "mulhu"; 4: mnemonico = "div"; 5: mnemonico = "divu";
                                           6: mnemonico = "rem"; 7: mnemonico = "remu"; endcase
                                7'h05: case (f3) 4: mnemonico = "min"; 5: mnemonico = "minu"; 6: mnemonico = "max";
                                           7: mnemonico = "maxu"; endcase
                                7'h30: mnemonico = (f3 == 1) ? "rol" : "ror";
                                7'h04: mnemonico = "zext.h";
                            endcase
                `OP_CUSTOM0: case (f3) 0: mnemonico = "nota"; 1: mnemonico = "passb"; 2: mnemonico = "sla"; endcase
                `OP_CUSTOM1: case (f3) 0: mnemonico = "x.abs"; 1: mnemonico = "x.sgt"; 2: mnemonico = "x.clamp"; endcase
                `OP_SYSTEM: case (f3) 0: mnemonico = w[20] ? "ebreak" : "ecall"; 1: mnemonico = "csrrw";
                                      2: mnemonico = "csrrs"; 3: mnemonico = "csrrc"; 5: mnemonico = "csrrwi";
                                      6: mnemonico = "csrrsi"; 7: mnemonico = "csrrci"; endcase
                `OP_MISC_MEM: mnemonico = "fence";
                default: ;
            endcase
        end
    endfunction

    // una linea del listado: hexadecimal, direccion y la instruccion con sus operandos
    task linea;
        input integer pc;
        input [31:0]  w;
        reg [8*8-1:0] m;
        reg [4:0] rd, rs1, rs2;
        reg signed [31:0] inm_i, inm_s, inm_b, inm_j;
        reg [15:0] dir;
        begin
            dir = pc;
            m   = mnemonico(w);
            rd  = w[11:7]; rs1 = w[19:15]; rs2 = w[24:20];
            inm_i = {{20{w[31]}}, w[31:20]};
            inm_s = {{20{w[31]}}, w[31:25], w[11:7]};
            inm_b = {{19{w[31]}}, w[31], w[7], w[30:25], w[11:8], 1'b0};
            inm_j = {{11{w[31]}}, w[31], w[19:12], w[20], w[30:21], 1'b0};
            if (pc >= gen.T_sccb || m == "dato")
                $fdisplay(f, "%08h // %04h: dato", w, dir);
            else case (w[6:0])
                `OP_LUI, `OP_AUIPC:
                    $fdisplay(f, "%08h // %04h: %0s %0s, 0x%05h", w, dir, m, reg_nombre(rd), w[31:12]);
                `OP_JAL:
                    $fdisplay(f, "%08h // %04h: %0s %0s, 0x%04h", w, dir, m, reg_nombre(rd), dir + inm_j[15:0]);
                `OP_BRANCH:
                    $fdisplay(f, "%08h // %04h: %0s %0s, %0s, 0x%04h", w, dir, m, reg_nombre(rs1), reg_nombre(rs2), dir + inm_b[15:0]);
                `OP_LOAD, `OP_JALR:
                    $fdisplay(f, "%08h // %04h: %0s %0s, %0d(%0s)", w, dir, m, reg_nombre(rd), inm_i, reg_nombre(rs1));
                `OP_STORE:
                    $fdisplay(f, "%08h // %04h: %0s %0s, %0d(%0s)", w, dir, m, reg_nombre(rs2), inm_s, reg_nombre(rs1));
                `OP_IMM:
                    if (w[14:12] == 3'b001 && w[31:25] == 7'h30 || w[31:20] == 12'h698)
                        $fdisplay(f, "%08h // %04h: %0s %0s, %0s", w, dir, m, reg_nombre(rd), reg_nombre(rs1));
                    else if (w[14:12] == 3'b001 || w[14:12] == 3'b101)
                        $fdisplay(f, "%08h // %04h: %0s %0s, %0s, %0d", w, dir, m, reg_nombre(rd), reg_nombre(rs1), w[24:20]);
                    else
                        $fdisplay(f, "%08h // %04h: %0s %0s, %0s, %0d", w, dir, m, reg_nombre(rd), reg_nombre(rs1), inm_i);
                `OP_SYSTEM:
                    if (w[14:12] == 3'b000) $fdisplay(f, "%08h // %04h: %0s", w, dir, m);
                    else $fdisplay(f, "%08h // %04h: %0s %0s, 0x%03h, %0s", w, dir, m, reg_nombre(rd), w[31:20], reg_nombre(rs1));
                default:
                    $fdisplay(f, "%08h // %04h: %0s %0s, %0s, %0s", w, dir, m, reg_nombre(rd), reg_nombre(rs1), reg_nombre(rs2));
            endcase
        end
    endtask

    initial begin
        #1;
        if (gen.errores_ens != 0) begin
            $display("ERROR: el ensamblador reporto %0d errores", gen.errores_ens);
            $finish;
        end
        fin_prog = (PROGRAMA == 4) ? gen.D_fin : gen.V_fin;
        if (PROGRAMA == 4) f = $fopen("fpga/programa_demo.txt", "w");
        else               f = $fopen("fpga/programa_vigia.txt", "w");
        // la memoria completa (4096 palabras): lo que no usa el programa queda en nop
        for (i = 0; i < 4096; i = i + 1) begin
            w = gen.memoria[i];
            if (i * 4 < fin_prog) linea(i * 4, w);
            else                  $fdisplay(f, "%08h", w);
        end
        $fclose(f);
        if (PROGRAMA == 4)
            $display("fpga/programa_demo.txt: %0d instrucciones", fin_prog / 4);
        else
            $display("fpga/programa_vigia.txt: %0d instrucciones y %0d palabras de tablas y pesos (memoria de 4096)",
                     gen.T_sccb / 4, (gen.V_fin - gen.T_sccb) / 4);
        $finish;
    end
endmodule
