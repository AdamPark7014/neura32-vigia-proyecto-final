# El RISC-V de la clase (punto de partida)

Estos nueve archivos son el procesador `riscv_ab_c` tal como se armó en clase, sin ningún cambio. Calcula
`(a + b) · c` con dos instrucciones leídas de `programa_ab_c.txt`. NEURA-32 se construyó ampliando cada uno:

| Archivo de la clase | En el proyecto | Qué se le agregó |
|---|---|---|
| `riscv_ab_c.v` | `hdl/riscv_neura.v` | registros `PCI`, `ALUOUT` y `MDR`, mux del PC, RAM por bytes, divisor, entradas y salidas |
| `uc_simple.v` | `hdl/uc_simple.v` | estados `EXEC_DIV`, `EXEC_BR`, `JUMP_WAIT` y `HALT`; `alu_op = funct3` |
| `alu_riscv.v` | `hdl/alu_riscv.v` | `case (opcode)` con las tablas `OP_R1` (la original), `OP_R2`, `OP_R3` y los saltos |
| `decoder.v` | `hdl/decoder.v` | inmediatos `imm_s`, `imm_b`, `imm_u` e `imm_j` |
| `regfile.v` | `hdl/regfile.v` | sin cambios de fondo (los valores iniciales a, b, c valen 0 por omisión) |
| `pipo_register.v` | `hdl/pipo_register.v` | sin cambios |
| `rom.v` | `hdl/rom.v` | 4096 palabras y un puerto de escritura para el cargador de programas |
| `ram.v` | `hdl/ram.v` | sin cambios; se usan cuatro de 8 bits, una por byte |
| `programa_ab_c.txt` | se usa tal cual | `tb/tb_programa_ab_c.v` lo corre en el procesador final |

Estilo que se conservó en todo el procesador: nombres de señales en inglés y en minúsculas (`clk`, `rst`,
`en`, `we`, `addr`, `data_in`, `data_out`, `instr`, `opcode`, `rd`, `rs1`, `rs2`, `funct3`), parámetros en
minúsculas (`nbits`, `addr_width`, `data_width`), reinicio asíncrono activo en bajo
(`always @(posedge clk or negedge rst)` con `if(!rst)`), registros hechos con `pipo_register` y `begin` /
`end` escritos completos.

Un detalle de la copia original, corregido en `hdl/`: `pipo_register.v` trae una coma de más después de
`output [nbits-1:0] q`.
