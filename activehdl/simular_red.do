# Simula el clasificador neuronal (tb_red_neuronal) y muestra el pipeline.
set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"
# La consola debe terminar con "PRUEBAS: 481  ERRORES: 0".

asim +access +r tb_red_neuronal

# --- entrada / salida del SoC ---
wave -radix hex     /tb_red_neuronal/sw
wave -radix hex     /tb_red_neuronal/leds
wave -radix hex     /tb_red_neuronal/hex
wave                /tb_red_neuronal/fin

# --- pipeline: una fila por etapa ---
wave -radix hex     /tb_red_neuronal/dut/nucleo/pc_f
wave -radix hex     /tb_red_neuronal/dut/nucleo/imem_instr
wave -radix hex     /tb_red_neuronal/dut/nucleo/instr_d
wave -radix hex     /tb_red_neuronal/dut/nucleo/opcode_d
wave -radix hex     /tb_red_neuronal/dut/nucleo/instr_e
wave -radix hex     /tb_red_neuronal/dut/nucleo/operando_a
wave -radix hex     /tb_red_neuronal/dut/nucleo/operando_b
wave -radix hex     /tb_red_neuronal/dut/nucleo/alu_result_e
wave                /tb_red_neuronal/dut/nucleo/bandera_c
wave                /tb_red_neuronal/dut/nucleo/bandera_o
wave                /tb_red_neuronal/dut/nucleo/bandera_z
wave                /tb_red_neuronal/dut/nucleo/bandera_n
wave                /tb_red_neuronal/dut/nucleo/salto_tomado_e
wave -radix bin     /tb_red_neuronal/dut/nucleo/adel_a
wave -radix bin     /tb_red_neuronal/dut/nucleo/adel_b
wave                /tb_red_neuronal/dut/nucleo/parar_f
wave                /tb_red_neuronal/dut/nucleo/limpiar_e
wave -radix hex     /tb_red_neuronal/dut/nucleo/dmem_dir
wave -radix hex     /tb_red_neuronal/dut/nucleo/dmem_dato_esc
wave -radix hex     /tb_red_neuronal/dut/nucleo/dmem_dato_lec
wave                /tb_red_neuronal/dut/nucleo/dmem_we
wave -radix hex     /tb_red_neuronal/dut/nucleo/resultado_w
wave -radix unsigned /tb_red_neuronal/dut/nucleo/rd_w
wave -radix unsigned /tb_red_neuronal/ciclos
wave -radix unsigned /tb_red_neuronal/instret

run -all
