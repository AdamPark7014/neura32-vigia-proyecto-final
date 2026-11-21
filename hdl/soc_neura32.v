`timescale 1ns / 1ps
// ============================================================
// SISTEMA NEURA-32 VIGIA: el procesador (riscv_neura) con sus entradas
// y salidas: LED, interruptores, displays, camara OV7670, vision y
// monitor VGA, mas el cargador de programas por JTAG.
//
// MAPA DE MEMORIA
//   0x0000_0000 - 0x0000_3FFF  memoria de programa (dentro del procesador)
//   0x1000_0000 - 0x1000_3FFF  memoria de datos (dentro del procesador)
//   0x2000_0000 - 0x2000_12BF  mascara de movimiento 80 x 60 (1 byte por celda, solo lectura)
//   0xFFFF_0000 - 0xFFFF_003F  perifericos (LED, SW, HEX, KEY, contador de ciclos, consola)
//   0xFFFF_0040 - 0xFFFF_009F  camara y vision (SCCB, captura, zona, linea, cajas)
//
// El procesador pone la direccion un ciclo antes (io_addr_pre) para la
// mascara, que es una memoria sincrona; los registros se leen con io_addr.
// ============================================================
module soc_neura32 #(
    parameter ARCHIVO_PROGRAMA = "programa_vigia.txt",   // instrucciones en hexadecimal
    parameter SIMULACION       = 0,
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

    output wire        fin,          // el programa termino (ecall)
    output wire        instr_ilegal,
    output wire [31:0] ciclos,
    output wire [31:0] instret
);
    // ---------------- cargador de programas (JTAG) ----------------
    // Mientras la PC escribe otro programa, todo el sistema queda en reinicio.
    wire        cargar_we, detener;
    wire [11:0] cargar_dir;
    wire [31:0] cargar_dato;

    jtag_loader cargador (
        .clk(clk), .rst(~rst_ext),
        .load_we(cargar_we), .load_addr(cargar_dir), .load_data(cargar_dato),
        .halt(detener), .leds(leds), .hex(hex)
    );

    wire rst = rst_ext | detener;    // reinicio de los perifericos (activo en alto)

    // ---------------- procesador ----------------
    wire [31:0] io_addr_pre, io_addr, io_wdata, io_rdata, resultado;
    wire        io_we, io_re;

    riscv_neura #(.INIT_FILE(ARCHIVO_PROGRAMA)) cpu (
        .clk(clk), .rst(~rst),
        .result_out(resultado),
        .io_addr_pre(io_addr_pre), .io_addr(io_addr), .io_wdata(io_wdata),
        .io_we(io_we), .io_re(io_re), .io_rdata(io_rdata),
        .load_we(cargar_we), .load_addr(cargar_dir), .load_data(cargar_dato),
        .halted(fin), .illegal(instr_ilegal), .cycles(ciclos), .instrs(instret)
    );

    // ---------------- decodificacion de direcciones ----------------
    wire sel_msk   = (io_addr[31:28] == 4'h2);
    wire sel_perif = (io_addr[31:16] == 16'hFFFF);
    wire sel_vis   = sel_perif && (io_addr[7:6] != 2'b00);   // 0x40 en adelante

    // ---------------- perifericos basicos ----------------
    wire [31:0] perif_dato, ticks, lfsr;
    perifericos #(.SIMULACION(SIMULACION)) perif (
        .clk(clk), .rst(rst),
        .dir(io_addr), .dato_esc(io_wdata), .we(io_we & sel_perif & ~sel_vis),
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
        .offset(io_addr[7:0]), .we(io_we & sel_vis), .dato_esc(io_wdata), .dato_lec(vis_dato),
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
        .cpu_msk_dir(io_addr_pre[12:2]), .cpu_msk_dato(msk_dato),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_hs(vga_hs), .vga_vs(vga_vs)
    );

    // ---------------- dato que lee el procesador ----------------
    assign io_rdata = sel_msk   ? msk_dato   :
                      sel_vis   ? vis_dato   :
                      sel_perif ? perif_dato : 32'd0;
endmodule
