# Unidad de control contra su tabla (tb_unidad_control).
# La consola debe terminar con "PRUEBAS: 21  ERRORES: 0".
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_unidad_control

wave -radix hex     /tb_unidad_control/instr
wave                /tb_unidad_control/reg_write
wave                /tb_unidad_control/alu_src_b
wave                /tb_unidad_control/mem_read
wave                /tb_unidad_control/mem_write
wave -radix unsigned /tb_unidad_control/res_sel
wave                /tb_unidad_control/branch
wave                /tb_unidad_control/jump
wave -radix hex      /tb_unidad_control/resultado
wave -radix hex     /tb_unidad_control/ilegal_alu
wave                /tb_unidad_control/ilegal

run -all
