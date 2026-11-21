//Captura de la camara OV7670 a color (YUV 4:2:2)
//La camara manda 4 bytes por cada 2 pixeles: Y0 U Y1 V (brillo de cada pixel y color de la pareja).
//PCLK va a 12.5 MHz y aqui se muestrea con el reloj de 50 MHz (4 muestras por periodo):
//PCLK, HREF, VSYNC y D pasan por dos flip-flops y un detector de flanco marca cada byte.
//Las salidas duran 2 ciclos de clk, para que la logica de 25 MHz las vea una sola vez.
//
//  half = 0: la camara ya entrega width x height (modo QVGA del sensor, 31 cuadros/s)
//  half = 1: la camara entrega el doble (VGA) y aqui se toma 1 de cada 2 pixeles y lineas
//  fmt[0] = 1: el brillo llega en los bytes impares (U Y V Y)
//  fmt[1] = 1: U y V llegan intercambiados
module cam_capture #(
	parameter width = 320,
	parameter height = 240
)(
	input clk,   //50 MHz
	input rst,   //activo en bajo
	input en,
	input half,
	input [1:0] fmt,
	//senales de la camara
	input cam_pclk,
	input cam_href,
	input cam_vsync,
	input [7:0] cam_d,
	//brillo de cada pixel
	output reg pix_valid,
	output reg [8:0] pix_x,
	output reg [7:0] pix_y,
	output reg [7:0] pix_lum,
	//color: una muestra por cada bloque de 2 x 2 pixeles
	output reg uv_valid,
	output reg [7:0] uv_x,
	output reg [6:0] uv_y,
	output reg [7:0] uv_u,
	output reg [7:0] uv_v,
	output reg frame_done,   //termino el cuadro (subio VSYNC)
	//para medir desde la PC
	output wire byte_strobe,   //llego un byte dentro de la linea
	output wire pclk_rise,
	output wire href_s,
	output wire vsync_s
);

	//sincronizadores
	reg [2:0] pclk_ff, href_ff, vsync_ff;
	reg [7:0] d_ff1, d_ff2;

	always @(posedge clk)
	begin
		pclk_ff <= {pclk_ff[1:0], cam_pclk};
		href_ff <= {href_ff[1:0], cam_href};
		vsync_ff <= {vsync_ff[1:0], cam_vsync};
		d_ff1 <= cam_d;
		d_ff2 <= d_ff1;   //alineado con pclk_ff[1]
	end

	assign pclk_rise = pclk_ff[1] & ~pclk_ff[2];
	assign href_s = href_ff[1];
	assign vsync_s = vsync_ff[1];
	assign byte_strobe = pclk_rise & href_s;

	wire href_fall = ~href_ff[1] & href_ff[2];
	wire vsync_rise = vsync_ff[1] & ~vsync_ff[2];

	//posicion dentro del cuadro que manda la camara
	reg [1:0] nbyte;   //0..3 dentro de la pareja de pixeles
	reg [9:0] x;       //pixel de la camara
	reg [9:0] y;       //linea de la camara
	reg [7:0] u_hold;  //primer byte de color de la pareja

	//que trae este byte
	wire is_lum = (nbyte[0] == fmt[0]);
	wire is_last_color = (~is_lum) & nbyte[1];   //segundo byte de color de la pareja

	//posicion de salida (con half se parte entre 2)
	wire [9:0] out_x = half ? {1'b0, x[9:1]} : x;
	wire [9:0] out_y = half ? {1'b0, y[9:1]} : y;
	wire keep_pix = half ? ((x[0] == 1'b0) && (y[0] == 1'b0)) : 1'b1;

	//muestra de color: cuando llega su segundo byte, x ya paso por un pixel de la pareja,
	//asi que la pareja es (x - 1) / 2; se guarda 1 de cada 2 lineas (y 1 de cada 2 parejas con half)
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
				if(vsync_s)
				begin
					nbyte <= 2'd0;
					x <= 10'd0;
					y <= 10'd0;
					done_new <= vsync_rise;
				end else
				begin
					if(href_fall)
					begin
						nbyte <= 2'd0;
						x <= 10'd0;
						y <= y + 10'd1;
					end else
					begin
						if(byte_strobe)
						begin
							nbyte <= nbyte + 2'd1;
							if(is_lum)
							begin
								//brillo de un pixel
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
									//color completo de la pareja (x ya avanzo: la pareja es la anterior)
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
			//las salidas duran 2 ciclos
			valid_old <= valid_new;
			uvalid_old <= uvalid_new;
			done_old <= done_new;
			pix_valid <= valid_new | valid_old;
			uv_valid <= uvalid_new | uvalid_old;
			frame_done <= done_new | done_old;
		end
	end

endmodule
