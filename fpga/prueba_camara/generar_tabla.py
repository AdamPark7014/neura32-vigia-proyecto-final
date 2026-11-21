"""Pasa ajustes_ov7670.txt (probado en vivo) a la tabla en Verilog tabla_ov7670.v.
Uso (desde fpga/prueba_camara):  python generar_tabla.py
"""
import re

renglones = []          # (registro, valor, comentario)
for linea in open("ajustes_ov7670.txt", encoding="utf-8"):
    codigo, _, nota = linea.partition("//")
    partes = codigo.split()
    if len(partes) == 2 and all(re.fullmatch(r"[0-9A-Fa-f]{2}", p) for p in partes):
        renglones.append((partes[0].upper(), partes[1].upper(), nota.strip()))

inicio = [
    ("C_ESPERA,  8'd0,  8'd20", "RESET# en 0 durante 20 ms"),
    ("C_ESPERA,  8'd0,  8'd50", "RESET# en 1 y 50 ms de arranque"),
    ("C_ESCRIBE, 8'h12, 8'h80", "COM7: reinicio de registros"),
    ("C_ESPERA,  8'd0,  8'd20", ""),
    ("C_LEE,     8'h0A, 8'd0", "PID"),
    ("C_LEE,     8'h0B, 8'd1", "VER"),
    ("C_ESCRIBE, 8'h11, 8'h01", "CLKRC: PCLK = XCLK / (2 x 2) = 6.25 MHz (medido en la placa)"),
]
cuerpo = inicio + [(f"C_ESCRIBE, 8'h{r}, 8'h{v}", n) for r, v, n in renglones]
assert len(cuerpo) < 255, "la tabla no cabe en 8 bits de indice"

with open("tabla_ov7670.v", "w", encoding="utf-8", newline="\n") as f:
    f.write("""`timescale 1ns / 1ps
// ============================================================
// TABLA DE CONFIGURACION DE LA OV7670 (prueba de la camara)
// Cada renglon es {tipo, registro, valor}:
//   tipo 0 = esperar "valor" milisegundos     tipo 1 = escribir el registro
//   tipo 2 = leer el registro (PID / VER)     tipo 3 = fin de la tabla
// Los valores se afinan en vivo desde la PC (camara_reg.tcl con
// ajustes_ov7670.txt) y luego generar_tabla.py los anota aqui.
// ============================================================
module tabla_ov7670 (
    input  wire [7:0]  indice,
    output reg  [17:0] comando
);
    localparam C_ESPERA = 2'd0, C_ESCRIBE = 2'd1, C_LEE = 2'd2, C_FIN = 2'd3;

    always @(*) begin
        case (indice)
""")
    for i, (c, nota) in enumerate(cuerpo):
        coment = f"   // {nota}" if nota else ""
        f.write(f"            8'd{i}:".ljust(20) + f"comando = {{{c}}};{coment}\n")
    f.write("""            default: comando = {C_FIN, 16'd0};
        endcase
    end
endmodule
""")
print(f"tabla_ov7670.v: {len(cuerpo)} renglones ({len(renglones)} registros de ajuste)")
