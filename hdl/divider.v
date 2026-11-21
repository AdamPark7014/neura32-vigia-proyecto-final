//Divisor sin signo de 32 bits, un bit del cociente por ciclo (32 ciclos)
//La division no cabe en un ciclo como la suma: la unidad de control espera en el estado
//EXEC_DIV hasta que ready vale 1. Si b es 0 el cociente sale en unos y el resto es a.
module divider (
	input clk, rst,
	input start,
	input [31:0] a, b,
	output reg [31:0] q,   //cociente
	output reg [31:0] r,   //resto
	output reg ready
);

	reg [31:0] divisor;
	reg [5:0] count;
	reg busy;
	//resto parcial con un bit mas para la resta de prueba
	wire [32:0] trial = {r[30:0], q[31]} - {1'b0, divisor};

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			q <= 32'd0;
			r <= 32'd0;
			divisor <= 32'd0;
			count <= 6'd0;
			busy <= 1'b0;
			ready <= 1'b0;
		end else
		begin
			if(start)
			begin
				q <= a;
				r <= 32'd0;
				divisor <= b;
				count <= 6'd32;
				busy <= 1'b1;
				ready <= 1'b0;
			end else
			begin
				if(busy)
				begin
					//se baja un bit del dividendo; si el divisor cabe, se resta y el bit del cociente es 1
					if(!trial[32])
					begin
						r <= trial[31:0];
						q <= {q[30:0], 1'b1};
					end else
					begin
						r <= {r[30:0], q[31]};
						q <= {q[30:0], 1'b0};
					end
					count <= count - 6'd1;
					if(count == 6'd1)
					begin
						busy <= 1'b0;
						ready <= 1'b1;
					end
				end
			end
		end
	end

endmodule
