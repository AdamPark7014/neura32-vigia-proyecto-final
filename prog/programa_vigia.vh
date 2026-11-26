localparam PV_LEDS = 32'h00;  // LEDs rojos
localparam PV_SW = 32'h04;  // los interruptores
localparam PV_HEX = 32'h08;  // displays siete segmentos
localparam PV_KEY = 32'h0C;  // los botones
localparam PV_TICKS = 32'h10;  // contador de ciclos
localparam PV_CONSOLA = 32'h14;  // consola de texto
localparam PV_CONTROL = 32'h18;  // control del sistema
localparam PV_PLATAFORMA = 32'h24;  // placa o simulación
localparam PV_CAM_SAL = 32'h40;  // salidas a cámara
localparam PV_CAM_ENT = 32'h44;  // entradas de cámara
localparam PV_VIS_CTRL = 32'h48;  // control de visión
localparam PV_VIS_EST = 32'h4C;  // estado de visión
localparam PV_VIS_FG = 32'h50;  // celdas en movimiento
localparam PV_ZONA = 32'h54;  // zona prohibida
localparam PV_LINEA = 32'h58;  // línea virtual
localparam PV_LETRERO = 32'h5C;  // letrero de alarma
localparam PV_CAJA0 = 32'h60;  // primer recuadro
localparam PV_COLORES = 32'h80;  // color de recuadros

// variables en RAM
localparam VR_SIM = 0;  // modo simulación
localparam VR_RETARDO = 4;  // retardo del SCCB
localparam VR_PID = 8;  // modelo de cámara
localparam VR_VER = 12;  // versión de cámara
localparam VR_CUADRO = 16;  // cuadro actual
localparam VR_ENTRADAS = 20;  // contador de entradas
localparam VR_SALIDAS = 24;  // contador de salidas
localparam VR_ALARMA = 28;  // alarma activa
localparam VR_NBLOBS = 32;  // manchas encontradas
localparam VR_EN_ZONA = 36;  // personas en zona
localparam VR_SIG_ID = 40;  // siguiente número pista
localparam VR_BENCH_X = 44;  // ciclos con cpop
localparam VR_BENCH_R = 48;  // ciclos sin cpop
localparam VR_ZONA = 52;  // zona elegida
localparam VR_LINEA = 56;  // línea elegida
localparam VR_SENTIDO = 60;  // sentido prohibido
localparam VR_F_AEC = 64;  // cuadro fija exposición
localparam VR_F_APRENDE = 68;  // cuadro fin aprendizaje
localparam VR_NO_PERSONA = 72;  // objetos descartados
localparam VR_PERSONAS = 76;  // personas a la vista
localparam VR_EVENTOS = 80;  // eventos registrados
localparam VR_CLASE_PRUEBA = 84;  // clase de autoprueba
localparam VR_CICLOS = 88;  // ciclos del cuadro
localparam VR_MAX_CICLOS = 92;  // peor cuadro medido
localparam VR_PUNT = 96;  // puntuaciones de red
localparam VR_CAM_OK = 108;  // cámara respondió
localparam VR_VIS_CTRL = 112;  // copia control visión
localparam VR_MODO = 116;  // red sin cpop
localparam VR_ESPERA = 120;  // espera al arrancar
localparam VR_VISTAS = 124;  // conteo de vistas
localparam VR_AUTOPRUEBA = 128;  // aciertos de autoprueba
localparam VR_MOVIDA = 132;  // cuadros cámara movida
localparam VR_N_REAP = 136;  // cuadros para reaprender
localparam VR_REAPRENDIDOS = 140;  // veces que reaprendió
localparam VR_N_AEC = 144;  // cuadros para exposición
localparam VR_BLOBS = 32'h100;  // tabla de manchas
localparam VR_PISTAS = 32'h300;  // tabla de pistas
localparam VR_RECORTE = 32'h400;  // silueta recortada
localparam VR_EVENT_LOG = 32'h500;  // bitácora de eventos
localparam DIR_ETIQ = 32'h10000800;  // etiquetas por celda
localparam DIR_PILA_FF = 32'h10001C00;  // pila del rellenado
localparam DIR_PILA = 32'h10004000;  // pila del programa

// parametros del algoritmo
localparam AREA_MIN = 12;  // mancha más chica
localparam MAX_BLOBS = 8;  // máximo de manchas
localparam MAX_PISTAS = 8;  // máximo de pistas
localparam DIST_MAX = 14;  // distancia para emparejar
localparam PERM_MIN = 3;  // cuadros para alarma
localparam UMBRAL = 28;  // umbral de movimiento
localparam ALFA = 3;  // velocidad del fondo
localparam VOTO_MIN = 2;  // votos para confirmar
localparam VOTO_MAX = 4;  // tope de votos
localparam MOVIDA_MIN = 3;  // cuadros cámara movida

// etiquetas
integer L_inicio, L_plat_ok, L_lim, L_lim2, L_cam_ok, L_cam_sigue, L_cfg, L_cfg_fin, L_cp;
integer L_bucle, L_espera, L_sin_borrar, L_no_aec, L_aprende, L_detecta, L_cls, L_cls_np, L_cls_sig;
integer L_cls_fin, L_libera;
integer L_espera_larga, L_espera_bucle, L_imprime, L_imp_fin, L_hex, L_hex_num, L_hex_bucle;
integer L_sccb_inicio, L_sccb_fin, L_sccb_byte, L_sb_bit, L_sccb_leer, L_sl_bit, L_sccb_escribe, L_sccb_lee;
integer L_etiquetar, L_borra, L_scan, L_scan_b, L_ff, L_ff_fin, L_scan_b_sig, L_scan_sig, L_scan_cont;
integer L_recortar, L_rc_fila, L_rc_impar, L_rc_mb, L_rc_col, L_rc_col_sig, L_rc_fila_fin, L_rc_par;
integer L_red, L_rx_neur, L_red_rv, L_rr_neur, L_red_salida, L_rs_k, L_rs_j, L_rs_j0, L_rs_j1, L_rs_nomax;
integer L_seguimiento, L_sg_des, L_sg_blob, L_sg_busca, L_sg_busca_sig, L_sg_libre, L_sg_crea, L_sg_tiene;
integer L_sg_salida, L_sg_cruce_prohibido, L_sg_zona, L_sg_fuera, L_sg_blob_sig, L_sg_perdidas, L_sg_p, L_sg_p_sig;
integer L_evento, L_dibujar, L_dj_c, L_dj_col, L_dj_fin, L_dj_sin;
integer T_sccb, T_sccb_sim, T_zonas, T_w1, T_t1, T_w2, T_b2, T_prueba, T_tab_eventos;
integer T_titulo, T_camara, T_ver, T_nl, T_error_cam, T_cfg, T_red_x, T_red_r, T_ciclos_nl;
integer T_aec, T_fondo, T_id, T_cuadro, T_ev0, T_ev1, T_ev2, T_ev3, T_ev4;
integer L_ap, L_ap_cp, L_plat_ok2, L_quieta, L_mov_lim;
integer L_sg_pasada, L_sg_pasada_fin, L_sg_resta, L_sg_votado;
integer T_autoprueba, T_de3, T_movida;
integer V_fin;
integer vw;

// ayudas de emision
// lineas SCCB
task CAM_LINEAS;
    input scl, sda;
    begin
        emitir(ADDI(T6, X0, 4 + (sda ? 0 : 2) + (scl ? 1 : 0)));
        emitir(SW(T6, S0, PV_CAM_SAL));
        RETARDO_SCCB;
    end
endtask

task RETARDO_SCCB;
    begin
        emitir(LW(T5, S1, VR_RETARDO));
        emitir(ADDI(T5, T5, -1));
        emitir(BNE(T5, X0, -4));
    end
endtask

task TEXTO;
    input integer etiqueta;
    begin
        LA(A0, etiqueta);
        CALL(L_imprime);
    end
endtask

// cadena
task CADENA;
    input [8*40-1:0] s;
    integer k, m;
    reg [7:0] c;
    reg [8*44-1:0] cad;
    begin
        cad = 0; m = 0;
        for (k = 39; k >= 0; k = k - 1) begin
            c = s[8*k +: 8];
            if (c != 0) begin cad[8*m +: 8] = c; m = m + 1; end
        end
        m = m + 1;
        while (m % 4 != 0) m = m + 1;
        for (k = 0; k < m; k = k + 4)
            emitir_bytes(cad[8*k +: 8], cad[8*(k+1) +: 8], cad[8*(k+2) +: 8], cad[8*(k+3) +: 8]);
    end
endtask

// vecino
task VECINO;
    input integer d, dp;
    begin
        emitir(ADDI(T4, T3, d));
        emitir(ADD (T5, S2, T4));
        emitir(LBU (T5, T5, 0));
        emitir(BEQ (T5, X0, 36));
        emitir(ADD (T5, S3, T4));
        emitir(LBU (A1, T5, 0));
        emitir(BNE (A1, X0, 24));
        emitir(SB  (S10, T5, 0));
        emitir(BGEU(S8, S9, 16));
        emitir(ADDI(A1, T0, dp));
        emitir(SH  (A1, S8, 0));
        emitir(ADDI(S8, S8, 2));
    end
endtask

// umbral y bit
task UMBRAL_Y_BIT;
    begin
        emitir(LW  (T2, A3, 0));
        emitir(ADDI(A3, A3, 4));
        emitir(SLTU(T2, T0, T2));
        emitir(XORI(T2, T2, 1));
        emitir(ANDI(T4, TP, 31));
        emitir(SLL (T2, T2, T4));
        emitir(ADDI(T4, X0, 32));
        emitir(BGE (TP, T4, 12));
        emitir(OR  (A4, A4, T2));
        emitir(JAL (X0, 8));
        emitir(OR  (A5, A5, T2));
        emitir(ADDI(TP, TP, 1));
    end
endtask

task programa_vigia;
    input integer pasada;
    begin
        pc_ens = 0;

        // arranque
        L_inicio = pc_ens;
        emitir(LUI(S0, 32'hFFFF0000));
        emitir(LUI(S1, 32'h10000000));
        emitir(LUI(S2, 32'h20000000));
        LI(S3, DIR_ETIQ);
        LI(SP, DIR_PILA);

        // limpiar RAM
        emitir(ADDI(T0, S1, 16));
        emitir(ADDI(T1, S1, 256));
        L_lim = pc_ens;
        emitir(SW(X0, T0, 0));
        emitir(ADDI(T0, T0, 4));
        BLTU_A(T0, T1, L_lim);
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, S1, VR_RECORTE));
        L_lim2 = pc_ens;
        emitir(SW(X0, T0, 0));
        emitir(ADDI(T0, T0, 4));
        BLTU_A(T0, T1, L_lim2);
        emitir(ADDI(T0, X0, 1));
        emitir(SW(T0, S1, VR_SIG_ID));

        // plataforma
        emitir(LW  (T0, S0, PV_PLATAFORMA));
        emitir(ANDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_SIM));
        emitir(ADDI(T1, X0, 2));
        emitir(ADDI(T2, X0, 1));
        emitir(ADDI(T3, X0, 4));
        emitir(ADDI(T4, X0, 1));
        BNEZ(T0, L_plat_ok);
        emitir(ADDI(T1, X0, 50));
        emitir(ADDI(T2, X0, 62));
        emitir(ADDI(T3, X0, 93));
        emitir(ADDI(T4, X0, 64));
        L_plat_ok = pc_ens;
        emitir(SW(T4, S1, VR_ESPERA));
        emitir(SW(T1, S1, VR_RETARDO));
        emitir(SW(T2, S1, VR_F_AEC));
        emitir(SW(T3, S1, VR_F_APRENDE));
        emitir(ADDI(T1, X0, 1));
        emitir(ADDI(T2, X0, 2));
        BNEZ(T0, L_plat_ok2);
        emitir(ADDI(T1, X0, 31));
        emitir(ADDI(T2, X0, 47));
        L_plat_ok2 = pc_ens;
        emitir(SW(T1, S1, VR_N_AEC));
        emitir(SW(T2, S1, VR_N_REAP));

        TEXTO(T_titulo);

        // reset de camara
        emitir(ADDI(T0, X0, 1));
        emitir(SW(T0, S0, PV_CAM_SAL));
        emitir(ADDI(A0, X0, 64));
        CALL(L_espera_larga);
        emitir(ADDI(T0, X0, 5));
        emitir(SW(T0, S0, PV_CAM_SAL));
        emitir(ADDI(A0, X0, 256));
        CALL(L_espera_larga);
        emitir(ADDI(A0, X0, 32'h12));
        emitir(ADDI(A1, X0, 32'h80));
        CALL(L_sccb_escribe);
        emitir(ADDI(A0, X0, 256));
        CALL(L_espera_larga);

        // identificacion
        emitir(ADDI(A0, X0, 32'h0A));
        CALL(L_sccb_lee);
        emitir(SW(A0, S1, VR_PID));
        emitir(ADDI(A0, X0, 32'h0B));
        CALL(L_sccb_lee);
        emitir(SW(A0, S1, VR_VER));
        TEXTO(T_camara);
        emitir(LW(A0, S1, VR_PID));
        emitir(ADDI(A1, X0, 2));
        CALL(L_hex);
        TEXTO(T_ver);
        emitir(LW(A0, S1, VR_VER));
        emitir(ADDI(A1, X0, 2));
        CALL(L_hex);
        TEXTO(T_nl);
        emitir(LW  (T0, S1, VR_PID));
        emitir(SLLI(T0, T0, 8));
        emitir(LW  (T1, S1, VR_VER));
        emitir(OR  (T0, T0, T1));
        emitir(SW  (T0, S0, PV_HEX));
        emitir(LW  (T0, S1, VR_PID));
        emitir(ADDI(T1, X0, 32'h76));
        BEQ_A(T0, T1, L_cam_ok);
        TEXTO(T_error_cam);
        emitir(ADDI(T0, X0, 2));
        emitir(SW(T0, S0, PV_CONTROL));
        J(L_cam_sigue);
        L_cam_ok = pc_ens;
        emitir(ADDI(T0, X0, 1));
        emitir(SW(T0, S1, VR_CAM_OK));
        L_cam_sigue = pc_ens;
        emitir(LW  (T0, S1, VR_CAM_OK));
        emitir(SLLI(T0, T0, 7));
        emitir(SW  (T0, S0, PV_LEDS));

        // tabla de registros
        LA(S4, T_sccb);
        emitir(LW  (T0, S1, VR_SIM));
        BEQZ(T0, L_cfg);
        LA(S4, T_sccb_sim);
        L_cfg = pc_ens;
        emitir(LW  (T0, S4, 0));
        emitir(ADDI(T1, X0, -1));
        BEQ_A(T0, T1, L_cfg_fin);
        emitir(SRLI(A0, T0, 8));
        emitir(ANDI(A1, T0, 255));
        CALL(L_sccb_escribe);
        emitir(ADDI(S4, S4, 4));
        J(L_cfg);
        L_cfg_fin = pc_ens;
        TEXTO(T_cfg);

        // medicion
        LA(T0, T_prueba);
        emitir(ADDI(T1, S1, VR_RECORTE));
        emitir(ADDI(T2, X0, 16));
        L_cp = pc_ens;
        emitir(LW  (T3, T0, 0));
        emitir(SW  (T3, T1, 0));
        emitir(ADDI(T0, T0, 4));
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, -1));
        BNEZ(T2, L_cp);
        emitir(LW  (S11, S0, PV_TICKS));
        emitir(ADDI(A0, S1, VR_RECORTE));
        emitir(ADDI(A1, X0, 0));
        CALL(L_red);
        emitir(LW  (T0, S0, PV_TICKS));
        emitir(SUB (T0, T0, S11));
        emitir(SW  (T0, S1, VR_BENCH_X));
        emitir(SW  (A0, S1, VR_CLASE_PRUEBA));
        emitir(LW  (S11, S0, PV_TICKS));
        emitir(ADDI(A0, S1, VR_RECORTE));
        emitir(ADDI(A1, X0, 1));
        CALL(L_red);
        emitir(LW  (T0, S0, PV_TICKS));
        emitir(SUB (T0, T0, S11));
        emitir(SW  (T0, S1, VR_BENCH_R));
        emitir(SLLI(A0, A0, 8));
        emitir(LW  (T0, S1, VR_CLASE_PRUEBA));
        emitir(OR  (T0, T0, A0));
        emitir(SW  (T0, S1, VR_CLASE_PRUEBA));
        TEXTO(T_red_x);
        emitir(LW(A0, S1, VR_BENCH_X));
        emitir(ADDI(A1, X0, 6));
        CALL(L_hex);
        TEXTO(T_red_r);
        emitir(LW(A0, S1, VR_BENCH_R));
        emitir(ADDI(A1, X0, 6));
        CALL(L_hex);
        TEXTO(T_ciclos_nl);

        // autoprueba de la red
        emitir(ADDI(S10, X0, 0));
        emitir(ADDI(S11, X0, 0));
        L_ap = pc_ens;
        LA(T0, T_prueba);
        emitir(SLLI(T1, S10, 6));
        emitir(ADD (T0, T0, T1));
        emitir(ADDI(T1, S1, VR_RECORTE));
        emitir(ADDI(T2, X0, 16));
        L_ap_cp = pc_ens;
        emitir(LW  (T3, T0, 0));
        emitir(SW  (T3, T1, 0));
        emitir(ADDI(T0, T0, 4));
        emitir(ADDI(T1, T1, 4));
        emitir(ADDI(T2, T2, -1));
        BNEZ(T2, L_ap_cp);
        emitir(ADDI(A0, S1, VR_RECORTE));
        emitir(ADDI(A1, X0, 0));
        CALL(L_red);
        emitir(SLTIU(T0, A0, 1));
        emitir(ADD (S11, S11, T0));
        emitir(ADDI(S10, S10, 1));
        emitir(ADDI(T0, X0, 3));
        BLT_A(S10, T0, L_ap);
        emitir(SW  (S11, S1, VR_AUTOPRUEBA));
        TEXTO(T_autoprueba);
        emitir(LW  (A0, S1, VR_AUTOPRUEBA));
        emitir(ADDI(A1, X0, 1));
        CALL(L_hex);
        TEXTO(T_de3);

        // arranca la vision
        LI(T0, 32'h04100001 | (UMBRAL << 8) | (ALFA << 16));
        emitir(SW(T0, S1, VR_VIS_CTRL));
        emitir(SW(T0, S0, PV_VIS_CTRL));
        emitir(ADDI(T0, X0, 1));
        emitir(SW(T0, S0, PV_VIS_EST));

        // bucle principal
        L_bucle = pc_ens;
        L_espera = pc_ens;
        emitir(LW  (T0, S0, PV_VIS_EST));
        emitir(ANDI(T0, T0, 1));
        BEQZ(T0, L_espera);
        emitir(LW  (S11, S0, PV_TICKS));
        emitir(LW  (T0, S1, VR_CUADRO));
        emitir(ADDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_CUADRO));

        // interruptores
        emitir(LW  (T1, S0, PV_SW));
        emitir(ANDI(T2, T1, 3));
        emitir(SLLI(T2, T2, 3));
        LA(T3, T_zonas);
        emitir(ADD (T3, T3, T2));
        emitir(LW  (T4, T3, 0));
        emitir(SW  (T4, S1, VR_ZONA));
        emitir(LW  (T4, T3, 4));
        emitir(SW  (T4, S1, VR_LINEA));
        emitir(SRLI(T2, T1, 2));
        emitir(ANDI(T2, T2, 1));
        emitir(SW  (T2, S1, VR_SENTIDO));
        emitir(SRLI(T2, T1, 4));
        emitir(ANDI(T2, T2, 1));
        emitir(SW  (T2, S1, VR_MODO));
        emitir(LW  (T2, S1, VR_VIS_CTRL));
        LI(T3, 32'hFFDF00FF);
        emitir(AND (T2, T2, T3));
        emitir(SRLI(T4, T1, 3));
        emitir(ANDI(T4, T4, 1));
        emitir(SLLI(T4, T4, 21));
        emitir(OR  (T2, T2, T4));
        emitir(SRLI(T4, T1, 5));
        emitir(ANDI(T4, T4, 7));
        emitir(SLLI(T4, T4, 3));
        emitir(ADDI(T4, T4, UMBRAL));
        emitir(SLLI(T4, T4, 8));
        emitir(OR  (T2, T2, T4));
        emitir(SW  (T2, S1, VR_VIS_CTRL));
        emitir(SRLI(T4, T1, 9));
        emitir(ANDI(T4, T4, 1));
        emitir(SLLI(T4, T4, 20));
        emitir(OR  (T2, T2, T4));
        emitir(SW  (T2, S0, PV_VIS_CTRL));
        // KEY1
        emitir(LW  (T2, S0, PV_KEY));
        emitir(ANDI(T2, T2, 2));
        BNEZ(T2, L_sin_borrar);
        emitir(SW(X0, S1, VR_ALARMA));
        L_sin_borrar = pc_ens;

        // arranque
        emitir(LW(T1, S1, VR_F_AEC));
        BNE_A(T0, T1, L_no_aec);
        emitir(ADDI(A0, X0, 32'h13));
        emitir(ADDI(A1, X0, 32'hE0));
        CALL(L_sccb_escribe);
        TEXTO(T_aec);
        L_no_aec = pc_ens;
        emitir(LW  (T2, S0, PV_SW));
        emitir(ANDI(T2, T2, 512));
        BNEZ(T2, L_aprende);
        emitir(LW(T0, S1, VR_CUADRO));
        emitir(LW(T1, S1, VR_F_APRENDE));
        BLT_A(T1, T0, L_detecta);
        BNE_A(T0, T1, L_aprende);
        emitir(LW  (T2, S1, VR_VIS_CTRL));
        LI(T3, 32'hFFEFFFFF);
        emitir(AND (T2, T2, T3));
        emitir(SW  (T2, S1, VR_VIS_CTRL));
        emitir(SW  (T2, S0, PV_VIS_CTRL));
        TEXTO(T_fondo);
        L_aprende = pc_ens;
        emitir(LW  (T0, S1, VR_CUADRO));
        emitir(ANDI(T0, T0, 1));
        emitir(SLLI(T0, T0, 6));
        emitir(ORI (T0, T0, 32'h100));
        emitir(LW  (T1, S1, VR_CAM_OK));
        emitir(SLLI(T1, T1, 7));
        emitir(OR  (T0, T0, T1));
        emitir(SW  (T0, S0, PV_LEDS));
        J(L_libera);

        // deteccion
        L_detecta = pc_ens;
        // camara movida
        emitir(LW  (T0, S0, PV_VIS_FG));
        LI(T1, 2400);
        BLTU_A(T0, T1, L_quieta);
        emitir(LW  (T2, S1, VR_MOVIDA));
        emitir(ADDI(T2, T2, 1));
        emitir(SW  (T2, S1, VR_MOVIDA));
        emitir(ADDI(T3, X0, MOVIDA_MIN));
        BLT_A(T2, T3, L_libera);
        emitir(SW  (X0, S1, VR_MOVIDA));
        emitir(LW  (T0, S1, VR_REAPRENDIDOS));
        emitir(ADDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_REAPRENDIDOS));
        emitir(LW  (T0, S1, VR_CUADRO));
        emitir(LW  (T1, S1, VR_N_AEC));
        emitir(ADD (T1, T0, T1));
        emitir(SW  (T1, S1, VR_F_AEC));
        emitir(LW  (T1, S1, VR_N_REAP));
        emitir(ADD (T1, T0, T1));
        emitir(SW  (T1, S1, VR_F_APRENDE));
        emitir(LW  (T2, S1, VR_VIS_CTRL));
        LI(T3, 32'h00100000);
        emitir(OR  (T2, T2, T3));
        emitir(SW  (T2, S1, VR_VIS_CTRL));
        emitir(SW  (T2, S0, PV_VIS_CTRL));
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, S1, VR_RECORTE));
        L_mov_lim = pc_ens;
        emitir(SW  (X0, T0, 0));
        emitir(ADDI(T0, T0, 4));
        BLTU_A(T0, T1, L_mov_lim);
        emitir(SW  (X0, S0, PV_COLORES));
        emitir(SW  (X0, S1, VR_NBLOBS));
        emitir(SW  (X0, S1, VR_EN_ZONA));
        emitir(SW  (X0, S1, VR_VISTAS));
        emitir(ADDI(A0, X0, 32'h13));
        emitir(ADDI(A1, X0, 32'hE7));
        CALL(L_sccb_escribe);
        TEXTO(T_movida);
        J(L_aprende);
        L_quieta = pc_ens;
        emitir(SW  (X0, S1, VR_MOVIDA));
        CALL(L_etiquetar);
        emitir(LW  (S9, S1, VR_NBLOBS));
        emitir(ADDI(S10, S1, VR_BLOBS));
        L_cls = pc_ens;
        BEQZ(S9, L_cls_fin);
        emitir(ADDI(SP, SP, -16));
        emitir(SW  (S9, SP, 0));
        emitir(SW  (S10, SP, 4));
        emitir(ADDI(A0, S10, 0));
        CALL(L_recortar);
        emitir(ADDI(A0, S1, VR_RECORTE));
        emitir(LW  (A1, S1, VR_MODO));
        CALL(L_red);
        emitir(LW  (S9, SP, 0));
        emitir(LW  (S10, SP, 4));
        emitir(ADDI(SP, SP, 16));
        emitir(SW  (A0, S10, 24));
        BNEZ(A0, L_cls_np);
        emitir(LW  (T0, S1, VR_PERSONAS));
        emitir(ADDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_PERSONAS));
        J(L_cls_sig);
        L_cls_np = pc_ens;
        emitir(LW  (T0, S1, VR_NO_PERSONA));
        emitir(ADDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_NO_PERSONA));
        L_cls_sig = pc_ens;
        emitir(ADDI(S10, S10, 32));
        emitir(ADDI(S9, S9, -1));
        J(L_cls);
        L_cls_fin = pc_ens;
        CALL(L_seguimiento);
        CALL(L_dibujar);
        emitir(LW  (T0, S0, PV_TICKS));
        emitir(SUB (T0, T0, S11));
        emitir(SW  (T0, S1, VR_CICLOS));
        emitir(LW  (T1, S1, VR_MAX_CICLOS));
        BGEU_A(T1, T0, L_libera);
        emitir(SW  (T0, S1, VR_MAX_CICLOS));
        L_libera = pc_ens;
        emitir(ADDI(T0, X0, 1));
        emitir(SW  (T0, S0, PV_VIS_EST));
        J(L_bucle);

        // subrutinas
        // espera larga
        L_espera_larga = pc_ens;
        emitir(LW  (T4, S1, VR_ESPERA));
        emitir(MUL (A0, A0, T4));
        L_espera_bucle = pc_ens;
        RETARDO_SCCB;
        emitir(ADDI(A0, A0, -1));
        BNEZ(A0, L_espera_bucle);
        RET;

        // imprime
        L_imprime = pc_ens;
        emitir(LBU(T0, A0, 0));
        BEQZ(T0, L_imp_fin);
        emitir(SW  (T0, S0, PV_CONSOLA));
        emitir(ADDI(A0, A0, 1));
        J(L_imprime);
        L_imp_fin = pc_ens;
        RET;

        // hex
        L_hex = pc_ens;
        emitir(SLLI(T1, A1, 2));
        L_hex_bucle = pc_ens;
        emitir(ADDI(T1, T1, -4));
        emitir(SRL (T0, A0, T1));
        emitir(ANDI(T0, T0, 15));
        emitir(ADDI(T2, X0, 10));
        BLT_A(T0, T2, L_hex_num);
        emitir(ADDI(T0, T0, 7));
        L_hex_num = pc_ens;
        emitir(ADDI(T0, T0, 48));
        emitir(SW  (T0, S0, PV_CONSOLA));
        BNEZ(T1, L_hex_bucle);
        RET;

        // SCCB por software
        L_sccb_inicio = pc_ens;
        CAM_LINEAS(1, 1);
        CAM_LINEAS(1, 0);
        CAM_LINEAS(0, 0);
        RET;

        L_sccb_fin = pc_ens;
        CAM_LINEAS(0, 0);
        CAM_LINEAS(1, 0);
        CAM_LINEAS(1, 1);
        RET;

        L_sccb_byte = pc_ens;
        emitir(ADDI(T4, X0, 8));
        L_sb_bit = pc_ens;
        emitir(SRLI(T3, A0, 7));
        emitir(ANDI(T3, T3, 1));
        emitir(XORI(T3, T3, 1));
        emitir(SLLI(T3, T3, 1));
        emitir(ORI (T3, T3, 4));
        emitir(SW  (T3, S0, PV_CAM_SAL));
        RETARDO_SCCB;
        emitir(ORI (T3, T3, 1));
        emitir(SW  (T3, S0, PV_CAM_SAL));
        RETARDO_SCCB;
        emitir(ANDI(T3, T3, -2));
        emitir(SW  (T3, S0, PV_CAM_SAL));
        RETARDO_SCCB;
        emitir(SLLI(A0, A0, 1));
        emitir(ADDI(T4, T4, -1));
        BNEZ(T4, L_sb_bit);
        CAM_LINEAS(0, 1);
        CAM_LINEAS(1, 1);
        CAM_LINEAS(0, 1);
        RET;

        L_sccb_leer = pc_ens;
        emitir(ADDI(T4, X0, 8));
        emitir(ADDI(A0, X0, 0));
        CAM_LINEAS(0, 1);
        L_sl_bit = pc_ens;
        CAM_LINEAS(1, 1);
        emitir(LW  (T3, S0, PV_CAM_ENT));
        emitir(ANDI(T3, T3, 1));
        emitir(SLLI(A0, A0, 1));
        emitir(OR  (A0, A0, T3));
        CAM_LINEAS(0, 1);
        emitir(ADDI(T4, T4, -1));
        BNEZ(T4, L_sl_bit);
        CAM_LINEAS(1, 1);
        CAM_LINEAS(0, 1);
        RET;

        L_sccb_escribe = pc_ens;
        emitir(ADDI(SP, SP, -16));
        emitir(SW  (RA, SP, 0));
        emitir(SW  (A0, SP, 4));
        emitir(SW  (A1, SP, 8));
        CALL(L_sccb_inicio);
        emitir(ADDI(A0, X0, 32'h42));
        CALL(L_sccb_byte);
        emitir(LW(A0, SP, 4));
        CALL(L_sccb_byte);
        emitir(LW(A0, SP, 8));
        CALL(L_sccb_byte);
        CALL(L_sccb_fin);
        emitir(LW  (RA, SP, 0));
        emitir(ADDI(SP, SP, 16));
        RET;

        L_sccb_lee = pc_ens;
        emitir(ADDI(SP, SP, -16));
        emitir(SW  (RA, SP, 0));
        emitir(SW  (A0, SP, 4));
        CALL(L_sccb_inicio);
        emitir(ADDI(A0, X0, 32'h42));
        CALL(L_sccb_byte);
        emitir(LW(A0, SP, 4));
        CALL(L_sccb_byte);
        CALL(L_sccb_fin);
        CALL(L_sccb_inicio);
        emitir(ADDI(A0, X0, 32'h43));
        CALL(L_sccb_byte);
        CALL(L_sccb_leer);
        emitir(SW(A0, SP, 8));
        CALL(L_sccb_fin);
        emitir(LW  (A0, SP, 8));
        emitir(LW  (RA, SP, 0));
        emitir(ADDI(SP, SP, 16));
        RET;

        // etiquetado de manchas
        L_etiquetar = pc_ens;
        emitir(ADDI(T0, S3, 0));
        LI(T1, DIR_ETIQ + 4800);
        L_borra = pc_ens;
        emitir(SW  (X0, T0, 0));
        emitir(SW  (X0, T0, 4));
        emitir(SW  (X0, T0, 8));
        emitir(SW  (X0, T0, 12));
        emitir(ADDI(T0, T0, 16));
        BLTU_A(T0, T1, L_borra);
        emitir(ADDI(S4, X0, 0));
        emitir(ADDI(S10, X0, 0));
        emitir(ADDI(S5, X0, 0));
        emitir(ADDI(S6, X0, 0));
        emitir(ADDI(S7, X0, 0));
        LI(GP, 4800);
        L_scan = pc_ens;
        emitir(ADD (T0, S2, S5));
        emitir(LW  (T6, T0, 0));
        BEQZ(T6, L_scan_sig);
        emitir(ADDI(TP, X0, 0));
        L_scan_b = pc_ens;
        emitir(SLLI(T1, TP, 3));
        emitir(SRL (T1, T6, T1));
        emitir(ANDI(T1, T1, 255));
        BEQZ(T1, L_scan_b_sig);
        emitir(ADD (T2, S5, TP));
        emitir(ADD (T3, S3, T2));
        emitir(LBU (T4, T3, 0));
        BNEZ(T4, L_scan_b_sig);
        emitir(ADDI(T5, X0, 254));
        BGEU_A(S10, T5, L_scan_b_sig);
        emitir(ADDI(S10, S10, 1));
        emitir(ADD (A2, S7, TP));
        emitir(ADDI(A4, A2, 0));
        emitir(ADDI(A3, S6, 0));
        emitir(ADDI(A5, S6, 0));
        emitir(ADDI(A6, X0, 0));
        emitir(SB  (S10, T3, 0));
        LI(S8, DIR_PILA_FF);
        LI(A7, DIR_PILA_FF);
        LI(S9, DIR_PILA_FF + 2044);
        emitir(SLLI(T0, S6, 8));
        emitir(OR  (T0, T0, A2));
        emitir(SH  (T0, S8, 0));
        emitir(ADDI(S8, S8, 2));
        L_ff = pc_ens;
        BEQ_A(S8, A7, L_ff_fin);
        emitir(ADDI(S8, S8, -2));
        emitir(LHU (T0, S8, 0));
        emitir(ANDI(T1, T0, 255));
        emitir(SRLI(T2, T0, 8));
        emitir(ADDI(A6, A6, 1));
        emitir(MIN (A2, A2, T1));
        emitir(MAX (A4, A4, T1));
        emitir(MIN (A3, A3, T2));
        emitir(MAX (A5, A5, T2));
        emitir(SLLI(T3, T2, 6));
        emitir(SLLI(T4, T2, 4));
        emitir(ADD (T3, T3, T4));
        emitir(ADD (T3, T3, T1));
        emitir(BEQ (T1, X0, 52));
        VECINO(-1, -1);
        emitir(ADDI(A1, X0, 79));
        emitir(BEQ (T1, A1, 52));
        VECINO(1, 1);
        emitir(BEQ (T2, X0, 52));
        VECINO(-80, -256);
        emitir(ADDI(A1, X0, 59));
        emitir(BEQ (T2, A1, 52));
        VECINO(80, 256);
        J(L_ff);
        L_ff_fin = pc_ens;
        emitir(ADDI(T0, X0, AREA_MIN));
        BLT_A(A6, T0, L_scan_b_sig);
        emitir(ADDI(T0, X0, MAX_BLOBS));
        BGEU_A(S4, T0, L_scan_b_sig);
        emitir(SLLI(T0, S4, 5));
        emitir(ADD (T0, T0, S1));
        emitir(ADDI(T0, T0, VR_BLOBS));
        emitir(SW  (A2, T0, 0));
        emitir(SW  (A3, T0, 4));
        emitir(SW  (A4, T0, 8));
        emitir(SW  (A5, T0, 12));
        emitir(SW  (A6, T0, 16));
        emitir(SW  (S10, T0, 20));
        emitir(SW  (X0, T0, 24));
        emitir(SW  (X0, T0, 28));
        emitir(ADDI(S4, S4, 1));
        L_scan_b_sig = pc_ens;
        emitir(ADDI(TP, TP, 1));
        emitir(ADDI(T0, X0, 4));
        BLT_A(TP, T0, L_scan_b);
        L_scan_sig = pc_ens;
        emitir(ADDI(S5, S5, 4));
        emitir(ADDI(S7, S7, 4));
        emitir(ADDI(T0, X0, 80));
        BNE_A(S7, T0, L_scan_cont);
        emitir(ADDI(S7, X0, 0));
        emitir(ADDI(S6, S6, 1));
        L_scan_cont = pc_ens;
        BLT_A(S5, GP, L_scan);
        emitir(SW(S4, S1, VR_NBLOBS));
        RET;

        // recorte 16 x 32
        L_recortar = pc_ens;
        emitir(LW  (A2, A0, 0));
        emitir(LW  (A3, A0, 4));
        emitir(LW  (A4, A0, 8));
        emitir(LW  (A5, A0, 12));
        emitir(LW  (A6, A0, 20));
        emitir(SUB (T0, A4, A2));
        emitir(ADDI(T0, T0, 1));
        emitir(SLLI(T0, T0, 1));
        emitir(SUB (T1, A5, A3));
        emitir(ADDI(T1, T1, 1));
        emitir(MAX (S4, T0, T1));
        emitir(ADD (T2, A2, A4));
        emitir(SRAI(T2, T2, 1));
        emitir(SRAI(T3, S4, 2));
        emitir(SUB (S5, T2, T3));
        emitir(ADD (T2, A3, A5));
        emitir(SRAI(T2, T2, 1));
        emitir(SRAI(T3, S4, 1));
        emitir(SUB (S6, T2, T3));
        emitir(ADDI(S7, S1, VR_RECORTE));
        emitir(ADDI(S8, X0, 0));
        emitir(ADDI(S9, X0, 0));
        emitir(ADDI(A7, X0, 60));
        emitir(ADDI(GP, X0, 80));
        L_rc_fila = pc_ens;
        emitir(ANDI(T0, S8, 1));
        BNEZ(T0, L_rc_impar);
        emitir(ADDI(S10, X0, 0));
        emitir(ADDI(T5, X0, 1));
        J(L_rc_mb);
        L_rc_impar = pc_ens;
        emitir(LUI(T5, 32'h00010000));
        L_rc_mb = pc_ens;
        emitir(SRAI(T0, S9, 5));
        emitir(ADD (T0, T0, S6));
        BGEU_A(T0, A7, L_rc_fila_fin);
        emitir(SLLI(T1, T0, 6));
        emitir(SLLI(T2, T0, 4));
        emitir(ADD (T1, T1, T2));
        emitir(ADD (T1, T1, S3));
        emitir(ADDI(T2, X0, 0));
        emitir(ADDI(T3, X0, 0));
        L_rc_col = pc_ens;
        emitir(SRAI(T4, T3, 5));
        emitir(ADD (T4, T4, S5));
        BGEU_A(T4, GP, L_rc_col_sig);
        emitir(ADD (T6, T1, T4));
        emitir(LBU (T6, T6, 0));
        BNE_A(T6, A6, L_rc_col_sig);
        emitir(OR  (S10, S10, T5));
        L_rc_col_sig = pc_ens;
        emitir(SLLI(T5, T5, 1));
        emitir(ADD (T3, T3, S4));
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T6, X0, 16));
        BLT_A(T2, T6, L_rc_col);
        L_rc_fila_fin = pc_ens;
        emitir(ANDI(T0, S8, 1));
        BEQZ(T0, L_rc_par);
        emitir(SRLI(T0, S8, 1));
        emitir(SLLI(T0, T0, 2));
        emitir(ADD (T0, T0, S7));
        emitir(SW  (S10, T0, 0));
        L_rc_par = pc_ens;
        emitir(ADD (S9, S9, S4));
        emitir(ADDI(S8, S8, 1));
        emitir(ADDI(T0, X0, 32));
        BLT_A(S8, T0, L_rc_fila);
        RET;

        // red binaria
        L_red = pc_ens;
        emitir(ADDI(A2, A0, 0));
        LA(T1, T_w1);
        LA(A3, T_t1);
        emitir(ADDI(A4, X0, 0));
        emitir(ADDI(A5, X0, 0));
        emitir(ADDI(TP, X0, 0));
        BNEZ(A1, L_red_rv);
        // con XNOR y CPOP
        L_rx_neur = pc_ens;
        emitir(ADDI(T0, X0, 0));
        for (vw = 0; vw < 16; vw = vw + 1) begin
            emitir(LW (T2, A2, 4 * vw));
            emitir(LW (T5, T1, 4 * vw));
            emitir(XNOR(T2, T2, T5));
            emitir(CPOP(T2, T2));
            emitir(ADD(T0, T0, T2));
        end
        emitir(ADDI(T1, T1, 64));
        UMBRAL_Y_BIT;
        emitir(ADDI(T4, X0, 64));
        BLT_A(TP, T4, L_rx_neur);
        J(L_red_salida);
        // sin CPOP
        L_red_rv = pc_ens;
        LI(S4, 32'h55555555);
        LI(S5, 32'h33333333);
        LI(S6, 32'h0F0F0F0F);
        LI(S7, 32'h01010101);
        L_rr_neur = pc_ens;
        emitir(ADDI(T0, X0, 0));
        for (vw = 0; vw < 16; vw = vw + 1) begin
            emitir(LW  (T2, A2, 4 * vw));
            emitir(LW  (T5, T1, 4 * vw));
            emitir(XOR (T2, T2, T5));
            emitir(XORI(T2, T2, -1));
            emitir(SRLI(T6, T2, 1));
            emitir(AND (T6, T6, S4));
            emitir(SUB (T2, T2, T6));
            emitir(SRLI(T6, T2, 2));
            emitir(AND (T6, T6, S5));
            emitir(AND (T2, T2, S5));
            emitir(ADD (T2, T2, T6));
            emitir(SRLI(T6, T2, 4));
            emitir(ADD (T2, T2, T6));
            emitir(AND (T2, T2, S6));
            emitir(MUL (T2, T2, S7));
            emitir(SRLI(T2, T2, 24));
            emitir(ADD (T0, T0, T2));
        end
        emitir(ADDI(T1, T1, 64));
        UMBRAL_Y_BIT;
        emitir(ADDI(T4, X0, 64));
        BLT_A(TP, T4, L_rr_neur);
        // capa de salida
        L_red_salida = pc_ens;
        LA(T1, T_w2);
        LA(T3, T_b2);
        emitir(ADDI(A6, X0, 0));
        emitir(ADDI(A7, S1, VR_PUNT));
        emitir(LUI (S8, 32'h80000000));
        emitir(ADDI(S9, X0, 0));
        L_rs_k = pc_ens;
        emitir(LW  (T0, T3, 0));
        emitir(ADDI(T2, A4, 0));
        emitir(ADDI(T4, X0, 0));
        L_rs_j = pc_ens;
        emitir(ANDI(T5, T2, 1));
        BEQZ(T5, L_rs_j0);
        emitir(ADD (T6, T1, T4));
        emitir(LB  (T6, T6, 0));
        emitir(ADD (T0, T0, T6));
        L_rs_j0 = pc_ens;
        emitir(SRLI(T2, T2, 1));
        emitir(ADDI(T4, T4, 1));
        emitir(ADDI(T5, X0, 32));
        BNE_A(T4, T5, L_rs_j1);
        emitir(ADDI(T2, A5, 0));
        L_rs_j1 = pc_ens;
        emitir(ADDI(T5, X0, 64));
        BLT_A(T4, T5, L_rs_j);
        emitir(SW  (T0, A7, 0));
        emitir(ADDI(A7, A7, 4));
        emitir(XOP (XA_SGT, T5, T0, S8));
        BEQZ(T5, L_rs_nomax);
        MV(S8, T0);
        MV(S9, A6);
        L_rs_nomax = pc_ens;
        emitir(ADDI(T1, T1, 64));
        emitir(ADDI(T3, T3, 4));
        emitir(ADDI(A6, A6, 1));
        emitir(ADDI(T5, X0, 3));
        BLT_A(A6, T5, L_rs_k);
        MV(A0, S9);
        RET;

        // seguimiento
        L_seguimiento = pc_ens;
        emitir(ADDI(SP, SP, -16));
        emitir(SW  (RA, SP, 0));
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, X0, MAX_PISTAS));
        L_sg_des = pc_ens;
        emitir(LW  (T2, T0, 28));
        emitir(ANDI(T2, T2, -3));
        emitir(SW  (T2, T0, 28));
        emitir(ADDI(T0, T0, 32));
        emitir(ADDI(T1, T1, -1));
        BNEZ(T1, L_sg_des);
        emitir(SW  (X0, S1, VR_EN_ZONA));
        emitir(SW  (X0, S1, VR_VISTAS));
        // dos pasadas
        emitir(ADDI(S10, X0, 0));
        L_sg_pasada = pc_ens;
        emitir(LW  (S4, S1, VR_NBLOBS));
        emitir(ADDI(S5, S1, VR_BLOBS));
        L_sg_blob = pc_ens;
        BEQZ(S4, L_sg_pasada_fin);
        emitir(LW  (T0, S5, 24));
        emitir(SLTU(T0, X0, T0));
        BNE_A(T0, S10, L_sg_blob_sig);
        emitir(LW  (T0, S5, 0));
        emitir(LW  (T1, S5, 8));
        emitir(ADD (S6, T0, T1));
        emitir(SRLI(S6, S6, 1));
        emitir(LW  (S7, S5, 12));
        emitir(ADDI(S8, X0, 0));
        emitir(ADDI(S9, X0, DIST_MAX));
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, X0, MAX_PISTAS));
        L_sg_busca = pc_ens;
        emitir(LW  (T2, T0, 0));
        BEQZ(T2, L_sg_busca_sig);
        emitir(LW  (T2, T0, 28));
        emitir(ANDI(T2, T2, 2));
        BNEZ(T2, L_sg_busca_sig);
        emitir(LW  (T2, T0, 8));
        emitir(SUB (T2, T2, S6));
        emitir(XOP (XA_ABS, T2, T2, X0));
        emitir(LW  (T3, T0, 12));
        emitir(SUB (T3, T3, S7));
        emitir(XOP (XA_ABS, T3, T3, X0));
        emitir(ADD (T2, T2, T3));
        BGE_A(T2, S9, L_sg_busca_sig);
        MV(S9, T2);
        MV(S8, T0);
        L_sg_busca_sig = pc_ens;
        emitir(ADDI(T0, T0, 32));
        emitir(ADDI(T1, T1, -1));
        BNEZ(T1, L_sg_busca);
        BNEZ(S8, L_sg_tiene);
        BNEZ(S10, L_sg_blob_sig);
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, X0, MAX_PISTAS));
        L_sg_libre = pc_ens;
        emitir(LW  (T2, T0, 0));
        BEQZ(T2, L_sg_crea);
        emitir(ADDI(T0, T0, 32));
        emitir(ADDI(T1, T1, -1));
        BNEZ(T1, L_sg_libre);
        J(L_sg_blob_sig);
        L_sg_crea = pc_ens;
        MV(S8, T0);
        emitir(SW  (X0, S8, 0));
        emitir(LW  (T2, S1, VR_SIG_ID));
        emitir(SW  (T2, S8, 4));
        emitir(ADDI(T2, T2, 1));
        emitir(SW  (T2, S1, VR_SIG_ID));
        emitir(LW  (T2, S1, VR_LINEA));
        emitir(SLT (T3, S6, T2));
        emitir(XORI(T3, T3, 1));
        emitir(SW  (T3, S8, 16));
        emitir(SW  (X0, S8, 20));
        emitir(SW  (X0, S8, 28));
        L_sg_tiene = pc_ens;
        // voto
        emitir(LW  (T2, S8, 0));
        BNEZ(S10, L_sg_resta);
        emitir(ADDI(T2, T2, 1));
        emitir(ADDI(T3, X0, VOTO_MAX));
        emitir(MIN (T2, T2, T3));
        J(L_sg_votado);
        L_sg_resta = pc_ens;
        emitir(ADDI(T2, T2, -1));
        L_sg_votado = pc_ens;
        emitir(SW  (T2, S8, 0));
        BEQZ(T2, L_sg_blob_sig);
        emitir(SW  (S6, S8, 8));
        emitir(SW  (S7, S8, 12));
        emitir(SW  (X0, S8, 24));
        emitir(LW  (T3, S8, 28));
        emitir(ORI (T3, T3, 2));
        emitir(SW  (T3, S8, 28));
        emitir(ADDI(T3, X0, VOTO_MIN));
        BLT_A(T2, T3, L_sg_blob_sig);
        emitir(LW  (T2, S8, 4));
        emitir(SLLI(T2, T2, 8));
        emitir(ORI (T2, T2, 2));
        emitir(SW  (T2, S5, 28));
        emitir(LW  (T2, S1, VR_VISTAS));
        emitir(ADDI(T2, T2, 1));
        emitir(SW  (T2, S1, VR_VISTAS));
        // cruce de la linea
        emitir(LW  (T2, S1, VR_LINEA));
        emitir(SLT (T3, S6, T2));
        emitir(XORI(T3, T3, 1));
        emitir(LW  (T4, S8, 16));
        BEQ_A(T3, T4, L_sg_zona);
        emitir(SW  (T3, S8, 16));
        BEQZ(T3, L_sg_salida);
        emitir(LW  (T5, S1, VR_ENTRADAS));
        emitir(ADDI(T5, T5, 1));
        emitir(SW  (T5, S1, VR_ENTRADAS));
        emitir(ADDI(A0, X0, 1));
        emitir(LW  (A1, S8, 4));
        CALL(L_evento);
        emitir(LW  (T5, S1, VR_SENTIDO));
        BNEZ(T5, L_sg_zona);
        J(L_sg_cruce_prohibido);
        L_sg_salida = pc_ens;
        emitir(LW  (T5, S1, VR_SALIDAS));
        emitir(ADDI(T5, T5, 1));
        emitir(SW  (T5, S1, VR_SALIDAS));
        emitir(ADDI(A0, X0, 2));
        emitir(LW  (A1, S8, 4));
        CALL(L_evento);
        emitir(LW  (T5, S1, VR_SENTIDO));
        BEQZ(T5, L_sg_zona);
        L_sg_cruce_prohibido = pc_ens;
        emitir(LW  (T5, S1, VR_ALARMA));
        emitir(ORI (T5, T5, 32'h21));
        emitir(SW  (T5, S1, VR_ALARMA));
        emitir(ADDI(A0, X0, 3));
        emitir(LW  (A1, S8, 4));
        CALL(L_evento);
        // zona
        L_sg_zona = pc_ens;
        emitir(LW  (T2, S1, VR_ZONA));
        emitir(ANDI(T3, T2, 255));
        BLT_A(S6, T3, L_sg_fuera);
        emitir(SRLI(T3, T2, 16));
        emitir(ANDI(T3, T3, 255));
        BLT_A(T3, S6, L_sg_fuera);
        emitir(SRLI(T3, T2, 8));
        emitir(ANDI(T3, T3, 255));
        BLT_A(S7, T3, L_sg_fuera);
        emitir(SRLI(T3, T2, 24));
        BLT_A(T3, S7, L_sg_fuera);
        emitir(LW  (T3, S1, VR_EN_ZONA));
        emitir(ADDI(T3, T3, 1));
        emitir(SW  (T3, S1, VR_EN_ZONA));
        emitir(LW  (T3, S5, 28));
        emitir(ORI (T3, T3, 1));
        emitir(SW  (T3, S5, 28));
        emitir(LW  (T3, S8, 20));
        emitir(ADDI(T3, T3, 1));
        emitir(SW  (T3, S8, 20));
        emitir(ADDI(T4, X0, PERM_MIN));
        BNE_A(T3, T4, L_sg_blob_sig);
        emitir(LW  (T5, S1, VR_ALARMA));
        emitir(ORI (T5, T5, 32'h11));
        emitir(SW  (T5, S1, VR_ALARMA));
        emitir(ADDI(A0, X0, 4));
        emitir(LW  (A1, S8, 4));
        CALL(L_evento);
        J(L_sg_blob_sig);
        L_sg_fuera = pc_ens;
        emitir(SW  (X0, S8, 20));
        L_sg_blob_sig = pc_ens;
        emitir(ADDI(S5, S5, 32));
        emitir(ADDI(S4, S4, -1));
        J(L_sg_blob);
        L_sg_pasada_fin = pc_ens;
        emitir(ADDI(S10, S10, 1));
        emitir(ADDI(T0, X0, 2));
        BLT_A(S10, T0, L_sg_pasada);
        L_sg_perdidas = pc_ens;
        emitir(ADDI(T0, S1, VR_PISTAS));
        emitir(ADDI(T1, X0, MAX_PISTAS));
        L_sg_p = pc_ens;
        emitir(LW  (T2, T0, 0));
        BEQZ(T2, L_sg_p_sig);
        emitir(LW  (T2, T0, 28));
        emitir(ANDI(T2, T2, 2));
        BNEZ(T2, L_sg_p_sig);
        emitir(LW  (T2, T0, 24));
        emitir(ADDI(T2, T2, 1));
        emitir(SW  (T2, T0, 24));
        emitir(ADDI(T3, X0, 5));
        BLT_A(T2, T3, L_sg_p_sig);
        emitir(SW  (X0, T0, 0));
        L_sg_p_sig = pc_ens;
        emitir(ADDI(T0, T0, 32));
        emitir(ADDI(T1, T1, -1));
        BNEZ(T1, L_sg_p);
        emitir(LW  (RA, SP, 0));
        emitir(ADDI(SP, SP, 16));
        RET;

        // evento
        L_evento = pc_ens;
        emitir(ADDI(SP, SP, -16));
        emitir(SW  (RA, SP, 0));
        emitir(SW  (A0, SP, 4));
        emitir(SW  (A1, SP, 8));
        emitir(LW  (T0, S1, VR_EVENTOS));
        emitir(ANDI(T1, T0, 31));
        emitir(SLLI(T1, T1, 4));
        emitir(ADD (T1, T1, S1));
        emitir(ADDI(T1, T1, VR_EVENT_LOG));
        emitir(SW  (A0, T1, 0));
        emitir(SW  (A1, T1, 4));
        emitir(LW  (T2, S1, VR_CUADRO));
        emitir(SW  (T2, T1, 8));
        emitir(LW  (T2, S0, PV_TICKS));
        emitir(SW  (T2, T1, 12));
        emitir(ADDI(T0, T0, 1));
        emitir(SW  (T0, S1, VR_EVENTOS));
        emitir(LW  (T0, SP, 4));
        emitir(SLLI(T0, T0, 2));
        LA(T1, T_tab_eventos);
        emitir(ADD (T1, T1, T0));
        emitir(LW  (A0, T1, 0));
        CALL(L_imprime);
        TEXTO(T_id);
        emitir(LW  (A0, SP, 8));
        emitir(ADDI(A1, X0, 2));
        CALL(L_hex);
        TEXTO(T_cuadro);
        emitir(LW  (A0, S1, VR_CUADRO));
        emitir(ADDI(A1, X0, 4));
        CALL(L_hex);
        TEXTO(T_nl);
        emitir(LW  (RA, SP, 0));
        emitir(ADDI(SP, SP, 16));
        RET;

        // dibujar
        L_dibujar = pc_ens;
        emitir(LW  (T0, S1, VR_ZONA));
        emitir(SW  (T0, S0, PV_ZONA));
        emitir(LW  (T0, S1, VR_LINEA));
        emitir(ORI (T0, T0, 256));
        emitir(SW  (T0, S0, PV_LINEA));
        emitir(LW  (T1, S1, VR_NBLOBS));
        emitir(ADDI(T2, S1, VR_BLOBS));
        emitir(ADDI(T3, S0, PV_CAJA0));
        emitir(ADDI(T4, X0, 0));
        emitir(ADDI(T5, X0, 0));
        L_dj_c = pc_ens;
        BGE_A(T5, T1, L_dj_fin);
        emitir(LW  (T0, T2, 0));
        emitir(LW  (T6, T2, 4));
        emitir(SLLI(T6, T6, 8));
        emitir(OR  (T0, T0, T6));
        emitir(LW  (T6, T2, 8));
        emitir(SLLI(T6, T6, 16));
        emitir(OR  (T0, T0, T6));
        emitir(LW  (T6, T2, 12));
        emitir(SLLI(T6, T6, 24));
        emitir(OR  (T0, T0, T6));
        emitir(SW  (T0, T3, 0));
        emitir(LW  (T6, T2, 28));
        emitir(ADDI(A0, X0, 3));
        emitir(ANDI(A1, T6, 2));
        BEQZ(A1, L_dj_col);
        emitir(ANDI(T6, T6, 1));
        emitir(ADDI(A0, T6, 1));
        L_dj_col = pc_ens;
        emitir(SLLI(A1, T5, 1));
        emitir(SLL (A0, A0, A1));
        emitir(OR  (T4, T4, A0));
        emitir(ADDI(T2, T2, 32));
        emitir(ADDI(T3, T3, 4));
        emitir(ADDI(T5, T5, 1));
        J(L_dj_c);
        L_dj_fin = pc_ens;
        emitir(SW  (T4, S0, PV_COLORES));
        emitir(LW  (T0, S1, VR_ALARMA));
        emitir(ANDI(T0, T0, 1));
        BEQZ(T0, L_dj_sin);
        emitir(ADDI(T0, X0, 3));
        L_dj_sin = pc_ens;
        // barra de estado
        emitir(LW  (T1, S1, VR_VISTAS));
        emitir(ADDI(T2, X0, 9));
        emitir(MINU(T1, T1, T2));
        emitir(SLLI(T1, T1, 8));
        emitir(OR  (T0, T0, T1));
        emitir(LW  (T1, S1, VR_EVENTOS));
        emitir(ADDI(T2, X0, 100));
        emitir(REMU(T1, T1, T2));
        emitir(ADDI(T2, X0, 10));
        emitir(DIVU(T3, T1, T2));
        emitir(REMU(T1, T1, T2));
        emitir(SLLI(T3, T3, 4));
        emitir(OR  (T1, T1, T3));
        emitir(SLLI(T1, T1, 16));
        emitir(OR  (T0, T0, T1));
        emitir(SW  (T0, S0, PV_LETRERO));
        emitir(LW  (T0, S1, VR_ENTRADAS));
        emitir(ANDI(T0, T0, 255));
        emitir(SLLI(T0, T0, 16));
        emitir(LW  (T1, S1, VR_SALIDAS));
        emitir(ANDI(T1, T1, 255));
        emitir(SLLI(T1, T1, 8));
        emitir(OR  (T0, T0, T1));
        emitir(LW  (T1, S1, VR_EN_ZONA));
        emitir(ANDI(T1, T1, 15));
        emitir(SLLI(T1, T1, 4));
        emitir(OR  (T0, T0, T1));
        emitir(LW  (T1, S1, VR_NBLOBS));
        emitir(ANDI(T1, T1, 15));
        emitir(OR  (T0, T0, T1));
        emitir(SW  (T0, S0, PV_HEX));
        emitir(LW  (T0, S1, VR_ALARMA));
        emitir(ANDI(T0, T0, 1));
        emitir(LW  (T1, S1, VR_CUADRO));
        emitir(SRLI(T1, T1, 1));
        emitir(AND (T1, T1, T0));
        emitir(SLLI(T1, T1, 9));
        emitir(OR  (T0, T0, T1));
        emitir(LW  (T1, S1, VR_CAM_OK));
        emitir(SLLI(T1, T1, 7));
        emitir(OR  (T0, T0, T1));
        emitir(LW  (T1, S1, VR_CUADRO));
        emitir(ANDI(T1, T1, 1));
        emitir(SLLI(T1, T1, 6));
        emitir(OR  (T0, T0, T1));
        emitir(SW  (T0, S0, PV_LEDS));
        RET;

        // datos
        T_sccb = pc_ens;
`include "tabla_camara.vh"
        emitir(32'hFFFFFFFF);
        T_sccb_sim = pc_ens;
        emitir(32'h1101);
        emitir(32'h6B4A);
        emitir(32'h1200);
        emitir(32'h3A04);
        emitir(32'h3DC0);
        emitir(32'h40C0);
        emitir(32'h0C04);
        emitir(32'h3E19);
        emitir(32'h1500);
        emitir(32'hFFFFFFFF);

        T_zonas = pc_ens;
        emitir({8'd56, 8'd76, 8'd8,  8'd44}); emitir(32'd40);
        emitir({8'd56, 8'd36, 8'd8,  8'd4});  emitir(32'd40);
        emitir({8'd56, 8'd56, 8'd20, 8'd24}); emitir(32'd20);
        emitir({8'd59, 8'd79, 8'd0,  8'd40}); emitir(32'd40);

        T_w1 = pc_ens;
        for (vw = 0; vw < 1024; vw = vw + 1) emitir(VIG_W1[vw]);
        T_t1 = pc_ens;
        for (vw = 0; vw < 64; vw = vw + 1) emitir(VIG_T1[vw]);
        T_w2 = pc_ens;
        for (vw = 0; vw < 192; vw = vw + 4)
            emitir_bytes(VIG_W2[vw], VIG_W2[vw + 1], VIG_W2[vw + 2], VIG_W2[vw + 3]);
        T_b2 = pc_ens;
        for (vw = 0; vw < 3; vw = vw + 1) emitir(VIG_B2[vw]);
        T_prueba = pc_ens;
        for (vw = 0; vw < 48; vw = vw + 1) emitir(VIG_PRUEBA[vw]);

        T_tab_eventos = pc_ens;
        emitir(T_ev0); emitir(T_ev1); emitir(T_ev2); emitir(T_ev3); emitir(T_ev4);

        T_titulo    = pc_ens; CADENA("NEURA-32 VIGIA: vigilancia perimetral\n");
        T_camara    = pc_ens; CADENA("CAMARA PID=");
        T_ver       = pc_ens; CADENA(" VER=");
        T_nl        = pc_ens; CADENA("\n");
        T_error_cam = pc_ens; CADENA("ERROR: la camara no responde\n");
        T_cfg       = pc_ens; CADENA("CAMARA CONFIGURADA\n");
        T_red_x     = pc_ens; CADENA("RED BINARIA  CON CPOP=");
        T_red_r     = pc_ens; CADENA(" CICLOS  SIN CPOP=");
        T_ciclos_nl = pc_ens; CADENA(" CICLOS\n");
        T_autoprueba = pc_ens; CADENA("AUTOPRUEBA DE LA RED: PERSONAS=");
        T_de3       = pc_ens; CADENA(" DE 3\n");
        T_movida    = pc_ens; CADENA("CAMARA MOVIDA: APRENDO EL FONDO\n");
        T_aec       = pc_ens; CADENA("EXPOSICION FIJA\n");
        T_fondo     = pc_ens; CADENA("FONDO APRENDIDO: VIGILANDO\n");
        T_id        = pc_ens; CADENA(" ID=");
        T_cuadro    = pc_ens; CADENA(" CUADRO=");
        T_ev0       = pc_ens; CADENA("?");
        T_ev1       = pc_ens; CADENA("ENTRADA");
        T_ev2       = pc_ens; CADENA("SALIDA");
        T_ev3       = pc_ens; CADENA("INTRUSO: CRUCE PROHIBIDO");
        T_ev4       = pc_ens; CADENA("INTRUSO: EN ZONA");
        V_fin = pc_ens;
    end
endtask
