# Simula el sistema completo (tb_vigia): camara OV7670 simulada, camara movida, perro y persona.
# Son unos 45 millones de ciclos del reloj de 50 MHz: en la Student Edition (velocidad limitada)
# tarda mucho; para el resultado completo conviene simular.ps1 (Icarus). Aqui sirve para ver ondas.

set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_vigia

# --- camara ---
wave                 /tb_vigia/cam_vsync
wave                 /tb_vigia/cam_href
wave                 /tb_vigia/cam_pclk
wave -radix hex      /tb_vigia/cam_d
wave                 /tb_vigia/cam_sioc
wave                 /tb_vigia/cam_siod
# --- vision ---
wave                 /tb_vigia/dut/regs_vision/vis_listo
wave -radix unsigned /tb_vigia/dut/regs_vision/vis_cuadros
wave -radix unsigned /tb_vigia/dut/regs_vision/vis_pixeles_fg
wave                 /tb_vigia/dut/regs_vision/vis_aprender
# --- procesador ---
wave -radix unsigned /tb_vigia/dut/cpu/state
wave -radix hex      /tb_vigia/dut/cpu/pc
wave -radix hex      /tb_vigia/dut/cpu/instr
wave -radix hex      /tb_vigia/dut/cpu/alu_result
wave -radix hex      /tb_vigia/dut/cpu/aluout
wave                 /tb_vigia/dut/cpu/mem_write
# --- salidas ---
wave -radix hex      /tb_vigia/hex
wave -radix hex      /tb_vigia/leds
wave -radix unsigned /tb_vigia/dut/regs_vision/letrero
wave -radix hex      /tb_vigia/dut/regs_vision/colores
wave                 /tb_vigia/vga_hs
wave                 /tb_vigia/vga_vs

run -all
