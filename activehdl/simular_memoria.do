# Memoria de datos con accesos parciales (tb_memoria_datos).
# La consola debe terminar con "PRUEBAS: 19  ERRORES: 0".
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_memoria_datos

wave                /tb_memoria_datos/clk
wave -radix hex     /tb_memoria_datos/dir
wave -radix bin     /tb_memoria_datos/funct3
wave -radix hex     /tb_memoria_datos/dato_reg
wave                /tb_memoria_datos/mem_write
wave -radix bin     /tb_memoria_datos/dmem_be
wave -radix hex     /tb_memoria_datos/dmem_dato_esc
wave -radix hex     /tb_memoria_datos/ram_q
wave -radix hex     /tb_memoria_datos/dato_ext
wave                /tb_memoria_datos/desalineado

run -all
