// banco de registros
module regfile #(
	parameter A_INIT = 32'd0,
	parameter B_INIT = 32'd0,
	parameter C_INIT = 32'd0
	)(
	input wire    clk,
	input wire    we,
	input wire [4:0] rs1, rs2, rd,
	input wire [31:0] wdata,
	output wire [31:0] rdata1, rdata2
	);

	reg [31:0] regs [0:31];
	integer i;

	initial begin
		for (i=0;i<32;i=i+1) regs[i] = 32'b0;
			regs[1] = A_INIT;
			regs[2] = B_INIT;
			regs[3] = C_INIT;
	end

	assign rdata1 = (rs1==0) ? 32'b0 : regs[rs1];
	assign rdata2 = (rs2==0) ? 32'b0 : regs[rs2];

	// escritura
	always @(posedge clk)
		if (we && rd!=0) regs[rd] <= wdata;

endmodule
