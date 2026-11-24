create_clock -name CLK50 -period 20.000 [get_ports {MAX10_CLK1_50}]
create_generated_clock -name CLK25 -source [get_ports {MAX10_CLK1_50}] -divide_by 2 [get_registers {clk25}]
derive_clock_uncertainty
# entradas asincronas
set_false_path -from [get_ports {SW[*] KEY[*] GPIO[*]}]
# salidas lentas o registradas
set_false_path -to [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] VGA_* GPIO[*]}]
set_clock_groups -asynchronous -group {altera_reserved_tck} -group {CLK50 CLK25}
