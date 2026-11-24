from PIL import Image, ImageDraw, ImageFont

letra = None
for nombre, tam in (("consolab.ttf", 15), ("courbd.ttf", 14), ("lucon.ttf", 13)):
    try:
        letra = ImageFont.truetype(nombre, tam)
        break
    except OSError:
        pass
assert letra is not None, "no hay fuente monoespaciada"

renglones = []
vista = Image.new("L", (8 * 16 * 3, 16 * 4 * 3), 0)
for codigo in range(32, 96):
    celda = Image.new("L", (8, 16), 0)
    d = ImageDraw.Draw(celda)
    caja = d.textbbox((0, 0), chr(codigo), font=letra)
    ancho = caja[2] - caja[0]
    d.text(((8 - ancho) // 2 - caja[0], 1), chr(codigo), font=letra, fill=255)
    bits = celda.point(lambda p: 255 if p >= 96 else 0)
    for y in range(16):
        byte = 0
        for x in range(8):
            if bits.getpixel((x, y)):
                byte |= 0x80 >> x
        renglones.append(byte)
    i = codigo - 32
    vista.paste(bits.resize((24, 48), Image.NEAREST), ((i % 16) * 24, (i // 16) * 48))

with open("hdl/vision/font8x16.txt", "w", encoding="ascii", newline="\n") as f:
    for i, b in enumerate(renglones):
        nota = f"   // '{chr(32 + i // 16)}'" if i % 16 == 0 else ""
        f.write(f"{b:02X}{nota}\n")
vista.save("docs/img/fuente8x16.png")
print(len(renglones), "renglones ->", "hdl/vision/font8x16.txt")
