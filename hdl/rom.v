//Memoria de programa (la ROM de la clase)
//Las instrucciones vienen de un archivo de texto en hexadecimal, una por renglon.
//Lo nuevo: un puerto de carga. El procesador no puede escribirla; solo el cargador de
//programas (jtag_loader) escribe, con el procesador detenido, para ponerle otro programa
//desde la PC sin volver a compilar.
module rom #(
	parameter addr_width = 5,
	parameter data_width = 32,
	parameter INIT_FILE = "programa_ab_c.txt"
	) (
	input 					        clk,
	input 	   [addr_width-1:0] addr,
	output reg [data_width-1:0] data_out,
	//cargador de programas
	input 					        load_we,
	input 	   [addr_width-1:0] load_addr,
	input 	   [data_width-1:0] load_data
	);

	// [31:25] funct7 | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:7] rd | [6:0] opcode
	reg [data_width-1:0] rom_data [0:(2**addr_width-1)];

	initial begin
		$readmemh(INIT_FILE, rom_data);
	end

	always @(posedge clk) begin
		if (load_we)
			rom_data[load_addr] <= load_data;
		data_out <= rom_data[addr];
	end

endmodule
