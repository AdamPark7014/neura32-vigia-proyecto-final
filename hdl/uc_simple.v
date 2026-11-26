// unidad de control
module uc_simple (
	input wire    clk,
	input wire    rst,
	input wire [6:0] opcode,
	input wire [2:0] funct3,
	input wire    take,
	input wire    div_ready,
	// salidas de control
	output reg     reg_write,
	output reg     mem_read,
	output reg     mem_write,
	output reg     alu_src,
	output reg [1:0] result_src,
	output reg     pc_en,
	output reg [1:0] pc_src,
	output reg     ir_en,
	output reg     aluout_en,
	output reg     mdr_en,
	output reg     addr_phase,
	output reg     div_start,
	output reg     div_sel,
	output reg     halted,
	output reg     illegal,
	output reg [2:0] alu_op,
	output wire [3:0] state
	);

	// opcodes
	localparam OP_R1 = 7'b0110011,  // tipo R, tabla 1
	OP_R2 = 7'b0111011,  // tipo R, tabla 2
	OP_R3 = 7'b1011011,  // tipo R, tabla 3
	OP_I1 = 7'b0010011,  // inmediato, tabla 1
	OP_I2 = 7'b0011011,  // inmediato, tabla 2
	OP_LOAD = 7'b0000011,  // carga de memoria
	OP_STORE  = 7'b0100011,  // guarda en memoria
	OP_BRANCH  = 7'b1100011,  // saltos condicionales
	OP_LUI = 7'b0110111,  // carga inmediato alto
	OP_JAL = 7'b1101111,  // salto con enlace
	OP_JALR = 7'b1100111,  // salto a registro
	OP_SYSTEM = 7'b1110011;  // detiene el procesador

	// estados
	localparam FETCH = 4'b0000,  // busca instrucción
	DECODE = 4'b0001,  // decodifica instrucción
	EXEC_R = 4'b0010,  // ejecuta en ALU
	EXEC_DIV= 4'b0011,  // espera la división
	EXEC_BR = 4'b0100,  // evalúa el salto
	JUMP_WAIT=4'b0101,  // espera tras salto
	MEM_ADDR= 4'b0110,  // calcula la dirección
	MEM_READ= 4'b0111,  // lee la memoria
	MEM_WRITE=4'b1000,  // escribe la memoria
	WRITEBACK=4'b1001,  // escribe el registro
	HALT = 4'b1010;  // procesador detenido

	reg [3:0] current_state, next_state;
	assign state = current_state;

	// division
	wire is_div = (opcode == OP_R3) && (funct3[2:1] == 2'b00);

	// registro de estado
	always @(posedge clk or negedge rst) begin
		if (!rst)
			current_state <= FETCH;
		else
			current_state <= next_state;
	end

	// logica de siguiente estado
	always @(*) begin
		case(current_state)
			FETCH:   next_state = DECODE;
			DECODE: begin
				case(opcode)
					OP_R1:   next_state = EXEC_R;
					OP_R2:   next_state = EXEC_R;
					OP_R3: begin
						if (is_div) next_state = EXEC_DIV;
						else        next_state = EXEC_R;
					end
					OP_I1:   next_state = EXEC_R;
					OP_I2:   next_state = EXEC_R;
					OP_LUI:  next_state = EXEC_R;
					OP_LOAD:  next_state = MEM_ADDR;
					OP_STORE: next_state = MEM_ADDR;
					OP_BRANCH: next_state = EXEC_BR;
					OP_JAL:  next_state = EXEC_BR;
					OP_JALR: next_state = EXEC_BR;
					OP_SYSTEM: next_state = HALT;
					default:  next_state = FETCH;
				endcase
			end
			EXEC_R:  next_state = WRITEBACK;
			EXEC_DIV: next_state = div_ready ? WRITEBACK : EXEC_DIV;
			EXEC_BR: begin
				if (opcode == OP_BRANCH) next_state = take ? JUMP_WAIT : FETCH;
				else                     next_state = JUMP_WAIT;
			end
			JUMP_WAIT: next_state = FETCH;
			MEM_ADDR: next_state = (opcode == OP_LOAD) ? MEM_READ : MEM_WRITE;
			MEM_READ: next_state = WRITEBACK;
			MEM_WRITE: next_state = FETCH;
			WRITEBACK: next_state = FETCH;
			HALT:    next_state = HALT;
			default:  next_state = FETCH;
		endcase
	end

	// salidas
	always @(*) begin
		// valores por defecto
		reg_write = 0;
		mem_read  = 0;
		mem_write = 0;
		alu_src  = 0;
		result_src = 2'd0;
		pc_en   = 0;
		pc_src  = 2'd0;
		ir_en   = 0;
		aluout_en = 0;
		mdr_en  = 0;
		addr_phase = 0;
		div_start = 0;
		div_sel  = 0;
		halted  = 0;
		illegal = 0;
		alu_op   = funct3;

		case(current_state)
			FETCH: begin
				pc_en = 1;
				ir_en = 1;
			end
			DECODE: begin
				div_start = is_div;
				case(opcode)
					OP_R1, OP_R2, OP_R3, OP_I1, OP_I2, OP_LUI, OP_LOAD, OP_STORE,
					OP_BRANCH, OP_JAL, OP_JALR, OP_SYSTEM: illegal = 0;
					default: illegal = 1;
				endcase
			end
			EXEC_R: begin
				alu_src = (opcode == OP_I1) || (opcode == OP_I2) || (opcode == OP_LUI);
				aluout_en = 1;
			end
			EXEC_DIV: begin
				div_sel = 1;
				aluout_en = div_ready;
			end
			EXEC_BR: begin
				case(opcode)
					OP_BRANCH: begin
						pc_en = take;
						pc_src = 2'd1;
					end
					OP_JAL: begin
						pc_en = 1;
						pc_src = 2'd1;
						reg_write = 1;
						result_src = 2'd2;
					end
					default: begin
						alu_src = 1;
						pc_en = 1;
						pc_src = 2'd2;
						reg_write = 1;
						result_src = 2'd2;
					end
				endcase
			end
			JUMP_WAIT: begin
			end
			MEM_ADDR: begin
				alu_src = 1;
				aluout_en = 1;
				addr_phase = 1;
			end
			MEM_READ: begin
				mem_read  = 1;
				mdr_en = 1;
			end
			MEM_WRITE: begin
				mem_write = 1;
			end
			WRITEBACK: begin
				reg_write = 1;
				result_src = (opcode == OP_LOAD) ? 2'd1 : 2'd0;
			end
			HALT: begin
				halted = 1;
			end
			default: ;
		endcase
	end
endmodule
