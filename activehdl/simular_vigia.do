# Simula el sistema completo (tb_vigia): camara OV7670 simulada, perro y persona.
# Son unos 9 millones de ciclos: en la Student Edition (velocidad limitada) tarda mucho;
# para el resultado completo conviene simular.ps1 (Icarus). Aqui sirve para ver ondas.
# La consola debe terminar con "PRUEBAS: 25  ERRORES: 0".

set PROY "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32"
cd "$PROY"

asim +access +r tb_vigia

# --- camara ---
wave                /tb_vigia/cam_vsync
wave                /tb_vigia/cam_href
wave                /tb_vigia/cam_pclk
wave -radix hex     /tb_vigia/cam_d
wave                /tb_vigia/cam_sioc
wave                /tb_vigia/cam_siod
# --- vision ---
wave -radix hex     /tb_vigia/dut/vision/prom_dato
wave                /tb_vigia/dut/vision/listo
wave -radix unsigned /tb_vigia/dut/vision/cuadros
wave -radix unsigned /tb_vigia/dut/vision/pixeles_fg
# --- procesador ---
wave -radix hex     /tb_vigia/dut/nucleo/pc_f
wave -radix hex     /tb_vigia/dut/nucleo/instr_d
wave -radix hex     /tb_vigia/dut/nucleo/instr_e
wave -radix hex     /tb_vigia/dut/nucleo/resultado_ex
wave                /tb_vigia/dut/nucleo/parar_e
wave -radix hex     /tb_vigia/dut/nucleo/dmem_dir
# --- salidas ---
wave -radix hex     /tb_vigia/hex
wave -radix hex     /tb_vigia/leds
wave                /tb_vigia/vga_hs
wave                /tb_vigia/vga_vs

run -all
