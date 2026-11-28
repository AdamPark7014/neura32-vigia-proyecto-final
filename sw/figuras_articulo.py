import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
IMG = os.path.join(RAIZ, "docs", "img")
SALIDA = os.path.join(RAIZ, "docs", "articulo", "figs")

AZUL_OSC, AZUL, AMBAR, VERDE, ROJO, MORADO = "#0E2A47", "#1D6FA5", "#D98B12", "#1F7A6C", "#B5452F", "#6B5B95"
GRIS, GRIS_CL, TINTA = "#5B6770", "#C9D1D9", "#1E293B"
F_AZ, F_AM, F_VE, F_RO, F_MO = "#ECF3FA", "#FBF1E1", "#E6F2EF", "#F6E7E3", "#EEEBF4"
COL, DOBLE = 3.45, 7.16

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 7.5, "axes.titlesize": 8, "axes.titleweight": "bold",
    "axes.labelsize": 7.5, "xtick.labelsize": 7, "ytick.labelsize": 7, "legend.fontsize": 7,
    "axes.edgecolor": GRIS, "axes.linewidth": 0.6, "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": "#E6E9ED", "grid.linewidth": 0.5, "xtick.color": GRIS, "ytick.color": GRIS,
    "xtick.major.width": 0.5, "ytick.major.width": 0.5, "text.color": TINTA, "axes.labelcolor": TINTA,
    "pdf.fonttype": 42, "savefig.dpi": 300,
})


def guardar(fig, n):
    os.makedirs(SALIDA, exist_ok=True)
    fig.savefig(os.path.join(SALIDA, n + ".pdf"), bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)


def lienzo(w, h, ancho, alto):
    fig, ax = plt.subplots(figsize=(ancho, alto))
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.axis("off")
    fig.subplots_adjust(0, 0, 1, 1)
    return fig, ax


def caja(ax, x, y, w, h, t, c="", fc=F_AZ, ec=AZUL_OSC, tam=7.5, tam2=6, lw=0.8):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=0.08", fc=fc, ec=ec, lw=lw, zorder=3))
    if c:
        ax.text(x + w / 2, y + h * 0.66, t, ha="center", va="center", fontsize=tam, fontweight="bold", color=ec, zorder=4)
        ax.text(x + w / 2, y + h * 0.3, c, ha="center", va="center", fontsize=tam2, color=GRIS, zorder=4, linespacing=1.1)
    else:
        ax.text(x + w / 2, y + h / 2, t, ha="center", va="center", fontsize=tam, fontweight="bold", color=ec, zorder=4)


def fl(ax, p0, p1, c=AZUL_OSC, lw=0.8, rad=0.0, ls="-"):
    ax.add_patch(FancyArrowPatch(p0, p1, arrowstyle="-|>", mutation_scale=6, lw=lw, color=c, linestyle=ls,
                                 connectionstyle=f"arc3,rad={rad}", shrinkA=1, shrinkB=1, zorder=2))


def tx(ax, x, y, t, tam=6, c=GRIS, ha="center", peso="normal", va="center"):
    ax.text(x, y, t, ha=ha, va=va, fontsize=tam, color=c, fontweight=peso, zorder=5)


def ruta_datos():
    fig, ax = lienzo(20, 7.4, DOBLE, 2.65)
    caja(ax, 3.2, 6.2, 13.6, 1.0, "UC  (uc_simple)", "Moore, 11 estados: FETCH · DECODE · EXEC_R · EXEC_DIV · MEM_ADDR · MEM_READ · MEM_WRITE · EXEC_BR · JUMP_WAIT · WRITEBACK · HALT",
         fc=F_AM, ec=AMBAR, tam=7.5, tam2=6)
    y = 3.3
    B = [("PC", 0.2, 1.4, "registro"), ("IMEM", 2.1, 1.8, "rom · 4096"), ("IR", 4.4, 1.4, "registro"),
         ("DEC", 6.3, 1.6, "inm. I S B U J"), ("RF", 8.4, 1.8, "32 × 32 bits"), ("ALU", 10.7, 1.8, "3 tablas"),
         ("ALUOUT", 13.0, 1.8, "registro"), ("DMEM", 15.3, 2.0, "4 × ram 8 b"), ("MDR", 17.8, 1.9, "registro")]
    for n, x, w, c in B:
        fc, ec = (F_VE, VERDE) if n == "ALU" else (F_AZ, AZUL_OSC)
        caja(ax, x, y, w, 1.35, n, c, fc=fc, ec=ec)
    for (a, x0, w0, _), (b, x1, __, ___) in zip(B, B[1:]):
        fl(ax, (x0 + w0, y + 0.67), (x1, y + 0.67))
    caja(ax, 4.4, 1.55, 1.4, 1.0, "PCI", "PC de instr.", tam=7, tam2=5.5)
    caja(ax, 10.7, 1.5, 1.8, 1.05, "DIV", "1 bit/ciclo", fc=F_VE, ec=VERDE, tam=7, tam2=5.5)
    caja(ax, 15.3, 1.45, 2.0, 1.1, "E/S", "LED · HEX · TICKS\ncámara · visión", fc=F_MO, ec=MORADO, tam=7, tam2=5.3)
    fl(ax, (5.1, y), (5.1, 2.55))
    fl(ax, (11.6, 2.55), (11.6, y))
    fl(ax, (16.3, y), (16.3, 2.55))
    ax.plot([18.75, 18.75, 9.3], [y, 0.75, 0.75], color=ROJO, lw=0.9)
    ax.plot([13.9, 13.9], [y, 0.75], color=ROJO, lw=0.9)
    fl(ax, (9.3, 0.75), (9.3, y), c=ROJO, lw=0.9)
    tx(ax, 14.4, 0.4, "wdata: ALUOUT · MDR · PC + 4", 6.2, ROJO, peso="bold")
    ax.plot([4.4, 0.9], [2.05, 2.05], color=AMBAR, lw=0.9)
    fl(ax, (0.9, 2.05), (0.9, y), c=AMBAR, lw=0.9)
    tx(ax, 2.55, 1.55, "pc_src: PC + 4 · PCI + inm\n· rs1 + inm", 5.8, AMBAR, peso="bold")
    for xx in (0.9, 5.1, 9.3, 11.6, 13.9, 16.3):
        fl(ax, (xx, 6.2), (xx, 4.65), c=GRIS_CL, lw=0.6, ls="--")
    tx(ax, 10.0, 5.45, "pc_en · ir_en · alu_src · alu_op = funct3 · mem_read · mem_write · reg_write · aluout_en · mdr_en · div_start", 5.8)
    guardar(fig, "ruta_datos")


def uc():
    fig, ax = lienzo(20, 10.4, COL, 1.95)
    E = {"FETCH": (0.2, 4.6), "DECODE": (3.9, 4.6), "EXEC_R": (8.3, 8.6), "EXEC_DIV": (8.3, 6.6), "MEM_ADDR": (8.3, 4.6),
         "EXEC_BR": (8.3, 2.3), "HALT": (8.3, 0.2), "MEM_READ": (13.2, 5.5), "MEM_WRITE": (13.2, 3.6),
         "JUMP_WAIT": (13.2, 1.4), "WRITEBACK": (16.4, 8.6)}
    w, h = 3.5, 1.45
    col = {"HALT": (F_RO, ROJO), "EXEC_DIV": (F_VE, VERDE), "WRITEBACK": (F_AM, AMBAR), "FETCH": (F_AZ, AZUL_OSC),
           "DECODE": (F_AZ, AZUL_OSC)}
    for n, (x, y) in E.items():
        fc, ec = col.get(n, (F_MO, MORADO))
        caja(ax, x, y, w if n != "WRITEBACK" else 3.4, h, n, tam=5.6, fc=fc, ec=ec, lw=0.6)

    def c(n, l):
        x, y = E[n]
        ww = w if n != "WRITEBACK" else 3.4
        return {"r": (x + ww, y + h / 2), "l": (x, y + h / 2), "t": (x + ww / 2, y + h), "b": (x + ww / 2, y)}[l]

    fl(ax, c("FETCH", "r"), c("DECODE", "l"), lw=0.6)
    for d in ("EXEC_R", "EXEC_DIV", "MEM_ADDR", "EXEC_BR", "HALT"):
        fl(ax, c("DECODE", "r"), c(d, "l"), lw=0.6)
    fl(ax, c("MEM_ADDR", "r"), c("MEM_READ", "l"), lw=0.6)
    fl(ax, c("MEM_ADDR", "r"), c("MEM_WRITE", "l"), lw=0.6)
    fl(ax, c("EXEC_BR", "r"), c("JUMP_WAIT", "l"), lw=0.6)
    fl(ax, c("EXEC_R", "r"), c("WRITEBACK", "l"), lw=0.6)
    fl(ax, c("EXEC_DIV", "r"), c("WRITEBACK", "l"), lw=0.6)
    fl(ax, c("MEM_READ", "r"), c("WRITEBACK", "b"), lw=0.6)
    ax.plot([18.1, 18.1, 1.95], [10.05, 10.35, 10.35], color=GRIS, lw=0.6)
    fl(ax, (1.95, 10.35), (1.95, 6.05), c=GRIS, lw=0.6)
    tx(ax, 6.0, 9.9, "a FETCH", 5.2)
    guardar(fig, "uc")


def vision():
    fig, ax = lienzo(20, 5.6, DOBLE, 1.75)
    caja(ax, 0.1, 2.2, 2.3, 1.4, "OV7670", "320 × 240 · YUV\n31 cuadros/s", fc=F_MO, ec=MORADO)
    caja(ax, 3.0, 2.2, 2.4, 1.4, "cam_capture", "muestreo a 50 MHz\nfiltro de pulsos", fc=F_AM, ec=AMBAR)
    caja(ax, 5.95, 3.95, 2.8, 1.3, "memoria Y·UV", "video a color", fc=F_AM, ec=AMBAR, tam=7)
    caja(ax, 6.1, 2.2, 2.5, 1.4, "block_avg", "4 × 4 → 80 × 60", fc=F_AM, ec=AMBAR)
    caja(ax, 9.3, 2.2, 2.8, 1.4, "fondo_mascara", "F += (I − F)/2^α\n|I − F| > umbral", fc=F_AM, ec=AMBAR)
    caja(ax, 9.3, 0.15, 2.8, 1.35, "NEURA-32", "manchas · red · votos\nreglas", fc=F_AZ, ec=AZUL_OSC)
    caja(ax, 13.0, 3.95, 2.7, 1.3, "vga_draw", "silueta · zona · letreros", fc=F_AM, ec=AMBAR)
    caja(ax, 16.5, 3.95, 3.3, 1.3, "Monitor VGA", "640 × 480 · 62.5 Hz", fc=F_VE, ec=VERDE)
    caja(ax, 13.0, 1.65, 2.7, 1.3, "pc_view", "160 × 120 por JTAG", fc=F_AM, ec=AMBAR)
    caja(ax, 16.5, 1.65, 3.3, 1.3, "PC", "ver_vigia.py", fc=F_VE, ec=VERDE)
    fl(ax, (2.4, 2.9), (3.0, 2.9))
    fl(ax, (5.4, 3.2), (6.1, 4.6))
    fl(ax, (5.4, 2.9), (6.1, 2.9))
    fl(ax, (8.6, 2.9), (9.3, 2.9))
    fl(ax, (10.7, 2.2), (10.7, 1.5))
    tx(ax, 11.05, 1.85, "máscara", 5.2, ha="left")
    fl(ax, (8.6, 4.6), (13.0, 4.6))
    fl(ax, (12.1, 3.3), (13.0, 4.2))
    fl(ax, (12.1, 2.6), (13.0, 2.3))
    fl(ax, (12.1, 0.8), (13.6, 3.95), c=AZUL, rad=-0.3)
    tx(ax, 14.9, 0.55, "registros: zona, línea, recuadros, letreros", 5.6, AZUL)
    fl(ax, (15.7, 4.6), (16.5, 4.6))
    fl(ax, (15.7, 2.3), (16.5, 2.3))
    guardar(fig, "vision")


def rendimiento():
    fig, (a, b, c) = plt.subplots(1, 3, figsize=(DOBLE, 1.75), gridspec_kw={"width_ratios": [1.2, 0.9, 1.35]})
    p = ["(a+b)·c", "ISA", "red 3×3", "Vigía"]
    v = [4.00, 4.66, 4.09, 4.22]
    a.bar(p, v, color=[AZUL_OSC, MORADO, VERDE, ROJO], width=0.6)
    for k, x in enumerate(v):
        a.text(k, x + 0.08, f"{x:.2f}", ha="center", fontsize=6.5, fontweight="bold")
    a.set_ylim(0, 5.4)
    a.set_title("(a) CPI por programa")
    b.bar(["software", "xnor+cpop"], [82859, 33678], color=[GRIS_CL, VERDE], width=0.55)
    b.text(0, 85000, "82 859", ha="center", fontsize=6.5, fontweight="bold")
    b.text(1, 36000, "33 678", ha="center", fontsize=6.5, fontweight="bold", color=VERDE)
    b.text(0.5, 62000, "×2.46", ha="center", fontsize=10, fontweight="bold", color=VERDE)
    b.set_ylim(0, 98000)
    b.set_yticks([0, 40000, 80000])
    b.set_yticklabels(["0", "40 k", "80 k"])
    b.set_title("(b) Ciclos por clasificación")
    c.barh([0], [251942], color=ROJO, height=0.45)
    c.barh([0], [548058], left=[251942], color="#EEF1F4", height=0.45)
    c.text(125971, 0, "10.1 ms\n31 %", ha="center", va="center", color="white", fontsize=6.5, fontweight="bold")
    c.text(525971, 0, "libre: 21.9 ms", ha="center", va="center", color=GRIS, fontsize=6.5)
    c.set_xlim(0, 800000)
    c.set_yticks([])
    c.set_xticks([0, 400000, 800000])
    c.set_xticklabels(["0", "400 k", "800 k ciclos"])
    c.set_title("(c) Peor cuadro frente a 32 ms")
    c.grid(axis="y", visible=False)
    fig.tight_layout(w_pad=1.2)
    guardar(fig, "rendimiento")


def recursos():
    fig, (a, b) = plt.subplots(1, 2, figsize=(DOBLE, 2.0), gridspec_kw={"width_ratios": [1.25, 0.8]})
    le = [("vga_draw", 2165, AMBAR), ("regfile", 1633, AZUL), ("block_avg", 1280, AMBAR), ("alu_riscv", 1229, AZUL),
          ("resto del CPU", 863, AZUL), ("pc_view", 611, AMBAR), ("registros visión", 449, MORADO),
          ("fondo_mascara", 299, AMBAR), ("cam_capture", 181, AMBAR), ("periféricos", 174, MORADO),
          ("divider", 140, AZUL), ("cargador JTAG", 99, MORADO), ("uc_simple", 35, AZUL)]
    le.sort(key=lambda t: t[1])
    a.barh([t[0] for t in le], [t[1] for t in le], color=[t[2] for t in le], height=0.65)
    for k, t in enumerate(le):
        a.text(t[1] + 25, k, f"{t[1]:,}".replace(",", " "), va="center", fontsize=5.8)
    a.set_xlim(0, 2550)
    a.tick_params(axis="y", labelsize=6.3)
    a.grid(axis="y", visible=False)
    a.set_title("(a) Elementos lógicos por bloque (9 292 en total)")
    m9 = [("video Y", 57), ("vista PC", 36), ("video UV", 25), ("IMEM", 16), ("DMEM", 16), ("fondo", 8), ("otros", 6)]
    cuñas, _ = b.pie([t[1] for t in m9], startangle=90, counterclock=False,
          colors=[AMBAR, "#E9B65C", "#F2D29B", AZUL, "#5E9DC8", VERDE, GRIS_CL],
          wedgeprops={"width": 0.42, "edgecolor": "white", "linewidth": 0.8})
    b.legend(cuñas, [f"{t[0]}  {t[1]}" for t in m9], loc="center left", bbox_to_anchor=(0.98, 0.5), fontsize=6.2,
             handlelength=0.9, borderpad=0, frameon=False)
    b.text(0, 0, "164 / 182\nM9K", ha="center", va="center", fontsize=7.5, fontweight="bold")
    b.set_title("(b) Bloques M9K (90 %)")
    fig.tight_layout(w_pad=1.5)
    guardar(fig, "recursos")


def red():
    fig, (a, b) = plt.subplots(1, 2, figsize=(COL, 1.55), gridspec_kw={"width_ratios": [1, 1.05]})
    M = [[573, 13, 14], [19, 524, 57], [8, 40, 552]]
    a.imshow(M, cmap="Blues", vmin=0, vmax=650)
    for i in range(3):
        for j in range(3):
            a.text(j, i, M[i][j], ha="center", va="center", fontsize=6.5, fontweight="bold",
                   color="white" if M[i][j] > 300 else TINTA)
    lab = ["pers.", "obj.", "ruido"]
    a.set_xticks(range(3))
    a.set_xticklabels(lab, fontsize=6)
    a.set_yticks(range(3))
    a.set_yticklabels(lab, fontsize=6)
    a.set_xlabel("predicha", fontsize=6)
    a.set_ylabel("real", fontsize=6)
    a.grid(False)
    a.set_title("(a) 91.6 % en 1 800", fontsize=7)
    t = ["completo", "medio", "busto"]
    v = [92.8, 96.0, 95.8]
    b.bar(t, v, color=[AZUL_OSC, AZUL, "#5E9DC8"], width=0.6)
    for k, x in enumerate(v):
        b.text(k, x + 0.4, f"{x:.1f}", ha="center", fontsize=6, fontweight="bold")
    b.set_ylim(85, 100)
    b.tick_params(axis="x", labelsize=6)
    b.set_title("(b) personas (%)", fontsize=7)
    fig.tight_layout(w_pad=0.8)
    guardar(fig, "red")


def placa():
    P = os.path.join(RAIZ, "fpga", "prueba_camara")
    fs = [("captura.png", "(a) XCLK sin invertir"), ("captura_xclk_inv.png", "(b) XCLK a 180°"),
          ("antes_ajuste.png", "(c) antes del ajuste"), ("despues_ajuste.png", "(d) 157 registros de ajuste")]
    fig, ax = plt.subplots(1, 4, figsize=(DOBLE, 1.45))
    for a, (n, t) in zip(ax, fs):
        a.imshow(Image.open(os.path.join(P, n)).convert("L").resize((320, 240)), cmap="gray")
        a.set_title(t, fontsize=6.5, fontweight="normal")
        a.axis("off")
    fig.subplots_adjust(0, 0, 1, 0.88, wspace=0.04)
    fig.savefig(os.path.join(SALIDA, "placa.pdf"), dpi=300, pad_inches=0.01, bbox_inches="tight")
    plt.close(fig)


def resultado():
    fs = [("video_160x120.png", "(a) video de la cámara"), ("mascara_80x60.png", "(b) máscara 80 × 60"),
          ("vga_vigia.png", "(c) monitor: intrusión")]
    fig, ax = plt.subplots(1, 3, figsize=(COL, 0.98))
    for a, (n, t) in zip(ax, fs):
        a.imshow(Image.open(os.path.join(IMG, n)).convert("RGB"))
        a.set_title(t, fontsize=5.6, fontweight="normal", pad=2)
        a.axis("off")
    fig.subplots_adjust(0, 0, 1, 0.86, wspace=0.05)
    fig.savefig(os.path.join(SALIDA, "resultado.pdf"), dpi=300, pad_inches=0.01, bbox_inches="tight")
    plt.close(fig)


def copiar_rtl():
    R = os.path.join(IMG, "rtl")
    for n in ("soc_neura32", "riscv_neura", "riscv_neura_dec_dmem", "riscv_neura_rf_uc_alu", "uc_simple_estados",
              "uc_simple_salidas", "alu_cpop", "divider"):
        im = Image.open(os.path.join(R, n + ".png")).convert("RGB")
        if n == "uc_simple_estados":
            w, h = im.size
            im = im.crop((int(w * 0.10), int(h * 0.15), int(w * 0.90), int(h * 0.71)))
        im.save(os.path.join(SALIDA, "rtl_" + n + ".png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(SALIDA, exist_ok=True)
    for f in (ruta_datos, uc, vision, rendimiento, recursos, red, placa, resultado, copiar_rtl):
        f()
        print("listo:", f.__name__)
