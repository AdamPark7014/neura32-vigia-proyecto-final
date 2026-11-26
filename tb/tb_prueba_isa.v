`timescale 1ns / 1ps
module tb_prueba_isa;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire [9:0]  leds;
    wire [23:0] hex;
    wire [7:0]  consola_char;
    wire        consola_we, fin, instr_ilegal;
    wire [31:0] control;
    wire [31:0] ciclos, instret;

    // ensamblador
    generador_programa #(.PROGRAMA(2)) gen ();

    wire cam_siod;
    pullup (cam_siod);

    soc_neura32 #(.ARCHIVO_PROGRAMA("fpga/programa_isa.txt"), .SIMULACION(1)) dut (
        .clk(clk), .clk50(clk), .rst_ext(rst),
        .interruptores(10'h155), .botones(2'b11),
        .leds(leds), .hex(hex),
        .consola_char(consola_char), .consola_we(consola_we), .control(control),
        .fin(fin), .instr_ilegal(instr_ilegal),
        .cam_pclk(1'b0), .cam_href(1'b0), .cam_vsync(1'b0), .cam_d(8'd0),
        .cam_sioc(), .cam_siod(cam_siod), .cam_reset_n(), .cam_pwdn(), .cam_fase(),
        .vga_r(), .vga_g(), .vga_b(), .vga_hs(), .vga_vs(),
        .ciclos(ciclos), .instret(instret)
    );

    // consola del programa
    reg [8*64-1:0] texto = 0;
    always @(posedge clk)
        if (consola_we) begin
            $write("%c", consola_char);
            texto = {texto[8*63-1:0], consola_char};
        end

    integer ilegales = 0;
    always @(posedge clk)
        if (!rst && instr_ilegal) ilegales = ilegales + 1;

    // valores esperados
    localparam [31:0] A = 32'h12345678;  // operando de prueba
    localparam [31:0] B = 32'hDEADBEEF;  // operando de prueba
    localparam N = 61;  // número de pruebas

    reg [31:0]     esperado [0:N-1];
    reg [8*40-1:0] nombre   [0:N-1];

    function [31:0] popcount;
        input [31:0] v;
        integer b;
        begin
            popcount = 0;
            for (b = 0; b < 32; b = b + 1) popcount = popcount + v[b];
        end
    endfunction

    integer q;
    task definir_esperados;
        begin
            for (q = 43; q <= 54; q = q + 1) begin esperado[q] = 1; nombre[q] = "salto condicional"; end
            esperado[0]  = A;                                   nombre[0]  = "li A";
            esperado[1]  = B;                                   nombre[1]  = "li B";
            esperado[2]  = A + B;                               nombre[2]  = "add";
            esperado[3]  = A * B;                               nombre[3]  = "mul";
            esperado[4]  = A & B;                               nombre[4]  = "and";
            esperado[5]  = A | B;                               nombre[5]  = "or";
            esperado[6]  = A ^ B;                               nombre[6]  = "xor";
            esperado[7]  = ~A;                                  nombre[7]  = "nota";
            esperado[8]  = A << 4;                              nombre[8]  = "sll";
            esperado[9]  = B >> 4;                              nombre[9]  = "srl";
            esperado[10] = A - B;                               nombre[10] = "sub";
            esperado[11] = ($signed(B) < $signed(A)) ? 1 : 0;   nombre[11] = "slt";
            esperado[12] = (B < A) ? 1 : 0;                     nombre[12] = "sltu";
            esperado[13] = $signed(B) >>> 4;                    nombre[13] = "sra";
            esperado[14] = ~(A ^ B);                            nombre[14] = "xnor";
            esperado[15] = ($signed(A) < $signed(B)) ? A : B;   nombre[15] = "min";
            esperado[16] = (A < B) ? A : B;                     nombre[16] = "minu";
            esperado[17] = ($signed(A) > $signed(B)) ? A : B;   nombre[17] = "max";
            esperado[18] = B / 1000;                            nombre[18] = "divu";
            esperado[19] = B % 1000;                            nombre[19] = "remu";
            esperado[20] = popcount(B);                         nombre[20] = "cpop";
            esperado[21] = -$signed(B);                         nombre[21] = "abs";
            esperado[22] = ($signed(A) > $signed(B)) ? 1 : 0;   nombre[22] = "sgt";
            esperado[23] = 127;                                 nombre[23] = "clamp";
            esperado[24] = 32'hFFFFFFFF;                        nombre[24] = "divu entre cero";
            esperado[25] = A;                                   nombre[25] = "remu entre cero";
            esperado[26] = A - 1;                               nombre[26] = "addi";
            esperado[27] = A & 32'h0F0;                         nombre[27] = "andi";
            esperado[28] = A | 32'h700;                         nombre[28] = "ori";
            esperado[29] = A ^ 32'h0FF;                         nombre[29] = "xori";
            esperado[30] = A << 12;                             nombre[30] = "slli";
            esperado[31] = B >> 28;                             nombre[31] = "srli";
            esperado[32] = 1;                                   nombre[32] = "slti";
            esperado[33] = 1;                                   nombre[33] = "sltiu";
            esperado[34] = $signed(B) >>> 28;                   nombre[34] = "srai";
            esperado[35] = 32'hABCDE000;                        nombre[35] = "lui";
            esperado[36] = B;                                   nombre[36] = "sw + lw";
            esperado[37] = {{24{B[7]}}, B[7:0]};                nombre[37] = "lb";
            esperado[38] = {24'd0, B[7:0]};                     nombre[38] = "lbu";
            esperado[39] = {{16{B[15]}}, B[15:0]};              nombre[39] = "lh";
            esperado[40] = {16'd0, B[31:16]};                   nombre[40] = "lhu";
            esperado[41] = 32'h0000AA00;                        nombre[41] = "sb";
            esperado[42] = 32'h12340000;                        nombre[42] = "sh";
            nombre[43] = "beq se toma";       nombre[44] = "bne se toma";
            nombre[45] = "blt se toma";       nombre[46] = "bge se toma";
            nombre[47] = "bltu se toma";      nombre[48] = "bgeu se toma";
            nombre[49] = "beq no se toma";    nombre[50] = "bne no se toma";
            nombre[51] = "blt no se toma";    nombre[52] = "bge no se toma";
            nombre[53] = "bltu no se toma";   nombre[54] = "bgeu no se toma";
            esperado[55] = 77;                                  nombre[55] = "jal + jalr (funcion)";
            esperado[56] = gen.I_ret1;                          nombre[56] = "direccion de regreso";
            esperado[57] = 55;                                  nombre[57] = "lazo: suma de 1 a 10";
            esperado[58] = 32'hCAFEF00D;                        nombre[58] = "dato en la memoria de programa";
            esperado[59] = 1;                                   nombre[59] = "contador de ciclos";
            esperado[60] = 32'h155;                             nombre[60] = "interruptores";
        end
    endtask

    integer k, errores = 0, pruebas = 0, limite = 0;
    reg [31:0] leido;

    initial begin
        $display("=== NEURA-32: prueba de todas las instrucciones ===");
        #1 $display("programa: %0d instrucciones (fpga/programa_isa.txt)", gen.I_fin / 4);
        definir_esperados;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        while (!fin && limite < 40000) begin
            @(posedge clk);
            limite = limite + 1;
        end
        if (!fin) begin
            $display("ERROR: el programa no termino en %0d ciclos", limite);
            errores = errores + 1;
        end
        repeat (2) @(posedge clk);

        for (k = 0; k < N; k = k + 1) begin
            leido  = dut.cpu.palabra(k);
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
        if (ilegales != 0) begin
            errores = errores + 1;
            $display("  FALLA se detectaron %0d instrucciones que no existen", ilegales);
        end

        pruebas = pruebas + 1;
        if (!fin) errores = errores + 1;

        $display("ciclos=%0d  instrucciones=%0d  ciclos por instruccion=%0d.%02d",
                 ciclos, instret, ciclos / instret, (ciclos * 100 / instret) % 100);
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end

endmodule
