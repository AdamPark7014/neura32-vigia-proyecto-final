//Unidad de control (la maquina de estados de la clase, ampliada)
//Cada instruccion pasa por varias fases: FETCH -> DECODE -> ejecucion -> (memoria) -> WRITEBACK.
//Las salidas dependen solo del estado y de la instruccion que esta en el registro IR.
//
//Lo que se le agrego a la uc_simple original:
//  * mas opcodes: OP_R2, OP_R3, OP_I2, lui, jal, jalr y los seis saltos condicionales
//  * EXEC_DIV: espera al divisor (divu y remu tardan 32 ciclos)
//  * EXEC_BR:  saltos; si el PC cambia, JUMP_WAIT deja un ciclo para leer la memoria de programa
//  * HALT:     ecall detiene el procesador
//  * el resultado de la ALU y el dato de la memoria se guardan en registros (aluout_en, mdr_en),
//    asi la escritura al banco de registros usa valores que ya no cambian
//alu_op es siempre el funct3 de la instruccion (3 bits); la tabla la escoge el opcode en la ALU.
module uc_simple (
	input wire    clk,
	input wire    rst,
	input wire [6:0] opcode,
	input wire [2:0] funct3,
	input wire    take,      // la ALU dice que el salto condicional se cumple
	input wire    div_ready, // el divisor termino
	// salidas de control
	output reg     reg_write,
	output reg     mem_read,
	output reg     mem_write,
	output reg     alu_src,   // 0: rs2, 1: inmediato
	output reg [1:0] result_src, // 0: ALU, 1: memoria, 2: PC (direccion de regreso)
	output reg     pc_en,    // habilita la carga del PC
	output reg [1:0] pc_src,   // 0: PC + 4, 1: PC de la instruccion + inmediato, 2: resultado de la ALU (jalr)
	output reg     ir_en,    // carga el registro de instruccion
	output reg     aluout_en, // guarda el resultado de la ALU (o del divisor)
	output reg     mdr_en,   // guarda el dato leido de la memoria
	output reg     addr_phase, // la ALU esta calculando la direccion de memoria
	output reg     div_start, // arranca el divisor
	output reg     div_sel,  // el resultado viene del divisor
	output reg     halted,   // el programa termino (ecall)
	output reg     illegal,  // el opcode no existe
	output reg [2:0] alu_op,
	output wire [3:0] state
	);

	// opcodes (7 bits)
	localparam OP_R1 = 7'b0110011,
	OP_R2 = 7'b0111011,
	OP_R3 = 7'b1011011,
	OP_I1 = 7'b0010011,
	OP_I2 = 7'b0011011,
	OP_LOAD = 7'b0000011,
	OP_STORE  = 7'b0100011,
	OP_BRANCH  = 7'b1100011,
	OP_LUI = 7'b0110111,
	OP_JAL = 7'b1101111,
	OP_JALR = 7'b1100111,
	OP_SYSTEM = 7'b1110011;

	// Estados (fases del procesador)
	localparam FETCH = 4'b0000,
	DECODE = 4'b0001,
	EXEC_R = 4'b0010,
	EXEC_DIV= 4'b0011,  // NUEVO: division de varios ciclos
	EXEC_BR = 4'b0100,  // NUEVO: saltos
	JUMP_WAIT=4'b0101,  // NUEVO: un ciclo para leer la instruccion del destino
	MEM_ADDR= 4'b0110,
	MEM_READ= 4'b0111,
	MEM_WRITE=4'b1000,
	WRITEBACK=4'b1001,
	HALT = 4'b1010;     // NUEVO: fin del programa

	reg [3:0] current_state, next_state;
	assign state = current_state;

	// divu y remu son las operaciones 000 y 001 de OP_R3
	wire is_div = (opcode == OP_R3) && (funct3[2:1] == 2'b00);

	// ---- Registro de estado ----
	always @(posedge clk or negedge rst) begin
		if (!rst)
			current_state <= FETCH;
		else
			current_state <= next_state;
	end

	// ---- Logica de siguiente estado ----
	always @(*) begin
		case(current_state)
			FETCH:   next_state = DECODE;
			DECODE: begin
				case(opcode)
					OP_R1:   next_state = EXEC_R;
					OP_R2:   next_state = EXEC_R;
					OP_R3: begin
						if (is_div) next_state = EXEC_DIV; // divu, remu
						else        next_state = EXEC_R;   // cpop, abs, sgt, clamp
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

	// ---- Salidas ----
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
		alu_op   = funct3;   // la operacion es el funct3 de la instruccion

		case(current_state)
			FETCH: begin
				pc_en = 1;  // el PC avanza al terminar FETCH
				ir_en = 1;  // y la instruccion queda en el registro IR
			end
			DECODE: begin
				// aqui el decoder ya partio la instruccion
				div_start = is_div;
				case(opcode)
					OP_R1, OP_R2, OP_R3, OP_I1, OP_I2, OP_LUI, OP_LOAD, OP_STORE,
					OP_BRANCH, OP_JAL, OP_JALR, OP_SYSTEM: illegal = 0;
					default: illegal = 1;
				endcase
			end
			EXEC_R: begin
				alu_src = (opcode == OP_I1) || (opcode == OP_I2) || (opcode == OP_LUI);  // usan inmediato
				aluout_en = 1;
			end
			EXEC_DIV: begin
				div_sel = 1;
				aluout_en = div_ready;
			end
			EXEC_BR: begin
				case(opcode)
					OP_BRANCH: begin
						pc_en = take;   // la ALU compara rs1 con rs2
						pc_src = 2'd1;
					end
					OP_JAL: begin
						pc_en = 1;
						pc_src = 2'd1;
						reg_write = 1;  // guarda la direccion de regreso
						result_src = 2'd2;
					end
					default: begin  // jalr
						alu_src = 1;
						pc_en = 1;
						pc_src = 2'd2;
						reg_write = 1;
						result_src = 2'd2;
					end
				endcase
			end
			JUMP_WAIT: begin
				// la memoria de programa lee la instruccion del destino
			end
			MEM_ADDR: begin
				alu_src = 1;   // calcula direccion con inmediato
				aluout_en = 1;
				addr_phase = 1;
			end
			MEM_READ: begin
				mem_read  = 1;
				mdr_en = 1;   // el dato leido se guarda para el write-back
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
