`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// TESTBENCH AUTOVERIFICABLE — CLASIFICADOR NEURONAL (PROGRAMA = 1)
// Para cada patron de 3x3 (valor de SW) se reinicia el SoC, se deja
// correr el programa hasta ecall y se compara la clase y las 8
// puntuaciones con un modelo de referencia escrito en Verilog puro
// (misma red cuantizada, sin pasar por el procesador).
// Tambien se comprueban LEDs, HEX y el texto de la consola.
// ============================================================
module tb_red_neuronal;

    parameter ADELANTAR_CARGAS = 0;   // 1: sin detencion carga-uso (para comparar el CPI)

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    reg  [9:0]  sw = 10'd0;
    wire [9:0]  leds;
    wire [23:0] hex;
    wire [7:0]  consola_char;
    wire        consola_we, fin, instr_ilegal, desalineado;
    wire [31:0] control;
    wire [63:0] ciclos, instret;

    generador_programa #(.PROGRAMA(1)) gen ();

    wire cam_siod;
    pullup (cam_siod);

    soc_neura32 #(.USAR_ARCHIVO(0), .ADELANTAR_CARGAS(ADELANTAR_CARGAS), .SIMULACION(1)) dut (
        .clk(clk), .clk50(clk), .rst_ext(rst),
        .interruptores(sw), .botones(2'b11),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we), .control(control),
        .fin(fin), .instr_ilegal(instr_ilegal), .desalineado(desalineado),
        .cam_pclk(1'b0), .cam_href(1'b0), .cam_vsync(1'b0), .cam_d(8'd0),
        .cam_sioc(), .cam_siod(cam_siod), .cam_reset_n(), .cam_pwdn(),
        .vga_r(), .vga_g(), .vga_b(), .vga_hs(), .vga_vs(),
        .ciclos(ciclos), .instret(instret)
    );
    // ---- el programa lo arma el generador (ensamblador en Verilog) y se copia a la ROM ----
    integer palabra;
    task copiar_programa;
        for (palabra = 0; palabra < 4096; palabra = palabra + 1)
            dut.rom.memoria[palabra] = gen.memoria[palabra];
    endtask


    // ---- consola ----
    reg [8*16-1:0] texto;
    always @(posedge clk)
        if (consola_we) begin
            $write("%c", consola_char);
            texto = {texto[8*15-1:0], consola_char};
        end

    integer ilegales = 0;
    always @(posedge clk) if (instr_ilegal) ilegales = ilegales + 1;

    // ---- modelo de referencia (misma red, enteros, en Verilog) ----
    `include "pesos_red.vh"

    integer ref_punt [0:7];
    integer ref_act  [0:15];
    integer ref_clase;

    task modelo_referencia;
        input [8:0] pix;
        integer i, j, k, h, o, mejor;
        begin
            for (j = 0; j < RED_OCULTAS; j = j + 1) begin
                h = RED_B1[j];
                for (i = 0; i < RED_ENTRADAS; i = i + 1)
                    if (pix[i]) h = h + RED_W1[j * RED_ENTRADAS + i];
                h = h >>> RED_SH1;
                ref_act[j] = (h < 0) ? 0 : ((h > 127) ? 127 : h);
            end
            mejor = 32'sh80000000;
            ref_clase = 0;
            for (k = 0; k < RED_SALIDAS; k = k + 1) begin
                o = RED_B2[k];
                for (j = 0; j < RED_OCULTAS; j = j + 1)
                    o = o + RED_W2[k * RED_OCULTAS + j] * ref_act[j];
                ref_punt[k] = o;
                if (o > mejor) begin mejor = o; ref_clase = k; end
            end
        end
    endtask

    function [8*12-1:0] nombre_clase; input integer k;
        case (k)
            0: nombre_clase = "X";       1: nombre_clase = "O (anillo)";
            2: nombre_clase = "+";       3: nombre_clase = "- (barra)";
            4: nombre_clase = "| (palo)"; 5: nombre_clase = "/ diagonal";
            6: nombre_clase = "\\ diagonal"; 7: nombre_clase = "T";
            default: nombre_clase = "?";
        endcase
    endfunction

    // ---- casos de prueba: las 8 plantillas y variantes con un pixel cambiado ----
    localparam N_CASOS = 16;
    reg [8:0] caso [0:N_CASOS-1];
    integer c, k, errores = 0, pruebas = 0, limite, clase_hw, punt_hw, total_ciclos = 0, total_instr = 0;

    initial begin
        #1 copiar_programa;
        cargar_pesos;
        for (c = 0; c < 8; c = c + 1) begin
            caso[c]     = red_plantilla(c);
            caso[c + 8] = red_plantilla(c) ^ (9'h001 << ((c * 3 + 1) % 9));   // un pixel invertido
        end

        $display("=== NEURA-32: clasificador neuronal 3x3 (9-16-8, int8) ===");
        $display("ROM: codigo hasta 0x%03h, pesos hasta 0x%03h", gen.R_W1, gen.R_fin);

        for (c = 0; c < N_CASOS; c = c + 1) begin
            // reinicio con el patron en los interruptores
            rst = 1'b1; sw = {1'b0, caso[c]}; texto = 0;
            repeat (3) @(posedge clk);
            rst = 1'b0;

            limite = 0;
            while (!fin && limite < 30000) begin @(posedge clk); limite = limite + 1; end
            repeat (2) @(posedge clk);

            modelo_referencia(caso[c]);
            clase_hw = dut.ram.palabra(0);
            punt_hw  = dut.ram.palabra(1 + ref_clase);
            total_ciclos = total_ciclos + ciclos;
            total_instr  = total_instr  + instret;

            $display("caso %2d  SW=%03h  [%b %b %b | %b %b %b | %b %b %b]  hw=%0d  ref=%0d  %0s  punt=%0d  ciclos=%0d  instr=%0d",
                     c, caso[c],
                     caso[c][0], caso[c][1], caso[c][2], caso[c][3], caso[c][4], caso[c][5], caso[c][6], caso[c][7], caso[c][8],
                     clase_hw, ref_clase, nombre_clase(ref_clase), ref_punt[ref_clase], ciclos, instret);

            pruebas = pruebas + 1;
            if (!fin) begin errores = errores + 1; $display("   FALLA: no termino"); end

            pruebas = pruebas + 1;
            if (clase_hw !== ref_clase) begin errores = errores + 1; $display("   FALLA: clase %0d != %0d", clase_hw, ref_clase); end

            for (k = 0; k < 8; k = k + 1) begin
                pruebas = pruebas + 1;
                if ($signed(dut.ram.palabra(1 + k)) !== ref_punt[k]) begin
                    errores = errores + 1;
                    $display("   FALLA: puntuacion[%0d] = %0d, esperada %0d", k, $signed(dut.ram.palabra(1 + k)), ref_punt[k]);
                end
            end
            for (k = 0; k < 16; k = k + 1) begin
                pruebas = pruebas + 1;
                if (dut.ram.octeto(256 + k) !== ref_act[k][7:0]) begin
                    errores = errores + 1;
                    $display("   FALLA: activacion[%0d] = %0d, esperada %0d", k, dut.ram.octeto(256 + k), ref_act[k]);
                end
            end

            pruebas = pruebas + 1;
            if (leds !== (10'h200 | (10'h001 << ref_clase))) begin errores = errores + 1; $display("   FALLA: leds=%03h", leds); end

            pruebas = pruebas + 1;
            if (hex !== ((ref_punt[ref_clase] << 8) | ref_clase) & 24'hFFFFFF) begin errores = errores + 1; $display("   FALLA: hex=%06h", hex); end

            pruebas = pruebas + 1;
            if (texto[8*8-1:0] !== {"C", "L", "A", "S", "E", " ", 8'd48 + ref_clase[7:0], 8'h0A}) begin
                errores = errores + 1; $display("   FALLA: consola");
            end

            pruebas = pruebas + 1;
            if (control[0] !== 1'b1) begin errores = errores + 1; $display("   FALLA: CONTROL.listo"); end
        end

        pruebas = pruebas + 1;
        if (ilegales != 0) begin errores = errores + 1; $display("FALLA: %0d instrucciones ilegales", ilegales); end

        $display("promedio: %0d ciclos y %0d instrucciones por inferencia, CPI=%0d.%02d",
                 total_ciclos / N_CASOS, total_instr / N_CASOS,
                 total_ciclos / total_instr, (total_ciclos * 100 / total_instr) % 100);
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end

endmodule
