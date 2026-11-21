`timescale 1ns / 1ps
// ============================================================
// BANCO DE PRUEBAS DEL CARGADOR DE PROGRAMAS
// Demuestra que el procesador corre otro programa sin volver a compilar:
//   1. arranca con un programa corto que pone 0x155 en los LED;
//   2. por JTAG (como lo hace fpga/cargar_programa.tcl) detiene el
//      procesador, escribe el programa de demostracion y lo suelta;
//   3. el programa nuevo debe mostrar la serie de Fibonacci en los
//      displays y mover la luz por los LED.
// Al final imprime: PRUEBAS: n  ERRORES: 0
// ============================================================
module tb_cargador;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #20 clk = ~clk;

    wire [9:0]  leds;
    reg  [9:0]  sw = 10'd0;
    wire [23:0] hex;
    wire        fin, instr_ilegal;
    wire        cam_siod;
    pullup (cam_siod);

    soc_neura32 #(.ARCHIVO_PROGRAMA("fpga/programa_demo.txt"), .SIMULACION(1), .VID_ANCHO(160), .VID_ALTO(120), .BLOQUE_LOG2(1), .VGA_ESCALA_LOG2(2)) dut (
        .clk(clk), .clk50(clk), .rst_ext(rst),
        .interruptores(sw), .botones(2'b11),
        .leds(leds), .hex(hex),
        .consola_char(), .consola_we(), .control(),
        .cam_pclk(1'b0), .cam_href(1'b0), .cam_vsync(1'b0), .cam_d(8'd0),
        .cam_sioc(), .cam_siod(cam_siod), .cam_reset_n(), .cam_pwdn(), .cam_fase(),
        .vga_r(), .vga_g(), .vga_b(), .vga_hs(), .vga_vs(),
        .fin(fin), .instr_ilegal(instr_ilegal),
        .ciclos(), .instret()
    );

    // el programa de demostracion, armado por el ensamblador en Verilog
    generador_programa #(.PROGRAMA(4)) demo ();

    // el primer programa: unas cuantas instrucciones escritas con el mismo codificador
    reg [31:0] memoria [0:15];
    `include "codificador_riscv.vh"

    integer pruebas = 0, errores = 0;
    task revisar;
        input            bien;
        input [8*56-1:0] nombre;
        begin
            pruebas = pruebas + 1;
            if (bien) $display("  ok    %0s", nombre);
            else begin errores = errores + 1; $display("  FALLA %0s", nombre); end
        end
    endtask

    // lo que hace la PC por JTAG
    task escribir_palabra;
        input [11:0] dir;
        input [31:0] dato;
        begin
            dut.cargador.jtag_virtual.escribir_dr(44, {20'd0, dato, dir});
        end
    endtask

    integer i, n, k;
    reg [23:0] fib_a, fib_b, fib_t;
    reg [23:0] visto;
    reg [9:0]  luz;
    reg        serie_bien, luz_bien;
    reg [33:0] estado;

    initial begin
        $display("=== Cargador de programas: el procesador corre otro programa ===");
        for (i = 0; i < 4096; i = i + 1) dut.cpu.IMEM.rom_data[i] = 32'h00000013;
        // programa 1:  lui s0, 0xFFFF0 ; addi t0, x0, 0x155 ; sw t0, 0(s0) ; j .
        dut.cpu.IMEM.rom_data[0] = LUI(S0, 32'hFFFF0000);
        dut.cpu.IMEM.rom_data[1] = ADDI(T0, X0, 12'h155);
        dut.cpu.IMEM.rom_data[2] = SW(T0, S0, 0);
        dut.cpu.IMEM.rom_data[3] = JAL(X0, 0);
        #200 rst = 1'b0;
        repeat (40) @(posedge clk);
        revisar(leds == 10'h155, "el primer programa corre: LED = 0x155");

        // ---- la PC detiene el procesador ----
        dut.cargador.jtag_virtual.poner_ir(2'd2);
        dut.cargador.jtag_virtual.escribir_dr(1, 64'd1);
        repeat (8) @(posedge clk);
        revisar(dut.rst == 1'b1 && leds == 10'd0, "con el cargador detenido el SoC queda en reinicio");

        // ---- escribe el programa nuevo ----
        n = demo.D_fin / 4;
        dut.cargador.jtag_virtual.poner_ir(2'd1);
        for (i = 0; i < n; i = i + 1) escribir_palabra(i, demo.memoria[i]);
        repeat (8) @(posedge clk);
        serie_bien = 1'b1;
        for (i = 0; i < n; i = i + 1)
            if (dut.cpu.IMEM.rom_data[i] !== demo.memoria[i]) serie_bien = 1'b0;
        revisar(serie_bien, "las palabras del programa nuevo quedaron en la memoria");
        $display("        programa de demostracion: %0d instrucciones", n);

        // ---- lo suelta ----
        dut.cargador.jtag_virtual.poner_ir(2'd2);
        dut.cargador.jtag_virtual.escribir_dr(1, 64'd0);

        // ---- el programa nuevo: Fibonacci en los displays y luz en los LED ----
        fib_a = 0; fib_b = 1; luz = 10'd1;
        serie_bien = 1'b1; luz_bien = 1'b1;
        wait (leds == 10'd1);
        for (k = 0; k < 14; k = k + 1) begin
            if (hex !== fib_a) serie_bien = 1'b0;
            if (leds !== luz)  luz_bien = 1'b0;
            if (k < 13) begin
                // cada paso mueve la luz (los displays se escriben justo antes que los LED)
                wait (leds !== luz);
                fib_t = fib_a + fib_b; fib_a = fib_b; fib_b = fib_t;
                luz = (k < 9) ? (luz << 1) : (luz >> 1);
            end
        end
        revisar(serie_bien, "displays: 0 1 1 2 3 5 8 D 15 22 37 59 90 E9 (Fibonacci)");
        revisar(luz_bien,   "LED: la luz corre hasta el LED9 y regresa");

        // ---- la PC lee el estado (con SW9 arriba el programa queda en pausa) ----
        sw[9] = 1'b1;
        repeat (60) @(posedge clk);
        dut.cargador.jtag_virtual.poner_ir(2'd3);
        dut.cargador.jtag_virtual.correr_dr(34);
        for (i = 0; i < 34; i = i + 1) estado[i] = dut.cargador.jtag_virtual.datos[i];
        revisar(estado[23:0] == hex && estado[33:24] == leds, "la PC lee los LED y los displays por JTAG");
        revisar(!fin, "el programa sigue corriendo");

        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end

    integer ilegales = 0;
    always @(posedge clk) if (!rst && !dut.rst && instr_ilegal) ilegales = ilegales + 1;

    initial #20_000_000 begin $display("TIEMPO AGOTADO"); $finish; end
endmodule
