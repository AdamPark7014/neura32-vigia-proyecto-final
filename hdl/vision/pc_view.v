//Vista en la PC: manda el video por el cable USB-Blaster (JTAG virtual)
//Sirve para ver la imagen en la computadora cuando no hay monitor VGA.
//
//El JTAG pasa unos 2 Mbit/s, asi que se manda una imagen reducida a la mitad
//(width/2 x height/2) con 4 bits de brillo por pixel y el color de cada bloque de 2 x 2
//(4 bits de U y 4 de V), y ademas ENTRELAZADA: en cada corrimiento sale un campo
//(los renglones pares o los nones). Asi llegan ~25 campos por segundo.
//
//Hay DOS juegos de memorias (A y B): la camara escribe en uno y la PC lee el otro,
//que guarda el ultimo cuadro completo; la imagen nunca llega partida.
//
//Registro de instruccion virtual (2 bits):
//  0 = nada
//  1 = campo de video: cabecera de 16 bits {8'hA5, 7'd0, campo}, luego el brillo
//      (4 bits por pixel) y luego el color (8 bits por bloque), renglones del campo
//  2 = mascara de la deteccion (1 bit por celda)
//  3 = datos: recuadros, colores, zona, linea y contadores (meta)
//En todos sale primero el bit menos significativo.
module pc_view #(
	parameter width = 320,
	parameter height = 240,
	parameter meta_bits = 384
)(
	input clk,   //25 MHz
	input rst,   //activo en bajo
	//pixeles que entrega cam_capture
	input pix_valid,
	input [8:0] pix_x,
	input [7:0] pix_y,
	input [7:0] pix_lum,
	input uv_valid,
	input [7:0] uv_x,
	input [6:0] uv_y,
	input [7:0] uv_u,
	input [7:0] uv_v,
	input frame_done,
	//datos que dibuja la PC
	input [meta_bits-1:0] meta,
	//lectura de la copia de la mascara (memoria de dos relojes, se lee con tck)
	output wire tck,
	output wire [12:0] msk_addr,
	input msk_data,
	output wire held   //hay un cuadro guardado en espera de la PC
);

	//tamano de la imagen reducida
	localparam pw = width / 2;
	localparam ph = height / 2;
	localparam cw = width / 4;
	localparam ch = height / 4;
	localparam y_items = pw * (ph / 2);    //pixeles de brillo en un campo
	localparam uv_items = cw * (ch / 2);   //bloques de color en un campo

	//================ lado de la camara (clk) ================
	reg bank_wr;     //0: la camara escribe en A, 1: en B
	reg writing;     //hay un cuadro en curso de escritura
	reg holding;     //cuadro completo guardado, en espera de la PC
	assign held = holding;

	//brillo: 1 de cada 2 pixeles y lineas, de 8 a 4 bits con tramado 2 x 2
	wire [8:0] px = {1'b0, pix_x[8:1]};
	wire [7:0] py = {1'b0, pix_y[7:1]};
	wire y_take = pix_valid & writing & ~pix_x[0] & ~pix_y[0];
	wire [14:0] y_addr_wr = py * pw + px;

	reg [3:0] dither;   //umbral segun la posicion
	always @(*)
	begin
		case({py[0], px[0]})
			2'b00: dither = 4'd0;
			2'b01: dither = 4'd8;
			2'b10: dither = 4'd12;
			default: dither = 4'd4;
		endcase
	end
	wire [8:0] lum_sum = {1'b0, pix_lum} + {5'd0, dither};
	wire [3:0] lum4 = lum_sum[8] ? 4'hF : lum_sum[7:4];

	//color: 1 de cada 2 muestras y lineas, 4 bits de U y 4 de V
	wire [7:0] cx = {1'b0, uv_x[7:1]};
	wire [6:0] cy = {1'b0, uv_y[6:1]};
	wire uv_take = uv_valid & writing & ~uv_x[0] & ~uv_y[0];
	wire [12:0] uv_addr_wr = cy * cw + cx;

	//================ memorias ================
	wire [14:0] y_ptr_addr;
	wire [12:0] uv_ptr_addr;
	wire [3:0] ya_q, yb_q;
	wire [7:0] uva_q, uvb_q;

	ram_2clk #(.addr_width(15), .data_width(4), .depth(pw * ph)) ram_ya (
		.clk_wr(clk), .we(y_take & ~bank_wr), .addr_wr(y_addr_wr), .data_in(lum4),
		.clk_rd(tck), .addr_rd(y_ptr_addr), .data_out(ya_q));
	ram_2clk #(.addr_width(15), .data_width(4), .depth(pw * ph)) ram_yb (
		.clk_wr(clk), .we(y_take & bank_wr), .addr_wr(y_addr_wr), .data_in(lum4),
		.clk_rd(tck), .addr_rd(y_ptr_addr), .data_out(yb_q));
	ram_2clk #(.addr_width(13), .data_width(8), .depth(cw * ch)) ram_uva (
		.clk_wr(clk), .we(uv_take & ~bank_wr), .addr_wr(uv_addr_wr), .data_in({uv_u[7:4], uv_v[7:4]}),
		.clk_rd(tck), .addr_rd(uv_ptr_addr), .data_out(uva_q));
	ram_2clk #(.addr_width(13), .data_width(8), .depth(cw * ch)) ram_uvb (
		.clk_wr(clk), .we(uv_take & bank_wr), .addr_wr(uv_addr_wr), .data_in({uv_u[7:4], uv_v[7:4]}),
		.clk_rd(tck), .addr_rd(uv_ptr_addr), .data_out(uvb_q));

	//================ lado de la PC (tck) ================
	wire tdi, tdo, v_cdr, v_sdr, v_udr;
	wire [1:0] v_ir;

	sld_virtual_jtag #(
		.sld_auto_instance_index("NO"),
		.sld_instance_index(0),
		.sld_ir_width(2)
	) jtag_virtual (
		.tck(tck), .tdi(tdi), .tdo(tdo), .ir_in(v_ir), .ir_out(2'b00),
		.virtual_state_cdr(v_cdr), .virtual_state_sdr(v_sdr), .virtual_state_udr(v_udr)
	);

	localparam IR_VIDEO = 2'd1, IR_MASK = 2'd2, IR_META = 2'd3;
	localparam PH_HEAD = 2'd0, PH_LUM = 2'd1, PH_COLOR = 2'd2;

	reg reading;       //la PC esta bajando un campo
	reg field;         //0: renglones pares, 1: nones
	reg [1:0] bank_t;  //bank_wr visto desde tck
	reg bank_rd;       //juego que se lee: el que NO escribe la camara
	reg [1:0] phase;
	reg head_second;
	reg [7:0] shift;   //registro de corrimiento
	reg [2:0] nbit, last_bit;
	reg [14:0] y_ptr;  //siguiente pixel de brillo que se va a cargar
	reg [12:0] uv_ptr; //siguiente bloque de color
	reg [8:0] y_col;
	reg [7:0] uv_col;
	reg [14:0] items;
	reg bypass;

	assign y_ptr_addr = y_ptr;
	assign uv_ptr_addr = uv_ptr;
	wire [3:0] y_q = bank_rd ? yb_q : ya_q;
	wire [7:0] uv_q = bank_rd ? uvb_q : uva_q;

	//al terminar un renglon se salta el del otro campo
	wire [14:0] y_next = (y_col == pw - 1) ? y_ptr + pw + 15'd1 : y_ptr + 15'd1;
	wire [12:0] uv_next = (uv_col == cw - 1) ? uv_ptr + cw + 13'd1 : uv_ptr + 13'd1;

	//mascara: un bit por corrimiento. La salida es el registro de la propia memoria:
	//el puntero va una celda adelante (en reposo esta en la celda 0).
	reg [12:0] msk_ptr;
	assign msk_addr = msk_ptr;

	//datos (meta)
	reg [meta_bits-1:0] meta_shift;

	always @(posedge tck)
	begin
		bypass <= tdi;
		bank_t <= {bank_t[0], bank_wr};
		if(!reading)
		begin
			bank_rd <= ~bank_t[1];
		end

		//---- campo de video ----
		if((v_ir == IR_VIDEO) && v_cdr)
		begin
			reading <= 1'b1;
			phase <= PH_HEAD;
			head_second <= 1'b0;
			shift <= {7'd0, field};   //byte bajo de la cabecera
			nbit <= 3'd0;
			last_bit <= 3'd7;
			y_ptr <= field ? pw : 15'd0;
			uv_ptr <= field ? cw : 13'd0;
			y_col <= 9'd0;
			uv_col <= 8'd0;
			items <= 15'd0;
		end else
		begin
			if((v_ir == IR_VIDEO) && v_sdr)
			begin
				if(nbit == last_bit)
				begin
					nbit <= 3'd0;
					case(phase)
						PH_HEAD:
						begin
							if(!head_second)
							begin
								shift <= 8'hA5;   //byte alto de la cabecera
								head_second <= 1'b1;
							end else
							begin
								shift <= {4'd0, y_q};
								last_bit <= 3'd3;
								phase <= PH_LUM;
								y_ptr <= y_next;
								y_col <= (y_col == pw - 1) ? 9'd0 : y_col + 9'd1;
								items <= 15'd1;
							end
						end
						PH_LUM:
						begin
							if(items == y_items)
							begin
								shift <= uv_q;
								last_bit <= 3'd7;
								phase <= PH_COLOR;
								uv_ptr <= uv_next;
								uv_col <= (uv_col == cw - 1) ? 8'd0 : uv_col + 8'd1;
							end else
							begin
								shift <= {4'd0, y_q};
								y_ptr <= y_next;
								y_col <= (y_col == pw - 1) ? 9'd0 : y_col + 9'd1;
								items <= items + 15'd1;
							end
						end
						default:
						begin
							shift <= uv_q;
							uv_ptr <= uv_next;
							uv_col <= (uv_col == cw - 1) ? 8'd0 : uv_col + 8'd1;
						end
					endcase
				end else
				begin
					shift <= {1'b0, shift[7:1]};
					nbit <= nbit + 3'd1;
				end
			end
		end
		if(reading && (v_udr || (v_ir != IR_VIDEO)))
		begin
			reading <= 1'b0;
			field <= ~field;   //el siguiente corrimiento manda el otro campo
		end

		//---- mascara ----
		if(v_ir == IR_MASK)
		begin
			if(v_cdr)
			begin
				msk_ptr <= 13'd1;
			end else
			begin
				if(v_sdr)
				begin
					msk_ptr <= msk_ptr + 13'd1;
				end
			end
		end else
		begin
			msk_ptr <= 13'd0;
		end

		//---- datos ----
		if(v_ir == IR_META)
		begin
			if(v_cdr)
			begin
				meta_shift <= meta;
			end else
			begin
				if(v_sdr)
				begin
					meta_shift <= {1'b0, meta_shift[meta_bits-1:1]};
				end
			end
		end
	end

	//los registros del lado del JTAG no tienen reinicio: en la FPGA arrancan en 0
	initial begin
		reading = 1'b0;
		field = 1'b0;
		bank_t = 2'b00;
		bank_rd = 1'b0;
		msk_ptr = 13'd0;
	end

	assign tdo = (v_ir == IR_VIDEO) ? shift[0] :
	             (v_ir == IR_MASK) ? msk_data :
	             (v_ir == IR_META) ? meta_shift[0] : bypass;

	//================ cambio de memorias (clk) ================
	//Al terminar un cuadro (frame_done):
	//  si la PC no esta leyendo se cambian las memorias: el cuadro recien terminado queda
	//  para la PC y la camara sigue en la otra;
	//  si la PC esta leyendo, el cuadro se guarda (no se escribe mas) y el cambio se hace
	//  en cuanto la PC termina; la camara vuelve a escribir al empezar el siguiente cuadro.
	reg [1:0] reading_ff;

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			reading_ff <= 2'b00;
			bank_wr <= 1'b0;
			writing <= 1'b0;
			holding <= 1'b0;
		end else
		begin
			reading_ff <= {reading_ff[0], reading};
			if(holding)
			begin
				if(!reading_ff[1])
				begin
					bank_wr <= ~bank_wr;
					holding <= 1'b0;
				end
			end else
			begin
				if(frame_done)
				begin
					if(!writing)
					begin
						writing <= 1'b1;
					end else
					begin
						if(!reading_ff[1])
						begin
							bank_wr <= ~bank_wr;
						end else
						begin
							writing <= 1'b0;
							holding <= 1'b1;
						end
					end
				end
			end
		end
	end

endmodule
