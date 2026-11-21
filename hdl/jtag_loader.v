//Cargador de programas por JTAG
//Con el mismo cable USB-Blaster la PC le pone otro programa al procesador sin volver
//a compilar el proyecto: detiene el procesador, escribe las instrucciones en la memoria
//de programa y lo suelta (fpga/cargar_programa.tcl).
//
//Registro de instruccion virtual (2 bits):
//  0 = nada
//  1 = escribir una palabra: registro de datos de 44 bits {dato[31:0], direccion[11:0]}
//  2 = control: registro de datos de 1 bit, 1 = procesador detenido (en reinicio)
//  3 = estado: 34 bits {leds[9:0], hex[23:0]} para ver desde la PC que el programa corre
//En todos entra y sale primero el bit menos significativo.
module jtag_loader (
	input clk,   //reloj del sistema
	input rst,   //activo en bajo
	//hacia la memoria de programa
	output reg load_we,
	output wire [11:0] load_addr,
	output wire [31:0] load_data,
	//hacia el procesador
	output reg halt,
	//lo que se deja ver a la PC
	input [9:0] leds,
	input [23:0] hex
);

	wire tck, tdi, tdo, v_cdr, v_sdr, v_udr;
	wire [1:0] v_ir;

	sld_virtual_jtag #(
		.sld_auto_instance_index("NO"),
		.sld_instance_index(1),
		.sld_ir_width(2)
	) jtag_virtual (
		.tck(tck), .tdi(tdi), .tdo(tdo), .ir_in(v_ir), .ir_out(2'b00),
		.virtual_state_cdr(v_cdr), .virtual_state_sdr(v_sdr), .virtual_state_udr(v_udr)
	);

	localparam IR_WRITE = 2'd1, IR_CTRL = 2'd2, IR_STATE = 2'd3;

	//================ lado del JTAG (tck) ================
	reg [43:0] word;      //{dato, direccion}
	reg halt_t;           //orden de detener
	reg write_t;          //cambia de valor en cada palabra nueva
	reg [33:0] state;
	reg bypass;

	always @(posedge tck)
	begin
		bypass <= tdi;
		if(v_ir == IR_WRITE)
		begin
			if(v_sdr)
			begin
				word <= {tdi, word[43:1]};
			end
			if(v_udr)
			begin
				write_t <= ~write_t;
			end
		end
		if(v_ir == IR_CTRL)
		begin
			if(v_sdr)
			begin
				halt_t <= tdi;
			end
		end
		if(v_ir == IR_STATE)
		begin
			if(v_cdr)
			begin
				state <= {leds, hex};
			end else
			begin
				if(v_sdr)
				begin
					state <= {1'b0, state[33:1]};
				end
			end
		end
	end

	assign tdo = (v_ir == IR_WRITE) ? word[0] :
	             (v_ir == IR_CTRL) ? halt_t :
	             (v_ir == IR_STATE) ? state[0] : bypass;

	//================ lado del sistema (clk) ================
	//La palabra ya esta quieta cuando write_t cambia; se pasa el cambio por tres
	//flip-flops y se escribe un ciclo.
	reg [2:0] write_ff;
	reg [1:0] halt_ff;

	assign load_addr = word[11:0];
	assign load_data = word[43:12];

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			write_ff <= 3'b000;
			halt_ff <= 2'b00;
			load_we <= 1'b0;
			halt <= 1'b0;
		end else
		begin
			write_ff <= {write_ff[1:0], write_t};
			halt_ff <= {halt_ff[0], halt_t};
			load_we <= write_ff[2] ^ write_ff[1];
			halt <= halt_ff[1];
		end
	end

	//en simulacion los registros del lado del JTAG empiezan en 0
	initial begin
		word = 44'd0;
		halt_t = 1'b0;
		write_t = 1'b0;
	end

endmodule
