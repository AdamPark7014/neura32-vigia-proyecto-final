`timescale 1ns / 1ps
// ============================================================
// BANCO DE PRUEBAS DE LA UNIDAD DE CONTROL (uc_simple)
// Para cada tipo de instruccion revisa el recorrido de la maquina de
// estados y las senales que se prenden en cada fase.
// Al final imprime: PRUEBAS: n  ERRORES: 0
// ============================================================
module tb_uc_simple;
    reg clk = 1'b0, rst = 1'b0;
    always #5 clk = ~clk;

    reg  [6:0] opcode = 7'd0;
    reg  [2:0] funct3 = 3'd0;
    reg        take = 1'b0, div_ready = 1'b0;
    wire       reg_write, mem_read, mem_write, alu_src, pc_en, ir_en, aluout_en, mdr_en;
    wire       addr_phase, div_start, div_sel, halted, illegal;
    wire [1:0] result_src, pc_src;
    wire [2:0] alu_op;
    wire [3:0] state;

    uc_simple dut (
        .clk(clk), .rst(rst), .opcode(opcode), .funct3(funct3), .take(take), .div_ready(div_ready),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write), .alu_src(alu_src),
        .result_src(result_src), .pc_en(pc_en), .pc_src(pc_src), .ir_en(ir_en), .aluout_en(aluout_en),
        .mdr_en(mdr_en), .addr_phase(addr_phase), .div_start(div_start), .div_sel(div_sel),
        .halted(halted), .illegal(illegal), .alu_op(alu_op), .state(state)
    );

    localparam OP_R1 = 7'b0110011, OP_R3 = 7'b1011011, OP_I1 = 7'b0010011, OP_LOAD = 7'b0000011;
    localparam OP_STORE = 7'b0100011, OP_BRANCH = 7'b1100011, OP_JAL = 7'b1101111, OP_SYSTEM = 7'b1110011;
    localparam FETCH = 4'd0, DECODE = 4'd1, EXEC_R = 4'd2, EXEC_DIV = 4'd3, EXEC_BR = 4'd4, JUMP_WAIT = 4'd5;
    localparam MEM_ADDR = 4'd6, MEM_READ = 4'd7, MEM_WRITE = 4'd8, WRITEBACK = 4'd9, HALT = 4'd10;

    integer pruebas = 0, errores = 0;
    task revisar;
        input            bien;
        input [8*60-1:0] nombre;
        begin
            pruebas = pruebas + 1;
            if (bien) $display("  ok    %0s", nombre);
            else begin errores = errores + 1; $display("  FALLA %0s (estado %0d)", nombre, state); end
        end
    endtask

    task paso;                       // avanza un ciclo y deja ver las salidas del nuevo estado
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $display("=== Unidad de control: recorrido por tipo de instruccion ===");
        repeat (2) @(posedge clk);
        @(negedge clk);              // se suelta el reinicio lejos del flanco de subida
        rst = 1'b1; #1;
        revisar(state == FETCH && pc_en && ir_en, "FETCH: avanza el PC y carga la instruccion");

        // ---- tipo R (add) ----
        opcode = OP_R1; funct3 = 3'b000;
        paso; revisar(state == DECODE && !reg_write, "tipo R: DECODE");
        paso; revisar(state == EXEC_R && aluout_en && !alu_src && alu_op == 3'b000, "tipo R: EXEC_R con rs2, alu_op = funct3");
        paso; revisar(state == WRITEBACK && reg_write && result_src == 2'd0, "tipo R: WRITEBACK escribe el resultado de la ALU");
        paso; revisar(state == FETCH, "tipo R: regresa a FETCH (4 ciclos)");

        // ---- tipo I (srli) ----
        opcode = OP_I1; funct3 = 3'b111;
        paso; paso; revisar(state == EXEC_R && alu_src && alu_op == 3'b111, "tipo I: EXEC_R con el inmediato");
        paso; paso;

        // ---- carga ----
        opcode = OP_LOAD; funct3 = 3'b010;
        paso; paso; revisar(state == MEM_ADDR && alu_src && aluout_en && addr_phase, "carga: MEM_ADDR calcula la direccion");
        paso; revisar(state == MEM_READ && mem_read && mdr_en, "carga: MEM_READ guarda el dato leido");
        paso; revisar(state == WRITEBACK && reg_write && result_src == 2'd1, "carga: WRITEBACK escribe el dato de la memoria");
        paso;

        // ---- almacenamiento ----
        opcode = OP_STORE;
        paso; paso; revisar(state == MEM_ADDR, "almacenamiento: MEM_ADDR");
        paso; revisar(state == MEM_WRITE && mem_write && !reg_write, "almacenamiento: MEM_WRITE escribe la memoria");
        paso; revisar(state == FETCH, "almacenamiento: regresa a FETCH sin write-back");

        // ---- salto condicional que no se cumple ----
        opcode = OP_BRANCH; funct3 = 3'b000; take = 1'b0;
        paso; paso; revisar(state == EXEC_BR && !pc_en, "salto que no se cumple: el PC no cambia");
        paso; revisar(state == FETCH, "salto que no se cumple: 3 ciclos");

        // ---- salto condicional que si se cumple ----
        take = 1'b1;
        paso; paso; revisar(state == EXEC_BR && pc_en && pc_src == 2'd1 && !reg_write, "salto que se cumple: carga el destino");
        paso; revisar(state == JUMP_WAIT, "salto que se cumple: JUMP_WAIT lee la instruccion del destino");
        paso; take = 1'b0;

        // ---- jal ----
        opcode = OP_JAL;
        paso; paso; revisar(state == EXEC_BR && pc_en && reg_write && result_src == 2'd2, "jal: salta y guarda la direccion de regreso");
        paso; paso;

        // ---- division (divu): espera al divisor ----
        opcode = OP_R3; funct3 = 3'b000; div_ready = 1'b0;
        paso; revisar(state == DECODE && div_start, "divu: arranca el divisor en DECODE");
        paso; revisar(state == EXEC_DIV && !aluout_en, "divu: EXEC_DIV espera");
        paso; paso; revisar(state == EXEC_DIV, "divu: sigue esperando mientras ready = 0");
        div_ready = 1'b1; #1;
        revisar(aluout_en && div_sel, "divu: al terminar guarda el resultado del divisor");
        paso; revisar(state == WRITEBACK && reg_write, "divu: WRITEBACK");
        paso; div_ready = 1'b0;

        // ---- cpop: misma tabla OP_R3 pero de un ciclo ----
        funct3 = 3'b010;
        paso; revisar(state == DECODE && !div_start, "cpop: no usa el divisor");
        paso; revisar(state == EXEC_R, "cpop: EXEC_R");
        paso; paso;

        // ---- opcode que no existe ----
        opcode = 7'b0000000;
        paso; revisar(state == DECODE && illegal, "opcode que no existe: se marca");
        paso; revisar(state == FETCH && !reg_write && !mem_write, "opcode que no existe: no hace nada");

        // ---- ecall ----
        opcode = OP_SYSTEM;
        paso; paso; revisar(state == HALT && halted, "ecall: el procesador se detiene");
        paso; revisar(state == HALT && !pc_en, "ecall: se queda detenido");

        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
