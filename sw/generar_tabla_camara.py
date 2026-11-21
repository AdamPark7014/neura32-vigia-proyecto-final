"""Pasa prog/ajustes_camara.txt a la tabla que el programa manda a la camara (prog/tabla_camara.vh).
Cada renglon del archivo es "RR VV // nota" (registro y valor en hexadecimal).
Uso (desde la carpeta del proyecto):  python sw/generar_tabla_camara.py
"""
import re

renglones = []
for linea in open("prog/ajustes_camara.txt", encoding="utf-8"):
    codigo, _, nota = linea.partition("//")
    partes = codigo.split()
    if len(partes) == 2 and all(re.fullmatch(r"[0-9A-Fa-f]{2}", p) for p in partes):
        renglones.append((partes[0].upper(), partes[1].upper(), nota.strip()))

with open("prog/tabla_camara.vh", "w", encoding="utf-8", newline="\n") as f:
    f.write("// Tabla de registros de la camara OV7670: {registro, valor}\n")
    f.write("// La escribe sw/generar_tabla_camara.py a partir de prog/ajustes_camara.txt\n")
    for r, v, n in renglones:
        f.write(f"        emitir(32'h{r}{v});" + (f"   // {n}" if n else "") + "\n")
print(len(renglones), "registros -> prog/tabla_camara.vh")
