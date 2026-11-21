`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// NEURA-32 — NUCLEO RISC-V RV32IM + Zicsr + Zicntr + Xneura
// Pipeline de 5 etapas: IF -> ID -> EX -> MEM -> WB
//   * memorias sincronas (bloques M9K): la ROM entrega la instruccion
//     en ID y la RAM entrega el dato en MEM (direccion desde EX)
//   * adelantamiento (forwarding) MEM->EX y WB->EX
//   * deteccion de riesgo carga-uso (1 ciclo de detencion)
//   * saltos resueltos en EX con las banderas de la ALU (2 ciclos de
//     penalizacion cuando el salto se toma)
//   * DIV/REM con divisor iterativo de 34 ciclos
//   * ecall / ebreak detienen el procesador de forma ordenada
// La ALU (alu_riscv, Practica 3) recibe la instruccion de la etapa EX y
// decide la operacion con opcode, funct3 y funct7.
// ============================================================
module nucleo_neura32 #(
    parameter ADELANTAR_CARGAS = 0
) (
    input  wire        clk,
    input  wire        rst,

    // Puerto de instrucciones (ROM sincrona)
    output wire [31:0] imem_dir,
    output wire        imem_en,
    input  wire [31:0] imem_instr,

    // Acceso a memorias sincronas (RAM, ROM de datos, mascara): direccion en EX
    output wire [31:0] dmem_dir_e,
    output wire [31:0] dmem_dato_esc_e,
    output wire [3:0]  dmem_be_e,
    output wire        dmem_we_e,
    output wire        dmem_re_e,

    // Acceso a perifericos: etapa MEM (escritura al final de MEM, lectura combinacional)
    output wire [31:0] dmem_dir,
    output wire [31:0] dmem_dato_esc,
    output wire [3:0]  dmem_be,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_dato_lec,   // palabra leida, valida en MEM

    // Estado
    output reg         fin,            // se activo ecall/ebreak y el pipeline ya vacio
    output wire        instr_ilegal,   // pulso: una instruccion ilegal llego a EX
    output wire        desalineado,    // pulso: acceso a memoria no alineado
    output wire [63:0] ciclos,
    output wire [63:0] instret
);

    // ============================================================
    // Senales de control del pipeline
    // ============================================================
    wire parar_f, parar_d, limpiar_d, limpiar_e, parar_e;
    wire salto_tomado_e;
    wire [31:0] destino_e;
    reg  detenido;
    wire detener;

    // ============================================================
    // ETAPA IF — contador de programa
    // La ROM es sincrona: en el flanco toma pc_f y su registro de salida
    // es la instruccion de la etapa ID (el registro IF/ID de la instruccion).
    // ============================================================
    reg  [31:0] pc_f;
    wire [31:0] pc_mas4_f = pc_f + 32'd4;

    always @(posedge clk) begin
        if (rst)                 pc_f <= 32'd0;
        else if (salto_tomado_e) pc_f <= destino_e;
        else if (!parar_f)       pc_f <= pc_mas4_f;
    end

    assign imem_dir = pc_f;
    assign imem_en  = ~parar_d;

    // ---- registro IF/ID (PC y validez; la instruccion la guarda la ROM) ----
    reg [31:0] pc_d;
    reg        valido_d;

    always @(posedge clk) begin
        if (rst || limpiar_d) begin
            pc_d     <= 32'd0;
            valido_d <= 1'b0;
        end else if (!parar_d) begin
            pc_d     <= pc_f;
            valido_d <= 1'b1;
        end
    end

    wire [31:0] instr_d = valido_d ? imem_instr : `NOP;

    // ============================================================
    // ETAPA ID — decodificacion, inmediato y banco de registros
    // ============================================================
    wire [6:0] opcode_d = instr_d[6:0];
    wire [4:0] rd_d     = instr_d[11:7];
    wire [2:0] funct3_d = instr_d[14:12];
    wire [4:0] rs1_d    = instr_d[19:15];
    wire [4:0] rs2_d    = instr_d[24:20];
    wire [6:0] funct7_d = instr_d[31:25];

    wire       reg_write_d, sel_a_pc_d, alu_src_b_d, mem_read_d, mem_write_d;
    wire       branch_d, jump_d, jalr_d, csr_we_d, csr_imm_d;
    wire       es_fin_d, ilegal_d;
    wire [2:0] tipo_inm_d;
    wire [1:0] res_sel_d, csr_tipo_d;

    unidad_control control (
        .instr(instr_d),
        .reg_write(reg_write_d), .sel_a_pc(sel_a_pc_d), .alu_src_b(alu_src_b_d),
        .mem_read(mem_read_d), .mem_write(mem_write_d),
        .res_sel(res_sel_d), .branch(branch_d), .jump(jump_d), .jalr(jalr_d),
        .csr_we(csr_we_d), .csr_tipo(csr_tipo_d), .csr_imm(csr_imm_d),
        .es_fin(es_fin_d), .ilegal(ilegal_d), .tipo_inm(tipo_inm_d)
    );

    wire [31:0] inm_d;
    generador_inmediato gen_inm (.instr(instr_d), .tipo(tipo_inm_d), .inm(inm_d));

    // WB escribe el banco; las lecturas ven el valor nuevo en el mismo ciclo
    wire [31:0] rd1_d, rd2_d;
    wire [31:0] resultado_w;
    reg  [4:0]  rd_w;
    reg         reg_write_w;

    banco_registros banco (
        .clk(clk), .we(reg_write_w), .wa(rd_w), .wd(resultado_w),
        .ra1(rs1_d), .rd1(rd1_d), .ra2(rs2_d), .rd2(rd2_d)
    );

    // ---- registro ID/EX ----
    reg [31:0] rd1_e, rd2_e, inm_e, pc_e;
    reg [11:0] csr_dir_e;
    reg [4:0]  rs1_e, rs2_e, rd_e;
    reg [6:0]  opcode_e, funct7_e;
    reg [2:0]  funct3_e;
    reg [1:0]  res_sel_e, csr_tipo_e;
    reg        reg_write_e, sel_a_pc_e, alu_src_b_e, mem_read_e, mem_write_e;
    reg        branch_e, jump_e, jalr_e, csr_we_e, csr_imm_e;
    reg        es_fin_e, ilegal_e, valido_e;

    always @(posedge clk) begin
        if (rst || limpiar_e) begin
            rd1_e <= 32'd0; rd2_e <= 32'd0; inm_e <= 32'd0; pc_e <= 32'd0; csr_dir_e <= 12'd0;
            rs1_e <= 5'd0; rs2_e <= 5'd0; rd_e <= 5'd0;
            opcode_e <= 7'b0010011; funct7_e <= 7'd0; funct3_e <= 3'd0;      // burbuja = NOP (addi x0, x0, 0)
            res_sel_e <= `RES_ALU; csr_tipo_e <= 2'd0;
            reg_write_e <= 1'b0; sel_a_pc_e <= 1'b0; alu_src_b_e <= 1'b0;
            mem_read_e <= 1'b0; mem_write_e <= 1'b0;
            branch_e <= 1'b0; jump_e <= 1'b0; jalr_e <= 1'b0;
            csr_we_e <= 1'b0; csr_imm_e <= 1'b0;
            es_fin_e <= 1'b0; ilegal_e <= 1'b0; valido_e <= 1'b0;
        end else if (!parar_e) begin
            rd1_e <= rd1_d; rd2_e <= rd2_d; inm_e <= inm_d; pc_e <= pc_d; csr_dir_e <= instr_d[31:20];
            rs1_e <= rs1_d; rs2_e <= rs2_d; rd_e <= rd_d;
            opcode_e <= opcode_d; funct7_e <= funct7_d; funct3_e <= funct3_d;
            res_sel_e <= res_sel_d; csr_tipo_e <= csr_tipo_d;
            reg_write_e <= reg_write_d; sel_a_pc_e <= sel_a_pc_d; alu_src_b_e <= alu_src_b_d;
            mem_read_e <= mem_read_d; mem_write_e <= mem_write_d;
            branch_e <= branch_d; jump_e <= jump_d; jalr_e <= jalr_d;
            csr_we_e <= csr_we_d; csr_imm_e <= csr_imm_d;
            es_fin_e <= es_fin_d; ilegal_e <= ilegal_d; valido_e <= valido_d;
        end
    end

    // ============================================================
    // ETAPA EX — adelantamiento, ALU, divisor, saltos y CSR
    // ============================================================
    wire [1:0]  adel_a, adel_b;
    wire [31:0] resultado_m;
    reg  [4:0]  rd_m;
    reg         reg_write_m;

    unidad_adelantamiento adelanto (
        .rs1_e(rs1_e), .rs2_e(rs2_e),
        .rd_m(rd_m), .reg_write_m(reg_write_m),
        .rd_w(rd_w), .reg_write_w(reg_write_w),
        .adel_a(adel_a), .adel_b(adel_b)
    );

    wire [31:0] srca_e = (adel_a == 2'b10) ? resultado_m :
                         (adel_a == 2'b01) ? resultado_w : rd1_e;
    wire [31:0] srcb_e = (adel_b == 2'b10) ? resultado_m :
                         (adel_b == 2'b01) ? resultado_w : rd2_e;

    // Operandos A y B de la ALU
    wire [31:0] operando_a = sel_a_pc_e  ? pc_e  : srca_e;
    wire [31:0] operando_b = alu_src_b_e ? inm_e : srcb_e;

    // La instruccion de la etapa EX, armada con sus campos (formato tipo R):
    //   | funct7 | rs2 | rs1 | funct3 | rd | opcode |
    wire [31:0] instr_e = {funct7_e, rs2_e, rs1_e, funct3_e, rd_e, opcode_e};

    wire [31:0] alu_result_e;
    wire        ilegal_alu_e;
    wire        bandera_c, bandera_o, bandera_z_alu, bandera_n_alu;

    alu_riscv alu (
        .instr(instr_e), .A(operando_a), .B(operando_b),
        .result(alu_result_e), .ilegal(ilegal_alu_e),
        .C(bandera_c), .O(bandera_o), .Z(bandera_z_alu), .N(bandera_n_alu)
    );

    // ---- divisor iterativo: tipo R con funct7 = 0000001 y funct3 = 1xx ----
    //      100 div, 101 divu, 110 rem, 111 remu
    wire        es_div_e = valido_e && (opcode_e == `OP_R) && (funct7_e == 7'b0000001) && funct3_e[2];
    wire        div_listo;
    wire [31:0] div_resultado;

    divisor_iterativo divisor (
        .clk(clk), .rst(rst), .pedir(es_div_e),
        .con_signo(~funct3_e[0]),
        .quiere_resto(funct3_e[1]),
        .dividendo(operando_a), .divisor(operando_b),
        .listo(div_listo), .resultado(div_resultado)
    );

    assign parar_e = es_div_e & ~div_listo;

    wire [31:0] resultado_ex = es_div_e ? div_resultado : alu_result_e;

    // Decision de salto a partir de las banderas de la resta
    wire tomar_e;
    unidad_saltos saltos (
        .funct3(funct3_e), .C(bandera_c), .O(bandera_o), .Z(bandera_z_alu), .N(bandera_n_alu),
        .tomar(tomar_e)
    );

    assign salto_tomado_e = (branch_e & tomar_e) | jump_e;

    wire [31:0] base_salto    = jalr_e ? srca_e : pc_e;
    wire [31:0] destino_bruto = base_salto + inm_e;
    assign destino_e = {destino_bruto[31:1], 1'b0};

    wire [31:0] pc_mas4_e = pc_e + 32'd4;

    // Una instruccion ilegal detectada por la ALU no escribe nada
    wire reg_write_e_ef = reg_write_e & ~ilegal_alu_e;
    assign instr_ilegal = valido_e & (ilegal_e | ilegal_alu_e);

    // CSR: lectura y escritura en EX (las instrucciones en EX ya no se anulan)
    wire [31:0] csr_dato_esc = csr_imm_e ? {27'b0, rs1_e} : srca_e;
    wire [31:0] csr_dato_lec;
    reg         valido_w;

    registros_csr csr (
        .clk(clk), .rst(rst),
        .dir(csr_dir_e), .we(csr_we_e), .tipo(csr_tipo_e),
        .dato_esc(csr_dato_esc), .dato_lec(csr_dato_lec),
        .retirar(valido_w),
        .ciclos(ciclos), .instret(instret)
    );

    // ecall / ebreak: a partir de aqui no entra nada mas al pipeline
    assign detener = detenido | (es_fin_e & valido_e);
    always @(posedge clk) begin
        if (rst)          detenido <= 1'b0;
        else if (detener) detenido <= 1'b1;
    end

    // ---- acceso a memoria: la direccion y el dato a escribir salen de EX ----
    wire [31:0] dato_lec_m;
    reg  [31:0] alu_out_m;
    reg  [2:0]  funct3_m;
    wire [31:0] dir_esc_e;
    wire [31:0] dato_fmt_e;
    wire [3:0]  be_e;

    unidad_acceso_memoria acceso (
        .dir_e(resultado_ex), .funct3_e(funct3_e), .dato_reg_e(srcb_e),
        .mem_read_e(mem_read_e), .mem_write_e(mem_write_e),
        .dmem_dir_e(dir_esc_e), .dmem_dato_esc_e(dato_fmt_e), .dmem_be_e(be_e),
        .dmem_we_e(dmem_we_e), .dmem_re_e(dmem_re_e), .desalineado(desalineado),
        .despl_m(alu_out_m[1:0]), .funct3_m(funct3_m), .dato_mem_m(dmem_dato_lec),
        .dato_ext_m(dato_lec_m)
    );

    assign dmem_dir_e      = dir_esc_e;
    assign dmem_dato_esc_e = dato_fmt_e;
    assign dmem_be_e       = be_e;

    // ---- registro EX/MEM (burbuja mientras el divisor trabaja) ----
    reg [31:0] dato_esc_m, pc_mas4_m, csr_lec_m;
    reg [3:0]  be_m;
    reg [1:0]  res_sel_m;
    reg        mem_read_m, mem_write_m, es_fin_m, valido_m;

    always @(posedge clk) begin
        if (rst || parar_e) begin
            alu_out_m <= 32'd0; dato_esc_m <= 32'd0; pc_mas4_m <= 32'd0; csr_lec_m <= 32'd0;
            be_m <= 4'd0; rd_m <= 5'd0; funct3_m <= 3'd0; res_sel_m <= `RES_ALU;
            reg_write_m <= 1'b0; mem_read_m <= 1'b0; mem_write_m <= 1'b0;
            es_fin_m <= 1'b0; valido_m <= 1'b0;
        end else begin
            alu_out_m <= resultado_ex; dato_esc_m <= dato_fmt_e; pc_mas4_m <= pc_mas4_e; csr_lec_m <= csr_dato_lec;
            be_m <= be_e; rd_m <= rd_e; funct3_m <= funct3_e; res_sel_m <= res_sel_e;
            reg_write_m <= reg_write_e_ef; mem_read_m <= mem_read_e; mem_write_m <= mem_write_e;
            es_fin_m <= es_fin_e; valido_m <= valido_e;
        end
    end

    // ============================================================
    // ETAPA MEM — llega el dato de la memoria; perifericos
    // ============================================================
    assign dmem_dir      = {alu_out_m[31:2], 2'b00};
    assign dmem_dato_esc = dato_esc_m;
    assign dmem_be       = be_m;
    assign dmem_we       = mem_write_m;
    assign dmem_re       = mem_read_m;

    // Resultado de la instruccion en MEM (tambien es lo que se adelanta a EX)
    assign resultado_m = (res_sel_m == `RES_MEM) ? dato_lec_m :
                         (res_sel_m == `RES_PC4) ? pc_mas4_m  :
                         (res_sel_m == `RES_CSR) ? csr_lec_m  : alu_out_m;

    // ---- registro MEM/WB ----
    reg [31:0] resultado_w_r;
    reg        es_fin_w;

    always @(posedge clk) begin
        if (rst) begin
            resultado_w_r <= 32'd0; rd_w <= 5'd0;
            reg_write_w <= 1'b0; es_fin_w <= 1'b0; valido_w <= 1'b0;
        end else begin
            resultado_w_r <= resultado_m; rd_w <= rd_m;
            reg_write_w <= reg_write_m; es_fin_w <= es_fin_m; valido_w <= valido_m;
        end
    end

    // ============================================================
    // ETAPA WB — escritura del banco (dentro de banco_registros)
    // ============================================================
    assign resultado_w = resultado_w_r;

    always @(posedge clk) begin
        if (rst)           fin <= 1'b0;
        else if (es_fin_w) fin <= 1'b1;
    end

    // ============================================================
    // Unidad de riesgos
    // ============================================================
    unidad_riesgos #(.ADELANTAR_CARGAS(ADELANTAR_CARGAS)) riesgos (
        .rs1_d(rs1_d), .rs2_d(rs2_d), .rd_e(rd_e), .mem_read_e(mem_read_e),
        .salto_tomado_e(salto_tomado_e), .detener(detener), .parar_e(parar_e),
        .parar_f(parar_f), .parar_d(parar_d), .limpiar_d(limpiar_d), .limpiar_e(limpiar_e)
    );

endmodule
