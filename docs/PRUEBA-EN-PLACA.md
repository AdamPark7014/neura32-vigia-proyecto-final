# Prueba en la placa: DE10-Lite + OV7670 + monitor VGA

## Antes de conectar

* **Placa apagada** (cable USB desconectado) mientras se cablea.
* La cámara va a **3.3 V** (pin 29 de JP1). Nunca al pin 11 (5 V): quema el módulo.
* Jumpers lo más cortos posible (menos de 15 cm), sobre todo PCLK y D0–D7.
* Si hay resistencias de 4.7 kΩ: una de SIOC a 3.3 V y otra de SIOD a 3.3 V. Si no hay, funciona con las
  resistencias internas de la MAX 10 (ya activadas en el proyecto).

## Cableado (cámara → conector GPIO JP1)

Con la placa vista de frente, JP1 es el conector de 2 × 20 pines; el pin 1 está marcado.

| Cámara | Pin JP1 | | Cámara | Pin JP1 |
|---|---|---|---|---|
| 3V3 | 29 | | GND | 30 |
| SIOC (SCL) | 1 | | SIOD (SDA) | 2 |
| VSYNC (VS) | 3 | | HREF (HS) | 4 |
| PCLK | 5 | | XCLK (MCLK) | 6 |
| D7 | 7 | | D6 | 8 |
| D5 | 9 | | D4 | 10 |
| D3 | 13 | | D2 | 14 |
| D1 | 15 | | D0 | 16 |
| RESET | 17 | | PWDN | 18 |

Los pines 11 (5 V) y 12 (GND) quedan libres.

## Programar la placa

```powershell
cd "C:\Users\adpoz\OneDrive\Documentos\Universidad\2026-Semestre-5\09-Lab-Arquitecturas-LA116\Entregas\Proyecto-Final-NEURA32"
pwsh -File fpga\compilar.ps1 -Grabar
```

Si ya está compilado, solo grabar:

```powershell
cd fpga
C:\intelFPGA_lite\24.1std\quartus\bin64\quartus_pgm.exe -c 1 -m JTAG -o "p;output_files/vigia.sof@1"
```

La programación se pierde al apagar la placa: hay que grabar otra vez.

## Arranque por pasos (qué debe verse)

Todos los interruptores abajo al empezar.

| Paso | Qué hacer | Qué debe verse | Si no se ve |
|---|---|---|---|
| 1 | Subir **SW8** | Barras de colores y una escala de grises con marco blanco en el monitor | Revisar cable VGA y que el monitor esté en la entrada VGA. Esto no depende de la cámara ni del procesador |
| 2 | Bajar SW8, presionar **KEY0** | En 1 o 2 s los displays muestran **7673** y se prende **LEDR7** | La cámara no responde por SCCB: revisar 3V3, GND, SIOC (pin 1), SIOD (pin 2), XCLK (pin 6), RESET (pin 17) y PWDN (pin 18) |
| 3 | Esperar | **LEDR6 parpadea** (llegan cuadros) y **LEDR8** encendido unos 3 s (aprende el fondo) | Si LEDR7 sí pero LEDR6 no: revisar VSYNC (pin 3), HREF (pin 4) y PCLK (pin 5) |
| 4 | Mirar el monitor | El video de la cámara en gris | Imagen revuelta o rayada: revisar D0–D7 (pines 7 a 16) y su orden. Muy oscura o borrosa: girar el lente para enfocar |
| 5 | Subir **SW3** | Lo que se mueve aparece en **azul** | Si se pinta todo: subir el umbral con SW7..SW5. Si no se pinta nada: bajarlo |
| 6 | Pasar una persona (o una silueta recortada) | Recuadro **verde**; al entrar a la zona amarilla y quedarse, recuadro **rojo**, letrero **INTRUSO**, **LEDR9** parpadea | Ver la sección «Ajustes» |

## Controles

| Control | Función |
|---|---|
| KEY0 | reinicio |
| KEY1 | borra la alarma |
| SW1..SW0 | zona y línea: 0 zona a la derecha, 1 a la izquierda, 2 al centro, 3 media pantalla derecha |
| SW2 | sentido prohibido de la línea: 0 izquierda→derecha, 1 derecha→izquierda |
| SW3 | pinta en azul lo que se mueve |
| SW4 | red neuronal con RV32IM puro, sin Zbb (para comparar) |
| SW7..SW5 | umbral de movimiento: 28 + 8 × valor (0 = 28, más sensible; 7 = 84, menos sensible) |
| SW8 | barras de colores en el monitor |
| SW9 | arriba: vuelve a aprender el fondo (sin personas a la vista); abajo: vigila |
| LEDR9 | alarma (parpadea) |
| LEDR8 | aprendiendo el fondo |
| LEDR7 | la cámara respondió (PID 76, VER 73) |
| LEDR6 | parpadea con cada cuadro procesado |
| LEDR0 | alarma (fijo) |
| HEX5-4 / HEX3-2 / HEX1 / HEX0 | entradas / salidas / personas en la zona / manchas detectadas |

## Ajustes

* **La cámara debe quedar fija.** El fondo se aprende con la cámara quieta. Si se mueve, subir y bajar SW9
  sin nadie a la vista.
* **Distancia.** Con el lente del módulo, una persona completa de pie cabe a unos 6 m. Para una demo de mesa,
  usar siluetas recortadas o figuras de unos 30 cm a 1 m de la cámara.
* **Luz estable.** La exposición se congela a los 2 s del arranque. Si cambia mucho la luz, presionar KEY0.
* **Sombras o reflejos** que se marcan como manchas: subir el umbral (SW7..SW5). La red debería marcarlas en
  gris (no persona) y no dar alarma.
