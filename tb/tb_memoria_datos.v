`timescale 1ns/1ps
// ============================================================
// TESTBENCH DE LA MEMORIA DE DATOS (Practica 4)
// RAM sincrona + unidad de accesos parciales, como en el procesador:
// la direccion y el dato salen en un ciclo (EX) y la lectura llega en el
// siguiente (MEM). Pruebas que pide la guia:
//   1. escribir un patron conocido y leerlo de vuelta
//   2. accesos de byte y media palabra en las cuatro posiciones
//   3. extension de signo con valores negativos (lb/lh contra lbu/lhu)
// Al final imprime: PRUEBAS: n  ERRORES: 0
// ============================================================
module tb_memoria_datos;
    reg clk;
    reg  [31:0] dir;
    reg  [2:0]  funct3;
    reg  [31:0] dato_reg;
    reg         mem_read, mem_write;
    reg  [1:0]  despl_m;
    reg  [2:0]  funct3_m;

    wire [31:0] dmem_dir, dmem_dato_esc, ram_q, dato_ext;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re, desalineado;

    unidad_acceso_memoria acceso (
        .dir_e(dir), .funct3_e(funct3), .dato_reg_e(dato_reg),
        .mem_read_e(mem_read), .mem_write_e(mem_write),
        .dmem_dir_e(dmem_dir), .dmem_dato_esc_e(dmem_dato_esc), .dmem_be_e(dmem_be),
        .dmem_we_e(dmem_we), .dmem_re_e(dmem_re), .desalineado(desalineado),
        .despl_m(despl_m), .funct3_m(funct3_m), .dato_mem_m(ram_q), .dato_ext_m(dato_ext)
    );

    ram_datos #(.addr_width(6), .data_width(32)) dut (
        .clk(clk), .dir(dmem_dir), .dato_esc(dmem_dato_esc), .be(dmem_be), .we(dmem_we),
        .dato_lec(ram_q)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pruebas = 0, errores = 0;

    // almacenamiento: sb (000), sh (001), sw (010)
    task guarda;
        input [2:0]  f3;
        input [31:0] direccion, valor;
        begin
            @(negedge clk);
            dir = direccion; funct3 = f3; dato_reg = valor; mem_write = 1; mem_read = 0;
            @(negedge clk);
            mem_write = 0;
        end
    endtask

    // carga: lb (000), lh (001), lw (010), lbu (100), lhu (101)
    task carga;
        input [2:0]      f3;
        input [31:0]     direccion, esperado;
        input [8*24-1:0] nombre;
        begin
            @(negedge clk);
            dir = direccion; funct3 = f3; mem_read = 1; mem_write = 0;
            @(negedge clk);                           // un ciclo despues: etapa MEM
            despl_m = direccion[1:0]; funct3_m = f3; mem_read = 0;
            #1;
            pruebas = pruebas + 1;
            if (dato_ext === esperado) $display("  ok    %-0s dir=%02h -> %h", nombre, direccion, dato_ext);
            else begin
                errores = errores + 1;
                $display("  FALLA %-0s dir=%02h -> %h (esperado %h)", nombre, direccion, dato_ext, esperado);
            end
        end
    endtask

    initial begin
        dir = 0; funct3 = 3'b010; dato_reg = 0; mem_read = 0; mem_write = 0; despl_m = 0; funct3_m = 3'b010;
        $display("=== Memoria de datos: palabras, bytes, medias palabras y signo ===");

        // 1. patron conocido: se escriben 4 palabras y se leen de vuelta
        guarda(3'b010, 32'h00, 32'h12345678);
        guarda(3'b010, 32'h04, 32'hDEADBEEF);
        guarda(3'b010, 32'h08, 32'h00000000);
        guarda(3'b010, 32'h0C, 32'hFFFFFFFF);
        carga(3'b010, 32'h00, 32'h12345678, "lw patron 1");
        carga(3'b010, 32'h04, 32'hDEADBEEF, "lw patron 2");
        carga(3'b010, 32'h08, 32'h00000000, "lw patron 3");
        carga(3'b010, 32'h0C, 32'hFFFFFFFF, "lw patron 4");

        // 2. bytes en las cuatro posiciones de una palabra: 0x10 = 81 42 C3 04 (byte 0 = 0x04)
        guarda(3'b000, 32'h10, 32'h00000004);
        guarda(3'b000, 32'h11, 32'h000000C3);
        guarda(3'b000, 32'h12, 32'h00000042);
        guarda(3'b000, 32'h13, 32'h00000081);
        carga(3'b010, 32'h10, 32'h8142C304, "lw tras 4 sb");
        carga(3'b100, 32'h10, 32'h00000004, "lbu posicion 0");
        carga(3'b100, 32'h11, 32'h000000C3, "lbu posicion 1");
        carga(3'b100, 32'h12, 32'h00000042, "lbu posicion 2");
        carga(3'b100, 32'h13, 32'h00000081, "lbu posicion 3");

        // 3. extension de signo: los bytes C3 y 81 son negativos
        carga(3'b000, 32'h10, 32'h00000004, "lb posicion 0 (+)");
        carga(3'b000, 32'h11, 32'hFFFFFFC3, "lb posicion 1 (-)");
        carga(3'b000, 32'h12, 32'h00000042, "lb posicion 2 (+)");
        carga(3'b000, 32'h13, 32'hFFFFFF81, "lb posicion 3 (-)");

        // medias palabras en las dos posiciones: 0x14 = 8001 7FFF
        guarda(3'b001, 32'h14, 32'h00007FFF);
        guarda(3'b001, 32'h16, 32'h00008001);
        carga(3'b010, 32'h14, 32'h80017FFF, "lw tras 2 sh");
        carga(3'b001, 32'h14, 32'h00007FFF, "lh posicion 0 (+)");
        carga(3'b001, 32'h16, 32'hFFFF8001, "lh posicion 2 (-)");
        carga(3'b101, 32'h16, 32'h00008001, "lhu posicion 2");

        // un sb no debe tocar los otros 3 bytes de la palabra
        guarda(3'b000, 32'h05, 32'h00000000);
        carga(3'b010, 32'h04, 32'hDEAD00EF, "sb conserva el resto");

        // acceso no alineado: lw en una direccion que no es multiplo de 4
        @(negedge clk);
        dir = 32'h06; funct3 = 3'b010; mem_read = 1;
        #1;
        pruebas = pruebas + 1;
        if (desalineado) $display("  ok    lw en 0x06 se marca como desalineado");
        else begin errores = errores + 1; $display("  FALLA desalineado"); end
        @(negedge clk) mem_read = 0;

        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
