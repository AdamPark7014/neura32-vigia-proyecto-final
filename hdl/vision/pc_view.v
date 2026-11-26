// video a la PC
module pc_view #(
	parameter width = 320,
	parameter height = 240,
	parameter meta_bits = 384
)(
	input clk,
	input rst,
	// pixeles
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
	// datos
	input [meta_bits-1:0] meta,
	// lectura de la mascara
	output wire tck,
	output wire [12:0] msk_addr,
	input msk_data,
	output wire held
);

	// tamano
	localparam pw = width / 2;  // ancho hacia PC
	localparam ph = height / 2;  // alto hacia PC
	localparam cw = width / 4;  // ancho del color
	localparam ch = height / 4;  // alto del color
	localparam y_items = pw * ph;  // pixeles de brillo

	// lado de la camara
	reg bank_wr;
	reg writing;
	reg holding;
	assign held = holding;

	// brillo
	wire [8:0] px = {1'b0, pix_x[8:1]};
	wire [7:0] py = {1'b0, pix_y[7:1]};
	wire y_take = pix_valid & writing & ~pix_x[0] & ~pix_y[0];
	wire [14:0] y_addr_wr = py * pw + px;

	reg [3:0] dither;
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

	// color
	wire [7:0] cx = {1'b0, uv_x[7:1]};
	wire [6:0] cy = {1'b0, uv_y[6:1]};
	wire uv_take = uv_valid & writing & ~uv_x[0] & ~uv_y[0];
	wire [12:0] uv_addr_wr = cy * cw + cx;

	// memorias
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

	// lado de la PC
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

	localparam IR_VIDEO = 2'd1;  // lee el video
	localparam IR_MASK = 2'd2;  // lee la máscara
	localparam IR_META = 2'd3;  // lee los datos
	localparam PH_HEAD = 2'd0;  // manda la cabecera
	localparam PH_LUM = 2'd1;  // manda el brillo
	localparam PH_COLOR = 2'd2;  // manda el color

	reg reading;
	reg [1:0] bank_t;
	reg bank_rd;
	reg [1:0] phase;
	reg head_second;
	reg [7:0] shift;
	reg [2:0] nbit, last_bit;
	reg [14:0] y_ptr;
	reg [12:0] uv_ptr;
	reg [14:0] items;
	reg bypass;

	assign y_ptr_addr = y_ptr;
	assign uv_ptr_addr = uv_ptr;
	wire [3:0] y_q = bank_rd ? yb_q : ya_q;
	wire [7:0] uv_q = bank_rd ? uvb_q : uva_q;

	// siguiente pixel
	wire [14:0] y_next = y_ptr + 15'd1;
	wire [12:0] uv_next = uv_ptr + 13'd1;

	// mascara
	reg [12:0] msk_ptr;
	assign msk_addr = msk_ptr;

	// datos
	reg [meta_bits-1:0] meta_shift;

	always @(posedge tck)
	begin
		bypass <= tdi;
		bank_t <= {bank_t[0], bank_wr};
		if(!reading)
		begin
			bank_rd <= ~bank_t[1];
		end

		// cuadro de video
		if((v_ir == IR_VIDEO) && v_cdr)
		begin
			reading <= 1'b1;
			phase <= PH_HEAD;
			head_second <= 1'b0;
			shift <= 8'd0;
			nbit <= 3'd0;
			last_bit <= 3'd7;
			y_ptr <= 15'd0;
			uv_ptr <= 13'd0;
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
								shift <= 8'hA5;
								head_second <= 1'b1;
							end else
							begin
								shift <= {4'd0, y_q};
								last_bit <= 3'd3;
								phase <= PH_LUM;
								y_ptr <= y_next;
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
							end else
							begin
								shift <= {4'd0, y_q};
								y_ptr <= y_next;
								items <= items + 15'd1;
							end
						end
						default:
						begin
							shift <= uv_q;
							uv_ptr <= uv_next;
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
		end

		// mascara
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

		// datos
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

	// valores iniciales
	initial begin
		reading = 1'b0;
		bank_t = 2'b00;
		bank_rd = 1'b0;
		msk_ptr = 13'd0;
	end

	assign tdo = (v_ir == IR_VIDEO) ? shift[0] :
	             (v_ir == IR_MASK) ? msk_data :
	             (v_ir == IR_META) ? meta_shift[0] : bypass;

	// cambio de memorias
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
