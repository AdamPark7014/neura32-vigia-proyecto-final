# Simula la prueba del repertorio (tb_prueba_isa).
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"
# La consola debe terminar con "PRUEBAS: 94  ERRORES: 0".

asim +access +r tb_prueba_isa

wave -radix hex     /tb_prueba_isa/dut/nucleo/pc_f
wave -radix hex     /tb_prueba_isa/dut/nucleo/instr_d
wave -radix hex     /tb_prueba_isa/dut/nucleo/opcode_d
wave -radix hex     /tb_prueba_isa/dut/nucleo/instr_e
wave -radix hex     /tb_prueba_isa/dut/nucleo/instr_e
wave -radix hex     /tb_prueba_isa/dut/nucleo/operando_a
wave -radix hex     /tb_prueba_isa/dut/nucleo/operando_b
wave -radix hex     /tb_prueba_isa/dut/nucleo/alu_result_e
wave                /tb_prueba_isa/dut/nucleo/bandera_c
wave                /tb_prueba_isa/dut/nucleo/bandera_o
wave                /tb_prueba_isa/dut/nucleo/bandera_z
wave                /tb_prueba_isa/dut/nucleo/bandera_n
wave                /tb_prueba_isa/dut/nucleo/salto_tomado_e
wave -radix bin     /tb_prueba_isa/dut/nucleo/adel_a
wave -radix bin     /tb_prueba_isa/dut/nucleo/adel_b
wave                /tb_prueba_isa/dut/nucleo/parar_f
wave -radix hex     /tb_prueba_isa/dut/nucleo/dmem_dir
wave -radix hex     /tb_prueba_isa/dut/nucleo/dmem_dato_esc
wave -radix bin     /tb_prueba_isa/dut/nucleo/dmem_be
wave                /tb_prueba_isa/dut/nucleo/dmem_we
wave -radix hex     /tb_prueba_isa/dut/nucleo/resultado_w
wave -radix unsigned /tb_prueba_isa/dut/nucleo/rd_w
wave                /tb_prueba_isa/fin

run -all
