module riscv_ab_c #(

parameter A_INIT = 32'd7,

parameter B_INIT = 32'd5,

parameter C_INIT = 32'd5

)(

input wire    clk,

input wire    rst,

output wire [31:0] result_out

);



// ---- PC ----

wire [31:0] pc, pc_next;

wire    pc_en;

assign pc_next = pc + 32'd4;



pipo_register #(.nbits(32), .initial1(32'h00000000)) PC ( .clk(clk), .rst(rst), .en(pc_en), .d(pc_next), .q(pc));



// ---- ROM de instrucciones ----

wire [31:0] instr_raw, instr;

rom #(.addr_width(4), .data_width(32), .INIT_FILE("programa_ab_c.txt")) IMEM (.clk(clk), .addr(pc[5:2]), .data_out(instr_raw));



// Registro de instruccion: congela la instruccion durante toda la ejecucion

wire ir_en = (pc_en);  // carga nueva instr solo cuando el PC avanza

pipo_register #(.nbits(32), .initial1(32'h00000000)) IR (.clk(clk), .rst(rst), .en(ir_en),.d(instr_raw), .q(instr));



// ---- Decoder ----

wire [6:0] opcode;

wire [4:0] rd, rs1, rs2;

wire [2:0] funct3;

wire [31:0] imm_i;

decoder DEC (.instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2),.funct3(funct3), .imm_i(imm_i));



// ---- Unidad de control (FSM) ----

wire    reg_write, mem_read, mem_write, alu_src, result_src;

wire [2:0] alu_op;

uc_simple UC (.clk(clk), .rst(rst),.opcode(opcode), .funct3(funct3),.reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),.alu_src(alu_src), .result_src(result_src),

.pc_en(pc_en), .alu_op(alu_op)

);



// ---- Register file ----

wire [31:0] rdata1, rdata2, wdata;

regfile #(.A_INIT(A_INIT), .B_INIT(B_INIT), .C_INIT(C_INIT)) RF (

.clk(clk), .we(reg_write),

.rs1(rs1), .rs2(rs2), .rd(rd),

.wdata(wdata), .rdata1(rdata1), .rdata2(rdata2)

);



// ---- ALU ----

wire [31:0] alu_b = alu_src ? imm_i : rdata2;

wire [31:0] alu_result;

wire C, O, Z, N;

alu_riscv ALU (

.A(rdata1), .B(alu_b),

.opcode(opcode), .alu_op(alu_op),

.result(alu_result), .C(C), .O(O), .Z(Z), .N(N)

);



// ---- RAM de datos ----

wire [31:0] ram_rdata;

ram #(.addr_width(4), .data_width(32)) DMEM (

.clk(clk), .we(mem_write),

.addr(alu_result[5:2]),

.data_in(rdata2),

.data_out(ram_rdata)

);



// ---- Write-back mux ----

assign wdata   = result_src ? ram_rdata : alu_result;

assign result_out = wdata;

endmodule