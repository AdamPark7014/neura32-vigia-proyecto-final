set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_red_neuronal

wave -radix hex      /tb_red_neuronal/sw
wave -radix hex      /tb_red_neuronal/leds
wave -radix hex      /tb_red_neuronal/hex
wave                 /tb_red_neuronal/fin

# el procesador
wave -radix unsigned /tb_red_neuronal/dut/cpu/state
wave -radix hex      /tb_red_neuronal/dut/cpu/pc
wave -radix hex      /tb_red_neuronal/dut/cpu/instr
wave -radix bin      /tb_red_neuronal/dut/cpu/opcode
wave -radix bin      /tb_red_neuronal/dut/cpu/funct3
wave -radix hex      /tb_red_neuronal/dut/cpu/rdata1
wave -radix hex      /tb_red_neuronal/dut/cpu/alu_b
wave -radix hex      /tb_red_neuronal/dut/cpu/alu_result
wave -radix hex      /tb_red_neuronal/dut/cpu/aluout
wave -radix hex      /tb_red_neuronal/dut/cpu/mdr
wave                 /tb_red_neuronal/dut/cpu/reg_write
wave -radix unsigned /tb_red_neuronal/dut/cpu/rd
wave -radix hex      /tb_red_neuronal/dut/cpu/wdata

run -all
