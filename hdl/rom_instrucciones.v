`timescale 1ns / 1ps
// ============================================================
// MEMORIA DE PROGRAMA (Practica 4) — sincrona y de doble puerto
// Mismo estilo que la ROM de la Practica 4 (rom_txt.v): parametros
// addr_width / data_width, arreglo inicializado desde un archivo
// y lectura en el flanco de subida. Al ser sincrona, Quartus la coloca
// en bloques M9K de la MAX 10.
//
//   Puerto de instrucciones: lo usa la etapa IF. Su registro de salida
//   es el propio registro IF/ID de la instruccion; en_instr = 0 lo
//   congela cuando el pipeline se detiene.
//   Puerto de datos: lw/lb desde la memoria de programa (tablas y pesos).
//   La direccion llega desde EX y el dato sale en MEM.
//
// Para el procesador es una ROM: no puede escribirla. El unico que
// escribe es el cargador de programas (jtag_loader), por el puerto de
// datos y con el procesador detenido: asi se le puede dar otro
// programa desde la PC sin volver a compilar.
//
// El indice es dir[addr_width+1:2]: las direcciones son de bytes y cada
// palabra ocupa 4 (la guia de la Practica 4 usa dir[9:2] con 256 palabras).
// ============================================================
module rom_instrucciones #(
    parameter addr_width   = 12,                 // 4096 palabras = 16 KB
    parameter data_width   = 32,
    parameter archivo      = "programa_vigia.txt",
    parameter usar_archivo = 1                   // 0: el testbench la llena por jerarquia
) (
    input  wire                  clk,
    input  wire                  en_instr,
    input  wire [31:0]           dir_instr,
    output reg  [data_width-1:0] instr,
    input  wire [31:0]           dir_dato,
    output reg  [data_width-1:0] dato,
    // cargador de programas
    input  wire                  cargar_we,
    input  wire [addr_width-1:0] cargar_dir,
    input  wire [data_width-1:0] cargar_dato
);
    reg [data_width-1:0] memoria [0:(2**addr_width-1)];

    generate
        if (usar_archivo) begin : g_inicial
            initial $readmemh(archivo, memoria);
        end
    endgenerate

    // puerto A: instrucciones
    always @(posedge clk)
        if (en_instr) instr <= memoria[dir_instr[addr_width+1:2]];

    // puerto B: datos del procesador (lectura) o palabra del cargador (escritura)
    wire [addr_width-1:0] dir_b = cargar_we ? cargar_dir : dir_dato[addr_width+1:2];

    always @(posedge clk) begin
        if (cargar_we) memoria[dir_b] <= cargar_dato;
        dato <= memoria[dir_b];
    end
endmodule
