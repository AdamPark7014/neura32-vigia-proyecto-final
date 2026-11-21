// ============================================================
// PROGRAMA 2 — PRUEBA DE TODAS LAS INSTRUCCIONES
// Cada prueba deja un resultado de 32 bits en RAM[n] = 0x1000_0000 + 4n.
// tb_prueba_isa.v calcula los valores esperados con operadores de
// Verilog (independientes del procesador) y los compara uno por uno.
// Operandos base: A = 0x12345678 (t0), B = 0xDEADBEEF (t1), t3 = 4
// ============================================================

integer I_f1, I_ret1, I_lazo, I_dato, I_sigue, I_fin;
integer I_b0, I_b1, I_b2, I_b3, I_b4, I_b5, I_b6, I_b7, I_b8, I_b9, I_b10, I_b11;

task GUARDA;              // RAM[n] = reg
    input [4:0] r;
    input integer n;
    emitir(SW(r, S0, 4 * n));
endtask

task programa_isa;
    input integer pasada;
    begin
        pc_ens = 0;
        emitir(LUI(S0, 32'h10000000));            // s0 = RAM
        emitir(LUI(S1, 32'hFFFF0000));            // s1 = perifericos
        LI(T0, 32'h12345678);                     // A
        LI(T1, 32'hDEADBEEF);                     // B (lui + addi con compensacion de signo)
        emitir(ADDI(T3, X0, 4));
        GUARDA(T0, 0);
        GUARDA(T1, 1);

        // ---- tipo R, tabla 1 (OP_R1) ----
        emitir(ADD (T2, T0, T1)); GUARDA(T2, 2);
        emitir(MUL (T2, T0, T1)); GUARDA(T2, 3);
        emitir(AND (T2, T0, T1)); GUARDA(T2, 4);
        emitir(OR  (T2, T0, T1)); GUARDA(T2, 5);
        emitir(XOR (T2, T0, T1)); GUARDA(T2, 6);
        emitir(NOTA(T2, T0));     GUARDA(T2, 7);
        emitir(SLL (T2, T0, T3)); GUARDA(T2, 8);
        emitir(SRL (T2, T1, T3)); GUARDA(T2, 9);

        // ---- tipo R, tabla 2 (OP_R2) ----
        emitir(SUB (T2, T0, T1)); GUARDA(T2, 10);
        emitir(SLT (T2, T1, T0)); GUARDA(T2, 11);
        emitir(SLTU(T2, T1, T0)); GUARDA(T2, 12);
        emitir(SRA (T2, T1, T3)); GUARDA(T2, 13);
        emitir(XNOR(T2, T0, T1)); GUARDA(T2, 14);
        emitir(MIN (T2, T0, T1)); GUARDA(T2, 15);
        emitir(MINU(T2, T0, T1)); GUARDA(T2, 16);
        emitir(MAX (T2, T0, T1)); GUARDA(T2, 17);

        // ---- tipo R, tabla 3 (OP_R3) ----
        emitir(ADDI(T4, X0, 1000));
        emitir(DIVU(T2, T1, T4)); GUARDA(T2, 18);
        emitir(REMU(T2, T1, T4)); GUARDA(T2, 19);
        emitir(CPOP(T2, T1));     GUARDA(T2, 20);
        emitir(XOP (XA_ABS, T2, T1, X0));   GUARDA(T2, 21);
        emitir(XOP (XA_SGT, T2, T0, T1));   GUARDA(T2, 22);
        emitir(ADDI(T4, X0, 200));
        emitir(ADDI(T5, X0, 127));
        emitir(XOP (XA_CLAMP, T2, T4, T5)); GUARDA(T2, 23);
        emitir(DIVU(T2, T0, X0)); GUARDA(T2, 24);         // entre cero: todo en unos
        emitir(REMU(T2, T0, X0)); GUARDA(T2, 25);         // entre cero: queda el dividendo

        // ---- tipo I, tabla 1 (OP_I1) ----
        emitir(ADDI(T2, T0, -1));       GUARDA(T2, 26);
        emitir(ANDI(T2, T0, 32'h0F0));  GUARDA(T2, 27);
        emitir(ORI (T2, T0, 32'h700));  GUARDA(T2, 28);
        emitir(XORI(T2, T0, 32'h0FF));  GUARDA(T2, 29);
        emitir(SLLI(T2, T0, 12));       GUARDA(T2, 30);
        emitir(SRLI(T2, T1, 28));       GUARDA(T2, 31);

        // ---- tipo I, tabla 2 (OP_I2) ----
        emitir(SLTI (T2, T1, 0));       GUARDA(T2, 32);
        emitir(SLTIU(T2, T1, -1));      GUARDA(T2, 33);
        emitir(SRAI (T2, T1, 28));      GUARDA(T2, 34);

        // ---- lui ----
        emitir(LUI(T2, 32'hABCDE000));  GUARDA(T2, 35);

        // ---- memoria: palabra, media palabra y byte (zona de trabajo en RAM[100..103]) ----
        GUARDA(T1, 100);
        emitir(LW (T2, S0, 400));       GUARDA(T2, 36);   // lw
        emitir(LB (T2, S0, 400));       GUARDA(T2, 37);   // lb: byte 0 con signo
        emitir(LBU(T2, S0, 400));       GUARDA(T2, 38);   // lbu
        emitir(LH (T2, S0, 400));       GUARDA(T2, 39);   // lh: mitad baja con signo
        emitir(LHU(T2, S0, 402));       GUARDA(T2, 40);   // lhu: mitad alta
        emitir(ADDI(T4, X0, 32'h0AA));
        emitir(SB (T4, S0, 405));                         // sb en el byte 1 de RAM[101]
        emitir(LW (T2, S0, 404));       GUARDA(T2, 41);
        LI(T4, 32'h00001234);
        emitir(SH (T4, S0, 410));                         // sh en la mitad alta de RAM[102]
        emitir(LW (T2, S0, 408));       GUARDA(T2, 42);

        // ---- saltos condicionales: el resultado es 1 si el salto hizo lo correcto ----
        // los que se deben tomar brincan el "addi t2, x0, 0"
        emitir(ADDI(T2, X0, 1)); BEQ_A (T0, T0, I_b0);  emitir(ADDI(T2, X0, 0)); I_b0 = pc_ens;  GUARDA(T2, 43);
        emitir(ADDI(T2, X0, 1)); BNE_A (T0, T1, I_b1);  emitir(ADDI(T2, X0, 0)); I_b1 = pc_ens;  GUARDA(T2, 44);
        emitir(ADDI(T2, X0, 1)); BLT_A (T1, T0, I_b2);  emitir(ADDI(T2, X0, 0)); I_b2 = pc_ens;  GUARDA(T2, 45);
        emitir(ADDI(T2, X0, 1)); BGE_A (T0, T1, I_b3);  emitir(ADDI(T2, X0, 0)); I_b3 = pc_ens;  GUARDA(T2, 46);
        emitir(ADDI(T2, X0, 1)); BLTU_A(T0, T1, I_b4);  emitir(ADDI(T2, X0, 0)); I_b4 = pc_ens;  GUARDA(T2, 47);
        emitir(ADDI(T2, X0, 1)); BGEU_A(T1, T0, I_b5);  emitir(ADDI(T2, X0, 0)); I_b5 = pc_ens;  GUARDA(T2, 48);
        // los que no se deben tomar dejan pasar el "addi t2, x0, 1"
        emitir(ADDI(T2, X0, 0)); BEQ_A (T0, T1, I_b6);  emitir(ADDI(T2, X0, 1)); I_b6 = pc_ens;  GUARDA(T2, 49);
        emitir(ADDI(T2, X0, 0)); BNE_A (T0, T0, I_b7);  emitir(ADDI(T2, X0, 1)); I_b7 = pc_ens;  GUARDA(T2, 50);
        emitir(ADDI(T2, X0, 0)); BLT_A (T0, T1, I_b8);  emitir(ADDI(T2, X0, 1)); I_b8 = pc_ens;  GUARDA(T2, 51);
        emitir(ADDI(T2, X0, 0)); BGE_A (T1, T0, I_b9);  emitir(ADDI(T2, X0, 1)); I_b9 = pc_ens;  GUARDA(T2, 52);
        emitir(ADDI(T2, X0, 0)); BLTU_A(T1, T0, I_b10); emitir(ADDI(T2, X0, 1)); I_b10 = pc_ens; GUARDA(T2, 53);
        emitir(ADDI(T2, X0, 0)); BGEU_A(T0, T1, I_b11); emitir(ADDI(T2, X0, 1)); I_b11 = pc_ens; GUARDA(T2, 54);

        // ---- jal y jalr: llamada a una funcion y regreso ----
        emitir(ADDI(A0, X0, 0));
        CALL(I_f1);
        I_ret1 = pc_ens;
        GUARDA(A0, 55);                                   // lo que dejo la funcion
        GUARDA(RA, 56);                                   // la direccion de regreso

        // ---- lazo: suma de 1 a 10 ----
        emitir(ADDI(T2, X0, 0));
        emitir(ADDI(T4, X0, 10));
        I_lazo = pc_ens;
        emitir(ADD (T2, T2, T4));
        emitir(ADDI(T4, T4, -1));
        BNEZ(T4, I_lazo);
        GUARDA(T2, 57);

        // ---- un dato guardado en la memoria de programa ----
        LA(T4, I_dato);
        emitir(LW (T2, T4, 0));         GUARDA(T2, 58);

        // ---- perifericos: el contador de ciclos avanza y se leen los interruptores ----
        emitir(LW (T4, S1, 32'h10));
        emitir(LW (T5, S1, 32'h10));
        emitir(SLTU(T2, T4, T5));       GUARDA(T2, 59);
        emitir(LW (T2, S1, 32'h04));    GUARDA(T2, 60);

        // ---- fin: "OK" a la consola y ecall ----
        CONSOLA(S1, T5, "O");
        CONSOLA(S1, T5, "K");
        CONSOLA(S1, T5, 8'h0A);
        emitir(ECALL(0));

        // ---- la funcion ----
        I_f1 = pc_ens;
        emitir(ADDI(A0, X0, 77));
        RET;

        // ---- datos ----
        I_dato = pc_ens;
        emitir(32'hCAFEF00D);
        I_fin = pc_ens;
    end
endtask
