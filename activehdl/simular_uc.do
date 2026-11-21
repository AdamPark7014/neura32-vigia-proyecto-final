# La unidad de control sola (tb_uc_simple): recorrido de estados por tipo de instruccion.
# La consola debe terminar con "PRUEBAS: 28  ERRORES: 0".
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_uc_simple

wave                 /tb_uc_simple/clk
wave                 /tb_uc_simple/rst
wave -radix bin      /tb_uc_simple/opcode
wave -radix bin      /tb_uc_simple/funct3
wave                 /tb_uc_simple/take
wave                 /tb_uc_simple/div_ready
wave -radix unsigned /tb_uc_simple/state
wave -radix bin      /tb_uc_simple/alu_op
wave                 /tb_uc_simple/pc_en
wave -radix unsigned /tb_uc_simple/pc_src
wave                 /tb_uc_simple/ir_en
wave                 /tb_uc_simple/alu_src
wave                 /tb_uc_simple/aluout_en
wave                 /tb_uc_simple/addr_phase
wave                 /tb_uc_simple/mem_read
wave                 /tb_uc_simple/mdr_en
wave                 /tb_uc_simple/mem_write
wave                 /tb_uc_simple/reg_write
wave -radix unsigned /tb_uc_simple/result_src
wave                 /tb_uc_simple/div_start
wave                 /tb_uc_simple/div_sel
wave                 /tb_uc_simple/halted
wave                 /tb_uc_simple/illegal

run -all
