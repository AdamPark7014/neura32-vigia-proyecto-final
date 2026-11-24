integer R_inicio, R_capa1, R_c1_i, R_c1_skip, R_capa2, R_c2_j, R_c2_skip;
integer R_W1, R_B1, R_W2, R_B2, R_fin;
integer r_idx;

task programa_red;
    input integer pasada;
    begin
        pc_ens   = 0;
        R_inicio = pc_ens;

        // punteros y entrada
        emitir(LUI(S0, 32'hFFFF0000));
        emitir(LW(S1, S0, 32'h04));
        emitir(ANDI(S1, S1, 32'h1FF));
        emitir(LUI(S2, 32'h10000000));
        LA(T0, R_W1);
        LA(T1, R_B1);
        emitir(ADDI(T2, X0, 0));

        // capa 1
        R_capa1 = pc_ens;
        emitir(LW(A0, T1, 0));
        emitir(ADDI(T4, S1, 0));
        emitir(ADDI(T3, X0, 0));
        R_c1_i = pc_ens;
        emitir(ANDI(T5, T4, 1));
        BEQZ(T5, R_c1_skip);
        emitir(LB(T6, T0, 0));
        emitir(ADD(A0, A0, T6));
        R_c1_skip = pc_ens;
        emitir(ADDI(T0, T0, 1));
        emitir(SRLI(T4, T4, 1));
        emitir(ADDI(T3, T3, 1));
        emitir(ADDI(T5, X0, RED_ENTRADAS));
        BLT_A(T3, T5, R_c1_i);
        emitir(SRAI(A0, A0, RED_SH1));
        emitir(ADDI(T5, X0, 127));
        emitir(XOP(XA_CLAMP, A0, A0, T5));
        emitir(ADD(T5, S2, T2));
        emitir(SB(A0, T5, 32'h100));
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T5, X0, RED_OCULTAS));
        BLT_A(T2, T5, R_capa1);

        // capa 2
        LA(T0, R_W2);
        LA(T1, R_B2);
        emitir(ADDI(T2, X0, 0));
        emitir(LUI(S3, 32'h80000000));
        emitir(ADDI(S4, X0, 0));
        R_capa2 = pc_ens;
        emitir(LW(A0, T1, 0));
        emitir(ADDI(T3, X0, 0));
        R_c2_j = pc_ens;
        emitir(LB(T6, T0, 0));
        emitir(ADD(T5, S2, T3));
        emitir(LBU(T4, T5, 32'h100));
        emitir(MUL(T6, T6, T4));
        emitir(ADD(A0, A0, T6));
        emitir(ADDI(T0, T0, 1));
        emitir(ADDI(T3, T3, 1));
        emitir(ADDI(T5, X0, RED_OCULTAS));
        BLT_A(T3, T5, R_c2_j);
        emitir(SLLI(T5, T2, 2));
        emitir(ADD(T5, T5, S2));
        emitir(SW(A0, T5, 4));
        emitir(XOP(XA_SGT, T5, A0, S3));
        BEQZ(T5, R_c2_skip);
        emitir(ADDI(S3, A0, 0));
        emitir(ADDI(S4, T2, 0));
        R_c2_skip = pc_ens;
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T5, X0, RED_SALIDAS));
        BLT_A(T2, T5, R_capa2);

        // salida
        emitir(SW(S4, S2, 0));
        emitir(ADDI(T5, X0, 1));
        emitir(SLL(T5, T5, S4));
        emitir(ORI(T5, T5, 32'h200));
        emitir(SW(T5, S0, 32'h00));
        emitir(SLLI(T5, S3, 8));
        emitir(OR(T5, T5, S4));
        emitir(SW(T5, S0, 32'h08));
        CONSOLA(S0, T5, "C");
        CONSOLA(S0, T5, "L");
        CONSOLA(S0, T5, "A");
        CONSOLA(S0, T5, "S");
        CONSOLA(S0, T5, "E");
        CONSOLA(S0, T5, " ");
        emitir(ADDI(T5, S4, 48));
        emitir(SW(T5, S0, 32'h14));
        CONSOLA(S0, T5, 8'h0A);
        emitir(ADDI(T5, X0, 1));
        emitir(SW(T5, S0, 32'h18));
        emitir(ECALL(0));

        // tablas de pesos
        R_W1 = pc_ens;
        for (r_idx = 0; r_idx < RED_OCULTAS * RED_ENTRADAS; r_idx = r_idx + 4)
            emitir_bytes(RED_W1[r_idx], RED_W1[r_idx+1], RED_W1[r_idx+2], RED_W1[r_idx+3]);
        R_B1 = pc_ens;
        for (r_idx = 0; r_idx < RED_OCULTAS; r_idx = r_idx + 1)
            emitir(RED_B1[r_idx]);
        R_W2 = pc_ens;
        for (r_idx = 0; r_idx < RED_SALIDAS * RED_OCULTAS; r_idx = r_idx + 4)
            emitir_bytes(RED_W2[r_idx], RED_W2[r_idx+1], RED_W2[r_idx+2], RED_W2[r_idx+3]);
        R_B2 = pc_ens;
        for (r_idx = 0; r_idx < RED_SALIDAS; r_idx = r_idx + 1)
            emitir(RED_B2[r_idx]);
        R_fin = pc_ens;
    end
endtask
