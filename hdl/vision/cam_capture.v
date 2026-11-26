// captura
module cam_capture #(
	parameter width = 320,
	parameter height = 240
)(
	input clk,
	input rst,
	input en,
	input half,
	input [1:0] fmt,
	// senales de la camara
	input cam_pclk,
	input cam_href,
	input cam_vsync,
	input [7:0] cam_d,
	// brillo de cada pixel
	output reg pix_valid,
	output reg [8:0] pix_x,
	output reg [7:0] pix_y,
	output reg [7:0] pix_lum,
	// color
	output reg uv_valid,
	output reg [7:0] uv_x,
	output reg [6:0] uv_y,
	output reg [7:0] uv_u,
	output reg [7:0] uv_v,
	output reg frame_done,
	// para medir desde la PC
	output wire byte_strobe,
	output wire pclk_rise,
	output wire href_s,
	output wire vsync_s
);

	// sincronizadores
	reg [2:0] pclk_ff, href_ff, vsync_ff;
	reg [7:0] d_ff1, d_ff2;

	always @(posedge clk)
	begin
		pclk_ff <= {pclk_ff[1:0], cam_pclk};
		href_ff <= {href_ff[1:0], cam_href};
		vsync_ff <= {vsync_ff[1:0], cam_vsync};
		d_ff1 <= cam_d;
		d_ff2 <= d_ff1;
	end

	assign pclk_rise = pclk_ff[1] & ~pclk_ff[2];
	assign href_s = href_ff[1];
	assign vsync_s = vsync_ff[1];
	assign byte_strobe = pclk_rise & href_s;

	// filtro contra pulsos falsos en VSYNC y HREF
	reg [8:0] vs_cnt;
	reg [4:0] hl_cnt;
	always @(posedge clk)
	begin
		vs_cnt <= vsync_ff[1] ? (vs_cnt[8] ? vs_cnt : vs_cnt + 9'd1) : 9'd0;
		hl_cnt <= href_ff[1] ? 5'd0 : ((hl_cnt == 5'd31) ? hl_cnt : hl_cnt + 5'd1);
	end
	wire vs_ok = vs_cnt[8];
	wire vsync_rise = vsync_ff[1] && (vs_cnt == 9'd255);
	wire href_fall = ~href_ff[1] && (hl_cnt == 5'd15);
	wire byte_ok = pclk_rise & href_ff[1] & href_ff[2];

	// posicion en el cuadro
	reg [1:0] nbyte;
	reg [9:0] x;
	reg [9:0] y;
	reg [7:0] u_hold;
	reg con_bytes;

	// tipo de byte
	wire is_lum = (nbyte[0] == fmt[0]);
	wire is_last_color = (~is_lum) & nbyte[1];

	// posicion de salida
	wire [9:0] out_x = half ? {1'b0, x[9:1]} : x;
	wire [9:0] out_y = half ? {1'b0, y[9:1]} : y;
	wire keep_pix = half ? ((x[0] == 1'b0) && (y[0] == 1'b0)) : 1'b1;

	// color
	wire [9:0] x_prev = x - 10'd1;
	wire [9:0] pair = {1'b0, x_prev[9:1]};
	wire [9:0] col_x = half ? {1'b0, pair[9:1]} : pair;
	wire [9:0] col_y = half ? {2'b00, y[9:2]} : {1'b0, y[9:1]};
	wire keep_uv = half ? ((pair[0] == 1'b0) && (y[1:0] == 2'b00)) : (y[0] == 1'b0);

	reg valid_new, valid_old;
	reg uvalid_new, uvalid_old;
	reg done_new, done_old;

	always @(posedge clk or negedge rst)
	begin
		if(!rst)
		begin
			nbyte <= 2'd0;
			x <= 10'd0;
			y <= 10'd0;
			u_hold <= 8'd128;
			con_bytes <= 1'b0;
			valid_new <= 1'b0;
			valid_old <= 1'b0;
			uvalid_new <= 1'b0;
			uvalid_old <= 1'b0;
			done_new <= 1'b0;
			done_old <= 1'b0;
			pix_valid <= 1'b0;
			pix_x <= 9'd0;
			pix_y <= 8'd0;
			pix_lum <= 8'd0;
			uv_valid <= 1'b0;
			uv_x <= 8'd0;
			uv_y <= 7'd0;
			uv_u <= 8'd128;
			uv_v <= 8'd128;
			frame_done <= 1'b0;
		end else
		begin
			valid_new <= 1'b0;
			uvalid_new <= 1'b0;
			done_new <= 1'b0;
			if(!en)
			begin
				nbyte <= 2'd0;
				x <= 10'd0;
				y <= 10'd0;
			end else
			begin
				if(vs_ok || vsync_rise)
				begin
					nbyte <= 2'd0;
					x <= 10'd0;
					y <= 10'd0;
					con_bytes <= 1'b0;
					done_new <= vsync_rise;
				end else
				begin
					if(href_fall && con_bytes)
					begin
						nbyte <= 2'd0;
						x <= 10'd0;
						y <= y + 10'd1;
						con_bytes <= 1'b0;
					end else
					begin
						if(byte_ok)
						begin
							con_bytes <= 1'b1;
							nbyte <= nbyte + 2'd1;
							if(is_lum)
							begin
								// brillo de un pixel
								if(keep_pix && (out_x < width) && (out_y < height))
								begin
									valid_new <= 1'b1;
									pix_x <= out_x[8:0];
									pix_y <= out_y[7:0];
									pix_lum <= d_ff2;
								end
								x <= x + 10'd1;
							end else
							begin
								if(!is_last_color)
								begin
									u_hold <= d_ff2;
								end else
								begin
									// color
									if(keep_uv && (col_x < (width / 2)) && (col_y < (height / 2)))
									begin
										uvalid_new <= 1'b1;
										uv_x <= col_x[7:0];
										uv_y <= col_y[6:0];
										uv_u <= fmt[1] ? d_ff2 : u_hold;
										uv_v <= fmt[1] ? u_hold : d_ff2;
									end
								end
							end
						end
					end
				end
			end
			valid_old <= valid_new;
			uvalid_old <= uvalid_new;
			done_old <= done_new;
			pix_valid <= valid_new | valid_old;
			uv_valid <= uvalid_new | uvalid_old;
			frame_done <= done_new | done_old;
		end
	end

endmodule
