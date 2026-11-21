# NEURA-32 Vigía: vigilancia perimetral inteligente sobre un procesador RISC-V de 32 bits

**Laboratorio de Arquitecturas Computacionales · Proyecto final**
**Equipo:** Roberto Orozco Ramírez (ID 184595) · Adam Del Pozo Ontiveros (ID 185611)
**Plataforma:** Verilog-2005 · Icarus Verilog y Active-HDL 17 SE · Quartus Prime 24.1 Lite · DE10-Lite (MAX 10 10M50DAF484C7G) · cámara OV7670 · monitor VGA

---

## 1. Planteamiento del problema y justificación

Las cámaras de vigilancia comerciales avisan cuando «algo se mueve» en una zona. La mayoría de esas
alarmas son falsas: una sombra, un cambio de luz, una mascota o un objeto que rueda. Los equipos de gama
alta resuelven esto con un clasificador que decide si el movimiento es una persona antes de avisar
(detección de intrusión y cruce de línea con filtro de personas).

Este proyecto construye esa función completa sobre el procesador RISC-V que se armó en las prácticas:

* una cámara OV7670 mira una puerta o un pasillo y el monitor VGA muestra el video;
* el hardware separa lo que se mueve del fondo y entrega la **silueta** de cada objeto;
* el procesador etiqueta cada silueta, la recorta y la pasa por una **red neuronal binaria** que decide
  si es **persona**, **objeto o animal**, o **ruido**;
* solo si es una persona aplica las **reglas perimetrales**: entrar a una zona prohibida y quedarse, o
  cruzar una línea virtual en el sentido prohibido. Entonces enciende la alarma, dibuja un recuadro rojo y
  el letrero «INTRUSO», y cuenta entradas y salidas en los displays.

Es una aplicación real (videovigilancia con filtro de falsas alarmas) que usa todos los bloques de las
prácticas: banco de registros (P1), ALU de 32 bits (P2 y P3), ROM y RAM (P4), unidad de control (P5) y el
camino de datos integrado con E/S mapeada a memoria (P6). Además implementa tres de las ampliaciones que
propone la guía: la extensión M, el camino de datos segmentado en cinco etapas con adelantamiento y una
extensión del repertorio propia.

## 2. Arquitectura del sistema

### 2.1 Diagrama de bloques

```
                     ┌──────────────── tubería de visión (hardware, sin procesador) ─────────────────┐
 OV7670 ──D[7:0]────►│ captura_ov7670 ──► gris 4 bits ─────────────────────────► memoria de video ───┐ │
        HREF VSYNC   │   (sincronizador     promedio 8x8 ──► fondo_mascara ──► máscara (2 bancos) ─┐ │ │
        PCLK         │    de 2 FF)          (80 x 60)         F += (I-F)/2^α   máscara VGA (1 bit) ─┼─┤ │
   ▲ XCLK 25 MHz     └────────────────────────────────────────────────────────────────────────────┼─┼─┘
   ▲ SCCB (SIOC/SIOD) por GPIO                                                                    │ │
   │                                                                                              │ ▼
 ┌─┴──────────────────────────── NEURA-32 (RV32IM + Zbb + clase + Zicsr + Xneura) ─────────────┐  │ vga_dibujo
 │  IF ──────► ID ─────────► EX ─────────────────► MEM ─────────► WB                            │  │ (zona, línea,
 │  PC         unidad_control  adelantamiento        acceso a memoria  banco de registros       │  │  recuadros,
 │  ROM 16 KB  control_alu     alu_riscv (128 ops)   RAM 16 KB          (escritura)              │  │  INTRUSO)
 │  (síncrona) generador inm.  divisor iterativo     máscara (lectura)                           │  │     │
 │             banco (lectura) unidad_saltos, CSR    periféricos                                 │◄─┘     ▼
 │                       unidad_riesgos: carga-uso, saltos, división, ecall                      │      VGA
 └──────┬──────────────────────────────────────────────────────────────────────────────────────┘
        └──► LEDR · HEX5..HEX0 · registros de dibujo (zona, línea, 8 recuadros, letrero)
```

Todo el sistema trabaja con **un solo reloj de 25 MHz** (el reloj de píxel del VGA). La cámara se configura
para que su reloj de píxel PCLK sea lento (6.25 MHz) y la FPGA lo muestrea con un sincronizador de dos
flip-flops y un detector de flanco. Así no hay cruces de dominio de reloj, que es el problema más común
de los proyectos con esta cámara.

### 2.2 El procesador NEURA-32

| Bloque | Práctica | Archivo | Qué hace |
|---|---|---|---|
| Contador de programa | P1 | `nucleo_neura32.v` | PC + 4, destino de salto, detención |
| Banco de registros | P1 | `banco_registros.v` | 32 × 32 bits, x0 = 0, 2 lecturas y 1 escritura, el valor nuevo se ve en el mismo ciclo |
| ALU | P2, P3 | `alu_riscv.v` | la ALU de 128 operaciones de la Práctica 3 con banderas C, O, Z, N |
| ROM de programa | P4 | `rom_instrucciones.v` | 4096 palabras, síncrona, doble puerto (instrucciones y datos), `$readmemh` |
| RAM de datos | P4 | `ram_datos.v` | 4096 palabras, síncrona, escritura por byte |
| Accesos parciales | P4 | `unidad_acceso_memoria.v` | `lb lh lw lbu lhu sb sh sw`, extensión de signo, accesos no alineados |
| Generador de inmediato | P5 | `generador_inmediato.v` | formatos I, S, B, U, J |
| Unidad de control | P5 | `unidad_control.v` | `case (opcode)` con `case` anidados de funct3, funct7 e imm12 |
| Control de la ALU | P5 | `control_alu.v` | segundo nivel: grupo + funct3 + funct7 + rs2 → `alu_op` |
| Decisión de salto | P5 | `unidad_saltos.v` | la ALU resta; Z, N⊕O y C deciden `beq bne blt bge bltu bgeu` |
| Adelantamiento | P6 | `unidad_adelantamiento.v` | MEM→EX y WB→EX |
| Riesgos | P6 | `unidad_riesgos.v` | carga-uso (1 ciclo), salto tomado (anula 2), división (congela), `ecall` |
| Divisor | P6 | `divisor_iterativo.v` | división con restauración, 34 ciclos, casos especiales de la norma |
| CSR | P6 | `registros_csr.v` | `cycle`, `instret`, `time` (64 bits), `mscratch`, `misa`, banderas de Xneura |
| Periféricos | P6 | `perifericos.v`, `vision/registros_vision.v` | LED, interruptores, HEX, botones, consola, cámara, visión, dibujo |

**Pipeline de cinco etapas.** IF, ID, EX, MEM y WB, con adelantamiento desde MEM y WB. Una carga seguida de
una instrucción que usa su resultado detiene un ciclo (con el parámetro `ADELANTAR_CARGAS = 1` el dato se
adelanta desde MEM y no hay detención). Los saltos se resuelven en EX con las banderas de la ALU y, si se
toman, se anulan las dos instrucciones que se habían traído. Las memorias son síncronas, como la ROM de la
Práctica 4, para que Quartus las coloque en bloques M9K: la ROM entrega la instrucción en ID (su registro de
salida es el registro IF/ID) y la RAM entrega el dato en MEM con la dirección que llega desde EX.

**Unidad de control en dos niveles** (Práctica 5). El primer nivel genera las señales de la tabla de control:

| Instrucción | RegWrite | ALUSrc | MemRead | MemWrite | MemToReg | Branch | Jump | ALUOp |
|---|---|---|---|---|---|---|---|---|
| tipo R (`add`, `mul`, `andn`, ...) | 1 | 0 | 0 | 0 | 0 | 0 | 0 | OP |
| tipo I (`addi`, `srai`, `clz`, ...) | 1 | 1 | 0 | 0 | 0 | 0 | 0 | OPIMM |
| `lw` y demás cargas | 1 | 1 | 1 | 0 | 1 | 0 | 0 | suma |
| `sw` y demás almacenamientos | 0 | 1 | 0 | 1 | 0 | 0 | 0 | suma |
| `beq` y demás saltos condicionales | 0 | 0 | 0 | 0 | 0 | 1 | 0 | resta |
| `jal`, `jalr` | 1 | 0 | 0 | 0 | 0 | 0 | 1 | suma |
| `lui` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | pasa B |
| `nota`, `passb`, `sla` (clase) | 1 | 0 | 0 | 0 | 0 | 0 | 0 | CLASE |

El segundo nivel (`control_alu`) combina ALUOp con funct3, funct7 y el campo rs2 para elegir una de las 128
operaciones de la ALU. Así el control principal no depende de todos los bits de la instrucción.

### 2.3 Repertorio de instrucciones

| Grupo | Instrucciones |
|---|---|
| RV32I | `lui auipc jal jalr beq bne blt bge bltu bgeu lb lh lw lbu lhu sb sh sw addi slti sltiu xori ori andi slli srli srai add sub sll slt sltu xor srl sra or and fence ecall ebreak` |
| RV32M | `mul mulh mulhsu mulhu div divu rem remu` |
| Zbb (de la ROM de la clase) | `andn orn xnor min minu max maxu rol ror rori clz ctz cpop sext.b sext.h zext.h rev8` |
| Propias de la clase (custom-0) | `nota rd, rs1` (= ~rs1) · `passb rd, rs2` (= rs2) · `sla rd, rs1, rs2` (corrimiento a la izquierda) |
| Zicsr / Zicntr | `csrrw csrrs csrrc csrrwi csrrsi csrrci`, contadores `cycle`, `time`, `instret` |
| Xneura (custom-1) | `funct7` es directamente uno de los 128 códigos de la ALU de la Práctica 3; `funct3[0]` guarda las banderas y `funct3[1]` usa el acarreo guardado (aritmética de precisión múltiple) |

Las codificaciones son las del manual de RISC-V y las de la ROM de instrucciones de la clase
(`Entregas/rom-instrucciones-riscv/src/instrucciones.txt`); el testbench `tb_instrucciones_clase` ejecuta
esa misma ROM en el procesador.

### 2.4 Mapa de memoria

| Dirección | Contenido |
|---|---|
| `0x0000_0000 – 0x0000_3FFF` | ROM de programa (también se lee como datos: tablas y pesos de la red) |
| `0x1000_0000 – 0x1000_3FFF` | RAM de datos: variables, manchas, pistas, etiquetas, pila |
| `0x2000_0000 – 0x2000_12BF` | máscara de movimiento de 80 × 60, un byte por píxel (solo lectura) |
| `0xFFFF_0000` LEDS · `+04` SW · `+08` HEX · `+0C` KEY · `+10` TICKS · `+14` CONSOLA · `+18` CONTROL · `+24` PLATAFORMA | periféricos básicos |
| `0xFFFF_0040` CAM_SAL · `+44` CAM_ENT · `+48` VIS_CTRL · `+4C` VIS_EST · `+50` VIS_FG | cámara (SCCB por GPIO) y visión |
| `0xFFFF_0054` ZONA · `+58` LINEA · `+5C` LETRERO · `+60..+7C` CAJA0..7 · `+80` COLORES | lo que se dibuja sobre el video |

### 2.5 La tubería de visión

1. **Captura** (`captura_ov7670.v`). Sincroniza PCLK, HREF, VSYNC y los 8 datos, toma los bytes de
   luminancia del formato YUYV y produce dos salidas: el video de 320 × 240 con 4 bits de gris para el
   monitor, y una imagen de 80 × 60 donde cada píxel es el **promedio de un bloque de 8 × 8** (filtro
   pasa-bajas que también quita el ruido del sensor).
2. **Fondo y máscara** (`fondo_mascara.v`). Guarda un fondo aprendido F por píxel y lo actualiza con un
   promedio exponencial F ← F + (I − F)/2^α. Un píxel es silueta si |I − F| supera un umbral. Donde hay
   alguien parado el fondo aprende cuatro veces más lento, para que una persona quieta no se «borre».
3. **Doble buffer.** La máscara se escribe en dos bancos: la cámara llena uno mientras el procesador lee el
   otro. Si el procesador aún no termina, el cuadro se descarta.
4. **VGA** (`vga_sincronia.v`, `vga_dibujo.v`). 640 × 480 a 60 Hz con los tiempos de la tabla 3-9 y 3-10 del
   manual de la DE10-Lite. Sobre el video dibuja la silueta en azul, la línea virtual, la zona prohibida, hasta
   ocho recuadros de color y el letrero «INTRUSO» con una fuente de 8 × 8.

## 3. El programa

El programa se escribió **en Verilog**, con funciones que codifican cada instrucción bit a bit según sus
formatos (`prog/codificador_riscv.vh`: `ADD(rd, rs1, rs2)`, `LW(rd, rs1, imm)`, `XNOR(...)`, `NOTA(...)`...).
Un generador de dos pasadas (`prog/generador_programa.v`) resuelve las etiquetas y revisa que cada salto quepa
en su formato. `tb/generar_rom.v` escribe la ROM en `fpga/programa_vigia.txt` con el mismo formato que la ROM de
instrucciones de la clase, una instrucción comentada por línea:

```
ffff0437 // 0000: lui s0, 0xffff0
100004b7 // 0004: lui s1, 0x10000
...
41e3c3b3 // 09c8: xnor t2, t2, t5
60239393 // 09cc: cpop t2, t2
```

Son **1 318 instrucciones** y 1 254 palabras de tablas (configuración de la cámara, zonas, pesos de la red,
textos). El programa completo y comentado está en `prog/programa_vigia.vh`.

### 3.1 Flujo

1. **Arranque.** Pulso de reset a la cámara por su pin, reinicio de registros por SCCB y lectura de su
   identificación (PID = 0x76, VER = 0x73): si no responde, el procesador lo indica en los displays. Después
   escribe la tabla de registros (preescala del reloj, formato YUYV, rango completo) por **SCCB hecho por
   software**: el procesador mueve las líneas SIOC y SIOD a través de un periférico GPIO.
2. **Medición de la red** con el CSR `cycle`, con y sin las instrucciones Zbb.
3. **Exposición fija y fondo.** Después de 2 s congela la exposición, la ganancia y el balance de blancos de
   la cámara (si cambian solos, todo el cuadro parece moverse) y aprende el fondo vacío.
4. **Por cada máscara:**
   * **Etiquetado** de manchas (componentes conexos con 4 vecinos) con relleno por inundación y pila en RAM;
     el recuadro de cada mancha se calcula con `min` y `max` de Zbb.
   * **Recorte** de cada mancha a 16 × 32 bits: ventana 1:2 centrada en el recuadro, muestreada con
     acumuladores (sin dividir).
   * **Red binaria** (sección 3.2).
   * **Seguimiento:** cada persona se empareja con la pista más cercana (distancia Manhattan de su centro y
     sus pies, con `abs` de Xneura).
   * **Reglas:** cruzar la línea cuenta una entrada o una salida; en el sentido prohibido es alarma. Tener los
     pies dentro de la zona tres cuadros seguidos es alarma de intrusión. Cada evento se guarda en un registro
     en RAM con el cuadro y el ciclo.
   * **Salidas:** recuadros (verde persona, rojo intruso, gris no persona), zona, línea, letrero, LED y displays.

### 3.2 La red neuronal binaria

| Capa | Tamaño | Operación en el procesador |
|---|---|---|
| Entrada | 16 × 32 = 512 bits | la silueta recortada, en 16 palabras |
| Oculta | 64 neuronas binarias | `cuenta = Σ cpop(xnor(x, w))` sobre 16 palabras; `a = cuenta ≥ T` |
| Salida | 3 clases | `o_k = B_k + Σ W_kj` para las neuronas activas (pesos de 8 bits); `argmax` |

Los pesos de la capa oculta son de **un bit**, así que cada neurona se resuelve con `xnor` y `cpop`, dos
instrucciones Zbb de la ROM de la clase. La red se entrenó fuera del procesador (`sw/entrenar_vigia.py`) con
9 000 siluetas sintéticas generadas en la misma rejilla de 80 × 60 y recortadas con la misma aritmética
entera del programa, con errores típicos de una máscara real (bordes comidos, huecos, sombra en los pies). Los
pesos entran a la ROM como un archivo Verilog (`prog/pesos_vigia.vh`).

Resultado con aritmética entera, que es lo que ejecuta el procesador, sobre 1 800 siluetas de prueba:
**90.7 % de aciertos**; 95.5 % de las personas se reconocen como persona.

| real \ predicha | persona | objeto o animal | ruido |
|---|---|---|---|
| persona | **573** | 14 | 13 |
| objeto o animal | 19 | **543** | 38 |
| ruido | 16 | 67 | **517** |

![Siluetas de entrenamiento](docs/img/siluetas_entrenamiento.png)

*Ejemplos de prueba: personas (arriba), objetos y animales (en medio), ruido (abajo).*

## 4. Modificaciones al procesador

Partiendo del procesador de las prácticas:

1. **Memorias síncronas** (como la ROM de la Práctica 4) para que quepan en los bloques M9K: la ROM pasó a ser el
   registro IF/ID y el acceso a la RAM se repartió entre EX (dirección y dato) y MEM (dato leído y extensión).
2. **Divisor iterativo** de 34 ciclos con detención del pipeline. Un divisor combinacional de 32 bits no cabe
   en un ciclo de 40 ns. La ALU de la Práctica 3 recibió el parámetro `DIV_COMBINACIONAL` y no cambió en lo demás.
3. **Repertorio de la clase:** Zbb (`andn orn xnor min rol ror clz ctz cpop sext.b sext.h zext.h rev8`, más
   `minu max maxu rori`) y las propias `nota`, `passb` y `sla` en custom-0, con la codificación exacta de la ROM
   de instrucciones del laboratorio. La extensión Xneura se movió a custom-1.
4. **Periféricos de cámara y visión** mapeados a memoria y un registro `PLATAFORMA` para que el mismo programa
   ajuste sus tiempos en simulación y en la placa.
5. **Tubería de visión y VGA** completas en hardware.

## 5. Verificación

Todo se simula con Icarus Verilog (`simular.ps1`) y compila sin errores ni advertencias en el compilador de
Active-HDL (`vlog`). Cada testbench se revisa solo y termina con `PRUEBAS: n  ERRORES: 0`.

| Testbench | Qué comprueba | Resultado |
|---|---|---|
| `tb_unidad_control` | la tabla de control para cada tipo de instrucción y el `alu_op` del segundo nivel (Práctica 5) | 21 / 21 |
| `tb_memoria_datos` | patrón conocido, bytes y medias palabras en las cuatro posiciones, extensión de signo, acceso no alineado (Práctica 4) | 19 / 19 |
| `tb_instrucciones_clase` | la ROM de instrucciones de la clase ejecutada en el procesador, contra un intérprete de referencia escrito aparte | 31 / 31 |
| `tb_prueba_isa` | 92 resultados: RV32I, M, Zbb, clase, CSR, Xneura, accesos parciales, la suma de 1 a 10, los seis saltos, `jal`/`jalr`, adelantamiento, carga-uso, división entre cero y con desbordamiento, instrucción ilegal | 94 / 94 |
| `tb_red_neuronal` | el clasificador 3 × 3 de la versión anterior (regresión) contra un modelo de referencia | 481 / 481 |
| `tb_vigia` | el sistema completo con un modelo de la cámara OV7670 (ver 5.1) | RESULTADO_VIGIA |

### 5.1 El sistema completo con la cámara simulada

`tb/modelo_ov7670.v` imita a la cámara: responde por SCCB (escritura y lectura de registros, PID y VER),
genera PCLK = XCLK / (CLKRC + 1) como dice la hoja de datos, respeta el orden de bytes que fija TSLB y genera
una escena sintética con textura, piso, ruido de sensor y, según el guion, un perro o una persona que camina.
En simulación la cámara entrega 160 × 120 en lugar de 640 × 480 para que la prueba dure minutos; la
detección es de 80 × 60 en ambos casos y el programa es exactamente el mismo.

Guion y resultado:

DETALLE_VIGIA

## 6. Mediciones de recursos y rendimiento

### 6.1 Rendimiento

| Programa | Instrucciones | Ciclos | CPI |
|---|---|---|---|
| ROM de instrucciones de la clase | 35 | 105 | 3.00 (incluye dos divisiones de 34 ciclos) |
| Prueba del repertorio | 296 | 617 | 2.08 (seis divisiones iterativas) |
| Clasificador 3 × 3 (una inferencia) | 2 632 | 3 534 | 1.34 |
| Vigía, procesar una máscara con una mancha | MEDIDA_INSTR | ≈ 58 000 | MEDIDA_CPI |

**Red binaria con y sin Zbb** (misma silueta, CSR `cycle`):

| Versión | Por palabra | Ciclos por clasificación |
|---|---|---|
| RV32IM puro (`xor`, `not` y conteo de bits por software) | 17 instrucciones | 22 568 |
| con Zbb (`xnor` + `cpop`) | 5 instrucciones | 10 273 |

Las instrucciones de la clase hacen la red **2.2 veces más rápida**.

**Tiempo real.** A 25 MHz, procesar una máscara con una persona toma unos 58 000 ciclos, 2.3 ms. En la placa
la cámara entrega un cuadro cada 128 ms (7.8 cuadros por segundo con PCLK de 6.25 MHz): el procesador ocupa
menos del 2 % del tiempo y el sistema reacciona en el cuadro siguiente.

### 6.2 Recursos en la MAX 10

RECURSOS_QUARTUS

## 7. Conclusiones y trabajo futuro

CONCLUSIONES

---

## Cómo se usa

### Simulación

```powershell
pwsh -File simular.ps1            # todo (tb_vigia tarda unos 10 minutos)
pwsh -File simular.ps1 -Rapido    # todo menos el sistema completo
pwsh -File simular.ps1 -Pruebas tb_vigia
```

En Active-HDL, con el workspace `Lab_Arquitecturas` abierto:
`do ".../Proyecto-Final-NEURA32/activehdl/agregar_diseno.do"` agrega el diseño, compila y corre la prueba del
repertorio. Después: `simular_clase.do`, `simular_control.do`, `simular_memoria.do`, `simular_isa.do`,
`simular_red.do` o `simular_vigia.do`.

### Placa DE10-Lite

```powershell
pwsh -File fpga\compilar.ps1          # compila y deja RESUMEN.txt con recursos y frecuencia
pwsh -File fpga\compilar.ps1 -Grabar  # además programa la placa por USB-Blaster
```

| Control | Función |
|---|---|
| KEY0 | reinicio |
| KEY1 | borra la alarma |
| SW1..SW0 | zona y línea (4 configuraciones) |
| SW2 | sentido prohibido: 0 izquierda→derecha, 1 al revés |
| SW3 | pinta la silueta en azul |
| SW4 | red con RV32IM puro (para comparar con Zbb) |
| SW7..SW5 | umbral de movimiento: 28 + 8 × valor |
| SW8 | barras de colores en el monitor (prueba del VGA sin cámara) |
| SW9 | vuelve a aprender el fondo mientras está arriba |
| LEDR9 / LEDR8 / LEDR7 / LEDR6 | alarma (parpadea) / aprendiendo el fondo / cámara identificada / un cuadro procesado |
| HEX5-4 / HEX3-2 / HEX1 / HEX0 | entradas / salidas / personas en la zona / manchas |

La guía de conexión y arranque paso a paso está en [docs/PRUEBA-EN-PLACA.md](docs/PRUEBA-EN-PLACA.md).

### La cámara

**Modelo:** OV7670 **sin FIFO**, módulo azul de 18 pines (cabezal 2 × 9), alimentación de 3.3 V, salida
paralela de 8 bits y configuración por SCCB. No sirve la versión con FIFO AL422 (24 pines): el buffer de
cuadro ya está en los bloques M9K. Se usó el paquete de 4 piezas de la tienda oficial Tecneu en Mercado Libre
(publicación MLM65989366); cualquier OV7670 de 18 pines sin FIFO es equivalente, y tener repuestos conviene
porque 5 V en lugar de 3.3 V quema el módulo.

**Compatibilidad con la DE10-Lite:** el conector GPIO (JP1) tiene 36 pines de 3.3-V LVTTL y salida de 3.3 V y
tierra; la cámara usa 16 señales. El XCLK de 25 MHz lo genera la FPGA y la cámara lo divide entre 4 (registro
CLKRC) para que PCLK sea de 6.25 MHz. SIOC y SIOD llevan resistencias de 4.7 kΩ a 3.3 V (además de la
resistencia interna de la MAX 10 que activa el `.qsf`).

| OV7670 | JP1 | GPIO | OV7670 | JP1 | GPIO |
|---|---|---|---|---|---|
| 3V3 | pin 29 | — | GND | pin 30 | — |
| SIOC | pin 1 | GPIO[0] | SIOD | pin 2 | GPIO[1] |
| VSYNC | pin 3 | GPIO[2] | HREF | pin 4 | GPIO[3] |
| PCLK | pin 5 | GPIO[4] | XCLK | pin 6 | GPIO[5] |
| D7 | pin 7 | GPIO[6] | D6 | pin 8 | GPIO[7] |
| D5 | pin 9 | GPIO[8] | D4 | pin 10 | GPIO[9] |
| D3 | pin 13 | GPIO[10] | D2 | pin 14 | GPIO[11] |
| D1 | pin 15 | GPIO[12] | D0 | pin 16 | GPIO[13] |
| RESET | pin 17 | GPIO[14] | PWDN | pin 18 | GPIO[15] |

**Distancia y campo de visión.** El lente del módulo es de unos 6 mm sobre un sensor de 1/6"; da un campo de
visión de unos 22° en horizontal y 16° en vertical. Para que una persona de 1.75 m de pie quepa completa, la
cámara debe estar a **unos 6 m**; a esa distancia la persona ocupa unas 50 de las 60 filas de la rejilla de
detección, justo el rango de tamaños con que se entrenó la red (16 a 56 filas). Para la demostración hay dos
opciones:

1. Cámara fija al fondo del salón o de un pasillo, de 6 a 8 m de la zona vigilada.
2. Siluetas recortadas o figuras de unos 30 cm a 1 m de la cámara: la red reconoce la forma de la silueta, no
   su tamaño, porque cada mancha se recorta y se escala a 16 × 32.

La cámara debe quedar fija (el fondo se aprende con la cámara quieta) y con luz estable. El enfoque se ajusta
girando el lente.

## Estructura

| Carpeta | Contenido |
|---|---|
| `hdl/` | el procesador (núcleo, ALU, memorias, control, CSR, periféricos) y el SoC |
| `hdl/vision/` | captura, fondo y máscara, memorias de video, VGA y registros de visión |
| `prog/` | ensamblador en Verilog, programas, pesos de las redes y la ROM de instrucciones de la clase |
| `tb/` | testbenches, modelo de la cámara y generador de la ROM; salidas en `tb/*.txt` |
| `fpga/` | proyecto de Quartus para la DE10-Lite, pines, restricciones y la ROM `programa_vigia.txt` |
| `activehdl/` | macros para Active-HDL |
| `sw/` | entrenamiento de las redes y conversión de imágenes |
| `docs/` | propuesta e imágenes |

## Referencias

1. A. Waterman y K. Asanović (eds.), *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, RISC-V International.
2. RISC-V International, *RISC-V Bit-Manipulation ISA-extensions (Zba, Zbb, Zbc, Zbs)*, versión 1.0.0, 2021.
3. D. A. Patterson y J. L. Hennessy, *Computer Organization and Design RISC-V Edition*, Morgan Kaufmann, 2.ª ed., 2020.
4. Terasic, *DE10-Lite User Manual*, 2022.
5. OmniVision, *OV7670/OV7171 CMOS VGA CameraChip Implementation Guide* y hoja de datos del OV7670.
6. M. Rastegari, V. Ordonez, J. Redmon y A. Farhadi, «XNOR-Net: ImageNet Classification Using Binary Convolutional Neural Networks», *ECCV*, 2016.
7. Y. Umuroglu *et al.*, «FINN: A Framework for Fast, Scalable Binarized Neural Network Inference», *FPGA '17*, 2017.
8. M. Rodríguez-Gómez *et al.*, «FPGA Implementation for Real-Time Background Subtraction Based on Horprasert Model», *Sensors*, 2012.
