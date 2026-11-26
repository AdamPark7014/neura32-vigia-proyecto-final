import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

COLORES = {1: (40, 235, 90), 2: (245, 50, 50), 3: (165, 165, 165)}
TEXTOS = {1: "PERSONA", 2: "INTRUSO", 3: "OBJETO"}


def bits_a_numeros(bits, ancho):
    # bits
    b = np.asarray(bits, dtype=np.uint8).reshape(-1, ancho)
    pesos = (1 << np.arange(ancho)).astype(np.uint32)
    return (b * pesos).sum(axis=1)


def hex_a_bits(texto, n):
    texto = texto.strip().rjust((n + 3) // 4, "0")
    valor = np.frombuffer(bytes.fromhex(texto if len(texto) % 2 == 0 else "0" + texto), dtype=np.uint8)[::-1]
    return np.unpackbits(valor, bitorder="little")[:n]


class Video:

    def __init__(self, ancho=160, alto=120):
        self.ancho, self.alto = ancho, alto
        self.y = np.zeros((alto, ancho), dtype=np.float32)
        self.u = np.full((alto // 2, ancho // 2), 128, dtype=np.float32)
        self.v = np.full((alto // 2, ancho // 2), 128, dtype=np.float32)
        self.cuadros = 0

    def bits_cuadro(self):
        return 16 + self.ancho * self.alto * 4 + (self.ancho // 2) * (self.alto // 2) * 8

    def poner_cuadro(self, bits):
        # cuadro completo de un solo banco
        cab = int(bits_a_numeros(bits[:16], 16)[0])
        if (cab >> 8) != 0xA5:
            return None
        n_y = self.ancho * self.alto
        lum = bits_a_numeros(bits[16:16 + n_y * 4], 4).reshape(self.alto, self.ancho).astype(np.float32)
        col = bits_a_numeros(bits[16 + n_y * 4:], 8).reshape(self.alto // 2, self.ancho // 2)
        self.y = lum * 17.0
        self.u = ((col >> 4) & 15).astype(np.float32) * 16 + 8
        self.v = (col & 15).astype(np.float32) * 16 + 8
        self.cuadros += 1
        return self.cuadros

    def imagen(self, escala=4, suavizar=True):
        # imagen RGB ampliada
        y = self.y
        if suavizar:
            p = np.pad(y, 1, mode="edge")
            y = (p[1:-1, 1:-1] * 4 + p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]) / 8
        u = np.asarray(Image.fromarray(self.u).resize((self.ancho, self.alto), Image.BILINEAR)) - 128
        v = np.asarray(Image.fromarray(self.v).resize((self.ancho, self.alto), Image.BILINEAR)) - 128
        r = y + 1.402 * v
        g = y - 0.344 * u - 0.714 * v
        b = y + 1.772 * u
        rgb = np.clip(np.dstack([r, g, b]), 0, 255).astype(np.uint8)
        img = Image.fromarray(rgb)
        return img.resize((self.ancho * escala, self.alto * escala), Image.BICUBIC)


def leer_datos(bits):
    # datos
    def campo(lo, n):
        return int(bits_a_numeros(bits[lo:lo + n], n)[0])
    cajas = []
    for k in range(8):
        w = campo(32 * k, 32)
        cajas.append((w & 255, (w >> 8) & 255, (w >> 16) & 255, (w >> 24) & 255, campo(256 + 2 * k, 2)))
    z = campo(272, 32)
    return {
        "cajas": cajas,
        "zona": (z & 255, (z >> 8) & 255, (z >> 16) & 255, (z >> 24) & 255),
        "linea": campo(304, 9),
        "letrero": campo(313, 2),
        "personas": campo(315, 4),
        "eventos": campo(319, 8),
        "cuadros": campo(327, 16),
        "silueta": campo(343, 13),
        "vga": campo(356, 1),
    }


def letra(tam):
    for nombre in ("consolab.ttf", "consola.ttf", "cour.ttf"):
        try:
            return ImageFont.truetype(nombre, tam)
        except OSError:
            pass
    return ImageFont.load_default()


def dibujar(img, datos=None, mascara=None, parpadeo=True, ver_mascara=False):
    d = ImageDraw.Draw(img, "RGBA")
    cw, chh = img.width / 80.0, img.height / 60.0
    f_chica, f_grande = letra(max(12, img.height // 30)), letra(max(20, img.height // 10))
    if datos is None:
        return img
    m = None
    if mascara is not None:
        m = np.asarray(mascara, dtype=np.uint8).reshape(60, 80)
    x0, y0, x1, y1 = datos["zona"]
    if x1 > x0:
        d.rectangle([x0 * cw, y0 * chh, (x1 + 1) * cw, (y1 + 1) * chh], outline=(255, 235, 0, 255), width=2)
    if datos["linea"] & 0x100:
        x = ((datos["linea"] & 0x7F) + 0.5) * cw
        for yy in range(0, img.height, 16):
            d.line([x, yy, x, yy + 8], fill=(0, 235, 235, 255), width=2)
    for (bx0, by0, bx1, by1, color) in datos["cajas"]:
        if color == 0:
            continue
        c = COLORES[color]
        # silueta
        if m is not None and color != 3:
            for cy in range(by0, min(by1, 59) + 1):
                for cx in range(bx0, min(bx1, 79) + 1):
                    if not m[cy, cx]:
                        continue
                    X0, Y0, X1, Y1 = cx * cw, cy * chh, (cx + 1) * cw, (cy + 1) * chh
                    if cx == 0 or not m[cy, cx - 1]:
                        d.line([X0, Y0, X0, Y1], fill=c + (255,), width=2)
                    if cx == 79 or not m[cy, cx + 1]:
                        d.line([X1, Y0, X1, Y1], fill=c + (255,), width=2)
                    if cy == 0 or not m[cy - 1, cx]:
                        d.line([X0, Y0, X1, Y0], fill=c + (255,), width=2)
                    if cy == 59 or not m[cy + 1, cx]:
                        d.line([X0, Y1, X1, Y1], fill=c + (255,), width=2)
        d.rectangle([bx0 * cw, by0 * chh, (bx1 + 1) * cw, (by1 + 1) * chh], outline=c + (255,), width=3)
        texto = TEXTOS[color]
        tw = d.textlength(texto, font=f_chica) + 10
        th = f_chica.size + 6
        ty = by0 * chh - th if by0 * chh >= th + 4 else by0 * chh + 3
        d.rectangle([bx0 * cw, ty, bx0 * cw + tw, ty + th], fill=c + (255,))
        d.text((bx0 * cw + 5, ty + 2), texto, font=f_chica, fill=(0, 0, 0, 255))
    if m is not None and ver_mascara:
        capa = Image.fromarray((m * 110).astype(np.uint8)).resize(img.size, Image.NEAREST)
        img.paste(Image.new("RGB", img.size, (40, 90, 255)), (0, 0), capa)
        d = ImageDraw.Draw(img, "RGBA")
    if (datos["letrero"] & 1) and (parpadeo or not (datos["letrero"] & 2)):
        texto = "INTRUSO"
        tw = d.textlength(texto, font=f_grande)
        cx = img.width / 2
        d.rectangle([cx - tw / 2 - 18, 44, cx + tw / 2 + 18, 44 + f_grande.size + 16], fill=(190, 0, 0, 235))
        d.text((cx - tw / 2, 50), texto, font=f_grande, fill=(255, 255, 255, 255))
    # barra de estado
    d.rectangle([0, 0, img.width, f_chica.size + 10], fill=(0, 0, 0, 150))
    d.text((10, 4), "NEURA-32 VIGIA", font=f_chica, fill=(255, 255, 255, 255))
    d.text((img.width * 0.33, 4), f"PERSONAS: {datos['personas']}", font=f_chica, fill=(255, 255, 255, 255))
    d.text((img.width * 0.58, 4), f"EVENTOS: {datos['eventos']:02X}", font=f_chica, fill=(255, 255, 255, 255))
    if parpadeo:
        d.ellipse([img.width - 78, 8, img.width - 66, 20], fill=(240, 30, 30, 255))
    d.text((img.width - 58, 4), "REC", font=f_chica, fill=(255, 255, 255, 255))
    return img


def revisar_simulacion(carpeta, salida):
    def bits_de(nombre):
        t = open(os.path.join(carpeta, nombre)).read().strip()
        return np.frombuffer(t.encode(), dtype=np.uint8) - 48

    video = Video()
    for nombre in ("pc_cuadro0.txt", "pc_cuadro1.txt"):
        n = video.poner_cuadro(bits_de(nombre))
        print(nombre, "-> cuadro", n)
    datos = leer_datos(bits_de("pc_datos.txt"))
    mascara = bits_de("pc_mascara.txt")
    print("datos:", {k: v for k, v in datos.items() if k != "cajas"})
    print("cajas:", [c for c in datos["cajas"] if c[4]])
    img = dibujar(video.imagen(escala=6), datos, mascara)
    img.save(salida)
    print(salida, img.size)


if __name__ == "__main__":
    carpeta = sys.argv[1] if len(sys.argv) > 1 else "tb/salidas"
    revisar_simulacion(carpeta, "docs/img/pc_vista.png")
