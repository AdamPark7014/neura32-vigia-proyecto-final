`timescale 1ns / 1ps
// ============================================================
// TESTBENCH DEL SISTEMA COMPLETO — NEURA-32 VIGIA (PROGRAMA = 3)
//
// SoC + modelo de la camara OV7670. La camara simulada entrega 160x120
// (en la placa son 640x480; la deteccion es de 80x60 en ambos casos).
// Guion:
//   1. arranque: el programa configura la camara por SCCB, la identifica,
//      mide la red y aprende el fondo vacio
//   2. un perro cruza de derecha a izquierda por la zona: NO debe haber
//      alarma ni conteo (la red debe decir "objeto o animal")
//   3. una persona entra por la izquierda, cruza la linea en el sentido
//      prohibido y se queda en la zona: entrada = 1, alarma por cruce y
//      por zona
// Comprueba ademas la red del programa contra un modelo de referencia en
// Verilog y guarda tb/salidas/*.ppm|pgm (monitor VGA, mascara, video).
// Al final imprime: PRUEBAS: n  ERRORES: 0
// ============================================================
module tb_vigia;

    reg clk50 = 1'b0;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #10 clk50 = ~clk50;                 // 50 MHz, el reloj de la placa
    always @(posedge clk50) clk <= ~clk;       // 25 MHz, dividido entre 2 como en top_vigia

    reg  [9:0]  sw  = 10'b00_0000_1000;        // SW3 = ver la silueta en el monitor
    reg  [1:0]  key = 2'b11;
    wire [9:0]  leds;
    wire [23:0] hex;
    wire [7:0]  consola_char;
    wire        consola_we, fin, instr_ilegal;
    wire [31:0] control;
    wire [31:0] ciclos, instret;

    wire        cam_pclk, cam_href, cam_vsync, cam_sioc, cam_reset_n, cam_pwdn;
    wire [7:0]  cam_d;
    wire        cam_siod;
    pullup (cam_siod);                         // resistencia de 4.7 k a 3.3 V

    wire [3:0]  vga_r, vga_g, vga_b;
    wire        vga_hs, vga_vs;

    generador_programa #(.PROGRAMA(3)) gen ();

    soc_neura32 #(
        .ARCHIVO_PROGRAMA("fpga/programa_vigia.txt"), .SIMULACION(1),
        .VID_ANCHO(160), .VID_ALTO(120), .BLOQUE_LOG2(1), .VGA_ESCALA_LOG2(2)
    ) dut (
        .clk(clk), .clk50(clk50), .rst_ext(rst),
        .interruptores(sw), .botones(key),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we), .control(control),
        .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync), .cam_d(cam_d),
        .cam_sioc(cam_sioc), .cam_siod(cam_siod), .cam_reset_n(cam_reset_n), .cam_pwdn(cam_pwdn),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs),
        .fin(fin), .instr_ilegal(instr_ilegal),
        .ciclos(ciclos), .instret(instret)
    );

    // sensor de 320 x 240 que el programa pone en modo reducido: entrega 160 x 120.
    // El borrado vertical se alarga para que un cuadro dure 400 000 ciclos: la mitad de lo
    // que dura en la placa (800 000 ciclos a 31 cuadros por segundo), para no alargar la prueba.
    modelo_ov7670 #(.ANCHO(320), .ALTO(240), .V_BLANCO(419)) camara (
        .xclk(clk), .resetb(cam_reset_n), .pwdn(cam_pwdn),
        .pclk(cam_pclk), .href(cam_href), .vsync(cam_vsync), .d(cam_d),
        .sioc(cam_sioc), .siod(cam_siod)
    );

    // el programa sale de fpga/programa_vigia.txt (lo escribe tb/generar_rom.v)

    // ---- variables del programa en la RAM ----
    localparam VR_PID = 8, VR_VER = 12, VR_CUADRO = 16, VR_ENTRADAS = 20, VR_SALIDAS = 24;
    localparam VR_ALARMA = 28, VR_NBLOBS = 32, VR_EN_ZONA = 36, VR_BENCH_X = 44, VR_BENCH_R = 48;
    localparam VR_NO_PERSONA = 72, VR_PERSONAS = 76, VR_EVENTOS = 80, VR_CLASE_PRUEBA = 84;
    localparam VR_CICLOS = 88, VR_MAX_CICLOS = 92, VR_PUNT = 96, VR_RECORTE = 32'h400, VR_LOG = 32'h500;

    function [31:0] ram;
        input integer desp;
        ram = dut.cpu.palabra(desp / 4);
    endfunction

    // ---- consola ----
    always @(posedge clk) if (consola_we) begin
        $write("%c", consola_char);
        if (consola_char == 8'h0A) $fflush;
    end

    // ---- avance: una linea por cada mascara que procesa el programa ----
    integer ultimo_cuadro = 0;
    always @(posedge clk) if (!rst && dut.cpu.palabra(VR_CUADRO / 4) != ultimo_cuadro) begin
        ultimo_cuadro = dut.cpu.palabra(VR_CUADRO / 4);
        $display("[%t] mascara %0d: manchas=%0d personas=%0d no persona=%0d en zona=%0d alarma=%02h ciclos=%0d",
                 $time, ultimo_cuadro, ram(VR_NBLOBS), ram(VR_PERSONAS), ram(VR_NO_PERSONA),
                 ram(VR_EN_ZONA), ram(VR_ALARMA), ram(VR_CICLOS));
        $fflush;
    end

    integer ilegales = 0;
    always @(posedge clk) begin
        if (!rst && instr_ilegal) ilegales = ilegales + 1;
    end

    // ---- modelo de referencia de la red binaria ----
    `include "pesos_vigia.vh"
    integer ref_punt [0:2];

    function integer popcount32;
        input [31:0] v;
        integer b;
        begin
            popcount32 = 0;
            for (b = 0; b < 32; b = b + 1) popcount32 = popcount32 + v[b];
        end
    endfunction

    task red_referencia;                       // sobre el recorte que dejo el programa en la RAM
        integer j, w, k, cuenta;
        reg [63:0] a;
        begin
            for (j = 0; j < 64; j = j + 1) begin
                cuenta = 0;
                for (w = 0; w < 16; w = w + 1)
                    cuenta = cuenta + popcount32(~(ram(VR_RECORTE + 4 * w) ^ VIG_W1[16 * j + w]));
                a[j] = (cuenta >= VIG_T1[j]);
            end
            for (k = 0; k < 3; k = k + 1) begin
                ref_punt[k] = VIG_B2[k];
                for (j = 0; j < 64; j = j + 1)
                    if (a[j]) ref_punt[k] = ref_punt[k] + VIG_W2[64 * k + j];
            end
        end
    endtask

    // ---- captura de la pantalla VGA ----
    reg [9:0]  h1, h2, h3, v1, v2, v3;
    reg        a1, a2, a3;
    reg [11:0] pantalla [0:640*480-1];
    reg        capturando = 1'b0, captura_lista = 1'b0;

    always @(posedge clk) begin
        h1 <= dut.vision.h; v1 <= dut.vision.v; a1 <= dut.vision.activo;
        h2 <= h1;           v2 <= v1;           a2 <= a1;
        h3 <= h2;           v3 <= v2;           a3 <= a2;          // vga_draw tarda 3 ciclos
    end
    always @(posedge clk) begin
        #1;
        if (capturando && a3) begin
            pantalla[v3 * 640 + h3] = {vga_r, vga_g, vga_b};
            if (h3 == 639 && v3 == 479) begin capturando = 1'b0; captura_lista = 1'b1; end
        end
    end

    integer f, x, y, idx;
    task guardar_imagenes;
        reg [31:0] p;
        begin
            f = $fopen("tb/salidas/vga_vigia.ppm", "w");
            $fwrite(f, "P3\n640 480\n15\n");
            for (idx = 0; idx < 640 * 480; idx = idx + 1)
                $fwrite(f, "%0d %0d %0d\n", pantalla[idx][11:8], pantalla[idx][7:4], pantalla[idx][3:0]);
            $fclose(f);
            f = $fopen("tb/salidas/mascara_80x60.pgm", "w");
            $fwrite(f, "P2\n80 60\n1\n");
            for (idx = 0; idx < 4800; idx = idx + 1) begin
                p = dut.vision.mem_mascara.memoria[(dut.vision.banco_lec ? 1200 : 0) + idx / 4];
                $fwrite(f, "%0d\n", p[8 * (idx % 4)] ? 1 : 0);
            end
            $fclose(f);
            f = $fopen("tb/salidas/video_160x120.pgm", "w");
            $fwrite(f, "P2\n160 120\n63\n");
            for (idx = 0; idx < 160 * 120; idx = idx + 1)
                $fwrite(f, "%0d\n", dut.vision.mem_y.ram_data[idx]);
            $fclose(f);
        end
    endtask

    // ---- comprobaciones ----
    integer pruebas = 0, errores = 0;
    task revisar;
        input condicion;
        input [8*64-1:0] nombre;
        begin
            pruebas = pruebas + 1;
            if (condicion) $display("  ok    %0s", nombre);
            else begin errores = errores + 1; $display("  FALLA %0s", nombre); end
        end
    endtask

    integer eventos_perro, alarma_perro, no_persona_perro, personas_perro, cuadro_inicio_persona;
    integer k2;

    initial begin
        #(40 * 75_000_000);                    // 3 s de simulacion como limite
        $display("TIEMPO AGOTADO");
        $finish;
    end

    initial begin
        $timeformat(-3, 2, " ms", 10);
        cargar_pesos_vigia;
        $display("=== NEURA-32 VIGIA: sistema completo con camara OV7670 simulada ===");
        $display("ROM: %0d palabras (codigo %0d, tablas y pesos %0d)",
                 gen.V_fin / 4, gen.T_sccb / 4, (gen.V_fin - gen.T_sccb) / 4);
        repeat (5) @(posedge clk);
        rst = 1'b0;

        // ---------------- 1. arranque y aprendizaje del fondo ----------------
        while (ram(VR_CUADRO) < 6) @(posedge clk);
        $display("[%t] arranque listo: cuadro %0d, %0d escrituras y %0d lecturas SCCB",
                 $time, ram(VR_CUADRO), camara.escrituras, camara.lecturas);

        // ---------------- 2. un perro cruza la zona ----------------
        camara.escena = 2'd1; camara.t_escena = 0;
        $display("[%t] escena: PERRO cruzando de derecha a izquierda", $time);
        repeat (15) @(posedge cam_vsync);
        eventos_perro    = ram(VR_EVENTOS);
        alarma_perro     = ram(VR_ALARMA);
        no_persona_perro = ram(VR_NO_PERSONA);
        personas_perro   = ram(VR_PERSONAS);
        camara.escena = 2'd0;
        repeat (6) @(posedge cam_vsync);

        // ---------------- 3. una persona entra y se queda en la zona ----------------
        cuadro_inicio_persona = ram(VR_CUADRO);
        camara.escena = 2'd2; camara.t_escena = 0;
        $display("[%t] escena: PERSONA entrando por la izquierda", $time);
        repeat (20) @(posedge cam_vsync);

        // captura de un cuadro VGA con la alarma
        @(posedge clk);
        wait (dut.vision.h == 0 && dut.vision.v == 0);
        capturando = 1'b1;
        wait (captura_lista);
        guardar_imagenes;
        red_referencia;

        // ---------------- resultados ----------------
        $display("");
        $display("cuadros procesados=%0d  manchas persona=%0d  no persona=%0d  eventos=%0d",
                 ram(VR_CUADRO), ram(VR_PERSONAS), ram(VR_NO_PERSONA), ram(VR_EVENTOS));
        $display("entradas=%0d salidas=%0d alarma=%02h  en zona=%0d  manchas=%0d",
                 ram(VR_ENTRADAS), ram(VR_SALIDAS), ram(VR_ALARMA), ram(VR_EN_ZONA), ram(VR_NBLOBS));
        $display("red binaria: Zbb=%0d ciclos, RV32IM=%0d ciclos (aceleracion x%0d.%02d)",
                 ram(VR_BENCH_X), ram(VR_BENCH_R), ram(VR_BENCH_R) / ram(VR_BENCH_X),
                 (ram(VR_BENCH_R) * 100 / ram(VR_BENCH_X)) % 100);
        $display("ciclos del ultimo cuadro=%0d  maximo=%0d  (un cuadro de la camara simulada = %0d ciclos)",
                 ram(VR_CICLOS), ram(VR_MAX_CICLOS), (160 + 24) * 2 * (2 + 419 + 120 + 2) * 2);
        $display("puntuaciones del ultimo recorte: programa (%0d, %0d, %0d)  referencia (%0d, %0d, %0d)",
                 $signed(ram(VR_PUNT)), $signed(ram(VR_PUNT + 4)), $signed(ram(VR_PUNT + 8)),
                 ref_punt[0], ref_punt[1], ref_punt[2]);
        $display("registro de eventos:");
        for (k2 = 0; k2 < ram(VR_EVENTOS) && k2 < 32; k2 = k2 + 1)
            $display("   tipo %0d  id %0d  cuadro %0d", ram(VR_LOG + 16 * k2), ram(VR_LOG + 16 * k2 + 4),
                     ram(VR_LOG + 16 * k2 + 8));
        $display("");

        revisar(ram(VR_PID) == 32'h76,                         "camara identificada: PID = 0x76");
        revisar(ram(VR_VER) == 32'h73,                         "camara identificada: VER = 0x73");
        revisar(camara.regs[8'h11] == 8'h01 && camara.regs[8'h6B] == 8'h4A, "SCCB: CLKRC = 0x01 y PLL x4 (31 cuadros/s)");
        revisar(camara.qvga,                                   "SCCB: la camara quedo en 320 x 240 (aqui 160 x 120)");
        revisar(camara.regs[8'h3A] == 8'h04,                   "SCCB: TSLB = 0x04 (orden Y U Y V)");
        revisar(camara.regs[8'h13] == 8'hE0,                   "SCCB: COM8 = 0xE0 (exposicion fija)");
        revisar(ram(VR_CLASE_PRUEBA) == {VIG_PRUEBA_CLASE[7:0], VIG_PRUEBA_CLASE[7:0]} &&
                VIG_PRUEBA_CLASE == 0,                         "red: silueta de prueba = persona en las 2 versiones");
        revisar(ram(VR_BENCH_X) < ram(VR_BENCH_R),             "red: con Zbb mas rapida que RV32IM");
        revisar(eventos_perro == 0,                            "perro: ningun evento");
        revisar(alarma_perro == 0,                             "perro: sin alarma");
        revisar(no_persona_perro > 0 && personas_perro == 0,   "perro: clasificado como no persona");
        revisar(ram(VR_ENTRADAS) == 1,                         "persona: 1 entrada contada");
        revisar(ram(VR_SALIDAS) == 0,                          "persona: 0 salidas");
        revisar(ram(VR_ALARMA) & 1,                            "persona: alarma activa");
        revisar((ram(VR_ALARMA) >> 4) & 1,                     "persona: motivo intrusion en zona");
        revisar((ram(VR_ALARMA) >> 5) & 1,                     "persona: motivo cruce prohibido");
        revisar(ram(VR_EVENTOS) == 3,                          "eventos: entrada, cruce y zona");
        revisar(ram(VR_EN_ZONA) == 1,                          "persona: 1 persona en la zona");
        revisar(dut.regs_vision.letrero == 2'd3,               "monitor: letrero INTRUSO parpadeando");
        revisar(dut.regs_vision.colores[1:0] == 2'd2,          "monitor: recuadro rojo sobre la persona");
        revisar(hex == 24'h010011,                             "displays: entradas 01, salidas 00, zona 1, manchas 1");
        for (k2 = 0; k2 < 3; k2 = k2 + 1)
            revisar($signed(ram(VR_PUNT + 4 * k2)) == ref_punt[k2], "red: puntuacion = referencia Verilog");
        revisar(ram(VR_MAX_CICLOS) < 800000, "tiempo real: cabe en un cuadro de la placa (800 000 ciclos)");
        revisar(ilegales == 0,                                 "sin instrucciones que no existan");

        $display("instrucciones=%0d ciclos=%0d CPI=%0d.%02d", instret, ciclos,
                 ciclos / instret, (ciclos * 100 / instret) % 100);
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
