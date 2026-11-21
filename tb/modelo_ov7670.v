`timescale 1ns / 1ps
// ============================================================
// MODELO DE LA CAMARA OV7670 PARA SIMULACION (no es hardware)
//
// Imita lo que el SoC necesita de la camara real:
//   * SCCB: escribir registros (ID 0x42) y leerlos (ID 0x43); PID = 0x76,
//     VER = 0x73; COM7[7] reinicia los registros.
//   * Reloj interno = XCLK x PLL / (2 x (CLKRC[5:0] + 1)), como se midio en la
//     camara real (el PLL sale de DBLV[7:6]: x1, x4, x6 o x8).
//   * Tamano: ANCHO x ALTO (el sensor completo, VGA) o la mitad en cada eje
//     (QVGA) si se prende el escalado (COM3[2] y COM14[3], o COM7[4]); en
//     QVGA el PCLK va a la mitad del reloj interno.
//   * Formato YUV 4:2:2; el orden de bytes sale de TSLB[3]
//     (por omision U Y V Y; el programa debe pedir Y U Y V).
//   * Tiempos: VSYNC alto al inicio del cuadro, HREF alto en cada linea
//     activa; los datos cambian en el flanco de bajada de PCLK.
// La imagen es sintetica y a color: pared con textura, piso mas claro, ruido
// de sensor y, segun 'escena', un perro cafe o una persona de azul que camina.
// Con 'movida' = 1 todo el fondo cambia de golpe, como cuando mueven la camara.
// La escena esta dibujada en una rejilla de 160 x 120 y se escala al tamano
// que entrega la camara.
// ============================================================
module modelo_ov7670 #(
    parameter ANCHO    = 320,     // sensor completo (en la camara real: 640 x 480)
    parameter ALTO     = 240,
    parameter H_BLANCO = 24,      // pixeles de borrado por linea
    parameter V_SYNC   = 2,       // lineas con VSYNC alto
    parameter V_BLANCO = 6        // lineas de borrado antes de la imagen
) (
    input  wire       xclk,
    input  wire       resetb,
    input  wire       pwdn,
    output reg        pclk,
    output reg        href,
    output reg        vsync,
    output reg  [7:0] d,
    input  wire       sioc,
    inout  wire       siod
);
    // ---------------- registros ----------------
    reg [7:0] regs [0:255];
    integer i;

    task valores_iniciales;
        begin
            for (i = 0; i < 256; i = i + 1) regs[i] = 8'h00;
            regs[8'h0A] = 8'h76;  regs[8'h0B] = 8'h73;          // PID, VER
            regs[8'h11] = 8'h80;  regs[8'h12] = 8'h00;          // CLKRC, COM7
            regs[8'h13] = 8'h8F;  regs[8'h3A] = 8'h0D;          // COM8, TSLB
            regs[8'h3D] = 8'h88;  regs[8'h40] = 8'hC0;          // COM13, COM15
            regs[8'h1C] = 8'h7F;  regs[8'h1D] = 8'hA2;          // MIDH, MIDL
            regs[8'h6B] = 8'h0A;                                // DBLV: PLL sin multiplicar
        end
    endtask

    initial valores_iniciales;
    always @(negedge resetb) valores_iniciales;

    integer escrituras = 0, lecturas = 0;

    // ---------------- esclavo SCCB ----------------
    reg       sda_bajo = 1'b0;
    assign siod = sda_bajo ? 1'b0 : 1'bz;

    reg       activa = 1'b0;
    reg [3:0] cuenta;             // flancos de subida de SIOC en el byte (0..9)
    reg [7:0] rx;
    reg [1:0] fase;               // 0: ID, 1: subdireccion, 2: dato
    reg       transmite;
    reg [7:0] sub = 8'h00;
    reg [7:0] tx;

    // inicio: SIOD baja con SIOC en alto
    always @(negedge siod) if (sioc === 1'b1) begin
        activa = 1'b1; cuenta = 0; fase = 0; transmite = 1'b0; sda_bajo = 1'b0;
    end
    // fin: SIOD sube con SIOC en alto
    always @(posedge siod) if (sioc === 1'b1) begin
        activa = 1'b0; sda_bajo = 1'b0;
    end

    always @(posedge sioc) if (activa) begin
        if (cuenta < 8 && !transmite) rx = {rx[6:0], (siod === 1'b0) ? 1'b0 : 1'b1};
        cuenta = (cuenta == 8) ? 0 : cuenta + 1;
    end

    always @(negedge sioc) if (activa) begin
        if (cuenta == 8) begin
            if (!transmite) begin
                case (fase)
                    2'd0: if (rx == 8'h43) begin transmite = 1'b1; tx = regs[sub]; lecturas = lecturas + 1; end
                    2'd1: sub = rx;
                    2'd2: begin
                        regs[sub] = rx;
                        escrituras = escrituras + 1;
                        if (sub == 8'h12 && rx[7]) valores_iniciales;
                    end
                    default: ;
                endcase
                fase = fase + 1;
                sda_bajo = 1'b1;                     // reconocimiento en el noveno bit
            end else begin
                sda_bajo  = 1'b0;                    // el maestro manda NA: fin de la lectura
                transmite = 1'b0;
            end
        end else if (cuenta == 0) begin
            sda_bajo = transmite ? ~tx[7] : 1'b0;    // suelta el reconocimiento o saca el bit 7
        end else if (transmite) begin
            sda_bajo = ~tx[7 - cuenta];
        end
    end

    // ---------------- reloj de pixel ----------------
    // Se mide el periodo de XCLK y PCLK se genera con el periodo que resulta de
    // los registros: T = T_xclk x 2 x (CLKRC + 1) / PLL, y el doble en QVGA.
    realtime t_ant = 0, t_xclk = 40;
    always @(posedge xclk) begin
        if (t_ant != 0) t_xclk = $realtime - t_ant;
        t_ant = $realtime;
    end

    wire       qvga = (regs[8'h0C][2] & regs[8'h3E][3]) | regs[8'h12][4];

    function integer pll_de;                  // multiplicador del PLL segun DBLV[7:6]
        input [1:0] b;
        begin
            case (b)
                2'b01:   pll_de = 4;
                2'b10:   pll_de = 6;
                2'b11:   pll_de = 8;
                default: pll_de = 1;
            endcase
        end
    endfunction

    realtime medio_pclk = 80;                 // medio periodo de PCLK en ns
    initial pclk = 1'b0;
    always begin
        medio_pclk = t_xclk * (regs[8'h11][5:0] + 1) * (qvga ? 2 : 1) / pll_de(regs[8'h6B][7:6]);
        if (!(medio_pclk >= 1)) medio_pclk = 80;      // registros sin valor todavia
        #(medio_pclk);
        if (!resetb || pwdn) pclk = 1'b0;
        else                 pclk = ~pclk;
    end

    // ---------------- escena ----------------
    reg [1:0] escena = 2'd0;      // 0 vacia, 1 perro, 2 persona (lo controla el testbench)
    reg       movida = 1'b0;      // 1 = movieron la camara: ahora ve otra pared, mas clara
    integer   t_escena = 0;       // cuadros desde que empezo la escena
    integer   cuadros  = 0;
    reg [15:0] lfsr = 16'hACE1;

    function [7:0] luminancia;
        input integer x, y;
        integer fondo, cx, k, dx, dy, pierna;
        begin
            fondo = 150 + ((y > 80) ? 20 : 0) + ((((x >> 3) ^ (y >> 3)) & 1) ? 6 : 0);
            if (movida)
                fondo = 222 + ((y > 80) ? 10 : 0) + ((((x >> 4) ^ (y >> 3)) & 1) ? 6 : 0);
            luminancia = fondo;
            if (escena == 2'd1) begin
                // perro: camina de derecha a izquierda por el piso
                cx = 150 - 10 * t_escena;
                dx = x - cx; dy = y - 96;
                if (dx * dx * 49 + dy * dy * 576 <= 576 * 49) luminancia = 60;           // cuerpo 24 x 7
                for (k = -1; k <= 1; k = k + 2) begin
                    if ((x >= cx + 15 * k - 2) && (x <= cx + 15 * k + 1) && (y >= 100) && (y <= 112)) luminancia = 60;
                    if ((x >= cx + 8 * k - 2)  && (x <= cx + 8 * k + 1)  && (y >= 100) && (y <= 112)) luminancia = 60;
                end
                dx = x - (cx - 26); dy = y - 89;
                if (dx * dx + dy * dy <= 36) luminancia = 60;                               // cabeza
                if ((x >= cx + 22) && (x <= cx + 32) && (y >= 90) && (y <= 92)) luminancia = 60;   // cola
            end
            if (escena == 2'd2) begin
                // persona: camina de izquierda a derecha y se queda en la zona
                cx = 10 + 8 * t_escena;
                if (cx > 120) cx = 120;
                pierna = (cx < 120) ? ((t_escena & 1) ? 4 : -2) : 0;
                dx = x - cx; dy = y - 30;
                if (dx * dx * 81 + dy * dy * 64 <= 64 * 81) luminancia = 45;               // cabeza 8 x 9
                if ((x >= cx - 3) && (x <= cx + 3) && (y >= 38) && (y <= 41)) luminancia = 45;      // cuello
                if ((x >= cx - 12) && (x <= cx + 12) && (y >= 41) && (y <= 72)) luminancia = 45;    // torso
                if ((x >= cx - 16) && (x <= cx - 13) && (y >= 43) && (y <= 72)) luminancia = 45;    // brazos
                if ((x >= cx + 13) && (x <= cx + 16) && (y >= 43) && (y <= 72)) luminancia = 45;
                if ((x >= cx - 10 - pierna) && (x <= cx - 3 - pierna) && (y >= 72) && (y <= 112)) luminancia = 45;  // piernas
                if ((x >= cx + 3 + pierna)  && (x <= cx + 10 + pierna) && (y >= 72) && (y <= 112)) luminancia = 45;
            end
        end
    endfunction

    // color {U, V} de la escena: pared calida, piso verdoso, perro cafe, persona de azul
    function [15:0] color;
        input integer x, y;
        reg [7:0] l;
        begin
            l = luminancia(x, y);
            if (l == 60)       color = {8'd110, 8'd150};      // perro: cafe
            else if (l == 45)  color = {8'd165, 8'd112};      // persona: azul
            else if (y > 80)   color = {8'd120, 8'd124};      // piso
            else               color = {8'd124, 8'd134};      // pared
        end
    endfunction

    // ---------------- generador de video ----------------
    wire [31:0] ancho_sal = qvga ? ANCHO / 2 : ANCHO;
    wire [31:0] alto_sal  = qvga ? ALTO  / 2 : ALTO;
    wire [31:0] bytes_linea = (ancho_sal + H_BLANCO) * 2;
    wire [31:0] lineas      = V_SYNC + V_BLANCO + alto_sal + 2;

    integer col = 0, lin = 0;
    integer px, fila, xs, ys;
    reg     y_primero;
    reg [7:0]  lum;
    reg [15:0] uv;

    initial begin href = 1'b0; vsync = 1'b0; d = 8'h00; end

    always @(negedge pclk) begin
        if (!resetb || pwdn) begin
            col <= 0; lin <= 0; href <= 1'b0; vsync <= 1'b0;
        end else begin
            // avanza la posicion
            if (col >= bytes_linea - 1) begin
                col <= 0;
                if (lin >= lineas - 1) begin
                    lin <= 0;
                    cuadros  <= cuadros + 1;
                    t_escena <= t_escena + 1;
                end else begin
                    lin <= lin + 1;
                end
            end else begin
                col <= col + 1;
            end
            // salidas para la posicion actual
            vsync <= (lin < V_SYNC);
            fila  = lin - V_SYNC - V_BLANCO;
            if (fila >= 0 && fila < alto_sal && col < 2 * ancho_sal) begin
                href <= 1'b1;
                px   = col >> 1;
                xs   = (px * 160) / ancho_sal;                 // posicion en la rejilla de la escena
                ys   = (fila * 120) / alto_sal;
                y_primero = ~regs[8'h3A][3];                   // TSLB[3] = 0 -> Y en los bytes pares
                if ((col[0] == 1'b0) == y_primero) begin
                    lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                    lum  = luminancia(xs, ys) + lfsr[2:0] - 8'd3;   // ruido de sensor +-3
                    d   <= lum;
                end else begin
                    uv   = color(((px >> 1) * 320) / ancho_sal, ys);   // color de la pareja de pixeles
                    d   <= px[0] ? uv[7:0] : uv[15:8];          // primero U, luego V
                end
            end else begin
                href <= 1'b0;
                d    <= 8'h00;
            end
        end
    end
endmodule
