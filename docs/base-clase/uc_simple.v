module uc_simple (

input wire    clk,

input wire    rst,

input wire [6:0] opcode,

input wire [2:0] funct3,

// salidas de control

output reg     reg_write,

output reg     mem_read,

output reg     mem_write,

output reg     alu_src,   // 0: rs2, 1: imm_i

output reg     result_src, // 0: ALU, 1: RAM

output reg     pc_en,    // habilita avance del PC

output reg [3:0] alu_op

);



// opcodes (7 bits)

localparam OP_R = 7'b0110011,

OP_I = 7'b0010011,

OP_LOAD = 7'b0000011,

OP_STORE  = 7'b0100011,

OP_BRANCH  = 7'b1100011;



// ALU ops (deben coincidir con alu_riscv.v)

localparam ALU_ADD = 4'b0000,

ALU_MUL = 4'b1001;



// Estados (fases del procesador)

localparam FETCH = 3'b000,

DECODE = 3'b001,

EXEC_R = 3'b010,

EXEC_MUL= 3'b011,  // NUEVO

MEM_ADDR= 3'b100,

MEM_READ= 3'b101,

MEM_WRITE=3'b110,

WRITEBACK=3'b111;



reg [2:0] current_state, next_state;



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

OP_R: begin

if (funct3 == 3'b001) next_state = EXEC_MUL; // mul

else         next_state = EXEC_R;  // add, etc.

end

OP_I:   next_state = EXEC_R;  // addi

OP_LOAD:  next_state = MEM_ADDR;

OP_STORE: next_state = MEM_ADDR;

OP_BRANCH: next_state = EXEC_R;  // simplificado

default:  next_state = FETCH;

endcase

end

EXEC_R:  next_state = WRITEBACK;

EXEC_MUL: next_state = WRITEBACK;

MEM_ADDR: next_state = (opcode == OP_LOAD) ? MEM_READ : MEM_WRITE;

MEM_READ: next_state = WRITEBACK;

MEM_WRITE: next_state = FETCH;

WRITEBACK: next_state = FETCH;

default:  next_state = FETCH;

endcase

end





always @(*) begin

// valores por defecto

reg_write = 0;

mem_read  = 0;

mem_write = 0;

alu_src  = 0;

result_src = 0;

pc_en   = 0;

alu_op   = ALU_ADD;



case(current_state)

FETCH: begin

pc_en = 1;  // el PC avanza al terminar FETCH

end

DECODE: begin

// sin salidas activas; aqui el decoder ya partio la instruccion

end

EXEC_R: begin

alu_src = (opcode == OP_I);  // addi usa inmediato

alu_op = ALU_ADD;

end

EXEC_MUL: begin

alu_op = ALU_MUL;

end

MEM_ADDR: begin

alu_src = 1;   // calcula direccion con inmediato

alu_op = ALU_ADD;

end

MEM_READ: begin

mem_read  = 1;

result_src = 1;  // el dato leido va a write-back

end

MEM_WRITE: begin

mem_write = 1;

end

WRITEBACK: begin

reg_write = 1;

end

default: ;

endcase

end

endmodule