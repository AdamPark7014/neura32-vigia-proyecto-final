// dibujo VGA
module vga_draw #(
	parameter width = 320,
	parameter scale = 1
)(
	input clk,
	input rst,
	// barrido
	input [9:0] h,
	input [9:0] v,
	input hs_in,
	input vs_in,
	input active_in,
	input frame_tick,
	// memorias de video
	output wire [16:0] y_addr,
	input [5:0] y_data,
	output wire [14:0] uv_addr,
	input [9:0] uv_data,
	output wire [12:0] msk_addr,
	input msk_data,
	// ordenes del procesador
	input show_mask,
	input pattern,
	input [31:0] zone,
	input [8:0] line,
	input [1:0] banner,
	input [255:0] boxes,
	input [15:0] colors,
	input [3:0] hud_persons,
	input [7:0] hud_events,
	// salida al monitor
	output reg [3:0] vga_r,
	output reg [3:0] vga_g,
	output reg [3:0] vga_b,
	output reg vga_hs,
	output reg vga_vs
);

	// ciclo 0
	wire [9:0] vx = h >> scale;
	wire [9:0] vy = v >> scale;
	assign y_addr = active_in ? (vy * width + vx) : 17'd0;
	assign uv_addr = active_in ? ((vy >> 1) * (width / 2) + (vx >> 1)) : 15'd0;

	// tres renglones
	reg [79:0] row_up, row_cur, row_dn;
	reg [9:0] h1, v1;
	reg hs1, vs1, act1;

	wire load_line = ((v < 10'd480) && (v[2:0] == 3'd3)) || (v == 10'd500);
	wire [6:0] load_row = (v == 10'd500) ? 7'd0 : ({1'b0, v[8:3]} + 7'd1);
	wire load_now = load_line && (h >= 10'd648) && (h < 10'd728);
	wire [9:0] load_i = h - 10'd648;
	assign msk_addr = load_row * 13'd80 + {6'd0, load_i[6:0]};

	wire load_now1 = (((v1 < 10'd480) && (v1[2:0] == 3'd3)) || (v1 == 10'd500)) &&
	                 (h1 >= 10'd648) && (h1 < 10'd728);
	wire [6:0] load_row1 = (v1 == 10'd500) ? 7'd0 : ({1'b0, v1[8:3]} + 7'd1);
	wire shift_rows = (h1 == 10'd760) && (((v1 < 10'd480) && (v1[2:0] == 3'd7)) || (v1 == 10'd502));

	always @(posedge clk)
	begin
		if(load_now1)
		begin
			row_dn <= {(load_row1 < 7'd60) ? msk_data : 1'b0, row_dn[79:1]};
		end
		if(shift_rows)
		begin
			row_up <= (v1 == 10'd502) ? 80'd0 : row_cur;
			row_cur <= row_dn;
		end
	end

	// ciclo 1
	reg [5:0] frames;

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			frames <= 6'd0;
		end else
		begin
			if(frame_tick)
			begin
				frames <= frames + 6'd1;
			end
		end
	end

	always @(posedge clk)
	begin
		h1 <= h;
		v1 <= v;
		hs1 <= hs_in;
		vs1 <= vs_in;
		act1 <= active_in;
	end

	// celda y vecinas
	wire [6:0] cx = h1[9:3];
	wire m_c = row_cur[cx];
	wire m_l = (cx == 7'd0) ? 1'b0 : row_cur[cx - 7'd1];
	wire m_r = (cx == 7'd79) ? 1'b0 : row_cur[cx + 7'd1];
	wire m_u = row_up[cx];
	wire m_d = row_dn[cx];
	wire edge_c = m_c & (((h1[2:0] < 3'd2) & ~m_l) | ((h1[2:0] >= 3'd6) & ~m_r) |
	                     ((v1[2:0] < 3'd2) & ~m_u) | ((v1[2:0] >= 3'd6) & ~m_d));

	// recuadros
	function inside;
		input [9:0] px, py;
		input [7:0] cx0, cy0, cx1, cy1;
		reg [10:0] x0, x1, y0, y1;
		begin
			x0 = {cx0, 3'b000};
			x1 = {cx1, 3'b111};
			y0 = {cy0, 3'b000};
			y1 = {cy1, 3'b111};
			inside = (px >= x0) && (px <= x1) && (py >= y0) && (py <= y1);
		end
	endfunction

	function border;
		input [9:0] px, py;
		input [7:0] cx0, cy0, cx1, cy1;
		reg [10:0] x0, x1, y0, y1;
		reg inner;
		begin
			x0 = {cx0, 3'b000};
			x1 = {cx1, 3'b111};
			y0 = {cy0, 3'b000};
			y1 = {cy1, 3'b111};
			inner = (px >= x0 + 2) && (px + 2 <= x1) && (py >= y0 + 2) && (py + 2 <= y1);
			border = inside(px, py, cx0, cy0, cx1, cy1) && !inner;
		end
	endfunction

	// letrero
	reg [1:0] box_color;
	reg [1:0] in_color;
	reg lbl_hit;
	reg [1:0] lbl_color;
	reg [2:0] lbl_char;
	reg [3:0] lbl_row;
	reg [2:0] lbl_col;
	reg [10:0] bx0, by0, ltop, dx, dy;
	integer k;

	always @(*)
	begin
		box_color = 2'd0;
		in_color = 2'd0;
		lbl_hit = 1'b0;
		lbl_color = 2'd0;
		lbl_char = 3'd0;
		lbl_row = 4'd0;
		lbl_col = 3'd0;
		bx0 = 11'd0; by0 = 11'd0; ltop = 11'd0; dx = 11'd0; dy = 11'd0;
		for(k = 7; k >= 0; k = k - 1)
		begin
			if(colors[2*k +: 2] != 2'd0)
			begin
				if(border(h1, v1, boxes[32*k +: 8], boxes[32*k+8 +: 8], boxes[32*k+16 +: 8], boxes[32*k+24 +: 8]))
				begin
					box_color = colors[2*k +: 2];
				end
				if((colors[2*k +: 2] != 2'd3) &&
				   inside(h1, v1, boxes[32*k +: 8], boxes[32*k+8 +: 8], boxes[32*k+16 +: 8], boxes[32*k+24 +: 8]))
				begin
					in_color = colors[2*k +: 2];
				end
				bx0 = {boxes[32*k +: 8], 3'b000};
				by0 = {boxes[32*k+8 +: 8], 3'b000};
				ltop = (by0 >= 11'd34) ? (by0 - 11'd17) : (by0 + 11'd3);
				dx = {1'b0, h1} - bx0;
				dy = {1'b0, v1} - ltop;
				if(({1'b0, h1} >= bx0) && (dx < 11'd56) && ({1'b0, v1} >= ltop) && (dy < 11'd16))
				begin
					lbl_hit = 1'b1;
					lbl_color = colors[2*k +: 2];
					lbl_char = dx[5:3];
					lbl_row = dy[3:0];
					lbl_col = dx[2:0];
				end
			end
		end
	end

	// letra del letrero
	function [5:0] label_text;
		input [1:0] color;
		input [2:0] i;
		reg [7:0] a;
		begin
			a = " ";
			case(color)
				2'd1: begin
					case(i)
						3'd0: a = "P"; 3'd1: a = "E"; 3'd2: a = "R"; 3'd3: a = "S";
						3'd4: a = "O"; 3'd5: a = "N"; 3'd6: a = "A"; default: a = " ";
					endcase
				end
				2'd2: begin
					case(i)
						3'd0: a = "I"; 3'd1: a = "N"; 3'd2: a = "T"; 3'd3: a = "R";
						3'd4: a = "U"; 3'd5: a = "S"; 3'd6: a = "O"; default: a = " ";
					endcase
				end
				2'd3: begin
					case(i)
						3'd0: a = "O"; 3'd1: a = "B"; 3'd2: a = "J"; 3'd3: a = "E";
						3'd4: a = "T"; 3'd5: a = "O"; default: a = " ";
					endcase
				end
				default: a = " ";
			endcase
			label_text = a[5:0] - 6'd32;
		end
	endfunction

	// letrero grande
	wire [9:0] tx = h1 - 10'd208;
	wire [9:0] ty = v1 - 10'd32;
	wire ban_hit = banner[0] && (h1 >= 10'd208) && (tx < 10'd224) && (v1 >= 10'd32) && (ty < 10'd64) &&
	               (!banner[1] || frames[4]);

	// barra de estado
	function [5:0] hud_text;
		input [6:0] col;
		input [3:0] persons;
		input [7:0] events;
		reg [7:0] a;
		begin
			a = " ";
			case(col)
				7'd1: a = "N"; 7'd2: a = "E"; 7'd3: a = "U"; 7'd4: a = "R"; 7'd5: a = "A";
				7'd6: a = "-"; 7'd7: a = "3"; 7'd8: a = "2";
				7'd10: a = "V"; 7'd11: a = "I"; 7'd12: a = "G"; 7'd13: a = "I"; 7'd14: a = "A";
				7'd26: a = "P"; 7'd27: a = "E"; 7'd28: a = "R"; 7'd29: a = "S"; 7'd30: a = "O";
				7'd31: a = "N"; 7'd32: a = "A"; 7'd33: a = "S"; 7'd34: a = ":";
				7'd36: a = {4'h3, persons};
				7'd44: a = "E"; 7'd45: a = "V"; 7'd46: a = "E"; 7'd47: a = "N"; 7'd48: a = "T";
				7'd49: a = "O"; 7'd50: a = "S"; 7'd51: a = ":";
				7'd53: a = {4'h3, events[7:4]};
				7'd54: a = {4'h3, events[3:0]};
				7'd74: a = "R"; 7'd75: a = "E"; 7'd76: a = "C";
				default: a = " ";
			endcase
			hud_text = a[5:0] - 6'd32;
		end
	endfunction

	wire hud_hit = (v1 < 10'd16);
	wire hud_dot = hud_hit && (h1 >= 10'd578) && (h1 < 10'd586) && (v1 >= 10'd4) && (v1 < 10'd12) && frames[5];

	// ROM de letras
	reg [5:0] ch;
	reg [3:0] ch_row;
	reg [2:0] ch_col;

	always @(*)
	begin
		if(hud_hit)
		begin
			ch = hud_text(h1[9:3], hud_persons, hud_events);
			ch_row = v1[3:0];
			ch_col = h1[2:0];
		end else
		begin
			if(ban_hit)
			begin
				ch = label_text(2'd2, tx[7:5]);
				ch_row = ty[5:2];
				ch_col = tx[4:2];
			end else
			begin
				ch = label_text(lbl_color, lbl_char);
				ch_row = lbl_row;
				ch_col = lbl_col;
			end
		end
	end

	// ROM de letras
	(* ramstyle = "M9K" *) reg [7:0] font_data [0:1023];
	reg [7:0] font_q;
	initial begin
		$readmemh("font8x16.txt", font_data);
	end
	always @(posedge clk) begin
		font_q <= font_data[{ch, ch_row}];
	end

	// zona y linea
	wire in_zone = border(h1, v1, zone[7:0], zone[15:8], zone[23:16], zone[31:24]);
	wire in_line = line[8] && (h1[9:1] == {line[6:0], 2'b10}) && !v1[3];

	// ciclo 2
	reg [5:0] y2;
	reg [9:0] uv2;
	reg [9:0] h2, v2;
	reg hs2, vs2, act2;
	reg m2, edge2, zone2, line2, lbl2, ban2, hud2, dot2;
	reg [1:0] box2, in2, lblc2;
	reg [2:0] col2;

	always @(posedge clk)
	begin
		y2 <= y_data;
		uv2 <= uv_data;
		h2 <= h1;
		v2 <= v1;
		hs2 <= hs1;
		vs2 <= vs1;
		act2 <= act1;
		m2 <= m_c;
		edge2 <= edge_c;
		zone2 <= in_zone;
		line2 <= in_line;
		lbl2 <= lbl_hit;
		ban2 <= ban_hit;
		hud2 <= hud_hit;
		dot2 <= hud_dot;
		box2 <= box_color;
		in2 <= in_color;
		lblc2 <= lbl_color;
		col2 <= ch_col;
	end

	// YUV a RGB
	wire signed [10:0] yy = {3'b000, y2, 2'b10};
	wire signed [10:0] du = $signed({3'b000, uv2[9:5], 3'b100}) - 11'sd128;
	wire signed [10:0] dv = $signed({3'b000, uv2[4:0], 3'b100}) - 11'sd128;

	wire signed [10:0] r_full = yy + dv + (dv >>> 2) + (dv >>> 3) + (dv >>> 5);
	wire signed [10:0] g_full = yy - ((du >>> 2) + (du >>> 4) + (du >>> 5))
	                               - ((dv >>> 1) + (dv >>> 3) + (dv >>> 4) + (dv >>> 5));
	wire signed [10:0] b_full = yy + du + (du >>> 1) + (du >>> 2) + (du >>> 6);

	// recorte 0-255
	function [7:0] clip8;
		input signed [10:0] x;
		begin
			if(x[10])
				clip8 = 8'd0;
			else if(x[9:8] != 2'b00)
				clip8 = 8'd255;
			else
				clip8 = x[7:0];
		end
	endfunction

	// tramado
	reg [3:0] thr;
	always @(*)
	begin
		case({v2[0], h2[0]})
			2'b00: thr = 4'd0;
			2'b01: thr = 4'd8;
			2'b10: thr = 4'd12;
			default: thr = 4'd4;
		endcase
	end

	function [3:0] dither4;
		input [7:0] c;
		input [3:0] t;
		reg [8:0] s;
		begin
			s = {1'b0, c} + {5'd0, t};
			dither4 = s[8] ? 4'hF : s[7:4];
		end
	endfunction

	wire [3:0] vid_r = dither4(clip8(r_full), thr);
	wire [3:0] vid_g = dither4(clip8(g_full), thr);
	wire [3:0] vid_b = dither4(clip8(b_full), thr);

	wire font_on = font_q[3'd7 - col2];

	// color del recuadro
	function [11:0] box_rgb;
		input [1:0] c;
		begin
			case(c)
				2'd1: box_rgb = 12'h0F2;
				2'd2: box_rgb = 12'hF11;
				2'd3: box_rgb = 12'h999;
				default: box_rgb = 12'h000;
			endcase
		end
	endfunction

	reg [3:0] r, g, b;
	always @(*)
	begin
		r = vid_r; g = vid_g; b = vid_b;
		// mascara
		if(show_mask && m2)
		begin
			r = vid_r >> 1; g = vid_g >> 1; b = 4'hF;
		end
		if(show_mask && edge2)
		begin
			r = 4'h0; g = 4'hF; b = 4'hF;
		end
		// silueta
		if(edge2 && (in2 != 2'd0))
		begin
			{r, g, b} = box_rgb(in2);
		end
		if(line2) begin r = 4'h0; g = 4'hF; b = 4'hF; end
		if(zone2) begin r = 4'hF; g = 4'hF; b = 4'h0; end
		if(box2 != 2'd0)
		begin
			{r, g, b} = box_rgb(box2);
		end
		// letrero
		if(lbl2)
		begin
			if(font_on) begin r = 4'h0; g = 4'h0; b = 4'h0; end
			else begin {r, g, b} = box_rgb(lblc2); end
		end
		// alarma
		if(ban2)
		begin
			if(font_on) begin r = 4'hF; g = 4'hF; b = 4'hF; end
			else begin r = 4'hB; g = 4'h0; b = 4'h0; end
		end
		// barra de estado
		if(hud2)
		begin
			if(font_on) begin r = 4'hF; g = 4'hF; b = 4'hF; end
			else begin r = vid_r >> 2; g = vid_g >> 2; b = vid_b >> 2; end
			if(dot2) begin r = 4'hF; g = 4'h1; b = 4'h1; end
		end
		// patron de prueba
		if(pattern)
		begin
			if(v2 < 10'd360)
			begin
				r = h2[8] ? 4'hF : 4'h0; g = h2[7] ? 4'hF : 4'h0; b = h2[6] ? 4'hF : 4'h0;
			end else
			begin
				r = h2[9:6]; g = h2[9:6]; b = h2[9:6];
			end
			if(h2 < 10'd2 || h2 > 10'd637 || v2 < 10'd2 || v2 > 10'd477)
			begin
				r = 4'hF; g = 4'hF; b = 4'hF;
			end
		end
		if(!act2) begin r = 4'h0; g = 4'h0; b = 4'h0; end
	end

	// ciclo 3
	always @(posedge clk)
	begin
		vga_r <= r;
		vga_g <= g;
		vga_b <= b;
		vga_hs <= hs2;
		vga_vs <= vs2;
	end

endmodule
