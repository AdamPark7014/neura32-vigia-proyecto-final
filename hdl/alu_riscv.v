//ALU de 32 bits (la de la clase, ampliada)
//Entra el opcode de la instruccion (su tipo) y alu_op, que es el funct3 de la instruccion:
//siempre 3 bits, 8 operaciones por opcode. Para tener mas de 8 operaciones del tipo R no se
//alarga alu_op: se agregan opcodes del mismo tipo (OP_R1, OP_R2, OP_R3), y lo mismo con las
//que llevan inmediato (OP_I1, OP_I2).
//
//  | funct7 (7) | rs2 (5) | rs1 (5) | funct3 (3) | rd (5) | opcode (7) |   = 32 bits
//
//  alu_op   OP_R1 / OP_I1      OP_R2 / OP_I2      OP_R3             OP_BRANCH
//   000     add                sub                divu (divisor)    beq   A == B
//   001     mul                slt                remu (divisor)    bne   A != B
//   010     and                sltu               cpop
//   011     or                 sra                abs
//   100     xor                xnor               sgt               blt   A <  B
//   101     nota  (~A)         min                clamp             bge   A >= B
//   110     sll                minu                                 bltu  sin signo
//   111     srl                max                                  bgeu  sin signo
//
//OP_R1 es la tabla original de la clase (el programa (a + b) * c corre igual).
//En cargas, almacenamientos y jalr la ALU suma (direccion); en lui deja pasar B.
module alu_riscv (
	input wire [31:0] A, B,
	input wire [6:0] opcode, //de 7 bits para RiscV, Tipo de instruccion
	input wire [2:0] alu_op, //La operacion a realizar (funct3) ej. Add, sub, xor, sll, srl
	output reg	[31:0] result,
	output wire C, O, Z, N
	);

	// Codigos de operacion de la ALU (OP_R1 y OP_I1)
	localparam	ALU_ADD = 3'b000;
	localparam	ALU_MUL = 3'b001;
	localparam	ALU_AND = 3'b010;
	localparam	ALU_OR = 3'b011;
	localparam	ALU_XOR = 3'b100;
	localparam	ALU_NOTA = 3'b101;
	localparam	ALU_SLL = 3'b110;
	localparam	ALU_SRL = 3'b111;

	// Codigos de operacion de la ALU (OP_R2 y OP_I2)
	localparam	ALU_SUB = 3'b000;
	localparam	ALU_SLT = 3'b001;
	localparam	ALU_SLTU = 3'b010;
	localparam	ALU_SRA = 3'b011;
	localparam	ALU_XNOR = 3'b100;
	localparam	ALU_MIN = 3'b101;
	localparam	ALU_MINU = 3'b110;
	localparam	ALU_MAX = 3'b111;

	// Codigos de operacion de la ALU (OP_R3)
	localparam	ALU_DIVU = 3'b000;  //la hace el divisor (divider.v)
	localparam	ALU_REMU = 3'b001;  //la hace el divisor
	localparam	ALU_CPOP = 3'b010;
	localparam	ALU_ABS = 3'b011;
	localparam	ALU_SGT = 3'b100;
	localparam	ALU_CLAMP = 3'b101;

	// Comparaciones de los saltos (OP_BRANCH)
	localparam	ALU_BEQ = 3'b000;
	localparam	ALU_BNE = 3'b001;
	localparam	ALU_BLT = 3'b100;
	localparam	ALU_BGE = 3'b101;
	localparam	ALU_BLTU = 3'b110;
	localparam	ALU_BGEU = 3'b111;

	// OPCODES
	localparam OP_R1	= 7'b0110011;  //tipo R, tabla 1 (la de la clase)
	localparam OP_R2	= 7'b0111011;  //tipo R, tabla 2
	localparam OP_R3	= 7'b1011011;  //tipo R, tabla 3
	localparam OP_I1	= 7'b0010011;  //tipo I, tabla 1 con inmediato
	localparam OP_I2	= 7'b0011011;  //tipo I, tabla 2 con inmediato
	localparam OP_LOAD	= 7'b0000011;
	localparam OP_STORE	= 7'b0100011;
	localparam OP_BRANCH	= 7'b1100011;
	localparam OP_LUI	= 7'b0110111;
	localparam OP_JALR	= 7'b1100111;

	wire [32:0] sum_ext = {1'b0,A} + {1'b0,B};
	wire [32:0] sub_ext = {1'b0,A} - {1'b0,B};
	wire [31:0] sum = sum_ext[31:0];
	wire [31:0] sub = sub_ext[31:0];
	// Overflow con signo
	wire ovf_add = (~A[31] & ~B[31] & sum[31]) | (A[31] & B[31] & ~sum[31]);
	wire ovf_sub = (~A[31] & B[31] & sub[31]) | (A[31] & ~B[31] & ~sub[31]);
	// Corrimientos
	wire [4:0] shamt = B[4:0];
	wire [31:0] sll_out = A << shamt;
	wire [31:0] srl_out = A >> shamt;
	wire [31:0] sra_out = $signed(A) >>> shamt;

	// Multiplicador combinacional (32 bits bajos)
	wire [31:0] mul_out = A * B;

	// Comparaciones
	wire lt_s = ($signed(A) < $signed(B));  //menor con signo
	wire lt_u = (A < B);                    //menor sin signo
	wire eq = (A == B);

	// Conteo de unos en arbol: se suman los bits por parejas, luego las parejas por
	// cuartetos, los cuartetos por bytes, los bytes por mitades y las dos mitades.
	// Es la operacion de la red neuronal binaria (xnor + cpop).
	wire [31:0] c1 = (A & 32'h55555555) + ((A >> 1) & 32'h55555555);
	wire [31:0] c2 = (c1 & 32'h33333333) + ((c1 >> 2) & 32'h33333333);
	wire [31:0] c4 = (c2 & 32'h0F0F0F0F) + ((c2 >> 4) & 32'h0F0F0F0F);
	wire [31:0] c8 = (c4 & 32'h00FF00FF) + ((c4 >> 8) & 32'h00FF00FF);
	wire [31:0] cpop_out = (c8 & 32'h0000FFFF) + (c8 >> 16);

	// Guardar Carrys
	reg carry_flag, ovf_flag;

	// Ahora si, empieza la ALU: primero el opcode y adentro la operacion
	always @(*) begin
		result = 32'b0;
		carry_flag = 1'b0;
		ovf_flag = 1'b0;

		case(opcode)
			//---------------- tabla 1: la de la clase ----------------
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

			//---------------- tabla 2 ----------------
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

			//---------------- tabla 3 ----------------
			OP_R3: begin
				case(alu_op)
					ALU_DIVU: result = 32'b0;  //el cociente lo entrega el divisor
					ALU_REMU: result = 32'b0;  //el resto lo entrega el divisor
					ALU_CPOP: result = cpop_out;
					ALU_ABS: result = A[31] ? (~A + 32'd1) : A;
					ALU_SGT: result = ($signed(A) > $signed(B)) ? 32'd1 : 32'd0;
					ALU_CLAMP: result = A[31] ? 32'd0 : (($signed(A) > $signed(B)) ? B : A);  //A limitado entre 0 y B
					default: result = 32'b0;
				endcase
			end

			//---------------- saltos condicionales: 1 si se cumple ----------------
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

			//---------------- direcciones: base + desplazamiento ----------------
			OP_LOAD, OP_STORE, OP_JALR: begin
				result = sum;
			end

			//---------------- lui: pasa el valor de B tal cual ----------------
			OP_LUI: begin
				result = B;
			end

			default: result = 32'b0;
		endcase
	end

	// Banderas
	assign Z = (result == 32'b0);
	assign N = result[31];
	assign C = carry_flag;
	assign O = ovf_flag;
endmodule
