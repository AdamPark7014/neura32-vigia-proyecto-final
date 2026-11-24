// RAM de doble puerto
module ram_dp #(
	parameter addr_width = 17,
	parameter data_width = 12,
	parameter depth = 76800
)(
	input clk,
	input we,
	input [addr_width-1:0] addr_wr,
	input [data_width-1:0] data_in,
	input [addr_width-1:0] addr_rd,
	output reg [data_width-1:0] data_out
);

	// declaracion de la memoria
	(* ramstyle = "M9K" *) reg [data_width-1:0] ram_data [0:depth-1];

	// proceso para escritura
	always @(posedge clk) begin
		if (we)
			ram_data[addr_wr] <= data_in;
	end

	// proceso para lectura
	always @(posedge clk) begin
		data_out <= ram_data[addr_rd];
	end

endmodule
