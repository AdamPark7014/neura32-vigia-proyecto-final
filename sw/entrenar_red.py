import os
import numpy as np

rng = np.random.default_rng(2026)

# patrones 3x3
CLASES = [
    ("X",         "101"
                  "010"
                  "101"),
    ("O (anillo)","111"
                  "101"
                  "111"),
    ("+",         "010"
                  "111"
                  "010"),
    ("- (barra)", "000"
                  "111"
                  "000"),
    ("| (palo)",  "010"
                  "010"
                  "010"),
    ("/ diagonal","001"
                  "010"
                  "100"),
    ("\\ diagonal","100"
                  "010"
                  "001"),
    ("T",         "111"
                  "010"
                  "010"),
]

def patron_a_bits(p):
    return np.array([int(c) for c in p], dtype=np.float64)

def bits_a_sw(bits):
    return int(sum(int(b) << i for i, b in enumerate(bits)))

# conjunto de entrenamiento
X, Y = [], []
for k, (_, p) in enumerate(CLASES):
    base = patron_a_bits(p)
    X.append(base); Y.append(k)
    for i in range(9):
        v = base.copy(); v[i] = 1 - v[i]
        X.append(v); Y.append(k)
X = np.array(X); Y = np.array(Y)

# prueba de estres aparte
X2, Y2 = [], []
for k, (_, p) in enumerate(CLASES):
    base = patron_a_bits(p)
    for i in range(9):
        for j in range(i + 1, 9):
            v = base.copy(); v[i] = 1 - v[i]; v[j] = 1 - v[j]
            X2.append(v); Y2.append(k)
X2 = np.array(X2); Y2 = np.array(Y2)

# quita las muestras ambiguas
plantillas = {bits_a_sw(patron_a_bits(p)): k for k, (_, p) in enumerate(CLASES)}
mask = np.array([plantillas.get(bits_a_sw(x), y) == y for x, y in zip(X, Y)])
X, Y = X[mask], Y[mask]

n_in, n_h, n_out = 9, 16, 8
W1 = rng.normal(0, 0.5, (n_h, n_in)); b1 = np.zeros(n_h)
W2 = rng.normal(0, 0.5, (n_out, n_h)); b2 = np.zeros(n_out)
lr = 0.5
onehot = np.eye(n_out)[Y]
for epoch in range(20000):
    h_pre = X @ W1.T + b1
    h = np.maximum(h_pre, 0)
    logits = h @ W2.T + b2
    logits -= logits.max(axis=1, keepdims=True)
    p = np.exp(logits); p /= p.sum(axis=1, keepdims=True)
    g = (p - onehot) / len(X)
    gW2 = g.T @ h; gb2 = g.sum(0)
    gh = (g @ W2) * (h_pre > 0)
    gW1 = gh.T @ X; gb1 = gh.sum(0)
    W2 -= lr * (gW2 + 1e-4 * W2); b2 -= lr * gb2
    W1 -= lr * (gW1 + 1e-4 * W1); b1 -= lr * gb1

pred = (np.maximum(X @ W1.T + b1, 0) @ W2.T + b2).argmax(1)
print(f"exactitud en flotante: {(pred == Y).mean()*100:.1f}% ({len(X)} muestras)")

Xi = X.astype(int)
# cuantizacion a enteros
S1 = 127.0 / np.abs(W1).max()
W1q = np.clip(np.round(W1 * S1), -127, 127).astype(int)
B1q = np.round(b1 * S1).astype(int)

# activaciones
h_max = (np.maximum(Xi @ W1q.T + B1q, 0)).max()
SH1 = int(max(0, np.ceil(np.log2(h_max / 127.0)))) if h_max > 127 else 0
A = np.clip(np.maximum(Xi @ W1q.T + B1q, 0) >> SH1, 0, 127)

S2 = 127.0 / np.abs(W2).max()
W2q = np.clip(np.round(W2 * S2), -127, 127).astype(int)
B2q = np.round(b2 * S2 * S1 / (2 ** SH1)).astype(int)

def inferir_q(sw):
    x = np.array([(sw >> i) & 1 for i in range(9)])
    h = W1q @ x + B1q
    a = np.clip(np.maximum(h, 0) >> SH1, 0, 127)
    o = W2q @ a + B2q
    return int(o.argmax()), o

predq = np.array([inferir_q(bits_a_sw(x))[0] for x in X])
print(f"exactitud cuantizada int8: {(predq == Y).mean()*100:.1f}%  SH1={SH1}")
predq2 = np.array([inferir_q(bits_a_sw(x))[0] for x in X2])
print(f"estres con 2 pixeles cambiados ({len(X2)} muestras, parte ambiguas): {(predq2 == Y2).mean()*100:.1f}%")
for k, (nombre, p) in enumerate(CLASES):
    c, o = inferir_q(bits_a_sw(patron_a_bits(p)))
    print(f"  clase {k} {nombre:12s} SW=0x{bits_a_sw(patron_a_bits(p)):03X} -> {c}  puntuaciones={list(o)}")
assert all(inferir_q(bits_a_sw(patron_a_bits(p)))[0] == k for k, (_, p) in enumerate(CLASES))

# salida Verilog
raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
destino = os.path.join(raiz, "prog", "pesos_red.vh")
with open(destino, "w", encoding="ascii") as f:
    f.write(f"localparam RED_ENTRADAS = {n_in};  // entradas de la red\nlocalparam RED_OCULTAS = {n_h};  // neuronas ocultas\nlocalparam RED_SALIDAS = {n_out};  // salidas de la red\nlocalparam RED_SH1 = {SH1};  // corrimiento capa oculta\n")
    f.write(f"reg signed [7:0]  RED_W1 [0:{n_h*n_in-1}];\n")
    f.write(f"reg signed [31:0] RED_B1 [0:{n_h-1}];\n")
    f.write(f"reg signed [7:0]  RED_W2 [0:{n_out*n_h-1}];\n")
    f.write(f"reg signed [31:0] RED_B2 [0:{n_out-1}];\n\n")
    f.write("task cargar_pesos;\n    begin\n")
    for j in range(n_h):
        fila = " ".join(f"RED_W1[{j*n_in+i:3d}] = {W1q[j,i]:4d};" for i in range(n_in))
        f.write(f"        {fila}\n")
    f.write("        " + " ".join(f"RED_B1[{j}] = {B1q[j]};" for j in range(n_h)) + "\n")
    for k in range(n_out):
        fila = " ".join(f"RED_W2[{k*n_h+j:3d}] = {W2q[k,j]:4d};" for j in range(n_h))
        f.write(f"        {fila}\n")
    f.write("        " + " ".join(f"RED_B2[{k}] = {B2q[k]};" for k in range(n_out)) + "\n")
    f.write("    end\nendtask\n\n")
    f.write("// plantillas\n")
    f.write("function [8:0] red_plantilla; input integer k;\n    case (k)\n")
    for k, (nombre, p) in enumerate(CLASES):
        f.write(f"        {k}: red_plantilla = 9'h{bits_a_sw(patron_a_bits(p)):03X};  // {nombre}\n")
    f.write("        default: red_plantilla = 9'h000;\n    endcase\nendfunction\n")
print("escrito", destino)
