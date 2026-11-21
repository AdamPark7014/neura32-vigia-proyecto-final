// ============================================================
// PROGRAMA DE DEMOSTRACION: "otro programa" para el mismo procesador
// No usa la camara. Muestra la serie de Fibonacci en los displays
// (en hexadecimal) y una luz que va y viene por los LED.
//   SW9 arriba: pausa.
// Sirve para comprobar que NEURA-32 corre cualquier programa: se carga
// por el cable USB-Blaster con fpga/cargar_programa.tcl, sin compilar
// de nuevo, y despues se puede volver a cargar el programa del vigia.
//
// Registros:  s0 perifericos   s2 = a   s3 = b   (Fibonacci)
//             s4 luz de los LED   s5 sentido   s6 vueltas de espera
// ============================================================
integer D_plat, D_ciclo, D_espera, D_sigue, D_der, D_fin;

task programa_demo;
    input integer pasada;
    begin
        pc_ens = 0;

        LI(S0, 32'hFFFF0000);                           // direccion de los perifericos
        emitir(ADDI(S2, X0, 0));                        // a = 0
        emitir(ADDI(S3, X0, 1));                        // b = 1
        emitir(ADDI(S4, X0, 1));                        // la luz empieza en el LED0
        emitir(ADDI(S5, X0, 0));                        // 0: hacia la izquierda

        // vueltas de espera: 3 en simulacion, ~0.3 s en la placa
        emitir(LW  (T0, S0, PV_PLATAFORMA));
        emitir(ANDI(T0, T0, 1));
        emitir(ADDI(S6, X0, 3));
        BNEZ(T0, D_plat);
        LI(S6, 32'd1500000);
        D_plat = pc_ens;

        // ---------------- ciclo principal ----------------
        D_ciclo = pc_ens;
        emitir(SW  (S2, S0, PV_HEX));                   // el numero de la serie a los displays
        emitir(SW  (S4, S0, PV_LEDS));                  // la luz a los LED

        emitir(ADDI(T0, S6, 0));                        // espera
        D_espera = pc_ens;
        emitir(ADDI(T0, T0, -1));
        BNEZ(T0, D_espera);

        emitir(LW  (T1, S0, PV_SW));                    // SW9 arriba: pausa
        emitir(SRLI(T1, T1, 9));
        BNEZ(T1, D_ciclo);

        emitir(ADD (T2, S2, S3));                       // t = a + b
        emitir(ADDI(S2, S3, 0));                        // a = b
        emitir(ADDI(S3, T2, 0));                        // b = t
        LI(T3, 32'h01000000);                           // ya no cabe en 6 displays: empezar de nuevo
        BLTU_A(S2, T3, D_sigue);
        emitir(ADDI(S2, X0, 0));
        emitir(ADDI(S3, X0, 1));
        D_sigue = pc_ens;

        BNEZ(S5, D_der);                                // luz que va y viene entre LED0 y LED9
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
