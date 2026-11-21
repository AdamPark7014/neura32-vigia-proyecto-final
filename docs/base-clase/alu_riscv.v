module alu_riscv (

input wire [31:0] A, B,

input wire [6:0] opcode, //de 7 bits para RiscV, Tipo de instruccion

input wire [2:0] alu_op, //LA operacion a realiza ej. Add, sub, xor, sll, srl

output reg	[31:0] result,

output wire C, O, Z, N

);

// Codigos de operacion de la ALU

localparam	ALU_ADD = 3'b000;

localparam	ALU_MUL = 3'b001;

localparam	ALU_AND = 3'b010;

localparam	ALU_OR = 3'b011;

localparam	ALU_XOR = 3'b100;

localparam	ALU_NOTA = 3'b101;

localparam	ALU_SLL = 3'b110;

localparam	ALU_SRL = 3'b111;

localparam	ALU_PASSB = 3'b000; //pasa el valor de B tal cual



// OPCODES

localparam OP_R	= 7'b0110011;

localparam OP_I	= 7'b0010011;

localparam OP_B	= 7'b1100011;



wire [32:0] sum_ext = {1'b0,A} + {1'b0,B};

wire [32:0] sub_ext = {1'b0,A} - {1'b0,B};

wire [31:0] sum = sum_ext[31:0];

wire [31:0] sub = sub_ext[31:0];

// Overflow con signo

wire ovf_add = (~A[31] & ~B[31] & sum[31]) | (A[31] & B[31] & ~sum[31]);

wire ovf_sub = (~A[31] & ~B[31] & sub[31]) | (A[31] & B[31] & ~sub[31]);

// Corrimientos

wire [4:0] shamt = B[4:0];

wire [31:0] sll_out = A << shamt;

wire [31:0] srl_out = A >> shamt;



// NUEVO: multiplicador combinacional (32 bits bajos)

wire [31:0] mul_out = A * B;



// Guardar Carrys

reg carry_flag, ovf_flag;

// Ahora si, despues de tanto cotorreo, empieza la ALU

always @(*) begin

result = 32'b0;

carry_flag = 1'b0;

ovf_flag = 1'b0;



case(alu_op)

ALU_ADD: begin result = sum; carry_flag = sum_ext[32]; ovf_flag = ovf_add; end

ALU_AND: result = A & B;

ALU_OR: result = A | B;

ALU_XOR: result = A ^ B;

ALU_NOTA: result = ~A ;

ALU_SLL: result = sll_out;

ALU_SRL: result = srl_out;

ALU_PASSB: result = B;

ALU_MUL: result = mul_out;  // aquí esta lo nuevo

default: result = 32'b0;

endcase

end

// Banderas

assign Z = (result == 32'b0);

assign N = result[31];

assign C = carry_flag;

assign O = ovf_flag;

endmodule