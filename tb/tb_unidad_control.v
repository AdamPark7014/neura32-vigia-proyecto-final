`timescale 1ns/1ps
`include "neura32_defs.vh"
// ============================================================
// TESTBENCH DE LA UNIDAD DE CONTROL (Practica 5)
// Como pide la guia: se aplica una instruccion codificada de cada tipo y se
// revisa que TODAS las senales coincidan con la tabla de control.
//   RegWrite ALUSrc MemRead MemWrite MemToReg Branch Jump ALUOp
// Tambien se revisa la ALU: con la misma instruccion y dos operandos fijos
// debe dar el resultado de esa operacion.
// Al final imprime: PRUEBAS: n  ERRORES: 0
// ============================================================
module tb_unidad_control;
    reg  [31:0] instr;

    wire       reg_write, sel_a_pc, alu_src_b, mem_read, mem_write, branch, jump, jalr;
    wire       csr_we, csr_imm, es_fin, ilegal;
    wire [2:0] tipo_inm;
    wire [1:0] res_sel, csr_tipo;
    wire [31:0] resultado;
    wire        ilegal_alu, C, O, Z, N;

    // operandos fijos para la ALU
    localparam [31:0] A = 32'h800000F0, B = 32'h00000004;

    unidad_control dut (
        .instr(instr),
        .reg_write(reg_write), .sel_a_pc(sel_a_pc), .alu_src_b(alu_src_b),
        .mem_read(mem_read), .mem_write(mem_write), .res_sel(res_sel), .branch(branch), .jump(jump),
        .jalr(jalr), .csr_we(csr_we), .csr_tipo(csr_tipo), .csr_imm(csr_imm),
        .es_fin(es_fin), .ilegal(ilegal),
        .tipo_inm(tipo_inm)
    );

    alu_riscv dut_alu (
        .instr(instr), .A(A), .B(B),
        .result(resultado), .ilegal(ilegal_alu), .C(C), .O(O), .Z(Z), .N(N)
    );

    // el codificador de instrucciones de los programas (solo sus funciones)
    reg [31:0] memoria [0:3];
    `include "codificador_riscv.vh"

    integer pruebas = 0, errores = 0;

    // fila de la tabla: {RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch, Jump} y el
    // resultado que debe dar la ALU con A = 0x800000F0 y B = 4
    task revisar;
        input [8*20-1:0] nombre;
        input [6:0]      senales;
        input [31:0]     esperado;
        reg   [6:0]      obtenido;
        begin
            #1;
            obtenido = {reg_write, alu_src_b, mem_read, mem_write, res_sel == `RES_MEM, branch, jump};
            pruebas = pruebas + 1;
            if (obtenido === senales && resultado === esperado && !ilegal && !ilegal_alu)
                $display("  ok    %-0s  RW=%b ALUSrc=%b MR=%b MW=%b M2R=%b Br=%b J=%b  ALU=%08h",
                         nombre, reg_write, alu_src_b, mem_read, mem_write, res_sel == `RES_MEM,
                         branch, jump, resultado);
            else begin
                errores = errores + 1;
                $display("  FALLA %-0s  senales=%b (esperadas %b) ALU=%08h (%08h) ilegal=%b",
                         nombre, obtenido, senales, resultado, esperado, ilegal | ilegal_alu);
            end
            #9;
        end
    endtask

    initial begin
        $display("=== Unidad de control y ALU: tabla por tipo de instruccion ===");
        //                                      RW ALUSrc MR MW M2R Br J    resultado de la ALU
        // primer caso: tipo R, add x3, x1, x2
        instr = ADD(5'd3, 5'd1, 5'd2);   revisar("add (R)",       7'b1000000, A + B);
        // segundo caso: tipo R, sub x4, x1, x2 (cambia funct7)
        instr = SUB(5'd4, 5'd1, 5'd2);   revisar("sub (R)",       7'b1000000, A - B);
        // tercer caso: tipo R de la extension M, mul
        instr = MUL(5'd5, 5'd1, 5'd2);   revisar("mul (R, M)",    7'b1000000, A * B);
        // cuarto caso: tipo I aritmetico, addi x1, x0, 5
        instr = ADDI(5'd1, 5'd0, 5);     revisar("addi (I)",      7'b1100000, A + B);
        // quinto caso: srai (funct7 = 0100000 elige el corrimiento aritmetico)
        instr = SRAI(5'd1, 5'd2, 3);     revisar("srai (I)",      7'b1100000, 32'hF800000F);
        // sexto caso: carga, lw x5, 8(x2): la ALU suma la direccion
        instr = LW(5'd5, 5'd2, 8);       revisar("lw (I)",        7'b1110100, A + B);
        // septimo caso: almacenamiento, sw x5, 8(x2)
        instr = SW(5'd5, 5'd2, 8);       revisar("sw (S)",        7'b0101000, A + B);
        // octavo caso: salto condicional, beq x1, x2, +8 (la ALU resta)
        instr = BEQ(5'd1, 5'd2, 8);      revisar("beq (B)",       7'b0000010, A - B);
        // noveno caso: jal x1, +16
        instr = JAL(5'd1, 16);           revisar("jal (J)",       7'b1000001, A + B);
        // decimo caso: jalr x0, 0(x1)
        instr = JALR(5'd0, 5'd1, 0);     revisar("jalr (I)",      7'b1000001, A + B);
        // caso 11: lui x5, 0x12345000 (la ALU deja pasar el inmediato)
        instr = LUI(5'd5, 32'h12345000); revisar("lui (U)",       7'b1100000, B);
        // caso 12: auipc x5, 0
        instr = AUIPC(5'd5, 32'h0);      revisar("auipc (U)",     7'b1100000, A + B);
        // caso 13: Zbb de la clase, andn
        instr = ANDN(5'd20, 5'd1, 5'd2); revisar("andn (Zbb)",    7'b1000000, A & ~B);
        // caso 14: Zbb con inmediato, clz (A tiene el bit 31 en 1: cero ceros)
        instr = CLZ(5'd30, 5'd1);        revisar("clz (Zbb)",     7'b1100000, 32'd0);
        // caso 15: Zbb rev8
        instr = REV8(5'd1, 5'd1);        revisar("rev8 (Zbb)",    7'b1100000, 32'hF0000080);
        // caso 16: propia de la clase, nota x8, x1
        instr = NOTA(5'd8, 5'd1, 5'd2);  revisar("nota (clase)",  7'b1000000, ~A);
        // caso 17: propia de la clase, passb x11, x2
        instr = PASSB(5'd11, 5'd1, 5'd2); revisar("passb (clase)", 7'b1000000, B);
        // caso 18: propia de la clase, sla x26, x1, x2
        instr = SLA(5'd26, 5'd1, 5'd2);  revisar("sla (clase)",   7'b1000000, A << 4);
        // caso 19: propia del proyecto, x.abs x3, x1
        instr = XOP(XA_ABS, 5'd3, 5'd1, 5'd0); revisar("x.abs (Xneura)", 7'b1000000, 32'h7FFFFF10);

        // caso 20: instruccion ilegal (opcode 1111111): ninguna senal debe activarse
        instr = 32'hFFFFFFFF;
        #1;
        pruebas = pruebas + 1;
        if (ilegal && !reg_write && !mem_write && !branch && !jump)
            $display("  ok    ilegal: se marca y no escribe nada");
        else begin errores = errores + 1; $display("  FALLA ilegal"); end
        #9;

        // caso 21: ecall detiene el procesador
        instr = 32'h00000073;
        #1;
        pruebas = pruebas + 1;
        if (es_fin && !reg_write) $display("  ok    ecall: es_fin = 1");
        else begin errores = errores + 1; $display("  FALLA ecall"); end
        #9;

        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
