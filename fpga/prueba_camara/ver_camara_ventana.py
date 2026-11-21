"""Video de la camara OV7670 en vivo, en una ventana tipo camara de vigilancia.

La FPGA (prueba_camara) manda cada cuadro de 320 x 240 por el cable
USB-Blaster (JTAG virtual); quartus_stp lo baja con flujo_camara.tcl y esta
ventana lo muestra ampliado y suavizado, con ajuste de contraste.

Uso (desde fpga/prueba_camara):  python ver_camara_ventana.py
Teclas:
    R      cambia entre imagen completa (320 x 240) y rapida (160 x 120)
    C      ajuste de contraste encendido / apagado
    E      espejo (izquierda <-> derecha)
    G      gira la imagen 180 grados
    F      guarda una foto en fotos/
    Esc    salir
"""
import os
import threading
import time
import tkinter as tk

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageTk

from ver_camara import cuadros

AQUI = os.path.dirname(os.path.abspath(__file__))


def fuente(tam):
    for nombre in ("consolab.ttf", "consola.ttf", "cour.ttf"):
        try:
            return ImageFont.truetype(nombre, tam)
        except OSError:
            pass
    return ImageFont.load_default()


class Visor:
    def __init__(self):
        self.raiz = tk.Tk()
        self.raiz.title("NEURA-32 Vigia  |  CAM 01")
        self.raiz.configure(bg="#0b0d10")
        self.raiz.geometry("1100x860")
        self.lienzo = tk.Label(self.raiz, bg="#0b0d10", bd=0)
        self.lienzo.pack(fill="both", expand=True)
        self.raiz.bind("<Key>", self.tecla)
        self.raiz.protocol("WM_DELETE_WINDOW", self.salir)

        self.modo = 1                     # 1 = 320 x 240, 2 = 160 x 120
        self.contraste = True
        self.espejo = False
        self.girar = False
        self.ultimo = None                # (numero, ms, imagen)
        self.tiempos = []
        self.aviso = ""
        self.aviso_hasta = 0.0
        self.vivo = True
        self.hilo_id = 0
        self.cerradura = threading.Lock()
        self.foto_tk = None
        self.procesos = []                # procesos de quartus_stp en marcha
        self.letra = fuente(18)
        self.letra_chica = fuente(14)
        self.arrancar_hilo()
        self.raiz.after(30, self.pintar)

    # ---------------- lectura de la FPGA en otro hilo ----------------
    def arrancar_hilo(self):
        self.hilo_id += 1
        mi_id = self.hilo_id
        modo = self.modo

        self.cortar_procesos()             # solo un quartus_stp puede usar el JTAG a la vez

        def trabajo():
            while self.vivo and mi_id == self.hilo_id:
                try:
                    for num, ms, img in cuadros(0, modo, 0, self.procesos):
                        if not self.vivo or mi_id != self.hilo_id:
                            break
                        with self.cerradura:
                            self.ultimo = (num, ms, img)
                            self.tiempos.append(time.time())
                            self.tiempos = self.tiempos[-12:]
                except Exception as e:     # se reintenta si quartus_stp se cae
                    self.avisar(f"reconectando: {e}")
                time.sleep(0.5)

        threading.Thread(target=trabajo, daemon=True).start()

    def cortar_procesos(self):
        for proc in self.procesos:
            try:
                proc.kill()
            except OSError:
                pass
        self.procesos.clear()

    def avisar(self, texto, segundos=2.5):
        self.aviso = texto
        self.aviso_hasta = time.time() + segundos

    # ---------------- teclas ----------------
    def tecla(self, ev):
        k = ev.keysym.lower()
        if k == "escape":
            self.salir()
        elif k == "r":
            self.modo = 2 if self.modo == 1 else 1
            self.avisar("imagen rapida 160 x 120" if self.modo == 2 else "imagen completa 320 x 240")
            self.arrancar_hilo()
        elif k == "c":
            self.contraste = not self.contraste
            self.avisar("contraste automatico " + ("encendido" if self.contraste else "apagado"))
        elif k == "e":
            self.espejo = not self.espejo
        elif k == "g":
            self.girar = not self.girar
        elif k == "f":
            self.guardar_foto()

    def guardar_foto(self):
        with self.cerradura:
            dato = self.ultimo
        if dato is None:
            return
        os.makedirs(os.path.join(AQUI, "fotos"), exist_ok=True)
        nombre = time.strftime("fotos/cam01_%Y%m%d_%H%M%S.png")
        self.preparar(dato[2]).save(os.path.join(AQUI, nombre))
        self.avisar("foto guardada: " + nombre)

    # ---------------- imagen ----------------
    def preparar(self, img):
        if self.contraste:
            bajo, alto = np.percentile(img, (1, 99.5))
            if alto - bajo >= 12:
                img = np.clip((img.astype(np.float32) - bajo) * (255.0 / (alto - bajo)), 0, 255).astype(np.uint8)
        if self.girar:
            img = img[::-1, ::-1]
        if self.espejo:
            img = img[:, ::-1]
        return Image.fromarray(np.ascontiguousarray(img))

    def pintar(self):
        if not self.vivo:
            return
        with self.cerradura:
            dato = self.ultimo
            tiempos = list(self.tiempos)
        ancho = max(self.lienzo.winfo_width(), 320)
        alto = max(self.lienzo.winfo_height(), 240)
        lienzo = Image.new("RGB", (ancho, alto), (11, 13, 16))
        d = ImageDraw.Draw(lienzo)

        if dato is None:
            d.text((30, 30), "Esperando video de la FPGA...", font=self.letra, fill=(200, 200, 200))
        else:
            num, ms, img = dato
            base = self.preparar(img)
            escala = min(ancho / base.width, (alto - 40) / base.height)
            w, h = int(base.width * escala), int(base.height * escala)
            grande = base.resize((w, h), Image.BICUBIC)
            grande = grande.filter(ImageFilter.UnsharpMask(radius=1.6, percent=70, threshold=2)).convert("RGB")
            x0, y0 = (ancho - w) // 2, max(0, (alto - 40 - h) // 2)
            lienzo.paste(grande, (x0, y0))

            # marco tipo camara de vigilancia
            verde = (80, 230, 120)
            L = max(24, w // 18)
            for (cx, cy, sx, sy) in ((x0, y0, 1, 1), (x0 + w - 1, y0, -1, 1),
                                     (x0, y0 + h - 1, 1, -1), (x0 + w - 1, y0 + h - 1, -1, -1)):
                d.line([(cx, cy), (cx + sx * L, cy)], fill=verde, width=3)
                d.line([(cx, cy), (cx, cy + sy * L)], fill=verde, width=3)
            parpadeo = int(time.time() * 2) % 2 == 0
            if parpadeo:
                d.ellipse([x0 + 18, y0 + 18, x0 + 32, y0 + 32], fill=(235, 40, 40))
            self.sombra(d, (x0 + 40, y0 + 14), "REC  CAM 01  NEURA-32 VIGIA", self.letra)
            hora = time.strftime("%d/%m/%Y  %H:%M:%S")
            tw = d.textlength(hora, font=self.letra)
            self.sombra(d, (x0 + w - tw - 16, y0 + 14), hora, self.letra)

            fps = (len(tiempos) - 1) / (tiempos[-1] - tiempos[0]) if len(tiempos) > 1 else 0.0
            pie = (f"{img.shape[1]} x {img.shape[0]}   {fps:4.1f} cuadros/s   JTAG {ms} ms   "
                   f"contraste {'auto' if self.contraste else 'normal'}      "
                   f"R rapida/completa   C contraste   E espejo   G girar   F foto   Esc salir")
            d.text((x0, alto - 30), pie, font=self.letra_chica, fill=(170, 175, 180))

        if tiempos and time.time() - tiempos[-1] > 4.0:
            self.avisar("sin cuadros nuevos: reconectando con la FPGA...", 1.0)
            with self.cerradura:
                self.tiempos = [time.time()]
            self.cortar_procesos()

        if time.time() < self.aviso_hasta:
            self.sombra(d, (30, alto - 70), self.aviso, self.letra, (255, 220, 120))

        self.foto_tk = ImageTk.PhotoImage(lienzo)
        self.lienzo.configure(image=self.foto_tk)
        self.raiz.after(30, self.pintar)

    @staticmethod
    def sombra(d, pos, texto, letra, color=(240, 240, 240)):
        x, y = pos
        d.text((x + 2, y + 2), texto, font=letra, fill=(0, 0, 0))
        d.text((x, y), texto, font=letra, fill=color)

    def salir(self):
        self.vivo = False
        self.hilo_id += 1
        self.cortar_procesos()
        self.raiz.after(300, self.raiz.destroy)

    def correr(self):
        self.raiz.mainloop()


if __name__ == "__main__":
    Visor().correr()
