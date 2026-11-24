// RAM de dos relojes
module ram_2clk #(
	parameter addr_width = 15,
	parameter data_width = 4,
	parameter depth = 19200
)(
	input clk_wr,
	input we,
	input [addr_width-1:0] addr_wr,
	input [data_width-1:0] data_in,
	input clk_rd,
	input [addr_width-1:0] addr_rd,
	output reg [data_width-1:0] data_out
);

	// declaracion de la memoria
	(* ramstyle = "M9K" *) reg [data_width-1:0] ram_data [0:depth-1];

	// proceso para escritura
	always @(posedge clk_wr) begin
		if (we)
			ram_data[addr_wr] <= data_in;
	end

	// proceso para lectura
	always @(posedge clk_rd) begin
		data_out <= ram_data[addr_rd];
	end

endmodule
