`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// TESTBENCH AUTOVERIFICABLE — PRUEBA DEL REPERTORIO (PROGRAMA = 2)
// Ejecuta programa_prueba_isa.vh en el SoC completo y compara cada
// resultado que el programa dejo en la RAM con el valor esperado,
// calculado aqui con operadores de Verilog (sin pasar por el procesador).
// Al final imprime: PRUEBAS: 94  ERRORES: 0
// ============================================================
module tb_prueba_isa;

    parameter ADELANTAR_CARGAS = 0;   // 1: sin detencion carga-uso (para comparar el CPI)

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;                      // 100 MHz

    wire [9:0]  leds;
    wire [23:0] hex;
    wire [7:0]  consola_char;
    wire        consola_we, fin, instr_ilegal, desalineado;
    wire [31:0] control;
    wire [63:0] ciclos, instret;

    generador_programa #(.PROGRAMA(2)) gen ();

    wire cam_siod;
    pullup (cam_siod);

    soc_neura32 #(.USAR_ARCHIVO(0), .ADELANTAR_CARGAS(ADELANTAR_CARGAS), .SIMULACION(1)) dut (
        .clk(clk), .clk50(clk), .rst_ext(rst),
        .interruptores(10'h155), .botones(2'b11),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we), .control(control),
        .fin(fin), .instr_ilegal(instr_ilegal), .desalineado(desalineado),
        .cam_pclk(1'b0), .cam_href(1'b0), .cam_vsync(1'b0), .cam_d(8'd0),
        .cam_sioc(), .cam_siod(cam_siod), .cam_reset_n(), .cam_pwdn(),
        .vga_r(), .vga_g(), .vga_b(), .vga_hs(), .vga_vs(),
        .ciclos(ciclos), .instret(instret)
    );
    // ---- el programa lo arma el generador (ensamblador en Verilog) y se copia a la ROM ----
    integer palabra;
    task copiar_programa;
        for (palabra = 0; palabra < 4096; palabra = palabra + 1)
            dut.rom.memoria[palabra] = gen.memoria[palabra];
    endtask


    // ---- consola del programa ----
    reg [8*64-1:0] texto = 0;
    always @(posedge clk)
        if (consola_we) begin
            $write("%c", consola_char);
            texto = {texto[8*63-1:0], consola_char};
        end

    integer ilegales = 0, desalineados = 0;
    always @(posedge clk) begin
        if (instr_ilegal) ilegales = ilegales + 1;
        if (desalineado)  desalineados = desalineados + 1;
    end

    // ---- valores esperados ----
    localparam [31:0] A = 32'h12345678;
    localparam [31:0] B = 32'hDEADBEEF;

    wire signed [63:0] A_s = {{32{A[31]}}, A};
    wire signed [63:0] B_s = {{32{B[31]}}, B};
    wire        [63:0] A_u = {32'b0, A};
    wire        [63:0] B_u = {32'b0, B};
    wire signed [63:0] mul_ss = A_s * B_s;
    wire        [63:0] mul_uu = A_u * B_u;
    wire signed [63:0] mul_su = A_s * $signed(B_u);

    function [31:0] popcount; input [31:0] v; integer i;
        begin popcount = 0; for (i = 0; i < 32; i = i + 1) popcount = popcount + v[i]; end
    endfunction
    function [31:0] clz; input [31:0] v; integer i; reg visto;
        begin clz = 32; visto = 0; for (i = 31; i >= 0; i = i - 1) if (!visto && v[i]) begin clz = 31 - i; visto = 1; end end
    endfunction
    function [31:0] bitrev; input [31:0] v; integer i;
        begin for (i = 0; i < 32; i = i + 1) bitrev[i] = v[31 - i]; end
    endfunction

    reg [31:0] esperado [0:91];
    reg [8*64-1:0] nombre [0:91];

    task definir_esperados;
        begin
            esperado[0]  = A;                                   nombre[0]  = "li (lui+addi)";
            esperado[1]  = B;                                   nombre[1]  = "li negativo";
            esperado[2]  = A + B;                               nombre[2]  = "add";
            esperado[3]  = A - B;                               nombre[3]  = "sub";
            esperado[4]  = A ^ B;                               nombre[4]  = "xor";
            esperado[5]  = A | B;                               nombre[5]  = "or";
            esperado[6]  = A & B;                               nombre[6]  = "and";
            esperado[7]  = A << 4;                              nombre[7]  = "sll";
            esperado[8]  = B >> 4;                              nombre[8]  = "srl";
            esperado[9]  = $signed(B) >>> 4;                    nombre[9]  = "sra";
            esperado[10] = ($signed(B) < $signed(A)) ? 1 : 0;   nombre[10] = "slt";
            esperado[11] = (B < A) ? 1 : 0;                     nombre[11] = "sltu";
            esperado[12] = A - 1;                               nombre[12] = "addi";
            esperado[13] = 1;                                   nombre[13] = "slti";
            esperado[14] = 1;                                   nombre[14] = "sltiu";
            esperado[15] = A ^ 32'h0FF;                         nombre[15] = "xori";
            esperado[16] = A | 32'h700;                         nombre[16] = "ori";
            esperado[17] = A & 32'h0F0;                         nombre[17] = "andi";
            esperado[18] = A << 12;                             nombre[18] = "slli";
            esperado[19] = B >> 28;                             nombre[19] = "srli";
            esperado[20] = $signed(B) >>> 28;                   nombre[20] = "srai";
            esperado[21] = 32'hABCDE000;                        nombre[21] = "lui";
            esperado[22] = gen.I_auipc;                     nombre[22] = "auipc";
            esperado[23] = mul_ss[31:0];                        nombre[23] = "mul";
            esperado[24] = mul_ss[63:32];                       nombre[24] = "mulh";
            esperado[25] = mul_su[63:32];                       nombre[25] = "mulhsu";
            esperado[26] = mul_uu[63:32];                       nombre[26] = "mulhu";
            esperado[27] = $signed(B) / $signed(32'd4);         nombre[27] = "div";
            esperado[28] = B / 4;                               nombre[28] = "divu";
            esperado[29] = $signed(B) % $signed(32'd4);         nombre[29] = "rem";
            esperado[30] = B % 4;                               nombre[30] = "remu";
            esperado[31] = 32'hFFFFFFFF;                        nombre[31] = "div entre cero";
            esperado[32] = A;                                   nombre[32] = "rem entre cero";
            esperado[33] = A;                                   nombre[33] = "sw / lw";
            esperado[34] = 32'hBEEF78EF;                        nombre[34] = "sb sb sh / lw";
            esperado[35] = 32'hFFFFFFEF;                        nombre[35] = "lb (signo)";
            esperado[36] = 32'h000000EF;                        nombre[36] = "lbu";
            esperado[37] = 32'hFFFFBEEF;                        nombre[37] = "lh (signo)";
            esperado[38] = 32'h0000BEEF;                        nombre[38] = "lhu";
            esperado[39] = 32'h78 + 32'h78EF;                   nombre[39] = "lb + lh en otras posiciones";
            esperado[40] = 32'hC0DEF00D;                        nombre[40] = "lw desde la ROM";
            esperado[41] = 55;                                  nombre[41] = "lazo suma 1..10";
            esperado[42] = 32'h0C0;                             nombre[42] = "beq bne blt bge bltu bgeu";
            esperado[43] = gen.I_ret1;                      nombre[43] = "jal + ret";
            esperado[44] = gen.I_ret2;                      nombre[44] = "jalr";
            esperado[45] = 20;                                  nombre[45] = "adelantamiento EX/MEM/WB";
            esperado[46] = A + 1;                               nombre[46] = "carga-uso (detencion)";
            esperado[47] = A;                                   nombre[47] = "carga -> almacenamiento";
            esperado[48] = 0;                                   nombre[48] = "csr mhartid";
            esperado[49] = `VALOR_MISA;                         nombre[49] = "csr misa";
            esperado[50] = A;                                   nombre[50] = "csrrw/csrrs mscratch";
            esperado[51] = A | 32'h7;                           nombre[51] = "csrrsi";
            esperado[52] = (A | 32'h7) & ~32'hF;                nombre[52] = "csrrci";
            esperado[53] = 1;                                   nombre[53] = "instret (1 por ciclo)";
            esperado[54] = 1;                                   nombre[54] = "cycle avanza";
esperado[55] = 0;                                   nombre[55] = "x.abs (cero)";
            esperado[56] = 32'h00123456;                        nombre[56] = "x.abs (positivo)";
            esperado[57] = ($signed(A) > $signed(B)) ? 1 : 0;   nombre[57] = "x.sgt A > B";
            esperado[58] = ($signed(B) > $signed(A)) ? 1 : 0;   nombre[58] = "x.sgt B > A";
            esperado[59] = 1;                                   nombre[59] = "x.sgt (maximo > 1)";
            esperado[60] = 0;                                   nombre[60] = "x.sgt (1 > maximo)";
            esperado[61] = 1;                                   nombre[61] = "x.abs (-1)";
            esperado[62] = A[31] ? 0 : (($signed(A) > $signed(B)) ? B : A); nombre[62] = "x.clamp(A, 0, B)";
            esperado[63] = 0;                                   nombre[63] = "x.clamp (negativo)";
            esperado[64] = 100;                                 nombre[64] = "x.clamp (dentro)";
            esperado[65] = 127;                                 nombre[65] = "x.clamp (en el limite)";
            esperado[66] = 127;                                 nombre[66] = "x.clamp (arriba)";
            esperado[67] = B[31] ? -$signed(B) : B;             nombre[67] = "x.abs (B)";
            esperado[68] = 0;                                   nombre[68] = "x.sgt (iguales)";
            esperado[69] = 77;                                  nombre[69] = "instruccion ilegal no escribe";
            esperado[70] = 32'h80000000;                        nombre[70] = "div desbordamiento (-2^31/-1)";
            esperado[71] = 32'h00000000;                        nombre[71] = "rem desbordamiento (-2^31/-1)";
            esperado[72] = A & ~B;                              nombre[72] = "andn (Zbb)";
            esperado[73] = A | ~B;                              nombre[73] = "orn (Zbb)";
            esperado[74] = ~(A ^ B);                            nombre[74] = "xnor (Zbb)";
            esperado[75] = ($signed(A) < $signed(B)) ? A : B;   nombre[75] = "min (Zbb)";
            esperado[76] = (A < B) ? A : B;                     nombre[76] = "minu (Zbb)";
            esperado[77] = ($signed(A) > $signed(B)) ? A : B;   nombre[77] = "max (Zbb)";
            esperado[78] = (A > B) ? A : B;                     nombre[78] = "maxu (Zbb)";
            esperado[79] = (A << 4) | (A >> 28);                nombre[79] = "rol (Zbb)";
            esperado[80] = (A >> 4) | (A << 28);                nombre[80] = "ror (Zbb)";
            esperado[81] = (B >> 8) | (B << 24);                nombre[81] = "rori (Zbb)";
            esperado[82] = clz(A);                              nombre[82] = "clz (Zbb)";
            esperado[83] = 0;                                   nombre[83] = "ctz (Zbb)";
            esperado[84] = popcount(A);                         nombre[84] = "cpop (Zbb)";
            esperado[85] = {{24{B[7]}}, B[7:0]};                nombre[85] = "sext.b (Zbb)";
            esperado[86] = {{16{B[15]}}, B[15:0]};              nombre[86] = "sext.h (Zbb)";
            esperado[87] = {16'd0, B[15:0]};                    nombre[87] = "zext.h (Zbb)";
            esperado[88] = {A[7:0], A[15:8], A[23:16], A[31:24]}; nombre[88] = "rev8 (Zbb)";
            esperado[89] = ~A;                                  nombre[89] = "nota (clase)";
            esperado[90] = B;                                   nombre[90] = "passb (clase)";
            esperado[91] = A << 4;                              nombre[91] = "sla (clase)";
        end
    endtask

    // ---- ejecucion ----
    integer k, errores = 0, pruebas = 0, limite = 0;
    reg [31:0] leido;

    initial begin
        #1 copiar_programa;
        $display("=== NEURA-32: prueba del repertorio ===");
        $display("ROM: %0d palabras de programa (fin en 0x%03h)", gen.I_fin / 4, gen.I_fin);
        definir_esperados;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        while (!fin && limite < 20000) begin
            @(posedge clk);
            limite = limite + 1;
        end
        if (!fin) begin
            $display("ERROR: el programa no termino en %0d ciclos", limite);
            errores = errores + 1;
        end
        repeat (2) @(posedge clk);

        for (k = 0; k < 92; k = k + 1) begin
            leido  = dut.ram.palabra(k);
            pruebas = pruebas + 1;
            if (leido !== esperado[k]) begin
                errores = errores + 1;
                $display("  FALLA %2d %0s leido=%08h esperado=%08h", k, nombre[k], leido, esperado[k]);
            end else
                $display("  ok    %2d %0s %08h", k, nombre[k], leido);
        end

        pruebas = pruebas + 1;
        if (texto[23:0] !== {"O", "K", 8'h0A}) begin
            errores = errores + 1;
            $display("  FALLA consola: se esperaba OK");
        end

        pruebas = pruebas + 1;
        if (ilegales != 1) begin
            errores = errores + 1;
            $display("  FALLA se detectaron %0d instrucciones ilegales (se esperaba 1)", ilegales);
        end

        $display("ciclos=%0d  instrucciones=%0d  CPI=%0d.%02d  desalineados=%0d",
                 ciclos, instret, ciclos / instret, (ciclos * 100 / instret) % 100, desalineados);
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end

endmodule
