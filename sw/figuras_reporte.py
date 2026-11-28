import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
SALIDA = os.path.join(RAIZ, "docs", "img")

AZUL_OSC = "#0E2A47"
AZUL = "#1D6FA5"
AMBAR = "#D98B12"
VERDE = "#1F7A6C"
ROJO = "#B5452F"
MORADO = "#6B5B95"
GRIS = "#5B6770"
GRIS_CL = "#C9D1D9"
TINTA = "#1E293B"
FONDO_AZ = "#ECF3FA"
FONDO_AM = "#FBF1E1"
FONDO_VE = "#E6F2EF"
FONDO_RO = "#F6E7E3"
FONDO_MO = "#EEEBF4"


def fuente():
    hay = {f.name for f in font_manager.fontManager.ttflist}
    for n in ("Segoe UI", "Arial", "DejaVu Sans"):
        if n in hay:
            return n
    return "sans-serif"


plt.rcParams.update({
    "font.family": fuente(), "font.size": 15, "axes.titlesize": 17, "axes.titleweight": "bold",
    "axes.edgecolor": GRIS, "axes.labelcolor": TINTA, "axes.linewidth": 1.1,
    "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True,
    "grid.color": "#E3E6EA", "xtick.color": GRIS, "ytick.color": GRIS, "text.color": TINTA,
    "legend.frameon": False, "figure.facecolor": "white", "axes.facecolor": "white",
    "savefig.facecolor": "white", "savefig.dpi": 170,
})


def guardar(fig, nombre):
    os.makedirs(SALIDA, exist_ok=True)
    fig.savefig(os.path.join(SALIDA, nombre + ".png"), bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)


def lienzo(w, h, pulg=(16, 6)):
    fig, ax = plt.subplots(figsize=pulg)
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.axis("off")
    return fig, ax


def caja(ax, x, y, w, h, titulo, cuerpo="", fc=FONDO_AZ, ec=AZUL_OSC, tam=15, tam2=11.5, lw=2.0):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                                fc=fc, ec=ec, lw=lw, zorder=3))
    if cuerpo:
        ax.text(x + w / 2, y + h * 0.64, titulo, ha="center", va="center", fontsize=tam,
                fontweight="bold", color=ec, zorder=4)
        ax.text(x + w / 2, y + h * 0.28, cuerpo, ha="center", va="center", fontsize=tam2,
                color=GRIS, zorder=4, linespacing=1.25)
    else:
        ax.text(x + w / 2, y + h / 2, titulo, ha="center", va="center", fontsize=tam,
                fontweight="bold", color=ec, zorder=4)


def flecha(ax, p0, p1, color=AZUL_OSC, lw=2.0, rad=0.0, ls="-"):
    ax.add_patch(FancyArrowPatch(p0, p1, arrowstyle="-|>", mutation_scale=16, lw=lw, color=color,
                                 connectionstyle=f"arc3,rad={rad}", linestyle=ls, zorder=2,
                                 shrinkA=2, shrinkB=2))


def etiqueta(ax, x, y, t, tam=11.5, color=GRIS, ha="center", peso="normal"):
    ax.text(x, y, t, ha=ha, va="center", fontsize=tam, color=color, fontweight=peso, zorder=5)


# ------------------------------------------------------------------ camino de datos
def ruta_datos():
    fig, ax = lienzo(20, 10, (17, 8.5))
    caja(ax, 4.0, 8.25, 12.0, 1.3, "UC  ·  uc_simple", "11 estados (Moore): FETCH · DECODE · EXEC_R · EXEC_DIV · MEM_ADDR · MEM_READ · MEM_WRITE · EXEC_BR · JUMP_WAIT · WRITEBACK · HALT",
         fc=FONDO_AM, ec=AMBAR)
    y = 4.6
    b = [("PC", 0.3, 1.3, "registro"), ("IMEM", 2.1, 1.7, "rom · 4096 instr."), ("IR", 4.3, 1.2, "registro"),
         ("DEC", 6.0, 1.4, "decoder\ninm I S B U J"), ("RF", 7.9, 1.7, "regfile\n32 × 32 bits"),
         ("ALU", 10.4, 1.7, "alu_riscv\n3 tablas"), ("ALUOUT", 12.7, 1.7, "registro"),
         ("DMEM", 15.0, 2.0, "4 × ram de 8 bits"), ("MDR", 17.7, 1.6, "registro")]
    for n, x, w, c in b:
        fc, ec = (FONDO_VE, VERDE) if n in ("ALU",) else (FONDO_AZ, AZUL_OSC)
        caja(ax, x, y, w, 1.6, n, c, fc=fc, ec=ec)
    for (n0, x0, w0, _), (n1, x1, _, __) in zip(b, b[1:]):
        flecha(ax, (x0 + w0, y + 0.8), (x1, y + 0.8))
    caja(ax, 4.3, 2.4, 1.2, 1.2, "PCI", "PC de la\ninstr.", tam=13, tam2=9.5)
    caja(ax, 10.4, 2.3, 1.7, 1.3, "DIV", "divider\n1 bit/ciclo", fc=FONDO_VE, ec=VERDE, tam=13, tam2=10)
    caja(ax, 15.0, 2.2, 2.0, 1.4, "E/S", "LED · SW · HEX\nKEY · TICKS\ncámara · visión", fc=FONDO_MO, ec=MORADO, tam=13, tam2=9.5)
    flecha(ax, (4.9, 4.6), (4.9, 3.6))
    flecha(ax, (11.25, 3.6), (11.25, 4.6))
    flecha(ax, (16.0, 4.6), (16.0, 3.6))
    ax.plot([18.5, 18.5, 9.4], [4.6, 1.45, 1.45], color=ROJO, lw=2.0, zorder=1)
    ax.plot([13.55, 13.55], [4.6, 1.45], color=ROJO, lw=2.0, zorder=1)
    flecha(ax, (9.4, 1.45), (9.4, 4.6), color=ROJO)
    etiqueta(ax, 13.6, 1.05, "wdata: ALUOUT · MDR · PC + 4  (result_src)", 12, ROJO, peso="bold")
    ax.plot([4.3, 0.95], [3.0, 3.0], color=AMBAR, lw=2.0, zorder=1)
    flecha(ax, (0.95, 3.0), (0.95, 4.6), color=AMBAR)
    etiqueta(ax, 2.2, 2.35, "pc_src: PC + 4 · PCI + inm\n· rs1 + inm", 11, AMBAR, peso="bold")
    for xx in (1.0, 5.0, 8.7, 11.2, 13.5, 16.0):
        flecha(ax, (xx, 8.25), (xx, 6.25), color=GRIS_CL, lw=1.6, ls="--")
    etiqueta(ax, 10.0, 7.35, "pc_en · ir_en · alu_src · alu_op = funct3 · mem_read · mem_write · reg_write · aluout_en · mdr_en · div_start", 11, GRIS)
    etiqueta(ax, 2.95, 6.55, "tablas y pesos (lw)", 10.5, GRIS)
    guardar(fig, "ruta_datos")


# ------------------------------------------------------------------ máquina de estados
def unidad_control():
    fig, ax = lienzo(20, 9.9, (17, 8.3))
    E = {"FETCH": (0.4, 4.2), "DECODE": (3.6, 4.2), "EXEC_R": (7.6, 7.6), "EXEC_DIV": (7.6, 5.9),
         "MEM_ADDR": (7.6, 4.2), "EXEC_BR": (7.6, 2.0), "HALT": (7.6, 0.3), "MEM_READ": (11.6, 4.9),
         "MEM_WRITE": (11.6, 3.3), "JUMP_WAIT": (11.6, 1.3), "WRITEBACK": (15.6, 7.0)}
    col = {"FETCH": (FONDO_AZ, AZUL_OSC), "DECODE": (FONDO_AZ, AZUL_OSC), "HALT": (FONDO_RO, ROJO),
           "EXEC_DIV": (FONDO_VE, VERDE), "WRITEBACK": (FONDO_AM, AMBAR)}
    w, h = 2.9, 1.15
    for n, (x, y) in E.items():
        fc, ec = col.get(n, (FONDO_MO, MORADO))
        caja(ax, x, y, w, h, n, tam=13.5, fc=fc, ec=ec)

    def c(n, lado):
        x, y = E[n]
        return {"r": (x + w, y + h / 2), "l": (x, y + h / 2), "t": (x + w / 2, y + h), "b": (x + w / 2, y)}[lado]

    flecha(ax, c("FETCH", "r"), c("DECODE", "l"))
    for d, t in (("EXEC_R", "R · I · lui"), ("EXEC_DIV", "divu · remu"), ("MEM_ADDR", "carga · almacenar"),
                 ("EXEC_BR", "saltos · jal · jalr"), ("HALT", "ecall")):
        flecha(ax, c("DECODE", "r"), c(d, "l"), rad=0.0)
        x1, y1 = c(d, "t")
        etiqueta(ax, x1, y1 + 0.2, t, 10.5, GRIS)
    flecha(ax, c("MEM_ADDR", "r"), c("MEM_READ", "l"))
    flecha(ax, c("MEM_ADDR", "r"), c("MEM_WRITE", "l"))
    flecha(ax, c("EXEC_BR", "r"), c("JUMP_WAIT", "l"))
    etiqueta(ax, 12.9, 2.75, "si el PC cambia", 10.5)
    flecha(ax, c("EXEC_R", "r"), c("WRITEBACK", "l"))
    flecha(ax, c("EXEC_DIV", "r"), c("WRITEBACK", "l"))
    etiqueta(ax, 13.2, 7.2, "espera ready (32 ciclos)", 10.5, VERDE)
    flecha(ax, c("MEM_READ", "r"), c("WRITEBACK", "b"))
    ax.plot([17.05, 17.05, 1.85], [8.15, 9.25, 9.25], color=GRIS, lw=1.8, zorder=1)
    flecha(ax, (1.85, 9.25), (1.85, 5.35), color=GRIS, lw=1.8)
    etiqueta(ax, 9.4, 9.55, "de vuelta a FETCH  (también desde MEM_WRITE, JUMP_WAIT y un salto que no se cumple)", 11, GRIS)
    tabla = [("R, I, lui", 4), ("carga", 5), ("almacenar", 4), ("salto no", 3), ("salto sí", 4), ("divu, remu", 36)]
    for k, (t, n) in enumerate(tabla):
        etiqueta(ax, 15.9, 5.2 - k * 0.62, f"{t}", 11.5, TINTA, ha="left")
        etiqueta(ax, 19.4, 5.2 - k * 0.62, f"{n} ciclos", 11.5, AZUL, ha="right", peso="bold")
    etiqueta(ax, 17.6, 5.85, "Ciclos por instrucción", 12.5, AZUL_OSC, peso="bold")
    guardar(fig, "unidad_control")


# ------------------------------------------------------------------ etapas
def etapas():
    fig, ax = lienzo(20, 7.4, (17, 6.3))
    E = [("0", "riscv_ab_c", "(a+b)·c de la clase", AZUL_OSC, FONDO_AZ),
         ("1", "alu_op = funct3", "8 ops por tabla", AZUL, FONDO_AZ),
         ("2", "OP_R2 / OP_I2", "sub slt xnor min max", AZUL, FONDO_AZ),
         ("3", "Saltos", "B · U · J · jal · jalr", MORADO, FONDO_MO),
         ("4", "Memoria", "ALUOUT · MDR · bytes", MORADO, FONDO_MO),
         ("5", "OP_R3", "divu remu cpop abs", VERDE, FONDO_VE),
         ("6", "E/S", "LED · HEX · TICKS", VERDE, FONDO_VE),
         ("7", "Cargador", "otro .txt por JTAG", AMBAR, FONDO_AM),
         ("8", "Visión", "cámara · VGA · PC", AMBAR, FONDO_AM),
         ("9", "Vigía", "1 470 instrucciones", ROJO, FONDO_RO)]
    w = 3.4
    for k, (n, t, c, ec, fc) in enumerate(E):
        x = 0.35 + (k % 5) * 3.95
        y = 4.6 if k < 5 else 0.4
        caja(ax, x, y, w, 2.3, t, c, fc=fc, ec=ec, tam=15, tam2=12)
        ax.add_patch(plt.Circle((x + 0.05, y + 2.3), 0.4, color=ec, zorder=4))
        etiqueta(ax, x + 0.05, y + 2.3, n, 14, "white", peso="bold")
        if k % 5:
            flecha(ax, (x - 0.55, y + 1.15), (x, y + 1.15), lw=1.8)
    ax.plot([17.9, 17.9, 2.05], [4.6, 3.6, 3.6], color=GRIS_CL, lw=1.8, zorder=1)
    flecha(ax, (2.05, 3.6), (2.05, 2.7), color=GRIS_CL, lw=1.8)
    guardar(fig, "etapas")


# ------------------------------------------------------------------ ISA
def isa():
    fig, ax = plt.subplots(figsize=(15, 6.3))
    ax.axis("off")
    cols = ["OP_R1 / OP_I1\n(la de la clase)", "OP_R2 / OP_I2", "OP_R3", "OP_BRANCH"]
    T = [["add", "mul", "and", "or", "xor", "nota", "sll", "srl"],
         ["sub", "slt", "sltu", "sra", "xnor", "min", "minu", "max"],
         ["divu", "remu", "cpop", "abs", "sgt", "clamp", "", ""],
         ["beq", "bne", "", "", "blt", "bge", "bltu", "bgeu"]]
    fc = [FONDO_AZ, FONDO_MO, FONDO_VE, FONDO_AM]
    ec = [AZUL_OSC, MORADO, VERDE, AMBAR]
    red = {"xnor", "cpop", "min", "max", "abs", "sgt"}
    ax.set_xlim(0, 5)
    ax.set_ylim(0, 9.3)
    for j, c in enumerate(cols):
        ax.text(1.5 + j, 8.75, c, ha="center", va="center", fontsize=13, fontweight="bold", color=ec[j])
    for i in range(8):
        ax.text(0.5, 7.7 - i, f"{i:03b}", ha="center", va="center", fontsize=14, family="monospace", color=GRIS)
        for j in range(4):
            t = T[j][i]
            if not t:
                continue
            ax.add_patch(FancyBboxPatch((1.08 + j, 7.28 - i), 0.84, 0.84, boxstyle="round,pad=0.01,rounding_size=0.08",
                                        fc=fc[j], ec=ROJO if t in red else ec[j], lw=3 if t in red else 1.4))
            ax.text(1.5 + j, 7.7 - i, t, ha="center", va="center", fontsize=14, family="monospace",
                    fontweight="bold", color=ec[j])
    ax.text(0.5, 8.75, "funct3", ha="center", va="center", fontsize=13, fontweight="bold", color=GRIS)
    ax.text(2.5, -0.05, "Borde rojo: las instrucciones que usa la red neuronal y el voto entre cuadros.  "
            "Más cargas, almacenamientos, lui, jal, jalr y ecall: 49 instrucciones con 12 opcodes.",
            ha="center", va="center", fontsize=11.5, color=GRIS)
    guardar(fig, "isa")


# ------------------------------------------------------------------ rendimiento
def rendimiento():
    fig, (a, b, c) = plt.subplots(1, 3, figsize=(17, 5.2), gridspec_kw={"width_ratios": [1.25, 1, 1.25]})
    p = ["(a+b)·c", "prueba ISA", "red 3×3", "Vigía"]
    v = [4.00, 4.66, 4.09, 4.22]
    a.bar(p, v, color=[AZUL_OSC, MORADO, VERDE, ROJO], width=0.62)
    for k, x in enumerate(v):
        a.text(k, x + 0.06, f"{x:.2f}", ha="center", fontsize=14, fontweight="bold", color=TINTA)
    a.set_ylim(0, 5.3)
    a.set_title("Ciclos por instrucción (CPI)")
    a.tick_params(axis="x", labelsize=12.5)
    b.bar(["software", "xnor + cpop"], [82859, 33678], color=[GRIS_CL, VERDE], width=0.58)
    b.text(0, 82859 + 2500, "82 859", ha="center", fontsize=14, fontweight="bold")
    b.text(1, 33678 + 2500, "33 678", ha="center", fontsize=14, fontweight="bold", color=VERDE)
    b.text(0.5, 66000, "× 2.46", ha="center", fontsize=22, fontweight="bold", color=VERDE)
    b.set_ylim(0, 95000)
    b.set_title("Ciclos por clasificación")
    b.ticklabel_format(axis="y", style="plain")
    c.barh([0], [251942], color=ROJO, height=0.5)
    c.barh([0], [800000 - 251942], left=[251942], color="#EEF1F4", height=0.5)
    c.text(125971, 0, "10.1 ms\n31 %", ha="center", va="center", color="white", fontsize=14, fontweight="bold")
    c.text(525971, 0, "libre: 21.9 ms", ha="center", va="center", color=GRIS, fontsize=13)
    c.set_xlim(0, 800000)
    c.set_yticks([])
    c.set_xticks([0, 200000, 400000, 600000, 800000])
    c.set_xticklabels(["0", "200 k", "400 k", "600 k", "800 k"])
    c.set_xlabel("ciclos de un cuadro de la cámara (32 ms a 25 MHz)")
    c.set_title("Peor cuadro con una persona")
    c.grid(axis="y", visible=False)
    fig.tight_layout(w_pad=2.5)
    guardar(fig, "rendimiento")


# ------------------------------------------------------------------ recursos
def recursos():
    fig, (a, b) = plt.subplots(1, 2, figsize=(17, 6.2), gridspec_kw={"width_ratios": [1.15, 1]})
    le = [("vga_draw (monitor y letreros)", 2165, AMBAR), ("regfile (RF)", 1633, AZUL),
          ("block_avg (promedio 4×4)", 1280, AMBAR), ("alu_riscv (ALU)", 1229, AZUL),
          ("resto del procesador", 3900 - 1633 - 1229 - 140 - 35, AZUL), ("pc_view (video a la PC)", 611, AMBAR),
          ("registros de visión", 449, MORADO), ("fondo_mascara", 299, AMBAR), ("periféricos", 174, MORADO),
          ("cam_capture", 181, AMBAR), ("divider (DIV)", 140, AZUL), ("cargador JTAG", 99, MORADO),
          ("uc_simple (UC)", 35, AZUL)]
    le.sort(key=lambda t: t[1])
    a.barh([t[0] for t in le], [t[1] for t in le], color=[t[2] for t in le], height=0.66)
    for k, t in enumerate(le):
        a.text(t[1] + 30, k, f"{t[1]:,}".replace(",", " "), va="center", fontsize=12)
    a.set_title("Elementos lógicos por bloque  (9 292 en total, 19 %)")
    a.tick_params(axis="y", labelsize=12)
    a.set_xlim(0, 2600)
    a.grid(axis="y", visible=False)
    m9 = [("video Y (320×240)", 57), ("vista en la PC", 36), ("video UV", 25), ("IMEM (programa)", 16),
          ("DMEM (datos)", 16), ("fondo", 8), ("máscaras y línea VGA", 6)]
    b.pie([t[1] for t in m9], labels=[f"{t[0]}  {t[1]}" for t in m9], startangle=90, counterclock=False,
          colors=[AMBAR, "#E9B65C", "#F2D29B", AZUL, "#5E9DC8", VERDE, GRIS_CL],
          wedgeprops={"width": 0.42, "edgecolor": "white", "linewidth": 2}, textprops={"fontsize": 12.5})
    b.text(0, 0, "164\nde 182\nM9K", ha="center", va="center", fontsize=17, fontweight="bold", color=TINTA)
    b.set_title("Bloques de memoria M9K (90 %)")
    fig.tight_layout(w_pad=3)
    guardar(fig, "recursos")


# ------------------------------------------------------------------ verificación
def verificacion():
    fig, ax = plt.subplots(figsize=(15, 4.6))
    B = [("tb_programa_ab_c", 3, "el programa de la clase"), ("tb_uc_simple", 28, "recorridos de la UC"),
         ("tb_prueba_isa", 64, "las 49 instrucciones"), ("tb_red_neuronal", 481, "clasificador 3 × 3"),
         ("tb_cargador", 7, "otro programa por JTAG"), ("tb_vision", 11, "cámara, máscara y monitor"),
         ("tb_vigia", 31, "sistema completo con cámara simulada")]
    for k, (n, t, d) in enumerate(B[::-1]):
        ax.barh(k, 1, color=VERDE, height=0.62)
        ax.text(0.02, k, f"{t} / {t}", va="center", color="white", fontsize=13.5, fontweight="bold")
        ax.text(1.02, k, d, va="center", fontsize=12.5, color=GRIS)
    ax.set_yticks(range(len(B)))
    ax.set_yticklabels([b[0] for b in B[::-1]], family="monospace", fontsize=12.5)
    ax.set_xlim(0, 1.75)
    ax.set_xticks([])
    ax.grid(False)
    ax.spines["bottom"].set_visible(False)
    ax.set_title("625 comprobaciones automáticas, 0 errores")
    guardar(fig, "verificacion")


# ------------------------------------------------------------------ red neuronal
def red():
    fig, (a, b, c) = plt.subplots(1, 3, figsize=(17, 5.4), gridspec_kw={"width_ratios": [1.35, 1, 0.9]})
    a.axis("off")
    a.set_xlim(0, 10)
    a.set_ylim(0, 10)
    capas = [(1.2, 12, "512 bits\nsilueta 16 × 32", AZUL), (5.0, 9, "64 neuronas\nxnor + cpop ≥ T", VERDE),
             (8.6, 3, "3 clases", ROJO)]
    pts = []
    for x, n, t, col in capas:
        ys = [1.6 + i * (7.2 / max(n - 1, 1)) for i in range(n)] if n > 1 else [5]
        if n == 3:
            ys = [3.2, 5.2, 7.2]
        pts.append((x, ys, col))
        a.text(x, 0.4, t, ha="center", va="center", fontsize=12, color=col, fontweight="bold")
    for (x0, y0s, _), (x1, y1s, _) in zip(pts, pts[1:]):
        for y0 in y0s:
            for y1 in y1s:
                a.plot([x0, x1], [y0, y1], color="#DDE3E8", lw=0.7, zorder=1)
    for x, ys, col in pts:
        for y in ys:
            a.add_patch(plt.Circle((x, y), 0.27, color=col, zorder=3))
    for y, t in zip([3.2, 5.2, 7.2], ["ruido", "objeto", "persona"]):
        a.text(9.15, y, t, va="center", fontsize=12, color=TINTA)
    a.set_title("Red binaria 512 → 64 → 3")
    M = [[573, 13, 14], [19, 524, 57], [8, 40, 552]]
    b.imshow(M, cmap="Blues", vmin=0, vmax=650)
    for i in range(3):
        for j in range(3):
            b.text(j, i, M[i][j], ha="center", va="center", fontsize=16, fontweight="bold",
                   color="white" if M[i][j] > 300 else TINTA)
    lab = ["persona", "objeto", "ruido"]
    b.set_xticks(range(3))
    b.set_xticklabels(lab)
    b.set_yticks(range(3))
    b.set_yticklabels(lab)
    b.set_xlabel("predicha")
    b.set_ylabel("real")
    b.grid(False)
    b.set_title("91.6 % en 1 800 siluetas")
    t = ["cuerpo\ncompleto", "medio\ncuerpo", "busto"]
    v = [92.8, 96.0, 95.8]
    c.bar(t, v, color=[AZUL_OSC, AZUL, "#5E9DC8"], width=0.6)
    for k, x in enumerate(v):
        c.text(k, x + 0.6, f"{x:.1f} %", ha="center", fontsize=14, fontweight="bold")
    c.set_ylim(80, 100)
    c.set_title("Personas reconocidas")
    fig.tight_layout(w_pad=2.5)
    guardar(fig, "red_neuronal")


# ------------------------------------------------------------------ visión y memoria
def vision():
    fig, ax = lienzo(20, 6.6, (17, 5.8))
    caja(ax, 0.2, 2.7, 2.4, 1.6, "OV7670", "320 × 240\nYUV 4:2:2 · 31 c/s", fc=FONDO_MO, ec=MORADO)
    caja(ax, 3.3, 2.7, 2.5, 1.6, "cam_capture", "muestrea a 50 MHz\nfiltra pulsos falsos", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 6.6, 4.6, 2.6, 1.5, "memoria Y · UV", "video a color\nen M9K", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 6.6, 2.7, 2.6, 1.5, "block_avg", "promedio 4 × 4\n→ 80 × 60", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 10.0, 2.7, 2.9, 1.5, "fondo_mascara", "F += (I − F) / 2^α\n|I − F| > umbral", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 10.0, 0.4, 2.9, 1.5, "NEURA-32", "manchas · red · votos\nreglas · recuadros", fc=FONDO_AZ, ec=AZUL_OSC)
    caja(ax, 13.8, 4.6, 2.8, 1.5, "vga_draw", "silueta · zona · línea\nletreros 8 × 16", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 17.4, 4.6, 2.4, 1.5, "Monitor", "640 × 480\n62.5 Hz enganchado", fc=FONDO_VE, ec=VERDE)
    caja(ax, 13.8, 2.0, 2.8, 1.5, "pc_view", "cuadros completos\n160 × 120 por JTAG", fc=FONDO_AM, ec=AMBAR)
    caja(ax, 17.4, 2.0, 2.4, 1.5, "PC", "ver_vigia.py", fc=FONDO_VE, ec=VERDE)
    flecha(ax, (2.6, 3.5), (3.3, 3.5))
    flecha(ax, (5.8, 3.8), (6.6, 5.3))
    flecha(ax, (5.8, 3.4), (6.6, 3.4))
    flecha(ax, (9.2, 3.45), (10.0, 3.45))
    flecha(ax, (11.45, 2.7), (11.45, 1.9))
    etiqueta(ax, 12.1, 2.32, "máscara\n2 bancos", 10)
    flecha(ax, (9.2, 5.35), (13.8, 5.35))
    flecha(ax, (12.9, 3.6), (13.8, 4.9))
    flecha(ax, (12.9, 1.15), (14.3, 4.6), color=AZUL, rad=-0.3)
    etiqueta(ax, 15.7, 0.8, "registros: zona, línea,\nrecuadros, letreros", 10.5, AZUL)
    flecha(ax, (16.6, 5.35), (17.4, 5.35))
    flecha(ax, (16.6, 2.75), (17.4, 2.75))
    flecha(ax, (12.9, 3.2), (13.8, 2.9))
    etiqueta(ax, 10.0, 6.45, "Hardware: lo que se repite en cada pixel.   Procesador: lo que decide.", 13, TINTA, peso="bold")
    guardar(fig, "vision")


def mapa_memoria():
    fig, ax = lienzo(10, 8.6, (9.5, 7.6))
    Z = [("0x0000_0000", "Memoria de programa · 4096 palabras", "código (1 470) + tablas y pesos (1 466)", FONDO_AZ, AZUL_OSC),
         ("0x1000_0000", "Memoria de datos · 16 KB", "variables, manchas, pistas, pila", FONDO_AZ, AZUL),
         ("0x2000_0000", "Máscara de movimiento", "80 × 60, un byte por celda (lectura)", FONDO_AM, AMBAR),
         ("0xFFFF_0000", "Periféricos", "LEDS · SW · HEX · KEY · TICKS · CONSOLA", FONDO_MO, MORADO),
         ("0xFFFF_0040", "Cámara y visión", "SCCB por software · VIS_CTRL · VIS_EST", FONDO_MO, MORADO),
         ("0xFFFF_0054", "Dibujo sobre el video", "ZONA · LÍNEA · LETRERO · CAJA0..7", FONDO_VE, VERDE)]
    for k, (d, t, c, fc, ec) in enumerate(Z):
        y = 7.2 - k * 1.38
        caja(ax, 3.3, y, 6.5, 1.18, t, c, fc=fc, ec=ec, tam=13.5, tam2=10.5)
        etiqueta(ax, 3.05, y + 0.59, d, 12.5, TINTA, ha="right", peso="bold")
    guardar(fig, "mapa_memoria")


# ------------------------------------------------------------------ placa
def placa():
    P = os.path.join(RAIZ, "fpga", "prueba_camara")
    fs = [("captura.png", "XCLK sin invertir: renglones rotos"),
          ("captura_xclk_inv.png", "XCLK invertido (180°): imagen limpia"),
          ("antes_ajuste.png", "Antes de los 157 registros de ajuste"),
          ("despues_ajuste.png", "Con los 157 registros de ajuste")]
    W, H, pie = 640, 480, 70
    try:
        f = ImageFont.truetype("segoeuib.ttf", 26)
    except OSError:
        f = ImageFont.load_default()
    lienzo_img = Image.new("RGB", (W * 4 + 30 * 3, H + pie), "white")
    d = ImageDraw.Draw(lienzo_img)
    for k, (n, t) in enumerate(fs):
        im = Image.open(os.path.join(P, n)).convert("RGB").resize((W, H), Image.NEAREST)
        x = k * (W + 30)
        lienzo_img.paste(im, (x, 0))
        d.text((x + W / 2, H + pie / 2), t, fill=TINTA, font=f, anchor="mm")
    lienzo_img.save(os.path.join(SALIDA, "placa_camara.png"))


def portada():
    fig = plt.figure(figsize=(17, 7.2))
    fig.patch.set_facecolor(AZUL_OSC)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 17)
    ax.set_ylim(0, 7.2)
    ax.axis("off")
    ax.text(0.6, 6.15, "NEURA-32 Vigía", fontsize=44, fontweight="bold", color="white", va="center")
    ax.text(0.62, 5.3, "Vigilancia perimetral con una red neuronal binaria\nsobre el RISC-V multiciclo de la clase",
            fontsize=17, color="#C9D8E6", va="center", linespacing=1.35)
    ax.text(0.62, 4.25, "Laboratorio de Arquitecturas Computacionales · LA116\nRoberto Orozco Ramírez · Adam Del Pozo Ontiveros",
            fontsize=13.5, color="#93A9BF", va="center", linespacing=1.4)
    im = Image.open(os.path.join(SALIDA, "vga_vigia.png")).convert("RGB")
    a2 = fig.add_axes([0.585, 0.33, 0.39, 0.63])
    a2.imshow(im)
    a2.set_xticks([])
    a2.set_yticks([])
    for s in a2.spines.values():
        s.set_edgecolor(AMBAR)
        s.set_linewidth(3)
    a2.set_title("el monitor en la simulación del sistema completo", color="#C9D8E6", fontsize=11.5, pad=6)
    tarjetas = [("49", "instrucciones\n12 opcodes"), ("31", "cuadros por\nsegundo"), ("91.6 %", "aciertos de\nla red binaria"),
                ("× 2.46", "más rápida\ncon cpop"), ("625 / 625", "pruebas\nautomáticas"), ("19 %", "de la MAX 10\n9 292 LE")]
    for k, (n, t) in enumerate(tarjetas):
        x = 0.6 + k * 2.75
        ax.add_patch(FancyBboxPatch((x, 0.35), 2.45, 1.75, boxstyle="round,pad=0.02,rounding_size=0.15",
                                    fc="#163B60", ec="#2C5A85", lw=1.5))
        ax.text(x + 1.225, 1.55, n, ha="center", va="center", fontsize=24, fontweight="bold", color=AMBAR)
        ax.text(x + 1.225, 0.8, t, ha="center", va="center", fontsize=11.5, color="#C9D8E6", linespacing=1.25)
    fig.savefig(os.path.join(SALIDA, "portada.png"), dpi=150, facecolor=AZUL_OSC)
    plt.close(fig)


if __name__ == "__main__":
    for fn in (portada, ruta_datos, unidad_control, etapas, isa, rendimiento, recursos, verificacion, red, vision,
               mapa_memoria, placa):
        fn()
        print("listo:", fn.__name__)
