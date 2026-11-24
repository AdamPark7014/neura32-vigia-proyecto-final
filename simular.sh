#!/bin/bash
IV=/c/iverilog/bin
HDL="hdl/pipo_register.v hdl/rom.v hdl/ram.v hdl/regfile.v hdl/decoder.v hdl/alu_riscv.v hdl/divider.v hdl/uc_simple.v hdl/riscv_neura.v hdl/perifericos.v hdl/jtag_loader.v hdl/vision/memoria_doble_puerto.v hdl/vision/ram_dp.v hdl/vision/ram_2clk.v hdl/vision/cam_capture.v hdl/vision/block_avg.v hdl/vision/fondo_mascara.v hdl/vision/vga_sincronia.v hdl/vision/vga_draw.v hdl/vision/pc_view.v hdl/vision/registros_vision.v hdl/vision/vision_vigia.v hdl/soc_neura32.v tb/sim_jtag.v"
mkdir -p build tb/salidas
cp hdl/vision/font8x16.txt font8x16.txt
for n in 1 2 3 4; do
  $IV/iverilog -g2005 -Wno-timescale -I hdl -I prog -Pgenerar_rom.PROGRAMA=$n -s generar_rom -o build/generar_rom.vvp prog/generador_programa.v tb/generar_rom.v 2>&1 | grep -iE "error" | head -5
  $IV/vvp -n build/generar_rom.vvp | grep -v finish
done
BANCOS="$@"
[ -z "$BANCOS" ] && BANCOS="tb_programa_ab_c tb_uc_simple tb_prueba_isa tb_red_neuronal tb_cargador tb_vision tb_vigia"
for tb in $BANCOS; do
  extra=""; [ -f tb/modelo_ov7670.v ] && extra="tb/modelo_ov7670.v"
  $IV/iverilog -g2005 -Wall -Wno-sensitivity-entire-array -Wno-timescale -I hdl -I prog -s $tb -o build/$tb.vvp $HDL prog/generador_programa.v $extra tb/$tb.v 2>&1 | grep -v "sensitive to all\|@\* is sensitive\|implicitly \|inherits" | grep -iE "error|warning" | head -20
  echo "== $tb (compilacion ${PIPESTATUS[0]})"
  $IV/vvp -n build/$tb.vvp > build/$tb.log 2>&1
  grep -E "PRUEBAS|TIEMPO AGOTADO" build/$tb.log | tail -1
done
