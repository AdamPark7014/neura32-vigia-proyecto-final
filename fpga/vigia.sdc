# Reloj de 50 MHz de la DE10-Lite (MAX10_CLK1_50, PIN_P11) y el de 25 MHz que sale del divisor
create_clock -name CLK50 -period 20.000 [get_ports {MAX10_CLK1_50}]
create_generated_clock -name CLK25 -source [get_ports {MAX10_CLK1_50}] -divide_by 2 [get_registers {clk25}]
derive_clock_uncertainty
# Entradas asincronas (interruptores, botones, camara): pasan por sincronizadores
set_false_path -from [get_ports {SW[*] KEY[*] GPIO[*]}]
# Salidas lentas o registradas (LED, displays, VGA, camara)
set_false_path -to [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] VGA_* GPIO[*]}]
# El reloj del JTAG no tiene relacion con los del sistema: solo se cruzan en memorias de dos relojes
# y en registros que pasan por sincronizadores
set_clock_groups -asynchronous -group {altera_reserved_tck} -group {CLK50 CLK25}
