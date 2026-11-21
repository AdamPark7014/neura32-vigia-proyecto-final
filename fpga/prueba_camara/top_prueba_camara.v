`timescale 1ns / 1ps
// ============================================================
// PRUEBA DE LA CAMARA OV7670 EN LA DE10-Lite (sin procesador)
// Sirve para revisar el cableado antes del sistema completo:
//   HEX5-4  PID de la camara (76 si responde por SCCB)
//   HEX3-2  VER de la camara (73)
//   HEX1-0  cuadros recibidos (cuenta VSYNC)
//   LEDR0   configuracion terminada
//   LEDR1   la camara respondio (PID = 0x76)
//   LEDR2   VSYNC llega (cambia con cada cuadro)
//   LEDR3   HREF llega (parpadea)
//   LEDR4   PCLK llega (parpadea)
//   SW8     barras de colores en el monitor
//   KEY0    reinicio (vuelve a configurar la camara)
//   VGA     el video de la camara en gris, 320 x 240 ampliado a 640 x 480
// Mismo cableado que el proyecto (docs/PRUEBA-EN-PLACA.md).
// ============================================================
module top_prueba_camara (
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [9:0]  LEDR,
    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1,
    output wire [7:0]  HEX2,
    output wire [7:0]  HEX3,
    output wire [7:0]  HEX4,
    output wire [7:0]  HEX5,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    inout  wire [35:0] GPIO
);
    // ---------------- reloj de 25 MHz y reinicio ----------------
    reg clk25 = 1'b0;
    always @(posedge MAX10_CLK1_50) clk25 <= ~clk25;
    wire clk = clk25;

    // El mismo reloj retrasado un cuarto de ciclo (10 ns): con el y con su
    // inverso XCLK puede salir en cuatro fases (0, 90, 180 y 270 grados).
    reg clk25_n = 1'b0;
    always @(negedge MAX10_CLK1_50) clk25_n <= clk25;
    wire [1:0] fase;                          // la elige la PC (sonda JTAG)
    wire xclk = (fase[0] ? clk25_n : clk25) ^ fase[1];

    wire      rst_jtag;                       // reinicio desde la PC (sonda JTAG)
    reg [2:0] rst_s = 3'b111;
    always @(posedge clk) rst_s <= {rst_s[1:0], ~KEY[0] | rst_jtag};
    wire rst = rst_s[2];

    // ---------------- camara: configuracion por SCCB ----------------
    wire       sioc, siod_bajo, reset_n, hecho;
    wire [7:0] pid, ver;

    // La PC puede escribir o leer registros de la camara en vivo (sonda JTAG)
    wire       ext_wr, ext_rd, ext_libre;
    wire [7:0] ext_reg, ext_val, ext_dato;

    sccb_maestro sccb (
        .clk(clk), .rst(rst), .sioc(sioc), .siod_bajo(siod_bajo), .siod_in(GPIO[1]),
        .cam_reset_n(reset_n), .pid(pid), .ver(ver), .hecho(hecho),
        .ext_wr(ext_wr), .ext_rd(ext_rd), .ext_reg(ext_reg), .ext_val(ext_val),
        .ext_dato(ext_dato), .ext_libre(ext_libre)
    );

    assign GPIO[0]  = sioc;
    assign GPIO[1]  = siod_bajo ? 1'b0 : 1'bz;
    // XCLK = 25 MHz. PCLK sale de XCLK con fase fija; si sus flancos caen junto
    // a los de clk el muestreo pierde pulsos (rayas en la imagen), asi que la
    // fase de XCLK se puede mover desde la PC para dejarla donde va limpio.
    assign GPIO[5]  = xclk;
    assign GPIO[14] = reset_n;
    assign GPIO[15] = 1'b0;                   // PWDN
    assign GPIO[35:16] = 20'bz;

    wire [7:0] cam_d = {GPIO[6], GPIO[7], GPIO[8], GPIO[9], GPIO[10], GPIO[11], GPIO[12], GPIO[13]};

    // ---------------- captura y video ----------------
    wire        vid_we, cuadro_inicio;
    wire [16:0] vid_dir_esc, vid_dir_lec;
    wire [3:0]  vid_dato_esc, vid_dato_lec;
    wire [7:0]  vid_lum_esc;

    captura_ov7670 #(.CAM_ANCHO(640), .CAM_ALTO(480), .VID_DECIM_LOG2(1), .BLOQUE_LOG2(3)) captura (
        .clk(clk), .rst(rst), .habilita(hecho),
        .cam_pclk(GPIO[4]), .cam_href(GPIO[3]), .cam_vsync(GPIO[2]), .cam_d(cam_d),
        .vid_we(vid_we), .vid_dir(vid_dir_esc), .vid_dato(vid_dato_esc),
        .vid_lum(vid_lum_esc),
        .prom_valido(), .prom_x(), .prom_y(), .prom_dato(), .cuadro_inicio(cuadro_inicio)
    );

    // Video para el monitor: 320 x 240 con 4 bits de gris
    memoria_doble_puerto #(.addr_width(17), .data_width(4), .palabras(76800)) mem_video (
        .clk(clk), .we(vid_we), .dir_esc(vid_dir_esc), .dato_esc(vid_dato_esc),
        .dir_lec(vid_dir_lec), .dato_lec(vid_dato_lec)
    );

    // Copia para la PC: 320 x 240 con 7 bits de gris (128 tonos; con 8 bits las
    // dos copias no caben en los 182 bloques M9K), en DOS memorias (A y B).
    // La camara escribe en una y la PC lee la otra, que guarda el ultimo
    // cuadro completo: asi la imagen nunca llega partida y no hay que esperar.
    // Se escriben con clk y se leen con el reloj del JTAG (TCK).
    reg         banco_esc;                    // 0: la camara escribe en A, 1: en B
    reg         escribiendo;                  // hay un cuadro en curso de escritura
    reg         retenido;                     // cuadro completo guardado, en espera de la PC
    wire        tck;
    wire [16:0] dir_pc;
    wire [6:0]  dato_a, dato_b;
    wire        we_pc = vid_we & escribiendo;
    memoria_dos_relojes #(.addr_width(17), .data_width(7), .palabras(76800)) mem_pc_a (
        .clk_esc(clk), .we(we_pc & ~banco_esc), .dir_esc(vid_dir_esc), .dato_esc(vid_lum_esc[7:1]),
        .clk_lec(tck), .dir_lec(dir_pc), .dato_lec(dato_a)
    );
    memoria_dos_relojes #(.addr_width(17), .data_width(7), .palabras(76800)) mem_pc_b (
        .clk_esc(clk), .we(we_pc & banco_esc), .dir_esc(vid_dir_esc), .dato_esc(vid_lum_esc[7:1]),
        .clk_lec(tck), .dir_lec(dir_pc), .dato_lec(dato_b)
    );

    wire [9:0] h, v;
    wire       hs, vs, activo, cuadro_vga;
    vga_sincronia sincronia (.clk(clk), .rst(rst), .h(h), .v(v), .hs(hs), .vs(vs),
                             .activo(activo), .cuadro_nuevo(cuadro_vga));

    vga_dibujo #(.VID_ANCHO(320), .ESCALA_LOG2(1)) dibujo (
        .clk(clk), .rst(rst),
        .h(h), .v(v), .hs_in(hs), .vs_in(vs), .activo_in(activo), .cuadro_nuevo(cuadro_vga),
        .vid_dir(vid_dir_lec), .vid_dato(vid_dato_lec), .msk_dir(), .msk_dato(1'b0),
        .ver_mascara(1'b0), .patron(SW[8]), .zona(32'd0), .linea(9'd0), .banner(2'd0),
        .cajas(256'd0), .colores(16'd0),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B), .vga_hs(VGA_HS), .vga_vs(VGA_VS)
    );

    // ---------------- actividad de las senales de la camara ----------------
    reg [2:0]  pclk_s, href_s, vsync_s;
    reg [23:0] cuenta_pclk;
    reg [17:0] cuenta_href;
    reg [7:0]  cuadros;
    always @(posedge clk) begin
        pclk_s  <= {pclk_s[1:0],  GPIO[4]};
        href_s  <= {href_s[1:0],  GPIO[3]};
        vsync_s <= {vsync_s[1:0], GPIO[2]};
        if (pclk_s[1] & ~pclk_s[2])   cuenta_pclk <= cuenta_pclk + 24'd1;
        if (href_s[1] & ~href_s[2])   cuenta_href <= cuenta_href + 18'd1;
        if (rst) cuadros <= 8'd0;
        else if (vsync_s[1] & ~vsync_s[2]) cuadros <= cuadros + 8'd1;
    end

    assign LEDR = {5'd0, cuenta_pclk[22], cuenta_href[8], cuadros[0], (pid == 8'h76), hecho};

    // ---------------- mediciones para leer desde la PC ----------------
    // Bytes por linea (640 px YUYV = 1280), lineas por cuadro (480),
    // flancos de PCLK por segundo (6.25 MHz) y bits de datos que cambian.
    reg [7:0]  d_r1, d_r2;                    // dato alineado con el flanco detectado de PCLK
    reg [10:0] bytes_linea, bytes_med;
    reg [9:0]  lineas, lineas_med;
    reg [24:0] ciclos_seg;
    reg [22:0] pclk_seg, pclk_med;
    reg [7:0]  d_or, d_and, d_or_med, d_and_med;
    reg [9:0]  malas, malas_med;              // lineas del cuadro que no traen 1280 bytes
    wire flanco_pclk = pclk_s[1] & ~pclk_s[2];
    wire href_alto   = href_s[2];
    always @(posedge clk) begin
        d_r1 <= cam_d;
        d_r2 <= d_r1;
        // bytes dentro de la linea
        if (href_s[2] & ~href_s[1]) begin
            bytes_med <= bytes_linea; bytes_linea <= 11'd0;
            if (bytes_linea != 11'd1280) malas <= malas + 10'd1;
        end
        else if (flanco_pclk && href_alto) bytes_linea <= bytes_linea + 11'd1;
        // lineas dentro del cuadro y bits que cambian
        if (vsync_s[1] & ~vsync_s[2]) begin
            lineas_med <= lineas; lineas <= 10'd0;
            malas_med  <= malas;  malas  <= 10'd0;
            d_or_med <= d_or; d_and_med <= d_and; d_or <= 8'h00; d_and <= 8'hFF;
        end else begin
            if (href_s[1] & ~href_s[2]) lineas <= lineas + 10'd1;
            if (flanco_pclk && href_alto) begin d_or <= d_or | d_r2; d_and <= d_and & d_r2; end
        end
        // frecuencia de PCLK
        if (ciclos_seg == 25'd24_999_999) begin
            ciclos_seg <= 25'd0; pclk_med <= pclk_seg; pclk_seg <= 23'd0;
        end else begin
            ciclos_seg <= ciclos_seg + 25'd1;
            if (flanco_pclk) pclk_seg <= pclk_seg + 23'd1;
        end
    end

    // Sonda JTAG: 96 bits que lee quartus_stp (leer_camara.tcl)
    //   [95:88] PID  [87:80] VER  [79] hecho  [78:71] cuadros
    //   [70:60] bytes por linea  [59:50] lineas por cuadro
    //   [49:27] PCLK por segundo  [26:19] OR de D  [18:11] AND de D
    //   [10:1] lineas malas por cuadro  [0] cuadro retenido para la PC
    //   [104] maestro SCCB libre  [103:96] registro leido de la camara
    // Fuente (21 bits): [0] reinicio  [2:1] fase de XCLK (arranca en 2 = 180 grados)
    //   [10:3] valor  [18:11] registro  [19] escribir  [20] leer (en la subida)
    wire [104:0] sonda = {ext_libre, ext_dato,
                          pid, ver, hecho, cuadros, bytes_med, lineas_med, pclk_med,
                          d_or_med, d_and_med, malas_med, retenido};
    wire [20:0] fuente;
    assign rst_jtag = fuente[0];
    assign fase     = fuente[2:1];
    assign ext_val  = fuente[10:3];
    assign ext_reg  = fuente[18:11];
    reg [2:0] wr_s, rd_s;                     // sincronizadores y detector de subida
    always @(posedge clk) begin
        wr_s <= {wr_s[1:0], fuente[19]};
        rd_s <= {rd_s[1:0], fuente[20]};
    end
    assign ext_wr = wr_s[1] & ~wr_s[2];
    assign ext_rd = rd_s[1] & ~rd_s[2];
    altsource_probe #(
        .sld_auto_instance_index("NO"),
        .sld_instance_index(0),
        .instance_id("CAM"),
        .probe_width(105),
        .source_width(21),
        .source_initial_value("4"),
        .enable_metastability("NO")
    ) sonda_jtag (
        .probe(sonda),
        .source(fuente)
    );

    // ---------------- video hacia la PC por JTAG virtual (flujo_camara.tcl) ----------------
    // Registro de instruccion virtual (2 bits):
    //   0 = nada
    //   1 = imagen completa: 320 x 240 pixeles (614 400 bits)
    //   2 = imagen rapida:   160 x 120 pixeles (153 600 bits), 1 de cada 2
    // Cada corrimiento de datos manda un cuadro desde el pixel 0: 8 bits por
    // pixel, primero el menos significativo. El pixel en turno es "act";
    // mientras se corre se lee por adelantado el siguiente ("sig", la memoria
    // tarda un ciclo de TCK) y al acabar el byte se carga en el registro.
    wire       tdi, tdo, v_cdr, v_sdr, v_udr;
    wire [1:0] v_ir;
    sld_virtual_jtag #(
        .sld_auto_instance_index("NO"),
        .sld_instance_index(0),
        .sld_ir_width(2)
    ) jtag_virtual (
        .tck(tck), .tdi(tdi), .tdo(tdo), .ir_in(v_ir), .ir_out(2'b00),
        .virtual_state_cdr(v_cdr), .virtual_state_sdr(v_sdr), .virtual_state_udr(v_udr)
    );

    wire        flujo  = (v_ir == 2'd1) || (v_ir == 2'd2);
    wire        rapido = (v_ir == 2'd2);
    reg  [16:0] act;
    reg  [7:0]  col;                          // columna en la imagen rapida (0..159)
    reg  [2:0]  nbit;
    reg  [7:0]  desplaza;
    reg         paso;                         // registro de un bit cuando no hay flujo
    reg         leyendo;                      // la PC esta bajando un cuadro
    reg  [1:0]  banco_t;                      // banco_esc visto desde TCK
    reg         banco_lec;                    // memoria que se lee: la que NO escribe la camara

    // siguiente pixel: +1; en la imagen rapida +2 y al acabar el renglon se salta el impar
    wire [16:0] sig = !rapido ? act + 17'd1 : (col == 8'd159) ? act + 17'd322 : act + 17'd2;
    wire [7:0]  dato_pc = {banco_lec ? dato_b : dato_a, 1'b0};
    assign dir_pc = leyendo ? sig : 17'd0;   // en reposo se tiene listo el pixel 0
    assign tdo    = flujo ? desplaza[0] : paso;

    always @(posedge tck) begin
        paso    <= tdi;
        banco_t <= {banco_t[0], banco_esc};
        if (!leyendo) banco_lec <= ~banco_t[1];
        if (!flujo || v_udr) leyendo <= 1'b0;
        if (flujo && v_cdr) begin
            leyendo  <= 1'b1;
            desplaza <= dato_pc;              // pixel 0 (la direccion en reposo es 0)
            act <= 17'd0; col <= 8'd0; nbit <= 3'd0;
        end else if (flujo && v_sdr) begin
            if (nbit == 3'd7) begin
                desplaza <= dato_pc;
                act  <= sig;
                col  <= (col == 8'd159) ? 8'd0 : col + 8'd1;
                nbit <= 3'd0;
            end else begin
                desplaza <= {1'b0, desplaza[7:1]};
                nbit     <= nbit + 3'd1;
            end
        end
    end

    // Lado de la camara (clk). Al terminar un cuadro (subida de VSYNC):
    //   * si la PC no esta leyendo, se cambian las memorias: el cuadro recien
    //     terminado queda para la PC y la camara sigue en la otra;
    //   * si la PC esta leyendo, el cuadro se retiene (no se escribe mas) y el
    //     cambio se hace en cuanto la PC termina; la camara vuelve a escribir
    //     al empezar el siguiente cuadro.
    reg [1:0] leyendo_s;
    always @(posedge clk) begin
        leyendo_s <= {leyendo_s[0], leyendo};
        if (rst) begin
            banco_esc <= 1'b0; escribiendo <= 1'b0; retenido <= 1'b0;
        end else if (retenido) begin
            if (!leyendo_s[1]) begin banco_esc <= ~banco_esc; retenido <= 1'b0; end
        end else if (cuadro_inicio) begin
            if (!escribiendo)        escribiendo <= 1'b1;
            else if (!leyendo_s[1])  banco_esc   <= ~banco_esc;
            else begin               escribiendo <= 1'b0; retenido <= 1'b1; end
        end
    end

    // ---------------- displays ----------------
    function [7:0] siete_seg;
        input [3:0] n;
        case (n)
            4'h0: siete_seg = 8'hC0; 4'h1: siete_seg = 8'hF9; 4'h2: siete_seg = 8'hA4; 4'h3: siete_seg = 8'hB0;
            4'h4: siete_seg = 8'h99; 4'h5: siete_seg = 8'h92; 4'h6: siete_seg = 8'h82; 4'h7: siete_seg = 8'hF8;
            4'h8: siete_seg = 8'h80; 4'h9: siete_seg = 8'h90; 4'hA: siete_seg = 8'h88; 4'hB: siete_seg = 8'h83;
            4'hC: siete_seg = 8'hC6; 4'hD: siete_seg = 8'hA1; 4'hE: siete_seg = 8'h86; default: siete_seg = 8'h8E;
        endcase
    endfunction

    assign HEX5 = siete_seg(pid[7:4]);
    assign HEX4 = siete_seg(pid[3:0]);
    assign HEX3 = siete_seg(ver[7:4]);
    assign HEX2 = siete_seg(ver[3:0]);
    assign HEX1 = siete_seg(cuadros[7:4]);
    assign HEX0 = siete_seg(cuadros[3:0]);
endmodule
