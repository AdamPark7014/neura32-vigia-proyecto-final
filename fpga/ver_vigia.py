import os
import subprocess
import sys
import threading
import time
import tkinter as tk

from PIL import ImageTk

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "sw"))
from video_pc import Video, dibujar, hex_a_bits, leer_datos

QUARTUS_STP = r"C:\intelFPGA_lite\24.1std\quartus\bin64\quartus_stp.exe"


class Visor:
    def __init__(self):
        self.raiz = tk.Tk()
        self.raiz.title("NEURA-32 Vigia  |  CAM 01")
        self.raiz.configure(bg="#0b0d10")
        self.raiz.geometry("1000x800")
        self.lienzo = tk.Label(self.raiz, bg="#0b0d10", bd=0)
        self.lienzo.pack(fill="both", expand=True)
        self.raiz.bind("<Key>", self.tecla)
        self.raiz.protocol("WM_DELETE_WINDOW", self.salir)

        self.video = Video()
        self.datos = None
        self.mascara = None
        self.ver_mascara = False
        self.suavizar = True
        self.tiempos = []
        self.ms_jtag = 0
        self.vivo = True
        self.proc = None
        self.cerradura = threading.Lock()
        self.foto_tk = None
        self.nuevo = False
        threading.Thread(target=self.leer, daemon=True).start()
        self.raiz.after(30, self.pintar)

    def leer(self):
        while self.vivo:
            try:
                self.proc = subprocess.Popen([QUARTUS_STP, "-t", "flujo_vigia.tcl", "0", "2"], cwd=AQUI,
                                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                salida = self.proc.stdout
                n_cuadro = self.video.bits_cuadro()
                while self.vivo:
                    linea = salida.readline()
                    if not linea:
                        break
                    linea = linea.strip()
                    if linea.startswith("CUADRO"):
                        self.ms_jtag = int(linea.split()[1])
                        bits = hex_a_bits(salida.readline(), n_cuadro)
                        with self.cerradura:
                            if self.video.poner_cuadro(bits) is not None:
                                self.tiempos = (self.tiempos + [time.time()])[-20:]
                                self.nuevo = True
                    elif linea == "MASCARA":
                        bits = hex_a_bits(salida.readline(), 4800)
                        with self.cerradura:
                            self.mascara = bits
                    elif linea == "DATOS":
                        bits = hex_a_bits(salida.readline(), 384)
                        with self.cerradura:
                            self.datos = leer_datos(bits)
            except Exception:
                pass
            self.cortar()
            time.sleep(0.5)

    def cortar(self):
        if self.proc is not None:
            try:
                self.proc.kill()
            except OSError:
                pass
            self.proc = None

    # teclas
    def tecla(self, ev):
        k = ev.keysym.lower()
        if k == "escape":
            self.salir()
        elif k == "m":
            self.ver_mascara = not self.ver_mascara
        elif k == "s":
            self.suavizar = not self.suavizar
        elif k == "f":
            os.makedirs(os.path.join(AQUI, "fotos"), exist_ok=True)
            nombre = time.strftime("fotos/vigia_%Y%m%d_%H%M%S.png")
            self.componer(960).save(os.path.join(AQUI, nombre))

    # imagen
    def componer(self, ancho):
        escala = max(2, ancho // 160)
        with self.cerradura:
            img = self.video.imagen(escala=escala, suavizar=self.suavizar)
            datos, mascara = self.datos, self.mascara
        parpadeo = int(time.time() * 2) % 2 == 0
        return dibujar(img, datos, mascara, parpadeo=parpadeo, ver_mascara=self.ver_mascara)

    def pintar(self):
        if not self.vivo:
            return
        ancho = max(self.lienzo.winfo_width(), 320)
        alto = max(self.lienzo.winfo_height() - 26, 240)
        img = self.componer(min(ancho, alto * 4 // 3))
        with self.cerradura:
            t = list(self.tiempos)
            vga = bool(self.datos and self.datos.get("vga"))
        ritmo = (len(t) - 1) / (t[-1] - t[0]) if len(t) > 1 and t[-1] > t[0] else 0.0
        sin_senal = (not t) or (time.time() - t[-1] > 3.0)
        pie = (f"{'SIN VIDEO: revisa la placa y el cable USB   ' if sin_senal else ''}"
               f"{ritmo:4.1f} cuadros/s   JTAG {self.ms_jtag} ms   VGA {'enganchado' if vga else 'libre'}   "
               f"M mascara   S suavizado   F foto   Esc salir")
        self.raiz.title("NEURA-32 Vigia  |  CAM 01  |  " + pie)
        self.foto_tk = ImageTk.PhotoImage(img)
        self.lienzo.configure(image=self.foto_tk)
        if sin_senal and t and time.time() - t[-1] > 6.0:
            self.cortar()
            with self.cerradura:
                self.tiempos = []
        self.raiz.after(33, self.pintar)

    def salir(self):
        self.vivo = False
        self.cortar()
        self.raiz.after(300, self.raiz.destroy)

    def correr(self):
        self.raiz.mainloop()


if __name__ == "__main__":
    Visor().correr()
