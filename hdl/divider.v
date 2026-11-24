// divisor
module divider (
	input clk, rst,
	input start,
	input [31:0] a, b,
	output reg [31:0] q,
	output reg [31:0] r,
	output reg ready
);

	reg [31:0] divisor;
	reg [5:0] count;
	reg busy;
	// resta de prueba
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
					// bit del cociente
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
