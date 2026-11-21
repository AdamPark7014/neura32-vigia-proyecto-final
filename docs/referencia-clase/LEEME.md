# Codigos de la clase (referencia de estilo)

Los tres modulos que se usan en clase (registro PIPO, RAM y decodificador),
tal como se entregaron en clase (19-11-2026). El proyecto sigue esta sintaxis:

- nombres de senales en ingles y en minusculas: `clk`, `rst`, `en`, `d`, `q`,
  `we`, `addr`, `data_in`, `data_out`, `instr`, `opcode`, `rd`, `rs1`, `rs2`,
  `funct3`, `imm_i`;
- parametros en minusculas: `nbits`, `initial1`, `addr_width`, `data_width`;
- reinicio asincrono activo en bajo: `always @(posedge clk or negedge rst)` con `if(!rst)`;
- registros hechos con `pipo_register` (con `en`), memoria con `ram`
  (`(* ramstyle = "M9K" *)`, lectura y escritura sincronas) y campos de la
  instruccion con `assign` en `decoder`;
- `begin` / `end` escritos completos y comentarios cortos en espanol.

En la copia original, `pipo_register` trae una coma de mas despues de
`output [nbits-1:0] q` (no compila asi) y a `ram` le faltaban los asteriscos de
`(* ramstyle = "M9K" *)`; aqui estan corregidos.
