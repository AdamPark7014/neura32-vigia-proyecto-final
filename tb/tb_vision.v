`timescale 1ns / 1ps
module tb_vision;
    reg clk50 = 0;
    always #10 clk50 = ~clk50;
    reg clk25 = 0;
    always @(posedge clk50) clk25 <= ~clk25;

    reg rst = 1;

    // camara
    wire pclk, href, vsync, sioc, siod;
    wire [7:0] d;
    pullup (siod);
    assign sioc = 1'b1;
    reg cam_resetb = 0;
    modelo_ov7670 #(.ANCHO(640), .ALTO(480), .H_BLANCO(464), .V_BLANCO(11)) camara (
        .xclk(clk25), .resetb(cam_resetb), .pwdn(1'b0),
        .pclk(pclk), .href(href), .vsync(vsync), .d(d), .sioc(sioc), .siod(siod)
    );

    // vision
    reg         habilita = 0, aprender = 1, ver_mascara = 0, ack = 0;
    reg  [31:0] zona = 0;
    reg  [8:0]  linea = 0;
    reg  [1:0]  letrero = 0;
    reg  [255:0] cajas = 0;
    reg  [15:0] colores = 0;
    wire        listo, banco_lec;
    wire [15:0] cuadros;
    wire [12:0] pixeles_fg;
    wire [31:0] cpu_msk_dato;
    wire [3:0]  vga_r, vga_g, vga_b;
    wire        vga_hs, vga_vs;

    vision_vigia #(.width(320), .height(240), .block_log2(2), .vga_scale(1)) dut (
        .clk(clk25), .clk50(clk50), .rst(rst),
        .cam_pclk(pclk), .cam_href(href), .cam_vsync(vsync), .cam_d(d),
        .habilita(habilita), .cam_half(1'b0), .cam_fmt(2'b00),
        .umbral(8'd28), .alfa(4'd3), .aprender(aprender), .ver_mascara(ver_mascara), .patron(1'b0),
        .ack(ack), .listo(listo), .banco_lec(banco_lec), .cuadros(cuadros), .pixeles_fg(pixeles_fg),
        .zona(zona), .linea(linea), .letrero(letrero), .cajas(cajas), .colores(colores),
        .hud_personas(4'd2), .hud_eventos(8'h07),
        .cpu_msk_dir(11'd0), .cpu_msk_dato(cpu_msk_dato),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs)
    );

    // acuse
    always @(posedge clk25) ack <= listo & ~ack;

    // cuadros de la camara
    realtime t_cuadro = 0, periodo = 0;
    integer  n_cuadros = 0;
    always @(posedge vsync) begin
        if (t_cuadro != 0) periodo = $realtime - t_cuadro;
        t_cuadro = $realtime;
        n_cuadros = n_cuadros + 1;
    end

    integer errores = 0, pruebas = 0;
    task revisar;
        input [8*56-1:0] nombre;
        input            bien;
        begin
            pruebas = pruebas + 1;
            if (bien) $display("  ok    %0s", nombre);
            else begin errores = errores + 1; $display("  FALLA %0s", nombre); end
        end
    endtask

    // sin cortes: el monitor no lee el renglon que escribe la camara
    integer choques = 0, escrituras = 0;
    always @(posedge clk25) begin
        if (dut.enganchado && dut.pix_valid) begin
            escrituras = escrituras + 1;
            if (dut.activo && (dut.v[9:1] == {2'b00, dut.pix_y})) choques = choques + 1;
        end
    end

    // guardar cuadro
    integer f, guardando = 0, pix = 0;
    always @(posedge clk25) begin
        if (guardando == 1 && dut.dibujo.h2 == 0 && dut.dibujo.v2 == 0) begin
            f = $fopen("tb/salidas/vga_color.ppm", "w");
            $fwrite(f, "P3\n640 480\n15\n");
            guardando = 2;
        end
        if (guardando == 2 && dut.dibujo.act2) begin
            $fwrite(f, "%0d %0d %0d\n", dut.dibujo.r, dut.dibujo.g, dut.dibujo.b);
            pix = pix + 1;
            if (pix == 640 * 480) begin $fclose(f); guardando = 3; end
        end
    end

    // lectura JTAG
    task guardar_bits;
        input [8*32-1:0] nombre;
        integer g, j;
        begin
            g = $fopen(nombre, "w");
            for (j = 0; j < dut.vista_pc.jtag_virtual.n_datos; j = j + 1)
                $fwrite(g, "%0d", dut.vista_pc.jtag_virtual.datos[j]);
            $fwrite(g, "\n");
            $fclose(g);
        end
    endtask

    reg [15:0]  cab;
    reg [383:0] vuelta;
    integer i, unos;

    initial begin
        $display("=== Vision: camara a color, monitor y vista en la PC ===");
        #200 rst = 0; cam_resetb = 1;
        #100;
        // configuracion de la camara
        camara.regs[8'h11] = 8'h01;
        camara.regs[8'h6B] = 8'h4A;
        camara.regs[8'h0C] = 8'h04;
        camara.regs[8'h3E] = 8'h19;
        camara.regs[8'h3A] = 8'h04;
        camara.escena = 2'd0;
        habilita = 1;

        // aprende el fondo
        wait (n_cuadros == 3);
        aprender = 0;
        // entra la persona
        camara.escena = 2'd2; camara.t_escena = 6;
        cajas[31:0]    = {8'd58, 8'd42, 8'd10, 8'd22};
        cajas[63:32]   = {8'd40, 8'd75, 8'd30, 8'd60};
        cajas[95:64]   = {8'd12, 8'd14, 8'd3,  8'd4};
        colores        = {10'd0, 2'd3, 2'd2, 2'd1};
        zona           = {8'd55, 8'd78, 8'd25, 8'd55};
        linea          = {1'b1, 8'd15};
        letrero        = 2'b01;

        wait (n_cuadros == 6);
        $display("        periodo de cuadro del modelo: %0.2f ms; PCLK = %0.2f MHz",
                 periodo / 1.0e6, 1000.0 / (2.0 * camara.medio_pclk));
        revisar("PCLK de 12.5 MHz (4 muestras del reloj de 50 MHz)", camara.medio_pclk == 40);
        revisar("la mascara encontro a la persona", pixeles_fg > 100 && pixeles_fg < 1500);
        $display("        celdas de silueta: %0d", pixeles_fg);

        guardando = 1;
        wait (guardando == 3);
        revisar("se guardo un cuadro completo del monitor", pix == 640 * 480);

        // dos cuadros completos
        dut.vista_pc.jtag_virtual.poner_ir(2'd1);
        dut.vista_pc.jtag_virtual.correr_dr(16 + 160 * 120 * 4 + 80 * 60 * 8);
        for (i = 0; i < 16; i = i + 1) cab[i] = dut.vista_pc.jtag_virtual.datos[i];
        revisar("cabecera del primer cuadro (A5)", cab == 16'hA500);
        guardar_bits("tb/salidas/pc_cuadro0.txt");
        dut.vista_pc.jtag_virtual.correr_dr(16 + 160 * 120 * 4 + 80 * 60 * 8);
        for (i = 0; i < 16; i = i + 1) cab[i] = dut.vista_pc.jtag_virtual.datos[i];
        revisar("cabecera del segundo cuadro (A5)", cab == 16'hA500);
        guardar_bits("tb/salidas/pc_cuadro1.txt");
        revisar("monitor enganchado a la camara", dut.enganchado == 1'b1);
        revisar("sin cortes entre cuadros", escrituras > 76800 && choques == 0);
        $display("        escrituras revisadas: %0d; choques: %0d", escrituras, choques);

        // mascara y datos
        dut.vista_pc.jtag_virtual.poner_ir(2'd2);
        dut.vista_pc.jtag_virtual.correr_dr(4800);
        unos = 0;
        for (i = 0; i < 4800; i = i + 1)
            if (dut.vista_pc.jtag_virtual.datos[i] === 1'b1) unos = unos + 1;
        revisar("la mascara que baja la PC trae la silueta", unos > 100 && unos < 1500);
        $display("        celdas en 1 en la mascara de la PC: %0d", unos);
        guardar_bits("tb/salidas/pc_mascara.txt");

        dut.vista_pc.jtag_virtual.poner_ir(2'd3);
        dut.vista_pc.jtag_virtual.correr_dr(384);
        for (i = 0; i < 384; i = i + 1) vuelta[i] = dut.vista_pc.jtag_virtual.datos[i];
        revisar("los recuadros llegan a la PC sin cambios", vuelta[255:0] == cajas && vuelta[271:256] == colores);
        revisar("zona, linea y letrero llegan a la PC",
                vuelta[303:272] == zona && vuelta[312:304] == linea && vuelta[314:313] == letrero);
        revisar("personas y eventos llegan a la PC", vuelta[318:315] == 4'd2 && vuelta[326:319] == 8'h07);
        guardar_bits("tb/salidas/pc_datos.txt");
        dut.vista_pc.jtag_virtual.poner_ir(2'd0);

        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end

    initial #900_000_000 begin $display("TIEMPO AGOTADO"); $finish; end
endmodule
