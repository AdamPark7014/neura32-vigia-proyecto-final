`timescale 1ns / 1ps

// registros de vision
module registros_vision (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  offset,
    input  wire        we,
    input  wire [31:0] dato_esc,
    output reg  [31:0] dato_lec,

    // camara
    output reg         cam_sioc,
    output reg         cam_siod_bajo,
    output reg         cam_reset_n,
    output reg         cam_pwdn,
    output wire [1:0]  cam_fase,
    input  wire        cam_siod_in,

    // vision
    output wire        vis_habilita,
    output wire [7:0]  vis_umbral,
    output wire [3:0]  vis_alfa,
    output wire        vis_aprender,
    output wire        vis_ver_mascara,
    output wire        vis_cam_half,
    output wire [1:0]  vis_cam_fmt,
    output reg         vis_ack,
    input  wire        vis_listo,
    input  wire        vis_banco,
    input  wire [15:0] vis_cuadros,
    input  wire [12:0] vis_pixeles_fg,

    // dibujo
    output reg  [31:0] zona,
    output reg  [8:0]  linea,
    output reg  [1:0]  letrero,
    output reg  [3:0]  hud_personas,
    output reg  [7:0]  hud_eventos,
    output wire [255:0] cajas,
    output reg  [15:0] colores
);
    reg [31:0] vis_ctrl;
    reg [31:0] caja [0:7];
    reg [1:0]  siod_s;

    assign vis_habilita    = vis_ctrl[0];
    assign vis_umbral      = vis_ctrl[15:8];
    assign vis_alfa        = vis_ctrl[19:16];
    assign vis_aprender    = vis_ctrl[20];
    assign vis_ver_mascara = vis_ctrl[21];
    assign vis_cam_half    = vis_ctrl[22];
    assign vis_cam_fmt     = vis_ctrl[24:23];
    assign cam_fase        = vis_ctrl[26:25];

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : g_cajas
            assign cajas[32*gi +: 32] = caja[gi];
        end
    endgenerate

    always @(posedge clk) siod_s <= {siod_s[0], cam_siod_in};

    always @(*) begin
        case (offset)
            8'h40:   dato_lec = {28'd0, cam_pwdn, cam_reset_n, cam_siod_bajo, cam_sioc};
            8'h44:   dato_lec = {30'd0, cam_sioc, siod_s[1]};
            8'h48:   dato_lec = vis_ctrl;
            8'h4C:   dato_lec = {vis_cuadros, 14'd0, vis_banco, vis_listo};
            8'h50:   dato_lec = {19'd0, vis_pixeles_fg};
            8'h54:   dato_lec = zona;
            8'h58:   dato_lec = {23'd0, linea};
            8'h5C:   dato_lec = {8'd0, hud_eventos, 4'd0, hud_personas, 6'd0, letrero};
            8'h60:   dato_lec = caja[0];
            8'h64:   dato_lec = caja[1];
            8'h68:   dato_lec = caja[2];
            8'h6C:   dato_lec = caja[3];
            8'h70:   dato_lec = caja[4];
            8'h74:   dato_lec = caja[5];
            8'h78:   dato_lec = caja[6];
            8'h7C:   dato_lec = caja[7];
            8'h80:   dato_lec = {16'd0, colores};
            default: dato_lec = 32'd0;
        endcase
    end

    integer i;
    always @(posedge clk) begin
        vis_ack <= 1'b0;
        if (rst) begin
            cam_sioc <= 1'b1; cam_siod_bajo <= 1'b0; cam_reset_n <= 1'b0; cam_pwdn <= 1'b0;
            hud_personas <= 4'd0; hud_eventos <= 8'd0;
            vis_ctrl <= 32'h04000000; zona <= 32'd0; linea <= 9'd0; letrero <= 2'd0; colores <= 16'd0;
            for (i = 0; i < 8; i = i + 1) caja[i] <= 32'd0;
        end else if (we) begin
            case (offset)
                8'h40: {cam_pwdn, cam_reset_n, cam_siod_bajo, cam_sioc} <= dato_esc[3:0];
                8'h48: vis_ctrl <= dato_esc;
                8'h4C: vis_ack  <= dato_esc[0];
                8'h54: zona     <= dato_esc;
                8'h58: linea    <= dato_esc[8:0];
                8'h5C: begin letrero <= dato_esc[1:0]; hud_personas <= dato_esc[11:8]; hud_eventos <= dato_esc[23:16]; end
                8'h60: caja[0]  <= dato_esc;
                8'h64: caja[1]  <= dato_esc;
                8'h68: caja[2]  <= dato_esc;
                8'h6C: caja[3]  <= dato_esc;
                8'h70: caja[4]  <= dato_esc;
                8'h74: caja[5]  <= dato_esc;
                8'h78: caja[6]  <= dato_esc;
                8'h7C: caja[7]  <= dato_esc;
                8'h80: colores  <= dato_esc[15:0];
                default: ;
            endcase
        end
    end
endmodule
