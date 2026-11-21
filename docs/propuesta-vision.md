# NEURA-32 Vigía — vigilancia perimetral inteligente sobre un RISC-V hecho a mano

Nota interna de diseño, 29-10-2026. Proyecto final de LA116. Todo en la DE10-Lite, sin ESP32.

## Qué hace, en sencillo

Una cámara mira una puerta o un pasillo. En el monitor VGA se ve el video. El sistema dibuja una
**zona prohibida** y una **línea virtual**. Cuando algo se mueve, el procesador RISC-V decide con una
red neuronal si es **una persona** o solo **ruido** (una sombra, un cambio de luz, un objeto, una mascota).
Solo si es persona y entra a la zona o cruza la línea en el sentido prohibido, suena la **alarma**:
recuadro rojo y letrero «INTRUSO» en el monitor, LED parpadeando y contadores de entradas y salidas en
los displays. Es lo mismo que hacen las cámaras comerciales con «detección de intrusión» y «cruce de
línea» con filtro de personas (por ejemplo AcuSense de Hikvision), pero corriendo en un procesador que
construimos desde la ALU.

## La placa y la cámara

**Placa:** DE10-Lite, MAX 10 `10M50DAF484C7G` (la de todas las prácticas: 16 proyectos Quartus).
50 mil LE, 1 638 Kbit de M9K, 144 multiplicadores 18×18, 4 PLL, VGA de 4 bits por color,
conector GPIO JP1 de 2×20 con 36 pines de usuario **3.3-V LVTTL**, más 3.3 V (pin 29), 5 V (pin 11)
y GND (pines 12 y 30). Manual: `Docs/Manuales/DE10-Lite_User_Manual.pdf`, tabla 3-7 y figura 3-18.

**Cámara elegida:** OV7670 **sin FIFO**, módulo azul con cabezal de 2×9 = 18 pines.
Mercado Libre, Tienda oficial de Tecneu, paquete de 4 piezas, $206.12 MXN, envío gratis, calificación
4.6 (14 opiniones), llega el domingo a CP 72810 (consultado el 29-10-2026):
https://www.mercadolibre.com.mx/4-camara-vga-ov7670-640x480-arduino-pic-raspberry/p/MLM65989366
Se eligió el paquete de 4 porque un error de cableado (por ejemplo 5 V en lugar de 3.3 V) quema el
módulo, y así hay repuestos. La versión con FIFO (24 pines, AL422) **no** hace falta: el buffer va en M9K.

### Compatibilidad verificada

| Punto | Cámara (listado y hoja de datos) | DE10-Lite (manual) | ¿Compatible? |
|---|---|---|---|
| Alimentación | 3.3 V, 60 mW | Pin 29 de JP1 = 3.3 V (hasta 5 W entre 3.3 V y 5 V) | Sí |
| Nivel lógico | Salidas ~2.8–3.3 V | Entradas 3.3-V LVTTL | Sí, sin convertidor |
| Señales | 8 datos + PCLK + VSYNC + HREF + XCLK + SIOC + SIOD + RESET + PWDN = 16 | 36 GPIO libres | Sí, sobran 20 |
| Reloj XCLK | 10–48 MHz (típico 24) | PLL interno: 25 MHz | Sí |
| Configuración | SCCB (I²C sin ACK) | Bit-bang desde NEURA-32 por GPIO | Sí |
| Conectores | Cabezal macho 2×9 | Cabezal macho 2×20 | Con jumpers hembra-hembra (ya los tiene Adam) |
| Pull-up SIOC/SIOD | El módulo normalmente no las trae | Pull-up débil interna de la MAX 10 | Sí; mejor 2 resistencias de 4.7 kΩ a 3.3 V |
| Monitor | — | VGA 640×480 a 60 Hz, reloj de píxel 25 MHz | Sí (Adam ya tiene monitor VGA) |

### Cableado propuesto (JP1)

| OV7670 | GPIO | Pin JP1 | Pin FPGA |
|---|---|---|---|
| 3V3 | 3.3 V | 29 | — |
| GND | GND | 30 | — |
| SIOC (SCL) | GPIO_0 | 1 | PIN_V10 |
| SIOD (SDA) | GPIO_1 | 2 | PIN_W10 |
| VSYNC | GPIO_2 | 3 | PIN_V9 |
| HREF | GPIO_3 | 4 | PIN_W9 |
| PCLK | GPIO_4 | 5 | PIN_V8 |
| XCLK | GPIO_5 | 6 | PIN_W8 |
| D7 | GPIO_6 | 7 | PIN_V7 |
| D6 | GPIO_7 | 8 | PIN_W7 |
| D5 | GPIO_8 | 9 | PIN_W6 |
| D4 | GPIO_9 | 10 | PIN_V5 |
| D3 | GPIO_10 | 13 | PIN_W5 |
| D2 | GPIO_11 | 14 | PIN_AA15 |
| D1 | GPIO_12 | 15 | PIN_AA14 |
| D0 | GPIO_13 | 16 | PIN_W13 |
| RESET | GPIO_14 | 17 | PIN_W12 |
| PWDN | GPIO_15 | 18 | PIN_AB13 |

**Un solo reloj de 25 MHz para todo** (procesador, VGA y captura): la cámara se configura con su
divisor interno para que PCLK sea lento (≈ 6 MHz) y la FPGA lo muestrea con sincronizador de dos
flip-flops y detector de flanco. Se elimina el cruce de dominios de reloj, que es lo que más falla en
los proyectos de referencia. Basta con 7–15 cuadros por segundo para personas caminando.

## Arquitectura

```
                        ┌──────────── tubería de video (Verilog, sin procesador) ────────────┐
OV7670 ─ D[7:0],HREF ──>│ captura YUV → Y (gris) → 160×120 → fondo promedio → |I−F| > umbral │
        VSYNC,PCLK      │   → apertura 3×3 (2 líneas) → máscara de silueta 160×120 × 1 bit   │
   ▲ XCLK 25 MHz        └───────┬──────────────────────────────┬───────────────────────────────┘
   ▲ SCCB por GPIO              │ máscara (memoria mapeada)    │ video gris 320×240×4 bit
   │                            ▼                              ▼
┌──┴─────────────────── NEURA-32 (RV32IM + Zicsr + Xneura) ─────────────┐   ┌──── VGA 640×480 ────┐
│ ROM programa 4 KB │ ROM pesos │ RAM 8 KB │ banco 32×32 │ ALU 128 ops   │   │ video + máscara en  │
│ 1. configura la cámara (SCCB)                                        │──>│ color + zona + línea│
│ 2. etiqueta manchas (componentes conexos) en la máscara reducida     │   │ + recuadros + texto │
│ 3. recorta cada mancha a 16×32 y la clasifica con la red binaria     │   └─────────────────────┘
│ 4. sigue cada mancha entre cuadros (centroide) y aplica las reglas   │──> LEDR (alarma), HEX (conteos)
│    de zona, línea y tiempo de permanencia                            │
└───────────────────────────────────────────────────────────────────────┘
```

### Bloques de las prácticas y su dimensionado

| Bloque | Práctica | En NEURA-32 | Tamaño para Vigía |
|---|---|---|---|
| PC y registro | P1 | `pc_f` en IF | 32 bits |
| Banco de registros | P1 | `banco_registros.v`, x0 = 0 | 32 × 32 bits |
| ALU | P3 | `alu_riscv.v`, 128 operaciones, banderas C/O/Z/N | igual; XNOR y POPCOUNT hacen la red binaria |
| ROM de programa | P4 | `rom_instrucciones.v`, índice `dir[11:2]` | 1 024 palabras (programa ≈ 700 instrucciones) |
| ROM de pesos | P4 | nueva | 512 × 64 bits + capa 2: ≈ 34 Kbit |
| RAM de datos | P4 | `ram_datos.v`, escritura por byte | 2 048 palabras (8 KB): etiquetas 80×60, manchas, pistas, pila |
| Inmediatos y control | P5 | `generador_inmediato.v`, `unidad_control.v` + `control_alu.v` | igual |
| Camino de datos | P6 | `nucleo_neura32.v`, 5 etapas, adelantamiento, riesgos | igual, a 25 MHz |
| E/S mapeada | P6 | `perifericos.v` en 0xFFFF0000 | + GPIO (SCCB), ventana de máscara, registros de video y de dibujo |

### Presupuesto de memoria interna (M9K)

| Uso | Tamaño |
|---|---|
| Video para el monitor, 320×240 × 4 bits de gris | 307 Kbit |
| Modelo de fondo, 160×120 × 8 bits | 154 Kbit |
| Máscara de silueta, 160×120 × 1 bit | 19 Kbit |
| ROM de programa + ROM de pesos | 66 Kbit |
| RAM de datos | 64 Kbit |
| Líneas para filtros 3×3 | 3 Kbit |
| **Total** | **≈ 613 Kbit de 1 638 (37 %)** |

## La red neuronal: «¿es una persona?»

- **Entrada:** la silueta de cada mancha, recortada a su recuadro y reducida a 16 × 32 píxeles
  (más alta que ancha, como una persona de pie) = 512 bits.
- **Capa oculta:** 64 neuronas **binarias**. Cada neurona compara la silueta con su patrón de pesos
  de 1 bit: `XNOR` y `POPCOUNT`. Las dos ya existen en la ALU de la P3 (códigos 0x27 y 0x57) y se usan
  con la extensión Xneura: 16 palabras × 64 neuronas ≈ 4 mil instrucciones por mancha.
- **Salida:** 3 clases con pesos de 8 bits: **persona**, **objeto o animal**, **ruido** (sombra,
  destello, mancha irregular). Solo «persona» puede disparar la alarma.
- **Entrenamiento (fuera de la placa):** siluetas de peatones del Penn-Fudan Database (345 personas con
  máscara), con aumentos de escala, desplazamiento, espejo y ruido; negativos generados (elipses,
  rectángulos, manchas irregulares, formas horizontales tipo mascota o auto). Después se afina con
  siluetas capturadas por la propia placa, leídas por JTAG con el *In-System Memory Content Editor* de
  Quartus (sin ESP32 ni UART).
- **Medición de arquitectura:** el mismo clasificador en tres versiones, cronometradas con el CSR
  `cycle`: RV32I puro (popcount por software), RV32IM + Xneura (XNOR + POPCOUNT de la ALU) y, como
  extra, un acelerador de 64 neuronas en paralelo mapeado en memoria.

## Reglas perimetrales (software en NEURA-32)

1. **Zona prohibida:** un rectángulo que se ajusta con interruptores y botones. Persona dentro por más
   de N cuadros = INTRUSIÓN.
2. **Línea virtual con sentido:** cuenta entradas y salidas; cruzar en el sentido prohibido = alarma.
3. **Seguimiento:** cada mancha recibe un número y se sigue por su centroide entre cuadros.
4. **Registro de eventos** en RAM con hora en ciclos (CSR `cycle`), legible por JTAG.
5. **Salidas:** recuadro verde (persona fuera), rojo (persona en zona), gris (no es persona);
   zona en amarillo; letrero «INTRUSO»; LED de alarma; HEX con personas en zona, entradas y salidas.

## Carga de trabajo por cuadro (NEURA-32 a 25 MHz)

| Tarea | Instrucciones aprox. |
|---|---|
| Componentes conexos en la máscara reducida 80×60 | 120 mil |
| Recorte, reducción y red binaria (por mancha, Xneura) | 12 mil |
| Seguimiento, reglas y dibujo | 3 mil |
| **Total con 2 personas en escena** | **≈ 150 mil → 8 ms** |

La cámara da un cuadro cada 70–140 ms, así que el procesador va sobrado y el sistema es de tiempo real.

## Etapas (entrega 23–27 nov)

| Etapa | Qué se demuestra | Necesita cámara |
|---|---|---|
| a | NEURA-32 sintetizado en la MAX 10 a 25 MHz (ROM/RAM síncronas, división multiciclo) | No |
| b | Patrón de colores y texto en VGA dibujado por el procesador | No |
| c | Toda la tubería simulada en Icarus y Active-HDL con video sintético (una silueta que cruza) | No |
| d | Video en vivo en el monitor, cámara configurada por el procesador | Sí |
| e | Máscara de movimiento y recuadros en vivo | Sí |
| f | Red neuronal + zona + línea + alarma | Sí |
| g | Comparación RV32I vs Xneura vs acelerador | No |

Con a–d ya hay proyecto presentable; con f está completo; g es el extra de arquitectura.

## Riesgos

- **Luz y autoexposición:** si la cámara ajusta la exposición sola, todo el cuadro cambia y el fondo se
  rompe. El procesador congela AEC/AGC/AWB por SCCB después de dos segundos.
- **Sombras:** dan falsas siluetas; justo lo que la clase «ruido» de la red debe filtrar.
- **Velocidad del núcleo:** nunca se ha sintetizado; el divisor combinacional limita f_max y pasa a multiciclo.
- **Cableado:** 18 jumpers; se valida primero con un programa que lee el ID de la cámara (0x76 0x73) por SCCB.

## Referencias

- Terasic, *DE10-Lite User Manual*, 2022 (en `Docs/Manuales`).
- OmniVision, hoja de datos del OV7670.
- Columbia CSEE 4840, *CameraControl* (OV7670 + VGA en Quartus):
  https://www.cs.columbia.edu/~sedwards/classes/2022/4840-spring/reports/CameraControl-report.pdf
- A. Jacobo, *FPGA_OV7670_Camera_Interface* (SCCB y captura en Verilog):
  https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface
- Rodríguez-Gómez et al., *FPGA Implementation for Real-Time Background Subtraction Based on Horprasert Model*, Sensors, 2012:
  https://digibug.ugr.es/handle/10481/22390
- Sheffield Hallam, *Accelerated hardware video object segmentation: from foreground detection to connected components labelling*:
  https://shura.shu.ac.uk/22195
- Penn-Fudan Database for Pedestrian Detection and Segmentation: https://www.cis.upenn.edu/~jshi/ped_html/
- Umuroglu et al., *FINN* (redes binarias con XNOR y popcount en FPGA):
  https://www.sintef.no/contentassets/128200348e69454a916880bc85f00aaf/yaman_umuroglu-finn-poster-updated.pdf
- Sabih et al., *Beyond BNNs: Sub-Bit Neural Networks Using RISC-V Custom Functional Units*, 2025:
  https://cris.fau.de/publications/352674217
