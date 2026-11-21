module decoder (
	input wire [31:0] instr,
	output wire [6:0] opcode,
	output wire [4:0] rd, rs1, rs2,
	output wire [2:0] funct3,
	output wire [31:0] imm_i
);

	assign opcode = instr[6:0];
	assign rd = instr[11:7];
	assign funct3 = instr[14:12];
	assign rs1 = instr[19:15];
	assign rs2 = instr[24:20];
	assign imm_i = {{20{instr[31]}}, instr[31:20]};

endmodule
