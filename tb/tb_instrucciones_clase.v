`timescale 1ns / 1ps
`include "neura32_defs.vh"
// ============================================================
// TESTBENCH: LA ROM DE INSTRUCCIONES DE LA CLASE EN EL PROCESADOR
//
// prog/instrucciones_clase.txt es la ROM de la practica
// Entregas/rom-instrucciones-riscv (31 instrucciones sobre x1 y x2).
// Aqui el procesador las EJECUTA:
//   li x1, A        (lui + addi)
//   li x2, B
//   las 31 instrucciones de la clase, tal cual vienen en el archivo
//   ecall
// y al final se compara cada registro con un interprete de referencia
// escrito aparte en este testbench (no usa nada del procesador).
// Al final imprime: PRUEBAS: 31  ERRORES: 0
// ============================================================
module tb_instrucciones_clase;

    reg clk;
    reg rst;

    initial clk = 0;
    always #5 clk = ~clk;

    // ---- operandos de prueba: A negativo para que signo y sin signo difieran ----
    localparam [31:0] A = 32'hF8A432EB;     // -123456789
    localparam [31:0] B = 32'h00000005;

    wire [9:0]  leds;
    wire [23:0] hex;
    wire [7:0]  consola_char;
    wire        consola_we, fin, instr_ilegal, desalineado;
    wire [31:0] control;
    wire [63:0] ciclos, instret;
    wire        cam_siod;
    pullup (cam_siod);

    soc_neura32 #(.USAR_ARCHIVO(0), .SIMULACION(1)) dut (
        .clk(clk), .clk50(clk), .rst_ext(rst),
        .interruptores(10'd0), .botones(2'b11),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we), .control(control),
        .cam_pclk(1'b0), .cam_href(1'b0), .cam_vsync(1'b0), .cam_d(8'd0),
        .cam_sioc(), .cam_siod(cam_siod), .cam_reset_n(), .cam_pwdn(),
        .vga_r(), .vga_g(), .vga_b(), .vga_hs(), .vga_vs(),
        .fin(fin), .instr_ilegal(instr_ilegal), .desalineado(desalineado),
        .ciclos(ciclos), .instret(instret)
    );

    // ---- el programa: se arma con el codificador y se copia a la ROM ----
    reg [31:0] memoria [0:4095];
    `include "codificador_riscv.vh"

    reg [31:0] clase [0:31];
    initial $readmemh("prog/instrucciones_clase.txt", clase);

    integer n, i;
    task armar_programa;
        begin
            for (i = 0; i < 4096; i = i + 1) memoria[i] = `NOP;
            pc_ens = 0;
            LI(5'd1, A);                     // x1
            LI(5'd2, B);                     // x2
            for (n = 0; n < 31; n = n + 1) emitir(clase[n]);
            emitir(ECALL(0));
            for (i = 0; i < 4096; i = i + 1) dut.rom.memoria[i] = memoria[i];
        end
    endtask

    // ---- interprete de referencia (independiente del procesador) ----
    reg [31:0] ref_x [0:31];

    function [31:0] contar_ceros_izq;
        input [31:0] v;
        integer k;
        begin
            contar_ceros_izq = 32;
            for (k = 0; k < 32; k = k + 1) if (v[k]) contar_ceros_izq = 31 - k;
        end
    endfunction

    function [31:0] contar_ceros_der;
        input [31:0] v;
        integer k;
        begin
            contar_ceros_der = 32;
            for (k = 31; k >= 0; k = k - 1) if (v[k]) contar_ceros_der = k;
        end
    endfunction

    function [31:0] contar_unos;
        input [31:0] v;
        integer k;
        begin
            contar_unos = 0;
            for (k = 0; k < 32; k = k + 1) contar_unos = contar_unos + v[k];
        end
    endfunction

    function [31:0] referencia;            // resultado que debe quedar en rd
        input [31:0] w;
        input [31:0] a, b;
        reg   [63:0] prod_s, prod_u;
        reg   [4:0]  sh;
        begin
            prod_s = $signed(a) * $signed(b);
            prod_u = {32'd0, a} * {32'd0, b};
            sh     = b[4:0];
            referencia = 32'hDEADDEAD;
            case (w[6:0])
                7'b0110011: case ({w[31:25], w[14:12]})              // tipo R
                    {7'h00, 3'd0}: referencia = a + b;                                   // add
                    {7'h20, 3'd0}: referencia = a - b;                                   // sub
                    {7'h00, 3'd7}: referencia = a & b;                                   // and
                    {7'h00, 3'd6}: referencia = a | b;                                   // or
                    {7'h00, 3'd4}: referencia = a ^ b;                                   // xor
                    {7'h00, 3'd1}: referencia = a << sh;                                 // sll
                    {7'h00, 3'd5}: referencia = a >> sh;                                 // srl
                    {7'h20, 3'd5}: referencia = $signed(a) >>> sh;                       // sra
                    {7'h00, 3'd2}: referencia = ($signed(a) < $signed(b)) ? 1 : 0;       // slt
                    {7'h00, 3'd3}: referencia = (a < b) ? 1 : 0;                         // sltu
                    {7'h01, 3'd0}: referencia = prod_s[31:0];                            // mul
                    {7'h01, 3'd1}: referencia = prod_s[63:32];                           // mulh
                    {7'h01, 3'd3}: referencia = prod_u[63:32];                           // mulhu
                    {7'h01, 3'd4}: referencia = $signed(a) / $signed(b);                 // div
                    {7'h01, 3'd6}: referencia = $signed(a) % $signed(b);                 // rem
                    {7'h05, 3'd4}: referencia = ($signed(a) < $signed(b)) ? a : b;       // min
                    {7'h20, 3'd7}: referencia = a & ~b;                                  // andn
                    {7'h20, 3'd6}: referencia = a | ~b;                                  // orn
                    {7'h20, 3'd4}: referencia = ~(a ^ b);                                // xnor
                    {7'h30, 3'd1}: referencia = (a << sh) | (a >> (6'd32 - sh));         // rol
                    {7'h30, 3'd5}: referencia = (a >> sh) | (a << (6'd32 - sh));         // ror
                    {7'h04, 3'd4}: referencia = {16'd0, a[15:0]};                        // zext.h
                    default: ;
                endcase
                7'b0010011: begin                                    // tipo I de Zbb
                    if (w[14:12] == 3'b001 && w[31:25] == 7'h30)
                        case (w[24:20])
                            5'd0: referencia = contar_ceros_izq(a);                      // clz
                            5'd1: referencia = contar_ceros_der(a);                      // ctz
                            5'd2: referencia = contar_unos(a);                           // cpop
                            5'd4: referencia = {{24{a[7]}}, a[7:0]};                     // sext.b
                            5'd5: referencia = {{16{a[15]}}, a[15:0]};                   // sext.h
                            default: ;
                        endcase
                    if (w[14:12] == 3'b101 && w[31:20] == 12'h698)
                        referencia = {a[7:0], a[15:8], a[23:16], a[31:24]};              // rev8
                end
                7'b0001011: case (w[14:12])                           // custom-0 de la clase
                    3'd0: referencia = ~a;                                               // nota
                    3'd1: referencia = b;                                                // passb
                    3'd2: referencia = a << sh;                                          // sla
                    default: ;
                endcase
                default: ;
            endcase
        end
    endfunction

    // nombre de cada caso, igual que los comentarios de instrucciones.txt
    function [8*24-1:0] nombre_caso;
        input integer k;
        case (k)
            0:  nombre_caso = "add x3, x1, x2";    1:  nombre_caso = "sub x4, x1, x2";
            2:  nombre_caso = "and x5, x1, x2";    3:  nombre_caso = "or x6, x1, x2";
            4:  nombre_caso = "xor x7, x1, x2";    5:  nombre_caso = "nota x8, x1";
            6:  nombre_caso = "sll x9, x1, x2";    7:  nombre_caso = "srl x10, x1, x2";
            8:  nombre_caso = "passb x11, x2";     9:  nombre_caso = "min x12, x1, x2";
            10: nombre_caso = "slt x13, x1, x2";   11: nombre_caso = "sltu x14, x1, x2";
            12: nombre_caso = "mul x15, x1, x2";   13: nombre_caso = "mulh x16, x1, x2";
            14: nombre_caso = "mulhu x17, x1, x2"; 15: nombre_caso = "div x18, x1, x2";
            16: nombre_caso = "rem x19, x1, x2";   17: nombre_caso = "andn x20, x1, x2";
            18: nombre_caso = "orn x21, x1, x2";   19: nombre_caso = "xnor x22, x1, x2";
            20: nombre_caso = "rol x23, x1, x2";   21: nombre_caso = "ror x24, x1, x2";
            22: nombre_caso = "sra x25, x1, x2";   23: nombre_caso = "sla x26, x1, x2";
            24: nombre_caso = "sext.b x27, x1";    25: nombre_caso = "sext.h x28, x1";
            26: nombre_caso = "zext.h x29, x1";    27: nombre_caso = "clz x30, x1";
            28: nombre_caso = "ctz x31, x1";       29: nombre_caso = "cpop x2, x1";
            30: nombre_caso = "rev8 x1, x1";       default: nombre_caso = "?";
        endcase
    endfunction

    // ---- ejecucion ----
    integer errores = 0, pruebas = 0, limite = 0, rd;
    reg [31:0] esperado [0:30];
    reg [4:0]  destino  [0:30];

    initial begin
        rst = 1;
        #1 armar_programa;

        // el interprete recorre las mismas 31 instrucciones en orden
        for (i = 0; i < 32; i = i + 1) ref_x[i] = 32'd0;
        ref_x[1] = A;
        ref_x[2] = B;
        for (n = 0; n < 31; n = n + 1) begin
            rd = clase[n][11:7];
            esperado[n] = referencia(clase[n], ref_x[clase[n][19:15]], ref_x[clase[n][24:20]]);
            destino[n]  = rd;
            if (rd != 0) ref_x[rd] = esperado[n];
        end

        $display("=== ROM de instrucciones de la clase ejecutada en NEURA-32 ===");
        $display("x1 = %h  x2 = %h", A, B);
        #20 rst = 0;
        while (!fin && limite < 5000) begin @(posedge clk); limite = limite + 1; end

        // el valor final de cada registro destino; si otra instruccion lo vuelve
        // a escribir despues (x2 y x1 al final), se compara contra la ultima
        for (n = 0; n < 31; n = n + 1) begin
            pruebas = pruebas + 1;
            if (dut.nucleo.banco.regs[destino[n]] === ref_x[destino[n]] &&
                (esperado[n] === ref_x[destino[n]] || destino[n] == 1 || destino[n] == 2)) begin
                $display("  caso %2d  %-0s  x%0d = %h  ok", n + 1, nombre_caso(n), destino[n], esperado[n]);
            end else begin
                errores = errores + 1;
                $display("  caso %2d  %-0s  x%0d = %h  ESPERADO %h  FALLA", n + 1, nombre_caso(n), destino[n],
                         dut.nucleo.banco.regs[destino[n]], ref_x[destino[n]]);
            end
        end
        if (!fin) begin errores = errores + 1; $display("  FALLA: no llego a ecall"); end
        if (dut.nucleo.instr_ilegal) errores = errores + 1;

        $display("ciclos=%0d instrucciones=%0d", ciclos, instret);
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
