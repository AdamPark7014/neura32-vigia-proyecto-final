`timescale 1ns / 1ps
// ============================================================
// TUBERIA DE VISION DE NEURA-32 VIGIA (hardware, sin procesador)
//
//   OV7670 -> cam_capture --brillo--> memoria Y (6 bits) ----------+
//      (YUV 4:2:2,     |---color--> memoria UV (5 + 5 bits) -------+-> vga_draw -> VGA
//       320 x 240,     |---brillo--> block_avg (80 x 60) -> fondo_mascara
//       ~31 cuadros/s) |                         mascara (CPU) <---+   |
//                      |                         mascara (VGA) ----+---+
//                      +--> pc_view (video reducido por JTAG a la PC)
//
// El procesador lee la mascara (dos bancos) y decide; el resultado lo
// pinta escribiendo zona, linea, cajas y letrero en registros_vision.
//
// La camara se muestrea con el reloj de 50 MHz (cam_capture); todo lo
// demas corre con el de 25 MHz, que sale de dividir el de 50 entre 2.
//
// Placa:      width = 320, height = 240, block_log2 = 2 (bloques de 4 x 4), vga_scale = 1
// Simulacion: width = 160, height = 120, block_log2 = 1 (bloques de 2 x 2), vga_scale = 2
// ============================================================
module vision_vigia #(
    parameter width      = 320,
    parameter height     = 240,
    parameter block_log2 = 2,
    parameter vga_scale  = 1
) (
    input  wire        clk,          // 25 MHz
    input  wire        clk50,        // 50 MHz: muestreo de la camara
    input  wire        rst,          // activo en alto (el del SoC)

    // camara
    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    input  wire [7:0]  cam_d,

    // configuracion (registros_vision)
    input  wire        habilita,
    input  wire        cam_half,     // la camara manda el doble de tamano: tomar 1 de cada 2
    input  wire [1:0]  cam_fmt,      // orden de los bytes (ver cam_capture)
    input  wire [7:0]  umbral,
    input  wire [3:0]  alfa,
    input  wire        aprender,
    input  wire        ver_mascara,
    input  wire        patron,
    input  wire        ack,
    output wire        listo,
    output wire        banco_lec,
    output wire [15:0] cuadros,
    output wire [12:0] pixeles_fg,
    input  wire [31:0] zona,
    input  wire [8:0]  linea,
    input  wire [1:0]  letrero,
    input  wire [255:0] cajas,
    input  wire [15:0] colores,
    input  wire [3:0]  hud_personas,
    input  wire [7:0]  hud_eventos,

    // lectura de la mascara por el CPU (sincrona, direccion de palabra 0..1199)
    input  wire [10:0] cpu_msk_dir,
    output wire [31:0] cpu_msk_dato,

    // VGA
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs
);
    wire rst_n = ~rst;               // los modulos nuevos usan el reinicio de la clase (activo en bajo)

    // ---------------- captura (50 MHz) ----------------
    wire        pix_valid, uv_valid, frame_done;
    wire [8:0]  pix_x;
    wire [7:0]  pix_y, pix_lum, uv_x, uv_u, uv_v;
    wire [6:0]  uv_y;

    cam_capture #(.width(width), .height(height)) captura (
        .clk(clk50), .rst(rst_n), .en(habilita), .half(cam_half), .fmt(cam_fmt),
        .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync), .cam_d(cam_d),
        .pix_valid(pix_valid), .pix_x(pix_x), .pix_y(pix_y), .pix_lum(pix_lum),
        .uv_valid(uv_valid), .uv_x(uv_x), .uv_y(uv_y), .uv_u(uv_u), .uv_v(uv_v),
        .frame_done(frame_done),
        .byte_strobe(), .pclk_rise(), .href_s(), .vsync_s()
    );

    // ---------------- memorias de video ----------------
    // Y: un brillo de 6 bits por pixel.  UV: un color {U, V} de 5 + 5 bits por bloque de 2 x 2.
    wire [16:0] y_addr_wr  = pix_y * width + pix_x;
    wire [14:0] uv_addr_wr = uv_y * (width / 2) + uv_x;
    wire [16:0] y_addr_rd;
    wire [14:0] uv_addr_rd;
    wire [5:0]  y_data_rd;
    wire [9:0]  uv_data_rd;

    ram_dp #(.addr_width(17), .data_width(6), .depth(width * height)) mem_y (
        .clk(clk), .we(pix_valid), .addr_wr(y_addr_wr), .data_in(pix_lum[7:2]),
        .addr_rd(y_addr_rd), .data_out(y_data_rd)
    );

    ram_dp #(.addr_width(15), .data_width(10), .depth((width / 2) * (height / 2))) mem_uv (
        .clk(clk), .we(uv_valid), .addr_wr(uv_addr_wr), .data_in({uv_u[7:3], uv_v[7:3]}),
        .addr_rd(uv_addr_rd), .data_out(uv_data_rd)
    );

    // ---------------- promedio por bloques, fondo y mascara ----------------
    wire        avg_valid;
    wire [6:0]  avg_x;
    wire [5:0]  avg_y;
    wire [7:0]  avg_data;

    block_avg #(.width(width), .block_log2(block_log2)) promedio (
        .clk(clk),
        .pix_valid(pix_valid), .pix_x(pix_x), .pix_y(pix_y), .pix_lum(pix_lum),
        .avg_valid(avg_valid), .avg_x(avg_x), .avg_y(avg_y), .avg_data(avg_data)
    );

    wire        msk_we, vmsk_we, vmsk_dato;
    wire [11:0] msk_dir_esc;
    wire [31:0] msk_dato_esc;
    wire [12:0] vmsk_dir_esc;

    fondo_mascara fondo (
        .clk(clk), .rst(rst),
        .px_valido(avg_valid), .px_x(avg_x), .px_y(avg_y), .px_dato(avg_data),
        .umbral(umbral), .alfa(alfa), .aprender(aprender), .ack(ack),
        .listo(listo), .banco_lec(banco_lec), .cuadros(cuadros), .pixeles_fg(pixeles_fg),
        .msk_we(msk_we), .msk_dir(msk_dir_esc), .msk_dato(msk_dato_esc),
        .vga_we(vmsk_we), .vga_dir(vmsk_dir_esc), .vga_dato(vmsk_dato)
    );

    // dos bancos de 1200 palabras: el CPU lee uno mientras la camara llena el otro
    memoria_doble_puerto #(.addr_width(12), .data_width(32), .palabras(2400)) mem_mascara (
        .clk(clk), .we(msk_we), .dir_esc(msk_dir_esc), .dato_esc(msk_dato_esc),
        .dir_lec(banco_lec ? ({1'b0, cpu_msk_dir} + 12'd1200) : {1'b0, cpu_msk_dir}), .dato_lec(cpu_msk_dato)
    );

    // la misma mascara, un bit por celda: una copia la lee el monitor y otra la PC
    wire [12:0] vmsk_addr_rd, pc_msk_addr;
    wire        vmsk_data_rd, pc_msk_data, tck;

    ram_dp #(.addr_width(13), .data_width(1), .depth(4800)) mem_mascara_vga (
        .clk(clk), .we(vmsk_we), .addr_wr(vmsk_dir_esc), .data_in(vmsk_dato),
        .addr_rd(vmsk_addr_rd), .data_out(vmsk_data_rd)
    );

    ram_2clk #(.addr_width(13), .data_width(1), .depth(4800)) mem_mascara_pc (
        .clk_wr(clk), .we(vmsk_we), .addr_wr(vmsk_dir_esc), .data_in(vmsk_dato),
        .clk_rd(tck), .addr_rd(pc_msk_addr), .data_out(pc_msk_data)
    );

    // ---------------- VGA ----------------
    wire [9:0] h, v;
    wire       hs, vs, activo, cuadro_vga;

    vga_sincronia sincronia (
        .clk(clk), .rst(rst), .h(h), .v(v), .hs(hs), .vs(vs),
        .activo(activo), .cuadro_nuevo(cuadro_vga)
    );

    vga_draw #(.width(width), .scale(vga_scale)) dibujo (
        .clk(clk), .rst(rst_n),
        .h(h), .v(v), .hs_in(hs), .vs_in(vs), .active_in(activo), .frame_tick(cuadro_vga),
        .y_addr(y_addr_rd), .y_data(y_data_rd), .uv_addr(uv_addr_rd), .uv_data(uv_data_rd),
        .msk_addr(vmsk_addr_rd), .msk_data(vmsk_data_rd),
        .show_mask(ver_mascara), .pattern(patron), .zone(zona), .line(linea), .banner(letrero),
        .boxes(cajas), .colors(colores), .hud_persons(hud_personas), .hud_events(hud_eventos),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs)
    );

    // ---------------- vista en la PC (JTAG) ----------------
    // Datos que dibuja la PC, 384 bits:
    //   [255:0] cajas  [271:256] colores  [303:272] zona  [312:304] linea  [314:313] letrero
    //   [318:315] personas  [326:319] eventos  [342:327] cuadros  [355:343] celdas de silueta
    wire [383:0] meta = {28'd0, pixeles_fg, cuadros, hud_eventos, hud_personas,
                         letrero, linea, zona, colores, cajas};

    pc_view #(.width(width), .height(height), .meta_bits(384)) vista_pc (
        .clk(clk), .rst(rst_n),
        .pix_valid(pix_valid), .pix_x(pix_x), .pix_y(pix_y), .pix_lum(pix_lum),
        .uv_valid(uv_valid), .uv_x(uv_x), .uv_y(uv_y), .uv_u(uv_u), .uv_v(uv_v),
        .frame_done(frame_done),
        .meta(meta),
        .tck(tck), .msk_addr(pc_msk_addr), .msk_data(pc_msk_data), .held()
    );
endmodule
