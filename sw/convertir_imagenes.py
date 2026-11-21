"""
Convierte las imagenes que guarda tb_vigia (tb/salidas/*.ppm y *.pgm, en texto)
a PNG en docs/img para el README.

Uso:  python sw/convertir_imagenes.py
"""
import os
from PIL import Image

raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
origen = os.path.join(raiz, "tb", "salidas")
destino = os.path.join(raiz, "docs", "img")
os.makedirs(destino, exist_ok=True)

def leer_pnm(ruta):
    tokens = []
    with open(ruta, encoding="ascii") as f:
        for linea in f:
            linea = linea.split("#")[0]
            tokens.extend(linea.split())
    tipo, ancho, alto, maximo = tokens[0], int(tokens[1]), int(tokens[2]), int(tokens[3])
    datos = [int(t) * 255 // maximo for t in tokens[4:]]
    if tipo == "P3":
        img = Image.new("RGB", (ancho, alto))
        img.putdata(list(zip(datos[0::3], datos[1::3], datos[2::3])))
    else:
        img = Image.new("L", (ancho, alto))
        img.putdata(datos)
    return img

for nombre, escala in (("vga_vigia.ppm", 1), ("mascara_80x60.pgm", 8), ("video_160x120.pgm", 4)):
    ruta = os.path.join(origen, nombre)
    if not os.path.exists(ruta):
        continue
    img = leer_pnm(ruta)
    if escala != 1:
        img = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
    salida = os.path.join(destino, os.path.splitext(nombre)[0] + ".png")
    img.save(salida)
    print("escrito", os.path.relpath(salida, raiz))
