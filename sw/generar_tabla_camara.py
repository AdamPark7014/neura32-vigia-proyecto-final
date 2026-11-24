import re

renglones = []
for linea in open("prog/ajustes_camara.txt", encoding="utf-8"):
    codigo, _, nota = linea.partition("//")
    partes = codigo.split()
    if len(partes) == 2 and all(re.fullmatch(r"[0-9A-Fa-f]{2}", p) for p in partes):
        renglones.append((partes[0].upper(), partes[1].upper(), nota.strip()))

with open("prog/tabla_camara.vh", "w", encoding="utf-8", newline="\n") as f:
    for r, v, n in renglones:
        f.write(f"        emitir(32'h{r}{v});\n")
print(len(renglones), "registros -> prog/tabla_camara.vh")
