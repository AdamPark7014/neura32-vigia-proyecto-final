//Decodificador: parte la instruccion en sus campos (el de la clase)
// [31:25] funct7 | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:7] rd | [6:0] opcode
//Lo nuevo: los otros inmediatos, que salen de los mismos bits acomodados de otra forma:
//  imm_i  tipo I (addi, cargas, jalr)      imm_s  tipo S (almacenamientos)
//  imm_b  tipo B (saltos condicionales)    imm_u  tipo U (lui)     imm_j  tipo J (jal)
module decoder (
	input wire [31:0] instr,
	output wire [6:0] opcode,
	output wire [4:0] rd, rs1, rs2,
	output wire [2:0] funct3,
	output wire [31:0] imm_i,
	output wire [31:0] imm_s,
	output wire [31:0] imm_b,
	output wire [31:0] imm_u,
	output wire [31:0] imm_j
	);

	assign opcode = instr[6:0];
	assign rd = instr[11:7];
	assign funct3 = instr[14:12];
	assign rs1 = instr[19:15];
	assign rs2 = instr[24:20];
	assign imm_i = {{20{instr[31]}}, instr[31:20]};
	assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
	assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
	assign imm_u = {instr[31:12], 12'b0};
	assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
endmodule
