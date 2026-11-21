module pipo_register #(
	parameter nbits = 32, parameter initial1 = 32'h00000000)
	(input clk, rst, en,
	input [nbits-1:0] d,
	output [nbits-1:0] q
	);

	reg [nbits-1:0] qaux;

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			qaux <= initial1;
		end else
		begin
			if(en) begin
				qaux <= d;
			end else
			begin
				qaux <= qaux;
			end
		end
	end

	assign q = qaux;

endmodule
