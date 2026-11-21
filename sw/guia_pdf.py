"""
Genera docs/Guia-Conexion-NEURA32-Vigia.pdf: cableado de la OV7670 a la DE10-Lite,
pasos de arranque con lo que debe indicar cada uno, controles y ajustes.
Uso:  python sw/guia_pdf.py
"""
import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                Flowable, PageBreak, KeepTogether)

raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
salida = os.path.join(raiz, "docs", "Guia-Conexion-NEURA32-Vigia.pdf")

# ---------------- colores por grupo de senales ----------------
C_PODER = colors.HexColor("#D93025")
C_TIERRA = colors.HexColor("#202124")
C_SCCB = colors.HexColor("#8E44AD")
C_SINC = colors.HexColor("#E67E22")
C_RELOJ = colors.HexColor("#F1C40F")
C_DATOS = colors.HexColor("#1A73E8")
C_CTRL = colors.HexColor("#16A085")
C_LIBRE = colors.HexColor("#DADCE0")

# senal de la camara -> (pin JP1, GPIO, color)
CABLES = [
    ("3V3", 29, "3.3 V", C_PODER), ("GND", 30, "GND", C_TIERRA),
    ("SIOC (SCL)", 1, "GPIO[0]", C_SCCB), ("SIOD (SDA)", 2, "GPIO[1]", C_SCCB),
    ("VSYNC (VS)", 3, "GPIO[2]", C_SINC), ("HREF (HS)", 4, "GPIO[3]", C_SINC),
    ("PCLK", 5, "GPIO[4]", C_RELOJ), ("XCLK (MCLK)", 6, "GPIO[5]", C_RELOJ),
    ("D7", 7, "GPIO[6]", C_DATOS), ("D6", 8, "GPIO[7]", C_DATOS),
    ("D5", 9, "GPIO[8]", C_DATOS), ("D4", 10, "GPIO[9]", C_DATOS),
    ("D3", 13, "GPIO[10]", C_DATOS), ("D2", 14, "GPIO[11]", C_DATOS),
    ("D1", 15, "GPIO[12]", C_DATOS), ("D0", 16, "GPIO[13]", C_DATOS),
    ("RESET", 17, "GPIO[14]", C_CTRL), ("PWDN", 18, "GPIO[15]", C_CTRL),
]
POR_PIN = {pin: (senal, color) for senal, pin, _, color in CABLES}

estilos = getSampleStyleSheet()
TIT = ParagraphStyle("tit", parent=estilos["Title"], fontSize=20, leading=24, spaceAfter=4)
SUB = ParagraphStyle("sub", parent=estilos["Normal"], fontSize=10, textColor=colors.HexColor("#5F6368"),
                     alignment=1, spaceAfter=10)
H1 = ParagraphStyle("h1", parent=estilos["Heading2"], fontSize=13.5, leading=17, spaceBefore=8, spaceAfter=5,
                    textColor=colors.HexColor("#1A73E8"))
TXT = ParagraphStyle("txt", parent=estilos["Normal"], fontSize=9.5, leading=12.5)
CEL = ParagraphStyle("cel", parent=estilos["Normal"], fontSize=8.6, leading=10.8)
CELB = ParagraphStyle("celb", parent=CEL, fontName="Helvetica-Bold")
AVISO = ParagraphStyle("aviso", parent=TXT, textColor=colors.HexColor("#B3261E"), fontName="Helvetica-Bold")


class Conectores(Flowable):
    """Dibujo del conector JP1 (2 x 20) y del modulo OV7670 (2 x 9) con colores por senal."""
    def __init__(self, ancho):
        super().__init__()
        self.ancho, self.alto = ancho, 152 * mm

    def wrap(self, *a):
        return self.ancho, self.alto

    def pin(self, c, x, y, color, r=2.2 * mm):
        c.setFillColor(color); c.setStrokeColor(colors.black); c.setLineWidth(0.5)
        c.rect(x - r, y - r, 2 * r, 2 * r, stroke=1, fill=1)

    def draw(self):
        c = self.canv
        paso = 5.6 * mm
        # ---------------- JP1 ----------------
        x0, ytop = 38 * mm, self.alto - 14 * mm
        c.setFont("Helvetica-Bold", 10); c.setFillColor(colors.black)
        c.drawCentredString(x0 + paso / 2, self.alto - 6 * mm, "DE10-Lite: conector GPIO JP1")
        c.setFont("Helvetica", 7)
        c.setFillColor(colors.HexColor("#F8F9FA")); c.setStrokeColor(colors.HexColor("#9AA0A6"))
        c.roundRect(x0 - 4 * mm, ytop - 20 * paso + 1 * mm, paso + 8 * mm, 20 * paso + 3 * mm, 2 * mm, stroke=1, fill=1)
        for fila in range(20):
            y = ytop - fila * paso
            for col in range(2):
                n = fila * 2 + col + 1
                x = x0 + col * paso
                if n in POR_PIN:
                    senal, color = POR_PIN[n]
                elif n == 11:
                    senal, color = "5 V - NO USAR", colors.HexColor("#FAD2CF")
                elif n == 12:
                    senal, color = "GND (libre)", C_LIBRE
                else:
                    senal, color = "", C_LIBRE
                self.pin(c, x, y, color)
                c.setFillColor(colors.white if color in (C_TIERRA, C_DATOS, C_SCCB, C_PODER, C_CTRL) else colors.black)
                c.setFont("Helvetica-Bold", 5.5)
                c.drawCentredString(x, y - 2, str(n))
                c.setFillColor(colors.black); c.setFont("Helvetica", 7)
                if senal:
                    if col == 0:
                        c.drawRightString(x - 4 * mm, y - 2.3, senal)
                    else:
                        c.drawString(x + 4 * mm, y - 2.3, senal)
        c.setFont("Helvetica-Oblique", 7)
        c.drawCentredString(x0 + paso / 2, ytop - 20 * paso - 3 * mm, "pin 1 = esquina marcada del conector")
        # ---------------- OV7670 ----------------
        mx, mtop = 132 * mm, self.alto - 24 * mm
        c.setFont("Helvetica-Bold", 10)
        c.drawCentredString(mx + paso / 2, self.alto - 6 * mm, "Modulo OV7670 (18 pines, sin FIFO)")
        c.setFillColor(colors.HexColor("#1F4E99")); c.setStrokeColor(colors.black)
        c.roundRect(mx - 25 * mm, mtop - 9 * paso - 30 * mm, paso + 50 * mm, 9 * paso + 38 * mm, 3 * mm, stroke=1, fill=1)
        c.setFillColor(colors.HexColor("#111111"))
        c.circle(mx + paso / 2, mtop - 9 * paso - 13 * mm, 9 * mm, stroke=0, fill=1)
        c.setFillColor(colors.HexColor("#3C4043"))
        c.circle(mx + paso / 2, mtop - 9 * paso - 13 * mm, 5 * mm, stroke=0, fill=1)
        c.setFillColor(colors.white); c.setFont("Helvetica", 6.5)
        c.drawCentredString(mx + paso / 2, mtop - 9 * paso - 26 * mm, "lente (enfoque girando)")
        izq = ["3V3", "SIOC", "VSYNC", "PCLK", "D7", "D5", "D3", "D1", "RESET"]
        der = ["GND", "SIOD", "HREF", "XCLK", "D6", "D4", "D2", "D0", "PWDN"]
        nombre = {"SIOC": "SIOC (SCL)", "SIOD": "SIOD (SDA)", "VSYNC": "VSYNC (VS)", "HREF": "HREF (HS)",
                  "XCLK": "XCLK (MCLK)"}
        destino = {s.split(" ")[0]: (p, col) for s, p, _, col in CABLES}
        for fila in range(9):
            y = mtop - fila * paso
            for col, lista in ((0, izq), (1, der)):
                s = lista[fila]
                pin_jp1, color = destino[s]
                x = mx + col * paso
                self.pin(c, x, y, color)
                c.setFillColor(colors.white); c.setFont("Helvetica", 7)
                if col == 0:
                    c.drawRightString(x - 4 * mm, y - 2.3, f"{s}  -> {pin_jp1}")
                else:
                    c.drawString(x + 4 * mm, y - 2.3, f"{pin_jp1} <-  {s}")
        c.setFillColor(colors.black); c.setFont("Helvetica-Oblique", 7.5)
        base = mtop - 9 * paso - 36 * mm
        c.drawCentredString(mx + paso / 2, base, "El numero junto a cada senal es el pin de JP1 al que va.")
        c.drawCentredString(mx + paso / 2, base - 4 * mm, "Guiarse por las letras impresas en el modulo, no por la posicion.")
        # ---------------- leyenda ----------------
        ly = 6 * mm
        items = [("3.3 V", C_PODER), ("GND", C_TIERRA), ("SCCB", C_SCCB), ("sincronia", C_SINC),
                 ("relojes", C_RELOJ), ("datos D7..D0", C_DATOS), ("reset / apagado", C_CTRL)]
        x = 8 * mm
        c.setFont("Helvetica", 7.5)
        for texto, color in items:
            self.pin(c, x, ly, color, r=1.8 * mm)
            c.setFillColor(colors.black)
            c.drawString(x + 3.5 * mm, ly - 2.5, texto)
            x += 26 * mm


def tabla(datos, anchos, encabezado=True, zebra=True):
    filas = [[Paragraph(str(v), CELB if (encabezado and i == 0) else CEL) for v in fila]
             for i, fila in enumerate(datos)]
    t = Table(filas, colWidths=anchos, repeatRows=1 if encabezado else 0)
    est = [("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#BDC1C6")),
           ("VALIGN", (0, 0), (-1, -1), "TOP"),
           ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    if encabezado:
        est.append(("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8F0FE")))
    if zebra:
        for i in range(1 if encabezado else 0, len(datos)):
            if i % 2 == 0:
                est.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#F8F9FA")))
    t.setStyle(TableStyle(est))
    return t


def pie(c, doc):
    c.saveState()
    c.setFont("Helvetica", 7.5); c.setFillColor(colors.HexColor("#80868B"))
    c.drawString(18 * mm, 10 * mm, "NEURA-32 Vigia - Laboratorio de Arquitecturas Computacionales - Orozco / Del Pozo")
    c.drawRightString(letter[0] - 18 * mm, 10 * mm, f"pagina {doc.page}")
    c.restoreState()


doc = SimpleDocTemplate(salida, pagesize=letter, leftMargin=18 * mm, rightMargin=18 * mm,
                        topMargin=15 * mm, bottomMargin=16 * mm,
                        title="Guia de conexion NEURA-32 Vigia", author="Orozco / Del Pozo")
ancho = letter[0] - 36 * mm
h = []

# ================= pagina 1 =================
h.append(Paragraph("NEURA-32 Vigía: conexión y prueba en placa", TIT))
h.append(Paragraph("DE10-Lite (MAX 10 10M50DAF484C7G) + cámara OV7670 + monitor VGA", SUB))
h.append(Paragraph("Antes de conectar", H1))
for t in ["<b>Placa apagada</b> (cable USB desconectado) mientras se cablea.",
          "La cámara va a <b>3.3 V, pin 29</b> de JP1. <font color='#B3261E'><b>Nunca al pin 11 (5 V): quema el módulo.</b></font>",
          "Jumpers lo más cortos posible (menos de 15 cm), sobre todo PCLK y D0 a D7.",
          "Resistencias de 4.7 k ohms de SIOC a 3.3 V y de SIOD a 3.3 V si las hay; si no, funciona con las "
          "resistencias internas de la MAX 10, que el proyecto ya activa."]:
    h.append(Paragraph("&bull; " + t, TXT))
h.append(Spacer(1, 3 * mm))
h.append(Conectores(ancho))
h.append(PageBreak())

# ================= pagina 2 =================
h.append(Paragraph("Cableado pin por pin", H1))
filas = [["Señal de la cámara", "Pin de JP1", "Señal en la FPGA", "Para qué sirve"]]
uso = {"3V3": "alimentación", "GND": "tierra común", "SIOC (SCL)": "reloj del bus de configuración SCCB",
       "SIOD (SDA)": "datos del bus SCCB (drenador abierto)", "VSYNC (VS)": "inicio de cada cuadro",
       "HREF (HS)": "línea de imagen válida", "PCLK": "reloj de píxel que entrega la cámara (6.25 MHz)",
       "XCLK (MCLK)": "reloj de 25 MHz que le da la FPGA", "RESET": "reinicio (activo en bajo)",
       "PWDN": "apagado (activo en alto, queda en 0)"}
for senal, pin, gpio, _ in CABLES:
    filas.append([senal, str(pin), gpio, uso.get(senal, "dato de imagen (8 bits)")])
h.append(tabla(filas, [36 * mm, 22 * mm, 30 * mm, ancho - 88 * mm]))
h.append(Spacer(1, 2 * mm))
h.append(Paragraph("Los pines 11 (5 V) y 12 (GND) quedan libres.", TXT))

h.append(Paragraph("Programar la placa", H1))
h.append(Paragraph("En PowerShell, desde la carpeta del proyecto <i>Entregas\\Proyecto-Final-NEURA32</i>:", TXT))
cmd = tabla([["pwsh -File fpga\\compilar.ps1 -Grabar"],
             ["Solo grabar si ya está compilado (desde fpga\\):  quartus_pgm -c 1 -m JTAG -o \"p;output_files/vigia.sof@1\""]],
            [ancho], encabezado=False, zebra=False)
h.append(cmd)
h.append(Paragraph("La programación se pierde al apagar la placa: hay que grabar otra vez.", TXT))
h.append(PageBreak())

h.append(Paragraph("Arranque por pasos: qué debe indicar cada uno", H1))
pasos = [["Paso", "Qué hacer", "Qué debe verse", "Si no se ve"],
         ["1", "Todos los interruptores abajo. Subir <b>SW8</b>.",
          "Barras de colores arriba y una escala de grises abajo, con marco blanco, en el monitor.",
          "Revisar el cable VGA y que el monitor esté en la entrada VGA. Esta prueba no depende de la cámara ni del procesador."],
         ["2", "Bajar SW8 y presionar <b>KEY0</b>.",
          "En 1 o 2 s los displays muestran <b>7673</b> y se enciende <b>LEDR7</b>: la cámara respondió por SCCB (PID 76, VER 73).",
          "La cámara no responde: revisar 3V3 (29), GND (30), SIOC (1), SIOD (2), XCLK (6), RESET (17) y PWDN (18)."],
         ["3", "Esperar.",
          "<b>LEDR6 parpadea</b> (llegan cuadros) y <b>LEDR8</b> queda encendido unos 3 s (aprende el fondo).",
          "LEDR7 sí pero LEDR6 no: revisar VSYNC (3), HREF (4) y PCLK (5)."],
         ["4", "Mirar el monitor.", "El video de la cámara en gris.",
          "Imagen revuelta o rayada: revisar D0 a D7 (pines 7 a 16) y su orden. Muy oscura o borrosa: girar el lente para enfocar."],
         ["5", "Subir <b>SW3</b>.", "Lo que se mueve aparece en <b>azul</b>.",
          "Se pinta todo: subir el umbral con SW7..SW5. No se pinta nada: bajarlo."],
         ["6", "Pasar una persona o una silueta recortada.",
          "Recuadro <b>verde</b>. Al cruzar la línea punteada o entrar a la zona amarilla y quedarse: recuadro <b>rojo</b>, "
          "letrero <b>INTRUSO</b> y <b>LEDR9</b> parpadeando. Los displays cuentan entradas y salidas.",
          "Ver «Ajustes». Si la mancha sale <b>gris</b>, la red la clasificó como «no persona»."]]
h.append(tabla(pasos, [13 * mm, 33 * mm, 62 * mm, ancho - 108 * mm]))

# ================= pagina 3 =================
h.append(Paragraph("Ayudas de diagnóstico", H1))
diag = [["Indicador", "Qué significa"],
        ["SW8 arriba: barras de color", "el monitor y la salida VGA funcionan (no depende de la cámara ni del procesador)"],
        ["Displays 7673 + LEDR7", "la cámara respondió por SCCB y quedó configurada"],
        ["LEDR6 parpadeando", "llegan cuadros de la cámara y el procesador los está procesando"],
        ["LEDR8 encendido", "está aprendiendo el fondo (también mientras SW9 esté arriba)"],
        ["SW7..SW5", "umbral de movimiento en vivo, sin recompilar"],
        ["SW9 arriba y luego abajo", "vuelve a aprender el fondo (sin personas a la vista)"]]
h.append(tabla(diag, [55 * mm, ancho - 55 * mm]))
h.append(PageBreak())

h.append(Paragraph("Controles", H1))
ctrl = [["Control", "Función"],
        ["KEY0", "reinicio"], ["KEY1", "borra la alarma"],
        ["SW1..SW0", "zona y línea: 0 zona a la derecha, 1 a la izquierda, 2 al centro, 3 media pantalla derecha"],
        ["SW2", "sentido prohibido de la línea: 0 de izquierda a derecha, 1 de derecha a izquierda"],
        ["SW3", "pinta en azul lo que se mueve"],
        ["SW4", "red neuronal con RV32IM puro, sin Zbb (para comparar)"],
        ["SW7..SW5", "umbral de movimiento: 28 + 8 x valor (0 = 28 más sensible, 7 = 84 menos sensible)"],
        ["SW8", "barras de colores en el monitor"],
        ["SW9", "arriba: vuelve a aprender el fondo; abajo: vigila"],
        ["LEDR9 / LEDR8 / LEDR7 / LEDR6 / LEDR0", "alarma (parpadea) / aprendiendo / cámara OK / cuadro procesado / alarma (fija)"],
        ["HEX5-4 / HEX3-2 / HEX1 / HEX0", "entradas / salidas / personas en la zona / manchas detectadas"],
        ["Monitor", "video en gris; zona amarilla; línea cian punteada; recuadros verde (persona), rojo (intruso), "
                    "gris (no persona); letrero INTRUSO"]]
h.append(tabla(ctrl, [55 * mm, ancho - 55 * mm]))

h.append(Paragraph("Ajustes y consejos para la demostración", H1))
for t in ["<b>Cámara fija.</b> El fondo se aprende con la cámara quieta. Si se mueve, subir y bajar SW9 sin nadie a la vista.",
          "<b>Distancia.</b> Con el lente del módulo (unos 22 grados en horizontal y 16 en vertical), una persona completa "
          "de pie cabe a unos 6 m. Para una demo de mesa: siluetas recortadas o figuras de unos 30 cm a 1 m de la cámara.",
          "<b>Luz estable.</b> La exposición se congela a los 2 s del arranque. Si la luz cambia mucho, presionar KEY0.",
          "<b>Sombras o reflejos</b> que se marcan como manchas: subir el umbral. La red debe marcarlas en gris y no dar alarma.",
          "<b>Enfoque.</b> Girar el lente del módulo hasta que el borde de la persona se vea nítido en el monitor."]:
    h.append(Paragraph("&bull; " + t, TXT))
    h.append(Spacer(1, 1.2 * mm))

doc.build(h, onFirstPage=pie, onLaterPages=pie)
print("escrito", salida)
