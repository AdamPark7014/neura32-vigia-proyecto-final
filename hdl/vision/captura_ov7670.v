`timescale 1ns / 1ps

// captura OV7670
module captura_ov7670 #(
    parameter CAM_ANCHO      = 640,
    parameter CAM_ALTO       = 480,
    parameter VID_DECIM_LOG2 = 1,
    parameter BLOQUE_LOG2    = 3
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        habilita,

    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    input  wire [7:0]  cam_d,

    output reg         vid_we,
    output reg  [16:0] vid_dir,
    output reg  [3:0]  vid_dato,
    output reg  [7:0]  vid_lum,

    output reg         prom_valido,
    output reg  [6:0]  prom_x,
    output reg  [5:0]  prom_y,
    output reg  [7:0]  prom_dato,

    output reg         cuadro_inicio
);
    localparam VID_ANCHO = CAM_ANCHO >> VID_DECIM_LOG2;
    localparam BLOQUE    = 1 << BLOQUE_LOG2;
    localparam BLQ_ANCHO = CAM_ANCHO >> BLOQUE_LOG2;
    localparam [9:0] MASK_V = (1 << VID_DECIM_LOG2) - 1;
    localparam [9:0] MASK_B = BLOQUE - 1;

    // sincronizadores
    reg [2:0] pclk_s, href_s, vsync_s;
    reg [7:0] d_s1, d_s2;

    always @(posedge clk) begin
        pclk_s  <= {pclk_s[1:0],  cam_pclk};
        href_s  <= {href_s[1:0],  cam_href};
        vsync_s <= {vsync_s[1:0], cam_vsync};
        d_s1    <= cam_d;
        d_s2    <= d_s1;
    end

    wire pclk_sube  =  pclk_s[1] & ~pclk_s[2];
    wire href       =  href_s[1];
    wire href_baja  = ~href_s[1] &  href_s[2];
    wire vsync      =  vsync_s[1];
    wire vsync_sube =  vsync_s[1] & ~vsync_s[2];

    // bytes a pixeles
    reg [9:0] x, y;
    reg       byte_uv;
    reg       pix_valido;
    reg [7:0] pix_lum;
    reg [9:0] pix_x, pix_fila;

    always @(posedge clk) begin
        pix_valido    <= 1'b0;
        cuadro_inicio <= 1'b0;
        if (rst || !habilita) begin
            x <= 10'd0; y <= 10'd0; byte_uv <= 1'b0;
        end else if (vsync) begin
            x <= 10'd0; y <= 10'd0; byte_uv <= 1'b0;
            cuadro_inicio <= vsync_sube;
        end else if (href_baja) begin
            x <= 10'd0; byte_uv <= 1'b0;
            y <= y + 10'd1;
        end else if (pclk_sube && href) begin
            byte_uv <= ~byte_uv;
            if (!byte_uv) begin
                pix_valido <= (x < CAM_ANCHO) && (y < CAM_ALTO);
                pix_lum    <= d_s2;
                pix_x      <= x;
                pix_fila   <= y;
                x          <= x + 10'd1;
            end
        end
    end

    // video para el monitor
    always @(posedge clk) begin
        vid_we <= 1'b0;
        if (pix_valido && ((pix_x & MASK_V) == 10'd0) && ((pix_fila & MASK_V) == 10'd0)) begin
            vid_we   <= 1'b1;
            vid_dir  <= (pix_fila >> VID_DECIM_LOG2) * VID_ANCHO + (pix_x >> VID_DECIM_LOG2);
            vid_dato <= pix_lum[7:4];
            vid_lum  <= pix_lum;
        end
    end

    // promedio
    wire [9:0] bx     = pix_x    & MASK_B;
    wire [9:0] by     = pix_fila & MASK_B;
    wire [6:0] col    = pix_x    >> BLOQUE_LOG2;
    wire [5:0] fila_b = pix_fila >> BLOQUE_LOG2;

    reg  [10:0] suma_h;
    reg  [15:0] acc [0:BLQ_ANCHO-1];
    reg  [15:0] acc_q;
    reg  [6:0]  acc_dir;
    wire [15:0] total_h = suma_h + pix_lum;
    wire [15:0] total_b = acc_q + total_h;

    integer i;
    initial for (i = 0; i < BLQ_ANCHO; i = i + 1) acc[i] = 16'd0;

    always @(posedge clk) acc_q <= acc[acc_dir];

    always @(posedge clk) begin
        prom_valido <= 1'b0;
        if (pix_valido) begin
            if (bx == 10'd0) begin
                suma_h  <= {3'd0, pix_lum};
                acc_dir <= col;
            end else begin
                suma_h  <= suma_h + pix_lum;
            end
            if (bx == MASK_B) begin
                acc[col] <= (by == 10'd0) ? total_h : total_b;
                if (by == MASK_B) begin
                    prom_valido <= 1'b1;
                    prom_x      <= col;
                    prom_y      <= fila_b;
                    prom_dato   <= total_b >> (2 * BLOQUE_LOG2);
                end
            end
        end
    end
endmodule
