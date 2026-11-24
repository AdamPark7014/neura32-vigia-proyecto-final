// ROM
module rom #(
	parameter addr_width = 5,
	parameter data_width = 32,
	parameter INIT_FILE = "programa_ab_c.txt"
	) (
	input 					        clk,
	input 	   [addr_width-1:0] addr,
	output reg [data_width-1:0] data_out,
	// cargador
	input 					        load_we,
	input 	   [addr_width-1:0] load_addr,
	input 	   [data_width-1:0] load_data
	);

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
