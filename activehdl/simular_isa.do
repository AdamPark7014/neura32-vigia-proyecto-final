set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_prueba_isa

wave -radix unsigned /tb_prueba_isa/dut/cpu/state
wave -radix hex      /tb_prueba_isa/dut/cpu/pc
wave -radix hex      /tb_prueba_isa/dut/cpu/instr
wave -radix bin      /tb_prueba_isa/dut/cpu/opcode
wave -radix bin      /tb_prueba_isa/dut/cpu/funct3
wave -radix hex      /tb_prueba_isa/dut/cpu/rdata1
wave -radix hex      /tb_prueba_isa/dut/cpu/alu_b
wave -radix hex      /tb_prueba_isa/dut/cpu/alu_result
wave                 /tb_prueba_isa/dut/cpu/C
wave                 /tb_prueba_isa/dut/cpu/O
wave                 /tb_prueba_isa/dut/cpu/Z
wave                 /tb_prueba_isa/dut/cpu/N
wave -radix hex      /tb_prueba_isa/dut/cpu/aluout
wave -radix hex      /tb_prueba_isa/dut/cpu/mdr
wave                 /tb_prueba_isa/dut/cpu/pc_en
wave -radix unsigned /tb_prueba_isa/dut/cpu/pc_src
wave                 /tb_prueba_isa/dut/cpu/mem_write
wave -radix bin      /tb_prueba_isa/dut/cpu/be
wave -radix hex      /tb_prueba_isa/dut/cpu/store_data
wave                 /tb_prueba_isa/dut/cpu/div_ready
wave                 /tb_prueba_isa/dut/cpu/reg_write
wave -radix unsigned /tb_prueba_isa/dut/cpu/rd
wave -radix hex      /tb_prueba_isa/dut/cpu/wdata
wave                 /tb_prueba_isa/fin

run -all
