//Ram de n bits para el tamano de palabra (la de la clase)
//En el procesador se usan cuatro de 8 bits, una por cada byte de la palabra, para poder
//guardar un byte, media palabra o la palabra completa (sb, sh, sw).
module ram #(
	parameter addr_width = 4,  //2^4 direcciones
	parameter data_width= 6
)(
	input clk,
	input we,  //we=0: modo lectura, we = 1, modo escritura
	input [addr_width-1:0] addr,
	input [data_width-1:0] data_in,
	output reg [data_width-1:0] data_out
);

	//declaracion de la memoria
	(* ramstyle = "M9K" *) reg [data_width-1:0] ram_data [0:(2**addr_width)-1];

	integer i;
	initial begin
		for (i=0;i<(2**addr_width); i = i+1)
			ram_data[i] = {data_width{1'b0}}; //inicializacion en 0
	end

	//proceso para escritura / lectura
	always @(posedge clk) begin
		if (we)
			ram_data[addr] <= data_in;
		data_out <= ram_data[addr];
	end

endmodule
