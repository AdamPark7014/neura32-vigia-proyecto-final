set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_programa_ab_c

wave                 /tb_programa_ab_c/clk
wave                 /tb_programa_ab_c/rst
wave -radix unsigned /tb_programa_ab_c/dut/state
wave -radix hex      /tb_programa_ab_c/dut/pc
wave -radix hex      /tb_programa_ab_c/dut/instr
wave -radix bin      /tb_programa_ab_c/dut/opcode
wave -radix bin      /tb_programa_ab_c/dut/funct3
wave -radix bin      /tb_programa_ab_c/dut/alu_op
wave -radix unsigned /tb_programa_ab_c/dut/rdata1
wave -radix unsigned /tb_programa_ab_c/dut/alu_b
wave -radix unsigned /tb_programa_ab_c/dut/alu_result
wave -radix unsigned /tb_programa_ab_c/dut/aluout
wave                 /tb_programa_ab_c/dut/pc_en
wave                 /tb_programa_ab_c/dut/ir_en
wave                 /tb_programa_ab_c/dut/reg_write
wave -radix unsigned /tb_programa_ab_c/dut/rd
wave -radix unsigned /tb_programa_ab_c/result_out

run -all
