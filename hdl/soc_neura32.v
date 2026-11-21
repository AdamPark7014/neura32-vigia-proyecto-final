`timescale 1ns / 1ps
// ============================================================
// SoC NEURA-32 VIGIA: nucleo + memoria de programa + RAM + mascara +
// perifericos + camara OV7670 + tuberia de vision + VGA + cargador de
// programas por JTAG
//
// MAPA DE MEMORIA
//   0x0000_0000 - 0x0000_3FFF  ROM de programa (16 KB, tambien legible como datos)
//   0x1000_0000 - 0x1000_3FFF  RAM de datos (16 KB)
//   0x2000_0000 - 0x2000_12BF  mascara de movimiento 80 x 60 (1 byte por pixel, solo lectura)
//   0xFFFF_0000 - 0xFFFF_003F  perifericos (LED, SW, HEX, KEY, consola, ...)
//   0xFFFF_0040 - 0xFFFF_009F  camara y vision (SCCB, captura, zona, linea, cajas)
//
// Las memorias son sincronas: la direccion llega desde EX y el dato sale
// en MEM. Los perifericos se leen y escriben en MEM.
// ============================================================
module soc_neura32 #(
    parameter ARCHIVO_PROGRAMA = "programa_vigia.txt",
    parameter USAR_ARCHIVO     = 1,
    parameter ADELANTAR_CARGAS = 0,
    parameter SIMULACION       = 0,
    parameter ROM_ADDR_WIDTH   = 12,
    parameter RAM_ADDR_WIDTH   = 12,
    // video: placa 320 x 240 (la camara ya lo entrega reducido) y deteccion 80 x 60
    parameter VID_ANCHO        = 320,
    parameter VID_ALTO         = 240,
    parameter BLOQUE_LOG2      = 2,
    parameter VGA_ESCALA_LOG2  = 1
) (
    input  wire        clk,          // 25 MHz
    input  wire        clk50,        // 50 MHz: muestreo de la camara
    input  wire        rst_ext,      // reinicio de la placa (activo en alto)

    input  wire [9:0]  interruptores,
    input  wire [1:0]  botones,
    output wire [9:0]  leds,
    output wire [23:0] hex,

    output wire [7:0]  consola_char,
    output wire        consola_we,
    output wire [31:0] control,

    // camara OV7670
    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    input  wire [7:0]  cam_d,
    output wire        cam_sioc,
    inout  wire        cam_siod,
    output wire        cam_reset_n,
    output wire        cam_pwdn,
    output wire [1:0]  cam_fase,     // fase de XCLK que pide el programa

    // VGA
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs,

    output wire        fin,
    output wire        instr_ilegal,
    output wire        desalineado,
    output wire [63:0] ciclos,
    output wire [63:0] instret
);
    // ---------------- cargador de programas (JTAG) ----------------
    // Mientras la PC escribe otro programa, todo el SoC queda en reinicio.
    wire        cargar_we, detener;
    wire [11:0] cargar_dir;
    wire [31:0] cargar_dato;

    jtag_loader cargador (
        .clk(clk), .rst(~rst_ext),
        .load_we(cargar_we), .load_addr(cargar_dir), .load_data(cargar_dato),
        .halt(detener), .leds(leds), .hex(hex)
    );

    wire rst = rst_ext | detener;

    // ---------------- nucleo ----------------
    wire [31:0] imem_dir, imem_instr;
    wire        imem_en;
    wire [31:0] dmem_dir_e, dmem_dato_esc_e;
    wire [3:0]  dmem_be_e;
    wire        dmem_we_e, dmem_re_e;
    wire [31:0] dmem_dir, dmem_dato_esc, dmem_dato_lec;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    nucleo_neura32 #(.ADELANTAR_CARGAS(ADELANTAR_CARGAS)) nucleo (
        .clk(clk), .rst(rst),
        .imem_dir(imem_dir), .imem_en(imem_en), .imem_instr(imem_instr),
        .dmem_dir_e(dmem_dir_e), .dmem_dato_esc_e(dmem_dato_esc_e), .dmem_be_e(dmem_be_e),
        .dmem_we_e(dmem_we_e), .dmem_re_e(dmem_re_e),
        .dmem_dir(dmem_dir), .dmem_dato_esc(dmem_dato_esc), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_dato_lec(dmem_dato_lec),
        .fin(fin), .instr_ilegal(instr_ilegal), .desalineado(desalineado),
        .ciclos(ciclos), .instret(instret)
    );

    // ---------------- decodificacion de direcciones ----------------
    wire sel_ram_e   = (dmem_dir_e[31:28] == 4'h1);
    wire sel_rom_m   = (dmem_dir[31:28] == 4'h0);
    wire sel_ram_m   = (dmem_dir[31:28] == 4'h1);
    wire sel_msk_m   = (dmem_dir[31:28] == 4'h2);
    wire sel_perif_m = (dmem_dir[31:16] == 16'hFFFF);
    wire sel_vis_m   = sel_perif_m && (dmem_dir[7:6] != 2'b00);   // 0x40 en adelante

    // ---------------- ROM de programa (doble puerto, sincrona) ----------------
    wire [31:0] rom_dato;
    rom_instrucciones #(
        .addr_width(ROM_ADDR_WIDTH), .data_width(32),
        .archivo(ARCHIVO_PROGRAMA), .usar_archivo(USAR_ARCHIVO)
    ) rom (
        .clk(clk), .en_instr(imem_en),
        .dir_instr(imem_dir), .instr(imem_instr),
        .dir_dato(dmem_dir_e), .dato(rom_dato),
        .cargar_we(cargar_we), .cargar_dir(cargar_dir[ROM_ADDR_WIDTH-1:0]), .cargar_dato(cargar_dato)
    );

    // ---------------- RAM de datos (sincrona) ----------------
    wire [31:0] ram_dato;
    ram_datos #(.addr_width(RAM_ADDR_WIDTH), .data_width(32)) ram (
        .clk(clk), .dir(dmem_dir_e), .dato_esc(dmem_dato_esc_e), .be(dmem_be_e),
        .we(dmem_we_e & sel_ram_e), .dato_lec(ram_dato)
    );

    // ---------------- perifericos basicos ----------------
    wire [31:0] perif_dato, ticks, lfsr;
    perifericos #(.SIMULACION(SIMULACION)) perif (
        .clk(clk), .rst(rst),
        .dir(dmem_dir), .dato_esc(dmem_dato_esc), .we(dmem_we & sel_perif_m & ~sel_vis_m),
        .dato_lec(perif_dato),
        .interruptores(interruptores), .botones(botones),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we),
        .control(control), .ticks(ticks), .lfsr(lfsr)
    );

    // ---------------- registros de camara y vision ----------------
    wire [31:0] vis_dato;
    wire        siod_bajo;
    wire        vis_habilita, vis_aprender, vis_ver_mascara, vis_ack, vis_listo, vis_banco;
    wire        vis_cam_half;
    wire [1:0]  vis_cam_fmt;
    wire [3:0]  hud_personas;
    wire [7:0]  hud_eventos;
    wire [7:0]  vis_umbral;
    wire [3:0]  vis_alfa;
    wire [15:0] vis_cuadros;
    wire [12:0] vis_pixeles_fg;
    wire [31:0] zona;
    wire [8:0]  linea;
    wire [1:0]  letrero;
    wire [255:0] cajas;
    wire [15:0] colores;

    registros_vision regs_vision (
        .clk(clk), .rst(rst),
        .offset(dmem_dir[7:0]), .we(dmem_we & sel_vis_m), .dato_esc(dmem_dato_esc), .dato_lec(vis_dato),
        .cam_sioc(cam_sioc), .cam_siod_bajo(siod_bajo), .cam_reset_n(cam_reset_n), .cam_pwdn(cam_pwdn),
        .cam_fase(cam_fase), .cam_siod_in(cam_siod),
        .vis_habilita(vis_habilita), .vis_umbral(vis_umbral), .vis_alfa(vis_alfa),
        .vis_aprender(vis_aprender), .vis_ver_mascara(vis_ver_mascara),
        .vis_cam_half(vis_cam_half), .vis_cam_fmt(vis_cam_fmt), .vis_ack(vis_ack),
        .vis_listo(vis_listo), .vis_banco(vis_banco), .vis_cuadros(vis_cuadros), .vis_pixeles_fg(vis_pixeles_fg),
        .zona(zona), .linea(linea), .letrero(letrero),
        .hud_personas(hud_personas), .hud_eventos(hud_eventos), .cajas(cajas), .colores(colores)
    );

    // SIOD de drenador abierto: la FPGA solo lo pone en 0 o lo suelta (pull-up)
    assign cam_siod = siod_bajo ? 1'b0 : 1'bz;

    // ---------------- tuberia de vision ----------------
    wire [31:0] msk_dato;

    vision_vigia #(
        .width(VID_ANCHO), .height(VID_ALTO), .block_log2(BLOQUE_LOG2), .vga_scale(VGA_ESCALA_LOG2)
    ) vision (
        .clk(clk), .clk50(clk50), .rst(rst),
        .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync), .cam_d(cam_d),
        .habilita(vis_habilita), .cam_half(vis_cam_half), .cam_fmt(vis_cam_fmt),
        .umbral(vis_umbral), .alfa(vis_alfa), .aprender(vis_aprender),
        .ver_mascara(vis_ver_mascara), .patron(interruptores[8]), .ack(vis_ack),
        .listo(vis_listo), .banco_lec(vis_banco), .cuadros(vis_cuadros), .pixeles_fg(vis_pixeles_fg),
        .zona(zona), .linea(linea), .letrero(letrero), .cajas(cajas), .colores(colores),
        .hud_personas(hud_personas), .hud_eventos(hud_eventos),
        .cpu_msk_dir(dmem_dir_e[12:2]), .cpu_msk_dato(msk_dato),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs)
    );

    // ---------------- dato leido (etapa MEM) ----------------
    assign dmem_dato_lec = sel_ram_m   ? ram_dato   :
                           sel_rom_m   ? rom_dato   :
                           sel_msk_m   ? msk_dato   :
                           sel_vis_m   ? vis_dato   :
                           sel_perif_m ? perif_dato : 32'd0;
endmodule
