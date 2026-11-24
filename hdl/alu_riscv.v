// ALU
module alu_riscv (
	input wire [31:0] A, B,
	input wire [6:0] opcode,
	input wire [2:0] alu_op,
	output reg	[31:0] result,
	output wire C, O, Z, N
	);

	// tabla 1
	localparam	ALU_ADD = 3'b000;
	localparam	ALU_MUL = 3'b001;
	localparam	ALU_AND = 3'b010;
	localparam	ALU_OR = 3'b011;
	localparam	ALU_XOR = 3'b100;
	localparam	ALU_NOTA = 3'b101;
	localparam	ALU_SLL = 3'b110;
	localparam	ALU_SRL = 3'b111;

	// tabla 2
	localparam	ALU_SUB = 3'b000;
	localparam	ALU_SLT = 3'b001;
	localparam	ALU_SLTU = 3'b010;
	localparam	ALU_SRA = 3'b011;
	localparam	ALU_XNOR = 3'b100;
	localparam	ALU_MIN = 3'b101;
	localparam	ALU_MINU = 3'b110;
	localparam	ALU_MAX = 3'b111;

	// tabla 3
	localparam	ALU_DIVU = 3'b000;
	localparam	ALU_REMU = 3'b001;
	localparam	ALU_CPOP = 3'b010;
	localparam	ALU_ABS = 3'b011;
	localparam	ALU_SGT = 3'b100;
	localparam	ALU_CLAMP = 3'b101;

	// saltos
	localparam	ALU_BEQ = 3'b000;
	localparam	ALU_BNE = 3'b001;
	localparam	ALU_BLT = 3'b100;
	localparam	ALU_BGE = 3'b101;
	localparam	ALU_BLTU = 3'b110;
	localparam	ALU_BGEU = 3'b111;

	// OPCODES
	localparam OP_R1	= 7'b0110011;
	localparam OP_R2	= 7'b0111011;
	localparam OP_R3	= 7'b1011011;
	localparam OP_I1	= 7'b0010011;
	localparam OP_I2	= 7'b0011011;
	localparam OP_LOAD	= 7'b0000011;
	localparam OP_STORE	= 7'b0100011;
	localparam OP_BRANCH	= 7'b1100011;
	localparam OP_LUI	= 7'b0110111;
	localparam OP_JALR	= 7'b1100111;

	wire [32:0] sum_ext = {1'b0,A} + {1'b0,B};
	wire [32:0] sub_ext = {1'b0,A} - {1'b0,B};
	wire [31:0] sum = sum_ext[31:0];
	wire [31:0] sub = sub_ext[31:0];
	// overflow con signo
	wire ovf_add = (~A[31] & ~B[31] & sum[31]) | (A[31] & B[31] & ~sum[31]);
	wire ovf_sub = (~A[31] & B[31] & sub[31]) | (A[31] & ~B[31] & ~sub[31]);
	// corrimientos
	wire [4:0] shamt = B[4:0];
	wire [31:0] sll_out = A << shamt;
	wire [31:0] srl_out = A >> shamt;
	wire [31:0] sra_out = $signed(A) >>> shamt;

	// multiplicador combinacional
	wire [31:0] mul_out = A * B;

	// comparaciones
	wire lt_s = ($signed(A) < $signed(B));
	wire lt_u = (A < B);
	wire eq = (A == B);

	// conteo de unos
	wire [31:0] c1 = (A & 32'h55555555) + ((A >> 1) & 32'h55555555);
	wire [31:0] c2 = (c1 & 32'h33333333) + ((c1 >> 2) & 32'h33333333);
	wire [31:0] c4 = (c2 & 32'h0F0F0F0F) + ((c2 >> 4) & 32'h0F0F0F0F);
	wire [31:0] c8 = (c4 & 32'h00FF00FF) + ((c4 >> 8) & 32'h00FF00FF);
	wire [31:0] cpop_out = (c8 & 32'h0000FFFF) + (c8 >> 16);

	// acarreo
	reg carry_flag, ovf_flag;

	// operaciones
	always @(*) begin
		result = 32'b0;
		carry_flag = 1'b0;
		ovf_flag = 1'b0;

		case(opcode)
			// tabla 1
			OP_R1, OP_I1: begin
				case(alu_op)
					ALU_ADD: begin result = sum; carry_flag = sum_ext[32]; ovf_flag = ovf_add; end
					ALU_MUL: result = mul_out;
					ALU_AND: result = A & B;
					ALU_OR: result = A | B;
					ALU_XOR: result = A ^ B;
					ALU_NOTA: result = ~A ;
					ALU_SLL: result = sll_out;
					ALU_SRL: result = srl_out;
					default: result = 32'b0;
				endcase
			end

			// tabla 2
			OP_R2, OP_I2: begin
				case(alu_op)
					ALU_SUB: begin result = sub; carry_flag = sub_ext[32]; ovf_flag = ovf_sub; end
					ALU_SLT: result = lt_s ? 32'd1 : 32'd0;
					ALU_SLTU: result = lt_u ? 32'd1 : 32'd0;
					ALU_SRA: result = sra_out;
					ALU_XNOR: result = ~(A ^ B);
					ALU_MIN: result = lt_s ? A : B;
					ALU_MINU: result = lt_u ? A : B;
					ALU_MAX: result = lt_s ? B : A;
					default: result = 32'b0;
				endcase
			end

			// tabla 3
			OP_R3: begin
				case(alu_op)
					ALU_DIVU: result = 32'b0;
					ALU_REMU: result = 32'b0;
					ALU_CPOP: result = cpop_out;
					ALU_ABS: result = A[31] ? (~A + 32'd1) : A;
					ALU_SGT: result = ($signed(A) > $signed(B)) ? 32'd1 : 32'd0;
					ALU_CLAMP: result = A[31] ? 32'd0 : (($signed(A) > $signed(B)) ? B : A);
					default: result = 32'b0;
				endcase
			end

			// saltos
			OP_BRANCH: begin
				case(alu_op)
					ALU_BEQ: result = eq ? 32'd1 : 32'd0;
					ALU_BNE: result = eq ? 32'd0 : 32'd1;
					ALU_BLT: result = lt_s ? 32'd1 : 32'd0;
					ALU_BGE: result = lt_s ? 32'd0 : 32'd1;
					ALU_BLTU: result = lt_u ? 32'd1 : 32'd0;
					ALU_BGEU: result = lt_u ? 32'd0 : 32'd1;
					default: result = 32'b0;
				endcase
			end

			// direcciones
			OP_LOAD, OP_STORE, OP_JALR: begin
				result = sum;
			end

			// lui
			OP_LUI: begin
				result = B;
			end

			default: result = 32'b0;
		endcase
	end

	// banderas
	assign Z = (result == 32'b0);
	assign N = result[31];
	assign C = carry_flag;
	assign O = ovf_flag;
endmodule
