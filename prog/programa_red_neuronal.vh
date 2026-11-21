// ============================================================
// PROGRAMA 1 — CLASIFICADOR DE PATRONES 3x3 CON RED NEURONAL (Edge AI)
//
// Lee los 9 interruptores SW[8:0] como una imagen de 3x3 pixeles y la
// clasifica con un perceptron multicapa 9 -> 16 -> 8 cuantizado a
// enteros de 8 bits (los pesos viven en la ROM, despues del codigo).
//
//   capa 1:  h[j] = b1[j] + sum_i W1[j][i] * x[i]        (x[i] = pixel)
//            a[j] = clamp(h[j] >> SH1, 0, 127)            ReLU + saturacion
//                   -> una sola instruccion de la tabla OP_R3: clamp
//   capa 2:  o[k] = b2[k] + sum_j W2[k][j] * a[j]        (mul de RV32M)
//   salida:  clase = argmax o[k]                          (sgt, de la tabla OP_R3)
//
// Resultados:  RAM 0x1000_0000 = clase, 0x1000_0004.. = 8 puntuaciones,
//              0x1000_0100.. = activaciones a[16]
//              LEDR[clase] encendido y LEDR9 = listo
//              HEX = puntuacion ganadora (16 bits) | clase (digito 0)
//              consola: "CLASE n"
// Clases: 0 X, 1 O, 2 +, 3 -, 4 |, 5 /, 6 \, 7 T   (ver pesos_red.vh)
// Escrito con el codificador Verilog: LW(rd, rs1, imm) = lw rd, imm(rs1)
// ============================================================

integer R_inicio, R_capa1, R_c1_i, R_c1_skip, R_capa2, R_c2_j, R_c2_skip;
integer R_W1, R_B1, R_W2, R_B2, R_fin;
integer r_idx;


task programa_red;
    input integer pasada;
    begin
        pc_ens   = 0;
        R_inicio = pc_ens;

        // ---------------- punteros y entrada ----------------
        emitir(LUI(S0, 32'hFFFF0000));            // s0 = pagina de perifericos
        emitir(LW(S1, S0, 32'h04));               // s1 = SW
        emitir(ANDI(S1, S1, 32'h1FF));            // solo 9 pixeles
        emitir(LUI(S2, 32'h10000000));            // s2 = RAM de datos
        LA(T0, R_W1);                             // t0 -> W1[0]
        LA(T1, R_B1);                             // t1 -> B1[0]
        emitir(ADDI(T2, X0, 0));                  // j = 0

        // ---------------- capa 1: 16 neuronas ocultas ----------------
        R_capa1 = pc_ens;
        emitir(LW(A0, T1, 0));                    // acc = b1[j]
        emitir(ADDI(T4, S1, 0));                  // t4 = pixeles por recorrer
        emitir(ADDI(T3, X0, 0));                  // i = 0
        R_c1_i = pc_ens;
        emitir(ANDI(T5, T4, 1));                  // pixel i encendido?
        BEQZ(T5, R_c1_skip);
        emitir(LB(T6, T0, 0));                    // W1[j][i] (byte con signo desde la ROM)
        emitir(ADD(A0, A0, T6));                  // acc += w   (riesgo carga-uso)
        R_c1_skip = pc_ens;
        emitir(ADDI(T0, T0, 1));
        emitir(SRLI(T4, T4, 1));
        emitir(ADDI(T3, T3, 1));
        emitir(ADDI(T5, X0, RED_ENTRADAS));
        BLT_A(T3, T5, R_c1_i);
        emitir(SRAI(A0, A0, RED_SH1));            // requantiza
        emitir(ADDI(T5, X0, 127));
        emitir(XOP(XA_CLAMP, A0, A0, T5));        // a = clamp(acc, 0, 127)  [OP_R3]
        emitir(ADD(T5, S2, T2));
        emitir(SB(A0, T5, 32'h100));              // a[j] -> RAM 0x1000_0100 + j
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T5, X0, RED_OCULTAS));
        BLT_A(T2, T5, R_capa1);

        // ---------------- capa 2: 8 salidas + argmax ----------------
        LA(T0, R_W2);
        LA(T1, R_B2);
        emitir(ADDI(T2, X0, 0));                  // k = 0
        emitir(LUI(S3, 32'h80000000));            // mejor = -2^31
        emitir(ADDI(S4, X0, 0));                  // clase = 0
        R_capa2 = pc_ens;
        emitir(LW(A0, T1, 0));                    // acc = b2[k]
        emitir(ADDI(T3, X0, 0));                  // j = 0
        R_c2_j = pc_ens;
        emitir(LB(T6, T0, 0));                    // W2[k][j]
        emitir(ADD(T5, S2, T3));
        emitir(LBU(T4, T5, 32'h100));             // a[j]
        emitir(MUL(T6, T6, T4));                  // w * a   [RV32M]
        emitir(ADD(A0, A0, T6));
        emitir(ADDI(T0, T0, 1));
        emitir(ADDI(T3, T3, 1));
        emitir(ADDI(T5, X0, RED_OCULTAS));
        BLT_A(T3, T5, R_c2_j);
        emitir(SLLI(T5, T2, 2));
        emitir(ADD(T5, T5, S2));
        emitir(SW(A0, T5, 4));                    // puntuacion[k] -> RAM 0x1000_0004 + 4k
        emitir(XOP(XA_SGT, T5, A0, S3));          // acc > mejor ?   [OP_R3]
        BEQZ(T5, R_c2_skip);
        emitir(ADDI(S3, A0, 0));                  // mejor = acc
        emitir(ADDI(S4, T2, 0));                  // clase = k
        R_c2_skip = pc_ens;
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T5, X0, RED_SALIDAS));
        BLT_A(T2, T5, R_capa2);

        // ---------------- salida ----------------
        emitir(SW(S4, S2, 0));                    // clase -> RAM[0]
        emitir(ADDI(T5, X0, 1));
        emitir(SLL(T5, T5, S4));                  // 1 << clase
        emitir(ORI(T5, T5, 32'h200));             // LEDR9 = listo
        emitir(SW(T5, S0, 32'h00));               // LEDS
        emitir(SLLI(T5, S3, 8));
        emitir(OR(T5, T5, S4));
        emitir(SW(T5, S0, 32'h08));               // HEX = puntuacion << 8 | clase
        CONSOLA(S0, T5, "C");
        CONSOLA(S0, T5, "L");
        CONSOLA(S0, T5, "A");
        CONSOLA(S0, T5, "S");
        CONSOLA(S0, T5, "E");
        CONSOLA(S0, T5, " ");
        emitir(ADDI(T5, S4, 48));                 // '0' + clase
        emitir(SW(T5, S0, 32'h14));
        CONSOLA(S0, T5, 8'h0A);
        emitir(ADDI(T5, X0, 1));
        emitir(SW(T5, S0, 32'h18));               // CONTROL.listo = 1
        emitir(ECALL(0));

        // ---------------- tablas de pesos (datos en la ROM) ----------------
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
