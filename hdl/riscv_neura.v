// procesador
module riscv_neura #(
	parameter A_INIT = 32'd0,
	parameter B_INIT = 32'd0,
	parameter C_INIT = 32'd0,
	parameter INIT_FILE = "programa_vigia.txt",
	parameter rom_addr_width = 12,
	parameter ram_addr_width = 12
	)(
	input wire    clk,
	input wire    rst,
	output wire [31:0] result_out,
	// E/S en memoria
	output wire [31:0] io_addr_pre,
	output wire [31:0] io_addr,
	output wire [31:0] io_wdata,
	output wire    io_we,
	output wire    io_re,
	input wire [31:0] io_rdata,
	// cargador
	input wire    load_we,
	input wire [rom_addr_width-1:0] load_addr,
	input wire [31:0] load_data,
	// estado
	output wire    halted,
	output wire    illegal,
	output reg [31:0] cycles,
	output reg [31:0] instrs
	);

	// opcodes
	localparam OP_LOAD = 7'b0000011,  // carga de memoria
	OP_STORE  = 7'b0100011,  // guarda en memoria
	OP_LUI = 7'b0110111,  // carga inmediato alto
	OP_JAL = 7'b1101111;  // salto con enlace

	// senales de control
	wire    reg_write, mem_read, mem_write, alu_src;
	wire    pc_en, ir_en, aluout_en, mdr_en, addr_phase, div_start, div_sel;
	wire [1:0] result_src, pc_src;
	wire [2:0] alu_op;
	wire [3:0] state;

	// PC
	wire [31:0] pc, pc_instr;
	reg  [31:0] pc_next;
	wire [31:0] alu_result;
	wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
	wire [6:0] opcode;

	// destino del salto
	wire [31:0] pc_target = pc_instr + ((opcode == OP_JAL) ? imm_j : imm_b);

	always @(*) begin
		case(pc_src)
			2'd1: pc_next = pc_target;
			2'd2: pc_next = {alu_result[31:1], 1'b0};
			default: pc_next = pc + 32'd4;
		endcase
	end

	pipo_register #(.nbits(32), .initial1(32'h00000000)) PC ( .clk(clk), .rst(rst), .en(pc_en), .d(pc_next), .q(pc));

	// memoria de programa
	wire [31:0] instr_raw, instr;
	wire rom_data_read = addr_phase && (opcode == OP_LOAD) && (alu_result[31:28] == 4'h0);
	wire [rom_addr_width-1:0] rom_addr = rom_data_read ? alu_result[rom_addr_width+1:2] : pc[rom_addr_width+1:2];

	rom #(.addr_width(rom_addr_width), .data_width(32), .INIT_FILE(INIT_FILE)) IMEM (.clk(clk), .addr(rom_addr), .data_out(instr_raw),
	.load_we(load_we), .load_addr(load_addr), .load_data(load_data));

	// registro de instruccion
	pipo_register #(.nbits(32), .initial1(32'h00000000)) IR (.clk(clk), .rst(rst), .en(ir_en),.d(instr_raw), .q(instr));

	// PC de la instruccion
	pipo_register #(.nbits(32), .initial1(32'h00000000)) PCI (.clk(clk), .rst(rst), .en(ir_en),.d(pc), .q(pc_instr));

	// decodificador
	wire [4:0] rd, rs1, rs2;
	wire [2:0] funct3;
	decoder DEC (.instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2),.funct3(funct3),
	.imm_i(imm_i), .imm_s(imm_s), .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j));

	// unidad de control
	wire div_ready;
	uc_simple UC (.clk(clk), .rst(rst),.opcode(opcode), .funct3(funct3), .take(alu_result[0]), .div_ready(div_ready),
	.reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),.alu_src(alu_src), .result_src(result_src),
	.pc_en(pc_en), .pc_src(pc_src), .ir_en(ir_en), .aluout_en(aluout_en), .mdr_en(mdr_en), .addr_phase(addr_phase),
	.div_start(div_start), .div_sel(div_sel), .halted(halted), .illegal(illegal), .alu_op(alu_op), .state(state)
	);

	// banco de registros
	wire [31:0] rdata1, rdata2;
	reg  [31:0] wdata;
	regfile #(.A_INIT(A_INIT), .B_INIT(B_INIT), .C_INIT(C_INIT)) RF (
	.clk(clk), .we(reg_write),
	.rs1(rs1), .rs2(rs2), .rd(rd),
	.wdata(wdata), .rdata1(rdata1), .rdata2(rdata2)
	);

	// ALU
	wire [31:0] imm = (opcode == OP_STORE) ? imm_s : (opcode == OP_LUI) ? imm_u : imm_i;
	wire [31:0] alu_b = alu_src ? imm : rdata2;
	wire C, O, Z, N;
	alu_riscv ALU (
	.A(rdata1), .B(alu_b),
	.opcode(opcode), .alu_op(alu_op),
	.result(alu_result), .C(C), .O(O), .Z(Z), .N(N)
	);

	// divisor
	wire [31:0] div_q, div_r;
	divider DIV (.clk(clk), .rst(rst), .start(div_start), .a(rdata1), .b(rdata2), .q(div_q), .r(div_r), .ready(div_ready));
	wire [31:0] div_result = funct3[0] ? div_r : div_q;

	// registro de la ALU
	wire [31:0] aluout;
	pipo_register #(.nbits(32), .initial1(32'h00000000)) ALUOUT (.clk(clk), .rst(rst), .en(aluout_en),
	.d(div_sel ? div_result : alu_result), .q(aluout));

	// decodificacion
	wire is_rom = (aluout[31:28] == 4'h0);
	wire is_ram = (aluout[31:28] == 4'h1);
	wire is_io = ~is_rom & ~is_ram;

	// dato a guardar
	reg [31:0] store_data;
	reg [3:0] be;
	always @(*) begin
		case(funct3)
			3'b000: begin
				store_data = {rdata2[7:0], rdata2[7:0], rdata2[7:0], rdata2[7:0]};
				case(aluout[1:0])
					2'd0: be = 4'b0001;
					2'd1: be = 4'b0010;
					2'd2: be = 4'b0100;
					default: be = 4'b1000;
				endcase
			end
			3'b001: begin
				store_data = {rdata2[15:0], rdata2[15:0]};
				be = aluout[1] ? 4'b1100 : 4'b0011;
			end
			default: begin
				store_data = rdata2;
				be = 4'b1111;
			end
		endcase
	end

	// RAM de datos
	wire [ram_addr_width-1:0] ram_addr = mem_write ? aluout[ram_addr_width+1:2] : alu_result[ram_addr_width+1:2];
	wire ram_we = mem_write & is_ram;
	wire [31:0] ram_rdata;
	ram #(.addr_width(ram_addr_width), .data_width(8)) DMEM0 (.clk(clk), .we(ram_we & be[0]), .addr(ram_addr), .data_in(store_data[7:0]), .data_out(ram_rdata[7:0]));
	ram #(.addr_width(ram_addr_width), .data_width(8)) DMEM1 (.clk(clk), .we(ram_we & be[1]), .addr(ram_addr), .data_in(store_data[15:8]), .data_out(ram_rdata[15:8]));
	ram #(.addr_width(ram_addr_width), .data_width(8)) DMEM2 (.clk(clk), .we(ram_we & be[2]), .addr(ram_addr), .data_in(store_data[23:16]), .data_out(ram_rdata[23:16]));
	ram #(.addr_width(ram_addr_width), .data_width(8)) DMEM3 (.clk(clk), .we(ram_we & be[3]), .addr(ram_addr), .data_in(store_data[31:24]), .data_out(ram_rdata[31:24]));

	// entradas y salidas
	assign io_addr_pre = alu_result;
	assign io_addr = aluout;
	assign io_wdata = store_data;
	assign io_we = mem_write & is_io;
	assign io_re = mem_read & is_io;

	// dato leido
	wire [31:0] mem_rdata = is_rom ? instr_raw : (is_ram ? ram_rdata : io_rdata);
	wire [31:0] mdr;
	pipo_register #(.nbits(32), .initial1(32'h00000000)) MDR (.clk(clk), .rst(rst), .en(mdr_en), .d(mem_rdata), .q(mdr));

	// cargas con signo
	reg [7:0] load_byte;
	always @(*) begin
		case(aluout[1:0])
			2'd0: load_byte = mdr[7:0];
			2'd1: load_byte = mdr[15:8];
			2'd2: load_byte = mdr[23:16];
			default: load_byte = mdr[31:24];
		endcase
	end
	wire [15:0] load_half = aluout[1] ? mdr[31:16] : mdr[15:0];

	reg [31:0] load_value;
	always @(*) begin
		case(funct3)
			3'b000: load_value = {{24{load_byte[7]}}, load_byte};
			3'b001: load_value = {{16{load_half[15]}}, load_half};
			3'b100: load_value = {24'b0, load_byte};
			3'b101: load_value = {16'b0, load_half};
			default: load_value = mdr;
		endcase
	end

	// write-back
	always @(*) begin
		case(result_src)
			2'd1: wdata = load_value;
			2'd2: wdata = pc;
			default: wdata = aluout;
		endcase
	end
	assign result_out = wdata;

	// contadores
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			cycles <= 32'd0;
			instrs <= 32'd0;
		end else begin
			cycles <= cycles + 32'd1;
			if (ir_en) instrs <= instrs + 32'd1;
		end
	end

	// solo simulacion
	// synthesis translate_off
	function [31:0] palabra;
		input integer k;
		palabra = {DMEM3.ram_data[k], DMEM2.ram_data[k], DMEM1.ram_data[k], DMEM0.ram_data[k]};
	endfunction

	function [7:0] octeto;
		input integer d;
		case (d % 4)
			0: octeto = DMEM0.ram_data[d / 4];
			1: octeto = DMEM1.ram_data[d / 4];
			2: octeto = DMEM2.ram_data[d / 4];
			default: octeto = DMEM3.ram_data[d / 4];
		endcase
	endfunction
	// synthesis translate_on
endmodule
