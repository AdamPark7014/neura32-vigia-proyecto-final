"""Convierte la captura de la camara (PGM 320x240, 16 grises) a PNG ampliado x2.
Uso: python pgm_a_png.py captura.pgm [captura.png]
"""
import sys
from PIL import Image

entrada = sys.argv[1] if len(sys.argv) > 1 else "captura.pgm"
salida = sys.argv[2] if len(sys.argv) > 2 else entrada.rsplit(".", 1)[0] + ".png"
img = Image.open(entrada)
img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
img.save(salida)
print(salida, img.size)
