// ============================================================
// PROGRAMA 2 — PRUEBA DEL REPERTORIO (RV32I + M + Zbb + Zicsr + clase + Xneura + riesgos)
// Cada prueba deja un resultado de 32 bits en RAM[n] = 0x1000_0000 + 4n.
// tb_prueba_isa.v calcula los valores esperados con operadores de
// Verilog (independientes del procesador) y los compara uno por uno.
// Operandos base: A = 0x12345678 (t0), B = 0xDEADBEEF (t1), t3 = 4
// ============================================================

integer I_auipc, I_ret1, I_ret2, I_f1, I_f2, I_dato, I_lazo, I_fin;
integer I_b0, I_b1, I_b2, I_b3, I_b4, I_b5, I_b6, I_b7, I_b8;

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

        // ---- tipo R ----
        emitir(ADD (T2, T0, T1)); GUARDA(T2, 2);
        emitir(SUB (T2, T0, T1)); GUARDA(T2, 3);
        emitir(XOR (T2, T0, T1)); GUARDA(T2, 4);
        emitir(OR  (T2, T0, T1)); GUARDA(T2, 5);
        emitir(AND (T2, T0, T1)); GUARDA(T2, 6);
        emitir(SLL (T2, T0, T3)); GUARDA(T2, 7);
        emitir(SRL (T2, T1, T3)); GUARDA(T2, 8);
        emitir(SRA (T2, T1, T3)); GUARDA(T2, 9);
        emitir(SLT (T2, T1, T0)); GUARDA(T2, 10);
        emitir(SLTU(T2, T1, T0)); GUARDA(T2, 11);

        // ---- tipo I ----
        emitir(ADDI (T2, T0, -1));      GUARDA(T2, 12);
        emitir(SLTI (T2, T1, 0));       GUARDA(T2, 13);
        emitir(SLTIU(T2, T1, -1));      GUARDA(T2, 14);
        emitir(XORI (T2, T0, 32'h0FF)); GUARDA(T2, 15);
        emitir(ORI  (T2, T0, 32'h700)); GUARDA(T2, 16);
        emitir(ANDI (T2, T0, 32'h0F0)); GUARDA(T2, 17);
        emitir(SLLI (T2, T0, 12));      GUARDA(T2, 18);
        emitir(SRLI (T2, T1, 28));      GUARDA(T2, 19);
        emitir(SRAI (T2, T1, 28));      GUARDA(T2, 20);

        // ---- tipo U ----
        emitir(LUI(T2, 32'hABCDE000));  GUARDA(T2, 21);
        I_auipc = pc_ens;
        emitir(AUIPC(T2, 32'h0));       GUARDA(T2, 22);

        // ---- RV32M ----
        emitir(MUL   (T2, T0, T1)); GUARDA(T2, 23);
        emitir(MULH  (T2, T0, T1)); GUARDA(T2, 24);
        emitir(MULHSU(T2, T0, T1)); GUARDA(T2, 25);
        emitir(MULHU (T2, T0, T1)); GUARDA(T2, 26);
        emitir(DIV   (T2, T1, T3)); GUARDA(T2, 27);
        emitir(DIVU  (T2, T1, T3)); GUARDA(T2, 28);
        emitir(REM   (T2, T1, T3)); GUARDA(T2, 29);
        emitir(REMU  (T2, T1, T3)); GUARDA(T2, 30);
        emitir(DIV   (T2, T0, X0)); GUARDA(T2, 31);     // division entre cero
        emitir(REM   (T2, T0, X0)); GUARDA(T2, 32);

        // ---- memoria: accesos parciales y extension de signo ----
        emitir(SW (T0, S0, 32'h200));
        emitir(LW (T2, S0, 32'h200));   GUARDA(T2, 33);  // carga seguida de uso en el almacenamiento
        emitir(SB (T1, S0, 32'h204));                    // byte 0xEF
        emitir(SB (T0, S0, 32'h205));                    // byte 0x78
        emitir(SH (T1, S0, 32'h206));                    // media palabra 0xBEEF
        emitir(LW (T2, S0, 32'h204));   GUARDA(T2, 34);
        emitir(LB (T2, S0, 32'h204));   GUARDA(T2, 35);
        emitir(LBU(T2, S0, 32'h204));   GUARDA(T2, 36);
        emitir(LH (T2, S0, 32'h206));   GUARDA(T2, 37);
        emitir(LHU(T2, S0, 32'h206));   GUARDA(T2, 38);
        emitir(LB (T2, S0, 32'h205));
        emitir(LH (T4, S0, 32'h204));
        emitir(ADD(T2, T2, T4));        GUARDA(T2, 39);  // 0x78 + 0x78EF
        LA(T4, I_dato);
        emitir(LW (T2, T4, 0));         GUARDA(T2, 40);  // dato leido de la ROM

        // ---- lazo: suma 1..10 (ejemplo del profesor) ----
        emitir(ADDI(T2, X0, 0));
        emitir(ADDI(T4, X0, 1));
        emitir(ADDI(T5, X0, 10));
        I_lazo = pc_ens;
        emitir(ADD (T2, T2, T4));
        emitir(ADDI(T4, T4, 1));
        BGE_A(T5, T4, I_lazo);
        GUARDA(T2, 41);

        // ---- saltos condicionales: si NO se toma, se enciende el bit ----
        emitir(ADDI(T2, X0, 0));
        I_b0 = pc_ens; emitir(BEQ (T0, T0, 8)); emitir(ORI(T2, T2, 32'h01));   // tomado
        I_b1 = pc_ens; emitir(BNE (T0, T1, 8)); emitir(ORI(T2, T2, 32'h02));   // tomado
        I_b2 = pc_ens; emitir(BLT (T1, T0, 8)); emitir(ORI(T2, T2, 32'h04));   // tomado (-ve < +ve)
        I_b3 = pc_ens; emitir(BGE (T0, T1, 8)); emitir(ORI(T2, T2, 32'h08));   // tomado
        I_b4 = pc_ens; emitir(BLTU(T0, T1, 8)); emitir(ORI(T2, T2, 32'h10));   // tomado (sin signo)
        I_b5 = pc_ens; emitir(BGEU(T1, T0, 8)); emitir(ORI(T2, T2, 32'h20));   // tomado
        I_b6 = pc_ens; emitir(BLT (T0, T1, 8)); emitir(ORI(T2, T2, 32'h40));   // NO tomado
        I_b7 = pc_ens; emitir(BLTU(T1, T0, 8)); emitir(ORI(T2, T2, 32'h80));   // NO tomado
        emitir(ADDI(T4, X0, 3));
        emitir(ADDI(T5, X0, 3));
        I_b8 = pc_ens; emitir(BEQ (T4, T5, 8)); emitir(ORI(T2, T2, 32'h100));  // tomado con operandos adelantados
        GUARDA(T2, 42);

        // ---- jal / jalr y retorno ----
        CALL(I_f1);
        I_ret1 = pc_ens;
        GUARDA(T2, 43);                                   // t2 = ra dentro de f1
        LA(T4, I_f2);
        emitir(JALR(RA, T4, 0));
        I_ret2 = pc_ens;
        GUARDA(T2, 44);

        // ---- cadena de adelantamiento EX->EX, MEM->EX y WB->ID ----
        emitir(ADDI(T2, X0, 1));
        emitir(ADD (T2, T2, T2));
        emitir(ADD (T2, T2, T2));
        emitir(ADD (T2, T2, T2));                         // 8
        emitir(ADDI(T4, X0, 5));
        NOP;
        emitir(ADD (T2, T2, T4));                         // 13 (distancia 2)
        emitir(ADDI(T5, X0, 7));
        NOP; NOP;
        emitir(ADD (T2, T2, T5));                         // 20 (distancia 3)
        GUARDA(T2, 45);

        // ---- riesgo carga-uso ----
        emitir(LW  (T4, S0, 32'h200));
        emitir(ADDI(T2, T4, 1));        GUARDA(T2, 46);   // A + 1
        emitir(LW  (T4, S0, 32'h200));
        emitir(SW  (T4, S0, 32'h208));                    // dato de almacenamiento adelantado
        emitir(LW  (T2, S0, 32'h208));  GUARDA(T2, 47);

        // ---- CSR ----
        emitir(CSRRS(T2, `CSR_MHARTID, X0));    GUARDA(T2, 48);
        emitir(CSRRS(T2, `CSR_MISA, X0));       GUARDA(T2, 49);
        emitir(CSRRW(X0, `CSR_MSCRATCH, T0));
        emitir(CSRRS(T2, `CSR_MSCRATCH, X0));   GUARDA(T2, 50);
        emitir(CSRRSI(X0, `CSR_MSCRATCH, 5'h7));
        emitir(CSRRS(T2, `CSR_MSCRATCH, X0));   GUARDA(T2, 51);
        emitir(CSRRCI(X0, `CSR_MSCRATCH, 5'hF));
        emitir(CSRRS(T2, `CSR_MSCRATCH, X0));   GUARDA(T2, 52);
        NOP; NOP; NOP; NOP;
        emitir(CSRRS(T4, `CSR_INSTRET, X0));
        emitir(CSRRS(T5, `CSR_INSTRET, X0));
        emitir(SUB  (T2, T5, T4));              GUARDA(T2, 53);   // exactamente 1 instruccion retirada
        emitir(CSRRS(T4, `CSR_CYCLE, X0));
        emitir(CSRRS(T5, `CSR_CYCLE, X0));
        emitir(SLTU (T2, T4, T5));              GUARDA(T2, 54);   // el reloj avanza

        // ---- Xneura: abs, sgt y clamp ----
        emitir(XOP(XA_ABS,   T2, X0, X0));      GUARDA(T2, 55);   // |0| = 0
        LI(T4, 32'h00123456);
        emitir(XOP(XA_ABS,   T2, T4, X0));      GUARDA(T2, 56);   // positivo: queda igual
        emitir(XOP(XA_SGT,   T2, T0, T1));      GUARDA(T2, 57);   // A > B
        emitir(XOP(XA_SGT,   T2, T1, T0));      GUARDA(T2, 58);   // B > A
        LI(T4, 32'h7FFFFFFF);
        emitir(ADDI(T5, X0, 1));
        emitir(XOP(XA_SGT,   T2, T4, T5));      GUARDA(T2, 59);   // el mayor positivo > 1
        emitir(XOP(XA_SGT,   T2, T5, T4));      GUARDA(T2, 60);   // 1 > el mayor positivo: no
        emitir(ADDI(T4, X0, -1));
        emitir(XOP(XA_ABS,   T2, T4, X0));      GUARDA(T2, 61);   // |-1| = 1
        emitir(XOP(XA_CLAMP, T2, T0, T1));      GUARDA(T2, 62);   // limitar(A, 0, B)
        emitir(ADDI(T4, X0, -5));
        emitir(ADDI(T5, X0, 127));
        emitir(XOP(XA_CLAMP, T2, T4, T5));      GUARDA(T2, 63);   // negativo -> 0
        emitir(ADDI(T4, X0, 100));
        emitir(XOP(XA_CLAMP, T2, T4, T5));      GUARDA(T2, 64);   // dentro del rango -> igual
        emitir(XOP(XA_CLAMP, T2, T5, T5));      GUARDA(T2, 65);   // justo en el limite
        emitir(ADDI(T4, X0, 200));
        emitir(XOP(XA_CLAMP, T2, T4, T5));      GUARDA(T2, 66);   // arriba del limite -> 127
        emitir(XOP(XA_ABS,   T2, T1, X0));      GUARDA(T2, 67);   // |B|
        emitir(XOP(XA_SGT,   T2, T5, T5));      GUARDA(T2, 68);   // iguales: no

        // ---- instruccion ilegal: no debe escribir t2; fence: sin efecto ----
        emitir(ADDI(T2, X0, 77));
        emitir(fmt_r(7'h00, X0, X0, 3'b000, T2, 7'b1111111));
        emitir(FENCE(0));
        GUARDA(T2, 69);

        // ---- division con desbordamiento: -2^31 / -1 (la norma fija el resultado) ----
        emitir(LUI (T4, 32'h80000000));
        emitir(ADDI(T5, X0, -1));
        emitir(DIV (T2, T4, T5));       GUARDA(T2, 70);
        emitir(REM (T2, T4, T5));       GUARDA(T2, 71);

        // ---- Zbb: las de la ROM de instrucciones de la clase (A = t0, B = t1, t3 = 4) ----
        emitir(ANDN  (T2, T0, T1));     GUARDA(T2, 72);
        emitir(ORN   (T2, T0, T1));     GUARDA(T2, 73);
        emitir(XNOR  (T2, T0, T1));     GUARDA(T2, 74);
        emitir(MIN   (T2, T0, T1));     GUARDA(T2, 75);
        emitir(MINU  (T2, T0, T1));     GUARDA(T2, 76);
        emitir(MAX   (T2, T0, T1));     GUARDA(T2, 77);
        emitir(MAXU  (T2, T0, T1));     GUARDA(T2, 78);
        emitir(ROL   (T2, T0, T3));     GUARDA(T2, 79);
        emitir(ROR   (T2, T0, T3));     GUARDA(T2, 80);
        emitir(RORI  (T2, T1, 8));      GUARDA(T2, 81);
        emitir(CLZ   (T2, T0));         GUARDA(T2, 82);
        emitir(CTZ   (T2, T1));         GUARDA(T2, 83);
        emitir(CPOP  (T2, T0));         GUARDA(T2, 84);
        emitir(SEXT_B(T2, T1));         GUARDA(T2, 85);
        emitir(SEXT_H(T2, T1));         GUARDA(T2, 86);
        emitir(ZEXT_H(T2, T1));         GUARDA(T2, 87);
        emitir(REV8  (T2, T0));         GUARDA(T2, 88);
        // ---- instrucciones propias de la clase (custom-0) ----
        emitir(NOTA  (T2, T0, T1));     GUARDA(T2, 89);
        emitir(PASSB (T2, T0, T1));     GUARDA(T2, 90);
        emitir(SLA   (T2, T0, T3));     GUARDA(T2, 91);

        // ---- consola y fin ----
        CONSOLA(S1, T5, "O");
        CONSOLA(S1, T5, "K");
        CONSOLA(S1, T5, 8'h0A);
        emitir(ECALL(0));
        NOP; NOP; NOP;

        // ---- subrutinas ----
        I_f1 = pc_ens;
        emitir(ADDI(T2, RA, 0));
        RET;
        I_f2 = pc_ens;
        emitir(ADDI(T2, RA, 0));
        emitir(JALR(X0, RA, 0));

        // ---- dato en la ROM ----
        I_dato = pc_ens;
        emitir(32'hC0DEF00D);
        I_fin = pc_ens;
    end
endtask
