`timescale 1ns / 1ps
// ============================================================
// UNIDAD DE ACCESO A MEMORIA (Practica 4: accesos parciales)
// Las memorias son sincronas, asi que el acceso se reparte en dos etapas:
//   EX : se forma la direccion de palabra, las habilitaciones por byte y
//        el dato a escribir (sb/sh/sw). La RAM escribe o lee en el flanco.
//   MEM: llega la palabra leida; se elige el byte o media palabra segun
//        dir[1:0] y se extiende el signo (lb/lh) o se rellena con ceros
//        (lbu/lhu).
// Un acceso no alineado (lh/sh con direccion impar, lw/sw no multiplo de
// 4) se marca con 'desalineado'; el diseno no lo soporta.
// ============================================================
module unidad_acceso_memoria (
    // ---- etapa EX ----
    input  wire [31:0] dir_e,
    input  wire [2:0]  funct3_e,
    input  wire [31:0] dato_reg_e,     // rs2 ya adelantado
    input  wire        mem_read_e,
    input  wire        mem_write_e,
    output wire [31:0] dmem_dir_e,
    output reg  [31:0] dmem_dato_esc_e,
    output reg  [3:0]  dmem_be_e,
    output wire        dmem_we_e,
    output wire        dmem_re_e,
    output wire        desalineado,

    // ---- etapa MEM ----
    input  wire [1:0]  despl_m,        // dir[1:0] de la instruccion en MEM
    input  wire [2:0]  funct3_m,
    input  wire [31:0] dato_mem_m,     // palabra leida
    output reg  [31:0] dato_ext_m
);
    wire [1:0] despl_e = dir_e[1:0];

    assign dmem_dir_e = {dir_e[31:2], 2'b00};
    assign dmem_we_e  = mem_write_e;
    assign dmem_re_e  = mem_read_e;

    // ---- escritura: colocar el byte / media palabra en su carril ----
    always @(*) begin
        case (funct3_e[1:0])
            2'b00: begin                                            // sb
                dmem_be_e       = 4'b0001 << despl_e;
                dmem_dato_esc_e = {4{dato_reg_e[7:0]}};
            end
            2'b01: begin                                            // sh
                dmem_be_e       = despl_e[1] ? 4'b1100 : 4'b0011;
                dmem_dato_esc_e = {2{dato_reg_e[15:0]}};
            end
            default: begin                                          // sw
                dmem_be_e       = 4'b1111;
                dmem_dato_esc_e = dato_reg_e;
            end
        endcase
    end

    assign desalineado = (mem_read_e | mem_write_e) &
                         ((funct3_e[1:0] == 2'b01 && despl_e[0]) |
                          (funct3_e[1:0] == 2'b10 && despl_e != 2'b00));

    // ---- lectura: seleccionar el carril y extender ----
    wire [31:0] despl_bits = dato_mem_m >> {despl_m, 3'b000};       // despl * 8
    wire [7:0]  byte_sel   = despl_bits[7:0];
    wire [15:0] half_sel   = despl_bits[15:0];

    always @(*) begin
        case (funct3_m)
            3'b000:  dato_ext_m = {{24{byte_sel[7]}},  byte_sel};   // lb
            3'b001:  dato_ext_m = {{16{half_sel[15]}}, half_sel};   // lh
            3'b010:  dato_ext_m = dato_mem_m;                       // lw
            3'b100:  dato_ext_m = {24'b0, byte_sel};                // lbu
            3'b101:  dato_ext_m = {16'b0, half_sel};                // lhu
            default: dato_ext_m = dato_mem_m;
        endcase
    end
endmodule
