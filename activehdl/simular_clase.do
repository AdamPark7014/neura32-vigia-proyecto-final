# La ROM de instrucciones de la clase ejecutada en el procesador (tb_instrucciones_clase).
# La consola debe terminar con "PRUEBAS: 31  ERRORES: 0".
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_instrucciones_clase

wave                /tb_instrucciones_clase/clk
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/pc_f
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/instr_d
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/instr_e
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/operando_a
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/operando_b
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/resultado_ex
wave                /tb_instrucciones_clase/dut/nucleo/parar_e
wave -radix unsigned /tb_instrucciones_clase/dut/nucleo/rd_w
wave -radix hex     /tb_instrucciones_clase/dut/nucleo/resultado_w

run -all
