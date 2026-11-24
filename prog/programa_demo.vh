integer D_plat, D_ciclo, D_espera, D_sigue, D_der, D_fin;

task programa_demo;
    input integer pasada;
    begin
        pc_ens = 0;

        LI(S0, 32'hFFFF0000);
        emitir(ADDI(S2, X0, 0));
        emitir(ADDI(S3, X0, 1));
        emitir(ADDI(S4, X0, 1));
        emitir(ADDI(S5, X0, 0));

        // espera
        emitir(LW  (T0, S0, PV_PLATAFORMA));
        emitir(ANDI(T0, T0, 1));
        emitir(ADDI(S6, X0, 3));
        BNEZ(T0, D_plat);
        LI(S6, 32'd1500000);
        D_plat = pc_ens;

        // ciclo principal
        D_ciclo = pc_ens;
        emitir(SW  (S2, S0, PV_HEX));
        emitir(SW  (S4, S0, PV_LEDS));

        emitir(ADDI(T0, S6, 0));
        D_espera = pc_ens;
        emitir(ADDI(T0, T0, -1));
        BNEZ(T0, D_espera);

        emitir(LW  (T1, S0, PV_SW));
        emitir(SRLI(T1, T1, 9));
        BNEZ(T1, D_ciclo);

        emitir(ADD (T2, S2, S3));
        emitir(ADDI(S2, S3, 0));
        emitir(ADDI(S3, T2, 0));
        LI(T3, 32'h01000000);
        BLTU_A(S2, T3, D_sigue);
        emitir(ADDI(S2, X0, 0));
        emitir(ADDI(S3, X0, 1));
        D_sigue = pc_ens;

        BNEZ(S5, D_der);
        emitir(SLLI(S4, S4, 1));
        emitir(ADDI(T4, X0, 512));
        BNE_A(S4, T4, D_ciclo);
        emitir(ADDI(S5, X0, 1));
        J(D_ciclo);
        D_der = pc_ens;
        emitir(SRLI(S4, S4, 1));
        emitir(ADDI(T4, X0, 1));
        BNE_A(S4, T4, D_ciclo);
        emitir(ADDI(S5, X0, 0));
        J(D_ciclo);

        D_fin = pc_ens;
    end
endtask
