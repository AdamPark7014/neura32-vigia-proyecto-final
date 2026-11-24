import os
import numpy as np

rng = np.random.default_rng(2026)
ANCHO, ALTO = 80, 60
YY, XX = np.mgrid[0:ALTO, 0:ANCHO]

def elipse(cx, cy, rx, ry):
    return ((XX - cx) / max(rx, 0.5)) ** 2 + ((YY - cy) / max(ry, 0.5)) ** 2 <= 1.0

def rect(x0, y0, x1, y1):
    return (XX >= x0) & (XX <= x1) & (YY >= y0) & (YY <= y1)

def segmento(xa, ya, xb, yb, grosor):
    vx, vy = xb - xa, yb - ya
    l2 = vx * vx + vy * vy + 1e-9
    t = np.clip(((XX - xa) * vx + (YY - ya) * vy) / l2, 0, 1)
    px, py = xa + t * vx, ya + t * vy
    return (XX - px) ** 2 + (YY - py) ** 2 <= (grosor / 2.0) ** 2

def persona(alto, cx, pies, fase=None, de_lado=None, hombros=None):
    H = alto
    if fase is None:
        fase = rng.uniform(-1, 1)
    if de_lado is None:
        de_lado = rng.random() < 0.5
    if hombros is None:
        hombros = rng.random() < 0.5
    ancho_t = H * (rng.uniform(0.17, 0.22) if de_lado else rng.uniform(0.24, 0.32))
    top = pies - H + 1
    r_cab = max(1.0, H * rng.uniform(0.065, 0.085))
    m = elipse(cx + rng.uniform(-0.5, 0.5), top + r_cab, r_cab * 0.9, r_cab)
    hombro = top + 2 * r_cab
    cadera = top + H * rng.uniform(0.50, 0.56)
    if hombros:
        caida = H * rng.uniform(0.02, 0.05)
        m |= elipse(cx, hombro + caida, ancho_t / 2, caida)
        m |= rect(cx - ancho_t / 2, hombro + caida, cx + ancho_t / 2, cadera)
    else:
        m |= rect(cx - ancho_t / 2, hombro, cx + ancho_t / 2, cadera)
    m |= rect(cx - r_cab * 0.4, hombro - r_cab * 0.6, cx + r_cab * 0.4, hombro)
    paso = fase * H * 0.18
    g_pierna = max(1.6, ancho_t * 0.42)
    m |= segmento(cx - ancho_t * 0.22, cadera, cx - ancho_t * 0.22 - paso, pies, g_pierna)
    m |= segmento(cx + ancho_t * 0.22, cadera, cx + ancho_t * 0.22 + paso, pies, g_pierna)
    g_brazo = max(1.2, ancho_t * 0.28)
    largo = H * 0.36
    for lado in (-1, 1):
        ang = rng.uniform(-0.35, 0.35) + (lado * fase * 0.3)
        xb = cx + lado * ancho_t / 2 + np.sin(ang) * largo * 0.4 * lado
        m |= segmento(cx + lado * ancho_t / 2, hombro + 1, xb + np.sin(ang) * largo * 0.2, hombro + largo, g_brazo)
    if rng.random() < 0.2:
        lado = rng.choice([-1, 1])
        m |= rect(cx + lado * ancho_t / 2, hombro + 1, cx + lado * (ancho_t / 2 + H * 0.1), cadera - 1)
    return m

def persona_cerca(tipo, estatura=None, cx=None, top=None, corte=None, **kw):
    # persona cerca de la camara
    while True:
        if tipo == 1:
            H = rng.uniform(45, 115) if estatura is None else estatura
            visible = rng.uniform(0.40, 0.62)
        else:
            H = rng.uniform(70, 220) if estatura is None else estatura
            visible = rng.uniform(0.20, 0.36)
        y_corte = corte
        if y_corte is None:
            y_corte = ALTO - 1 if rng.random() < 0.7 else rng.uniform(30, ALTO - 2)
        y_top = (y_corte - visible * H) if top is None else top
        if y_top < 0 and top is None:
            continue
        x = cx
        if x is None:
            medio = min(38.0, 0.16 * H + 2)
            x = rng.uniform(medio, ANCHO - medio)
        kw.setdefault("de_lado", rng.random() < (0.3 if tipo == 1 else 0.15))
        m = persona(H, x, y_top + H - 1, **kw) & (YY <= y_corte)
        if m.sum() >= 30:
            return m

def animal(largo, cx, pies):
    # perro o gato
    alto_c = largo * rng.uniform(0.28, 0.42)
    patas = largo * rng.uniform(0.2, 0.32)
    cy = pies - patas - alto_c / 2
    m = elipse(cx, cy, largo / 2, alto_c / 2)
    g = max(1.2, largo * 0.08)
    for f in (-0.38, -0.22, 0.22, 0.38):
        x = cx + f * largo
        m |= segmento(x, cy, x + rng.uniform(-1, 1), pies, g)
    lado = rng.choice([-1, 1])
    r = max(1.0, largo * rng.uniform(0.12, 0.17))
    m |= elipse(cx + lado * largo * 0.55, cy - alto_c * 0.45, r * 1.1, r)
    m |= segmento(cx - lado * largo / 2, cy, cx - lado * (largo / 2 + largo * 0.25), cy - alto_c * rng.uniform(0, 0.8), max(1.0, g * 0.8))
    return m

def objeto(cx, pies):
    # cajas
    tipo = rng.integers(0, 9)
    if tipo == 4:
        w = rng.uniform(12, 44); h = w * rng.uniform(0.5, 0.8)
        poste = rng.uniform(4, 22)
        m = rect(cx - w / 2, pies - poste - h, cx + w / 2, pies - poste)
        m |= rect(cx - 1.2, pies - poste, cx + 1.2, pies)
        m |= rect(cx - w * 0.25, pies - 1.5, cx + w * 0.25, pies)
        return m
    if tipo == 5:
        w = rng.uniform(14, 46); h = rng.uniform(8, 30)
        w2 = w * rng.uniform(0.3, 0.8); h2 = rng.uniform(5, 20)
        corr = rng.uniform(-0.3, 0.3) * (w - w2)
        m = rect(cx - w / 2, pies - h, cx + w / 2, pies)
        m |= rect(cx + corr - w2 / 2, pies - h - h2, cx + corr + w2 / 2, pies - h)
        return m
    if tipo == 6:
        r = rng.uniform(3, 16)
        m = elipse(cx, pies - r, r * rng.uniform(0.8, 1.2), r)
        if rng.random() < 0.4:
            m |= rect(cx - 0.8, pies - r, cx + 0.8, pies + rng.uniform(4, 20))
        return m
    if tipo == 7:
        w = rng.uniform(20, 60); h = rng.uniform(10, 30); g = rng.uniform(1.5, 4)
        m = rect(cx - w / 2, pies - h, cx + w / 2, pies - h + g)
        m |= rect(cx - w / 2, pies - h, cx - w / 2 + g, pies)
        m |= rect(cx + w / 2 - g, pies - h, cx + w / 2, pies)
        return m
    if tipo == 8:
        w = rng.uniform(10, 60); y0 = rng.uniform(5, 45)
        return rect(cx - w / 2, y0, cx + w / 2, ALTO - 1)
    if tipo == 0:
        w = rng.uniform(6, 34); h = rng.uniform(6, 50)
        return rect(cx - w / 2, pies - h, cx + w / 2, pies)
    if tipo == 1:
        w = rng.uniform(16, 50); h = w * rng.uniform(0.3, 0.6)
        m = rect(cx - w / 2, pies - h, cx + w / 2, pies - h * 0.25)
        r = h * 0.25
        m |= elipse(cx - w * 0.3, pies - r, r, r) | elipse(cx + w * 0.3, pies - r, r, r)
        return m
    if tipo == 2:
        w = rng.uniform(8, 16); h = rng.uniform(14, 26)
        m = rect(cx - w / 2, pies - h * 0.5, cx + w / 2, pies - h * 0.42)
        m |= rect(cx + w / 2 - 2, pies - h, cx + w / 2, pies)
        m |= rect(cx - w / 2, pies - h * 0.45, cx - w / 2 + 1.5, pies)
        return m
    w = rng.uniform(5, 12); h = rng.uniform(8, 18)
    m = rect(cx - w / 2, pies - h, cx + w / 2, pies)
    m |= rect(cx - 1, pies - h - 3, cx + 1, pies - h)
    return m

def ruido():
    # sombras
    tipo = rng.integers(0, 4)
    if tipo == 0:
        w = rng.uniform(16, 70); h = rng.uniform(2, 7)
        return elipse(rng.uniform(10, 70), rng.uniform(30, 58), w / 2, h / 2)
    if tipo == 1:
        m = np.zeros((ALTO, ANCHO), bool)
        cx, cy = rng.uniform(10, 70), rng.uniform(10, 50)
        for _ in range(rng.integers(3, 8)):
            m |= elipse(cx + rng.normal(0, 8), cy + rng.normal(0, 6), rng.uniform(3, 12), rng.uniform(3, 10))
        return m
    if tipo == 2:
        cx, cy = rng.uniform(10, 70), rng.uniform(10, 50)
        w, h = rng.uniform(8, 40), rng.uniform(8, 40)
        zona = rect(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        return zona & (rng.random((ALTO, ANCHO)) < rng.uniform(0.25, 0.5))
    # borde que vibra
    if rng.random() < 0.5:
        x = rng.uniform(5, 75); y0 = rng.uniform(0, 30)
        return rect(x, y0, x + rng.uniform(0, 1.5), y0 + rng.uniform(10, 30))
    y = rng.uniform(5, 55); x0 = rng.uniform(0, 40)
    return rect(x0, y, x0 + rng.uniform(15, 40), y + rng.uniform(0, 1.5))

# errores de una mascara real
def dilata(m):
    p = np.pad(m, 1)
    return p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]

def erosiona(m):
    p = np.pad(m, 1)
    return p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]

def ensucia(m):
    if rng.random() < 0.3:
        m = dilata(m)
    if rng.random() < 0.15 and m.sum() > 60:
        m = erosiona(m)
    borde = dilata(m) & ~erosiona(m)
    m = m ^ (borde & (rng.random(m.shape) < rng.uniform(0, 0.15)))
    if rng.random() < 0.3 and m.any():
        ys, xs = np.nonzero(m)
        i = rng.integers(len(ys))
        m &= ~elipse(xs[i], ys[i], rng.uniform(1, 3), rng.uniform(1, 4))
    return m

def sombra_pies(m):
    ys, xs = np.nonzero(m)
    if len(ys) == 0:
        return m
    y = ys.max(); x0, x1 = xs.min(), xs.max()
    lado = rng.choice([-1, 1]); w = (x1 - x0 + 1) * rng.uniform(0.5, 1.4)
    return m | elipse((x0 + x1) / 2 + lado * w / 2, y - 0.5, w / 2, rng.uniform(1, 2))

def mayor_componente(m):
    ys, xs = np.nonzero(m)
    if len(ys) == 0:
        return m
    etiqueta = np.zeros(m.shape, np.int32)
    mejor, mejor_n, n_et = 0, 0, 0
    for y0, x0 in zip(ys, xs):
        if etiqueta[y0, x0]:
            continue
        n_et += 1
        pila = [(y0, x0)]; etiqueta[y0, x0] = n_et; n = 0
        while pila:
            y, x = pila.pop(); n += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v, u = y + dy, x + dx
                if 0 <= v < ALTO and 0 <= u < ANCHO and m[v, u] and not etiqueta[v, u]:
                    etiqueta[v, u] = n_et; pila.append((v, u))
        if n > mejor_n:
            mejor, mejor_n = n_et, n
    return etiqueta == mejor

def recorte(m):
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    w, h = x1 - x0 + 1, y1 - y0 + 1
    hv = max(h, 2 * w)
    xv0 = ((x0 + x1) >> 1) - (hv >> 2)
    yv0 = ((y0 + y1) >> 1) - (hv >> 1)
    out = np.zeros((32, 16), np.uint8)
    for r in range(32):
        sy = yv0 + ((r * hv) >> 5)
        if not 0 <= sy < ALTO:
            continue
        for c in range(16):
            sx = xv0 + ((c * hv) >> 5)
            if 0 <= sx < ANCHO and m[sy, sx]:
                out[r, c] = 1
    return out

def empaca(img):
    palabras = []
    for w in range(16):
        v = 0
        for b in range(32):
            r, c = 2 * w + b // 16, b % 16
            if img[r, c]:
                v |= 1 << b
        palabras.append(v)
    return palabras

TIPOS_PERSONA = ("cuerpo completo", "medio cuerpo", "busto")

def muestra(clase, tipo=None):
    while True:
        if clase == 0:
            t = tipo if tipo is not None else rng.choice(3, p=(0.4, 0.3, 0.3))
            if t == 0:
                alto = rng.uniform(16, 56)
                pies = rng.uniform(alto, 59)
                m = persona(alto, rng.uniform(3, 77), pies)
                if rng.random() < 0.4:
                    m = sombra_pies(m)
                if rng.random() < 0.15:
                    m &= YY < pies - alto * rng.uniform(0.05, 0.3)
            else:
                m = persona_cerca(t)
        elif clase == 1:
            pies = rng.uniform(20, 59)
            m = animal(rng.uniform(10, 40), rng.uniform(5, 75), pies) if rng.random() < 0.5 else objeto(rng.uniform(5, 75), pies)
        else:
            m = ruido()
        m = mayor_componente(ensucia(m))
        if m.sum() >= 12:
            return recorte(m)

def conjunto(n_por_clase):
    X, Y = [], []
    for k in range(3):
        for _ in range(n_por_clase):
            X.append(muestra(k).reshape(-1)); Y.append(k)
    return np.array(X, np.float32), np.array(Y)

print("generando siluetas...")
Xtr, Ytr = conjunto(4000)
Xte, Yte = conjunto(600)
print(f"entrenamiento {len(Xtr)}, prueba {len(Xte)}")

# entrenamiento de la red binaria
N_IN, N_H, N_OUT = 512, 64, 3
W1 = rng.uniform(-0.1, 0.1, (N_H, N_IN)).astype(np.float32)
b1 = np.zeros(N_H, np.float32)
W2 = rng.normal(0, 0.3, (N_OUT, N_H)).astype(np.float32)
b2 = np.zeros(N_OUT, np.float32)
ESC = 16.0

params = [W1, b1, W2, b2]
m_ = [np.zeros_like(p) for p in params]
v_ = [np.zeros_like(p) for p in params]
paso = 0

def adelante(X, W1, b1, W2, b2):
    xs = 2 * X - 1
    wb = np.where(W1 >= 0, 1.0, -1.0).astype(np.float32)
    pre = xs @ wb.T + b1
    a = (pre >= 0).astype(np.float32)
    return xs, wb, pre, a, a @ W2.T + b2

lr = 0.01
for epoca in range(40):
    orden = rng.permutation(len(Xtr))
    for i in range(0, len(orden), 128):
        idx = orden[i:i + 128]
        X, Y = Xtr[idx], Ytr[idx]
        xs, wb, pre, a, logit = adelante(X, W1, b1, W2, b2)
        logit = logit - logit.max(1, keepdims=True)
        p = np.exp(logit); p /= p.sum(1, keepdims=True)
        g = p.copy(); g[np.arange(len(Y)), Y] -= 1; g /= len(Y)
        gW2 = g.T @ a; gb2 = g.sum(0)
        z = pre / ESC
        gz = (g @ W2) * 0.5 * (np.abs(z) <= 1)
        gpre = gz / ESC
        gb1 = gpre.sum(0)
        gW1 = (gpre.T @ xs) * (np.abs(W1) <= 1)
        paso += 1
        for j, (prm, gr) in enumerate(zip(params, (gW1, gb1, gW2, gb2))):
            m_[j] = 0.9 * m_[j] + 0.1 * gr
            v_[j] = 0.999 * v_[j] + 0.001 * gr * gr
            prm -= lr * (m_[j] / (1 - 0.9 ** paso)) / (np.sqrt(v_[j] / (1 - 0.999 ** paso)) + 1e-8)
        np.clip(W1, -1, 1, out=W1)
    if epoca in (19, 29):
        lr *= 0.3
    if epoca % 10 == 9 or epoca == 39:
        pred = adelante(Xte, W1, b1, W2, b2)[4].argmax(1)
        print(f"epoca {epoca + 1:2d}: exactitud de prueba {(pred == Yte).mean() * 100:.1f}%")

# exportar a enteros
bits_w1 = (W1 >= 0)
T1 = np.clip(np.ceil((512 - b1) / 2), 0, 513).astype(int)
esc2 = 127.0 / np.abs(W2).max()
W2q = np.clip(np.round(W2 * esc2), -127, 127).astype(int)
B2q = np.round(b2 * esc2).astype(int)

def inferir_entera(img_bits):
    x = img_bits.astype(bool)
    cuentas = (~(x[None, :] ^ bits_w1)).sum(1)
    a = cuentas >= T1
    o = B2q + (W2q * a[None, :]).sum(1)
    mejor = 0
    for k in range(1, N_OUT):
        if o[k] > o[mejor]:
            mejor = k
    return mejor, o, cuentas

pred = np.array([inferir_entera(x)[0] for x in Xte])
exact = (pred == Yte).mean() * 100
conf = np.zeros((3, 3), int)
for y, p in zip(Yte, pred):
    conf[y, p] += 1
print(f"exactitud con enteros (lo que corre en el RISC-V): {exact:.1f}%")
print("matriz de confusion (filas real, columnas predicha) persona/objeto/ruido:")
print(conf)

# exactitud por tipo de persona
exact_tipo = []
for t in range(3):
    bien = sum(inferir_entera(muestra(0, t).reshape(-1))[0] == 0 for _ in range(400))
    exact_tipo.append(bien / 4.0)
    print(f"personas de {TIPOS_PERSONA[t]} reconocidas: {exact_tipo[t]:.1f}%")

rng_guardado = rng
rng = np.random.default_rng(7)
figuras_prueba = [
    persona(40, 40, 50, fase=0.4, de_lado=False),
    persona_cerca(1, estatura=80, cx=40, top=12, corte=ALTO - 1, fase=0.2, de_lado=False),
    persona_cerca(2, estatura=170, cx=40, top=6, corte=ALTO - 1, fase=0.0, de_lado=False),
]
rng = rng_guardado
imgs_prueba = [recorte(mayor_componente(f)) for f in figuras_prueba]
clases_prueba = []
for t, img in enumerate(imgs_prueba):
    c, o, _ = inferir_entera(img.reshape(-1))
    clases_prueba.append(c)
    print(f"silueta de prueba ({TIPOS_PERSONA[t]}) -> clase {c}, puntuaciones {[int(v) for v in o]}")
img_prueba = imgs_prueba[0]
clase_prueba = clases_prueba[0]
personas_prueba = sum(c == 0 for c in clases_prueba)

raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
destino = os.path.join(raiz, "prog", "pesos_vigia.vh")
with open(destino, "w", encoding="ascii") as f:
    f.write("localparam VIG_ENTRADAS = 512, VIG_OCULTAS = 64, VIG_SALIDAS = 3;\n")
    f.write("reg        [31:0] VIG_W1 [0:1023];      // neurona j, palabra w -> VIG_W1[16*j + w]\n")
    f.write("reg        [31:0] VIG_T1 [0:63];        // a_j = POPCOUNT(XNOR) >= VIG_T1[j]\n")
    f.write("reg signed [7:0]  VIG_W2 [0:191];       // VIG_W2[64*k + j]\n")
    f.write("reg signed [31:0] VIG_B2 [0:2];\n")
    f.write("reg        [31:0] VIG_PRUEBA [0:47];    // 3 siluetas de prueba: cuerpo completo, medio cuerpo y busto\n")
    f.write(f"localparam VIG_PRUEBA_CLASE = {clase_prueba};      // clase de la primera (0 = persona)\n")
    f.write(f"localparam VIG_PRUEBA_PERSONAS = {personas_prueba};   // cuantas de las 3 salen como persona\n\n")
    f.write("task cargar_pesos_vigia;\n    begin\n")
    for j in range(N_H):
        pal = empaca(bits_w1[j].reshape(32, 16))
        f.write("        " + " ".join(f"VIG_W1[{16 * j + w}] = 32'h{pal[w]:08X};" for w in range(16)) + "\n")
    f.write("        " + " ".join(f"VIG_T1[{j}] = {T1[j]};" for j in range(N_H)) + "\n")
    for k in range(N_OUT):
        f.write("        " + " ".join(f"VIG_W2[{64 * k + j}] = {W2q[k, j]};" for j in range(N_H)) + "\n")
    f.write("        " + " ".join(f"VIG_B2[{k}] = {B2q[k]};" for k in range(N_OUT)) + "\n")
    for t, img in enumerate(imgs_prueba):
        f.write("        " + " ".join(f"VIG_PRUEBA[{16 * t + w}] = 32'h{v:08X};" for w, v in enumerate(empaca(img))) + "\n")
    f.write("    end\nendtask\n")
print("escrito", destino)

try:
    from PIL import Image
    os.makedirs(os.path.join(raiz, "docs", "img"), exist_ok=True)
    filas = [[muestra(0, t) for _ in range(10)] for t in range(3)]
    filas += [[muestra(k) for _ in range(10)] for k in (1, 2)]
    lienzo = Image.new("L", (10 * 72 + 8, 5 * 136 + 8), 40)
    for r, fila in enumerate(filas):
        for n, img in enumerate(fila):
            cuadro = Image.fromarray((img * 255).astype(np.uint8)).resize((64, 128), Image.NEAREST)
            lienzo.paste(cuadro, (8 + n * 72, 8 + r * 136))
    lienzo.save(os.path.join(raiz, "docs", "img", "siluetas_entrenamiento.png"))
    print("escrito docs/img/siluetas_entrenamiento.png")
    prueba = Image.new("L", (3 * 72 + 8, 136 + 8), 40)
    for n, img in enumerate(imgs_prueba):
        cuadro = Image.fromarray((img * 255).astype(np.uint8)).resize((64, 128), Image.NEAREST)
        prueba.paste(cuadro, (8 + n * 72, 8))
    prueba.save(os.path.join(raiz, "docs", "img", "siluetas_prueba.png"))
    print("escrito docs/img/siluetas_prueba.png")
except ImportError:
    pass
