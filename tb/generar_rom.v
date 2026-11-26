`timescale 1ns / 1ps

// escribe la ROM
module generar_rom #(
    parameter PROGRAMA = 3
) ();

    generador_programa #(.PROGRAMA(PROGRAMA)) gen ();

    localparam OP_R1 = 7'b0110011;  // tipo R, tabla 1
    localparam OP_R2 = 7'b0111011;  // tipo R, tabla 2
    localparam OP_R3 = 7'b1011011;  // tipo R, tabla 3
    localparam OP_I1 = 7'b0010011;  // inmediato, tabla 1
    localparam OP_I2 = 7'b0011011;  // inmediato, tabla 2
    localparam OP_LOAD = 7'b0000011;  // carga de memoria
    localparam OP_STORE = 7'b0100011;  // guarda en memoria
    localparam OP_BRANCH = 7'b1100011;  // saltos condicionales
    localparam OP_LUI = 7'b0110111;  // carga inmediato alto
    localparam OP_JAL = 7'b1101111;  // salto con enlace
    localparam OP_JALR = 7'b1100111;  // salto a registro
    localparam OP_SYSTEM = 7'b1110011;  // detiene el procesador

    integer f, i, fin_prog;
    reg [31:0] w;

    // mnemonico
    function [8*6-1:0] mnemonico;
        input [31:0] w;
        reg [2:0] f3;
        begin
            f3 = w[14:12];
            mnemonico = "dato";
            case (w[6:0])
                OP_R1: case (f3) 0: mnemonico = "add"; 1: mnemonico = "mul"; 2: mnemonico = "and"; 3: mnemonico = "or";
                                 4: mnemonico = "xor"; 5: mnemonico = "nota"; 6: mnemonico = "sll"; 7: mnemonico = "srl"; endcase
                OP_R2: case (f3) 0: mnemonico = "sub"; 1: mnemonico = "slt"; 2: mnemonico = "sltu"; 3: mnemonico = "sra";
                                 4: mnemonico = "xnor"; 5: mnemonico = "min"; 6: mnemonico = "minu"; 7: mnemonico = "max"; endcase
                OP_R3: case (f3) 0: mnemonico = "divu"; 1: mnemonico = "remu"; 2: mnemonico = "cpop"; 3: mnemonico = "abs";
                                 4: mnemonico = "sgt"; 5: mnemonico = "clamp"; default: mnemonico = "dato"; endcase
                OP_I1: case (f3) 0: mnemonico = "addi"; 1: mnemonico = "muli"; 2: mnemonico = "andi"; 3: mnemonico = "ori";
                                 4: mnemonico = "xori"; 6: mnemonico = "slli"; 7: mnemonico = "srli"; default: mnemonico = "dato"; endcase
                OP_I2: case (f3) 1: mnemonico = "slti"; 2: mnemonico = "sltiu"; 3: mnemonico = "srai"; default: mnemonico = "dato"; endcase
                OP_LOAD: case (f3) 0: mnemonico = "lb"; 1: mnemonico = "lh"; 2: mnemonico = "lw";
                                   4: mnemonico = "lbu"; 5: mnemonico = "lhu"; default: mnemonico = "dato"; endcase
                OP_STORE: case (f3) 0: mnemonico = "sb"; 1: mnemonico = "sh"; 2: mnemonico = "sw"; default: mnemonico = "dato"; endcase
                OP_BRANCH: case (f3) 0: mnemonico = "beq"; 1: mnemonico = "bne"; 4: mnemonico = "blt";
                                     5: mnemonico = "bge"; 6: mnemonico = "bltu"; 7: mnemonico = "bgeu"; default: mnemonico = "dato"; endcase
                OP_LUI:    mnemonico = "lui";
                OP_JAL:    mnemonico = "jal";
                OP_JALR:   mnemonico = "jalr";
                OP_SYSTEM: mnemonico = "ecall";
                default: ;
            endcase
        end
    endfunction

    // renglon
    task linea;
        input [31:0] dir;
        input [31:0] w;
        reg [8*6-1:0] m;
        reg [4:0] rd, rs1, rs2;
        reg signed [31:0] inm_i, inm_s, inm_b, inm_j;
        begin
            m = mnemonico(w);
            rd = w[11:7]; rs1 = w[19:15]; rs2 = w[24:20];
            inm_i = {{20{w[31]}}, w[31:20]};
            inm_s = {{20{w[31]}}, w[31:25], w[11:7]};
            inm_b = {{19{w[31]}}, w[31], w[7], w[30:25], w[11:8], 1'b0};
            inm_j = {{11{w[31]}}, w[31], w[19:12], w[20], w[30:21], 1'b0};
            if (m == "dato")
                $fdisplay(f, "%08h // %04h: dato", w, dir);
            else case (w[6:0])
                OP_R1, OP_R2, OP_R3:
                    $fdisplay(f, "%08h // %04h: %0s x%0d, x%0d, x%0d", w, dir, m, rd, rs1, rs2);
                OP_I1, OP_I2:
                    $fdisplay(f, "%08h // %04h: %0s x%0d, x%0d, %0d", w, dir, m, rd, rs1, inm_i);
                OP_LOAD, OP_JALR:
                    $fdisplay(f, "%08h // %04h: %0s x%0d, %0d(x%0d)", w, dir, m, rd, inm_i, rs1);
                OP_STORE:
                    $fdisplay(f, "%08h // %04h: %0s x%0d, %0d(x%0d)", w, dir, m, rs2, inm_s, rs1);
                OP_BRANCH:
                    $fdisplay(f, "%08h // %04h: %0s x%0d, x%0d, 0x%04h", w, dir, m, rs1, rs2, dir + inm_b);
                OP_LUI:
                    $fdisplay(f, "%08h // %04h: lui x%0d, 0x%05h", w, dir, rd, w[31:12]);
                OP_JAL:
                    $fdisplay(f, "%08h // %04h: jal x%0d, 0x%04h", w, dir, rd, dir + inm_j);
                default:
                    $fdisplay(f, "%08h // %04h: %0s", w, dir, m);
            endcase
        end
    endtask

    initial begin
        #1;
        if (gen.errores_ens != 0) begin
            $display("ERROR: el ensamblador reporto %0d errores", gen.errores_ens);
            $finish;
        end
        case (PROGRAMA)
            1: begin f = $fopen("fpga/programa_red.txt", "w");   fin_prog = gen.R_W1;   end
            2: begin f = $fopen("fpga/programa_isa.txt", "w");   fin_prog = gen.I_fin;  end
            4: begin f = $fopen("fpga/programa_demo.txt", "w");  fin_prog = gen.D_fin;  end
            default: begin f = $fopen("fpga/programa_vigia.txt", "w"); fin_prog = gen.T_sccb; end
        endcase
        // memoria completa
        for (i = 0; i < 4096; i = i + 1) begin
            w = gen.memoria[i];
            if (i * 4 < fin_prog) linea(i * 4, w);
            else                  $fdisplay(f, "%08h", w);
        end
        $fclose(f);
        $display("programa %0d: %0d instrucciones (memoria de 4096 palabras)", PROGRAMA, fin_prog / 4);
        $finish;
    end
endmodule
