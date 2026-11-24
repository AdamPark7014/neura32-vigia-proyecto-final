import argparse
import os
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image

QUARTUS_STP = r"C:\intelFPGA_lite\24.1std\quartus\bin64\quartus_stp.exe"
AQUI = os.path.dirname(os.path.abspath(__file__))


def activar_ansi():
    if os.name != "nt":
        return
    import ctypes
    k = ctypes.windll.kernel32
    h = k.GetStdHandle(-11)
    modo = ctypes.c_uint32()
    if k.GetConsoleMode(h, ctypes.byref(modo)):
        k.SetConsoleMode(h, modo.value | 0x0004)


def cuadros(n, modo, periodo=0, procesos=None):
    orden = [QUARTUS_STP, "-t", "flujo_camara.tcl", str(n), str(modo), str(periodo)]
    proc = subprocess.Popen(orden, cwd=AQUI, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, bufsize=1,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if procesos is not None:
        procesos.append(proc)
    try:
        while True:
            linea = proc.stdout.readline()
            if not linea:
                break
            linea = linea.strip()
            if linea.startswith("ERROR") or linea.startswith("Error"):
                print(linea, file=sys.stderr)
            if not linea.startswith("CUADRO"):
                continue
            _, num, ms, ancho, alto = linea.split()
            ancho, alto = int(ancho), int(alto)
            h = proc.stdout.readline().strip().rjust(ancho * alto * 2, "0")
            img = np.frombuffer(bytes.fromhex(h), dtype=np.uint8)[::-1].reshape(alto, ancho)
            yield int(num), int(ms), img
    finally:
        proc.kill()


def mejorar(img):
    bajo, alto = np.percentile(img, (1, 99))
    if alto - bajo < 16:
        return img
    return np.clip((img.astype(np.float32) - bajo) * (255.0 / (alto - bajo)), 0, 255).astype(np.uint8)


def acomodar(img, girar, espejo):
    if girar:
        img = np.rot90(img, k=girar // 90)
    if espejo:
        img = img[:, ::-1]
    return np.ascontiguousarray(img)


GRIS = [f"{g};{g};{g}" for g in range(256)]


def dibujar(img, texto):
    columnas, filas = shutil.get_terminal_size((120, 40))
    filas -= 2
    alto_img, ancho_img = img.shape
    escala = min(columnas / ancho_img, filas * 2 / alto_img)
    w = max(16, int(ancho_img * escala))
    h = max(8, int(alto_img * escala)) // 2 * 2
    chica = np.asarray(Image.fromarray(img).resize((w, h), Image.LANCZOS))
    margen = " " * ((columnas - w) // 2)
    partes = ["\x1b[H"]
    for y in range(0, h, 2):
        arriba, abajo = chica[y].tolist(), chica[y + 1].tolist()
        renglon = [f"\x1b[38;2;{GRIS[a]};48;2;{GRIS[b]}m\u2580" for a, b in zip(arriba, abajo)]
        partes.append(margen + "".join(renglon) + "\x1b[0m\x1b[K\n")
    partes.append(f"\x1b[0m{texto}\x1b[K\x1b[J")
    return "".join(partes), (w, h)


def main():
    ap = argparse.ArgumentParser(description="Video de la camara OV7670 en la terminal")
    ap.add_argument("--foto", help="guarda un cuadro de 320 x 240 en este archivo PNG y termina")
    ap.add_argument("--completa", action="store_true", help="manda 320 x 240 en lugar de 160 x 120")
    ap.add_argument("--girar", type=int, default=0, choices=(0, 90, 180, 270))
    ap.add_argument("--espejo", action="store_true")
    ap.add_argument("--sin-mejora", action="store_true")
    a = ap.parse_args()

    if a.foto:
        for _, ms, img in cuadros(1, 1):
            img = acomodar(img if a.sin_mejora else mejorar(img), a.girar, a.espejo)
            Image.fromarray(img).save(a.foto)
            print(f"{a.foto}: {img.shape[1]} x {img.shape[0]}, {ms} ms")
        return

    activar_ansi()
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stdout.write("\x1b[2J\x1b[?25l")
    anterior = time.time()
    fps = 0.0
    try:
        for num, ms, img in cuadros(0, 1 if a.completa else 2, 125):
            ahora = time.time()
            ritmo = 1 / max(ahora - anterior, 1e-3)
            fps = 0.8 * fps + 0.2 * ritmo if fps else ritmo
            anterior = ahora
            img = acomodar(img if a.sin_mejora else mejorar(img), a.girar, a.espejo)
            hora = time.strftime("%d/%m/%Y %H:%M:%S")
            texto = (f" \x1b[31m\u25cf\x1b[0m CAM 01  {hora}   {img.shape[1]} x {img.shape[0]}"
                     f"   {fps:4.1f} cuadros/s   JTAG {ms} ms   Ctrl+C para salir")
            salida, _ = dibujar(img, texto)
            sys.stdout.write(salida)
            sys.stdout.flush()
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write("\x1b[0m\x1b[?25h\n")


if __name__ == "__main__":
    main()
