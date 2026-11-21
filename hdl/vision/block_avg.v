//Promedio por bloques del brillo: de la imagen de la camara a la rejilla de deteccion
//Cada bloque de 2^block_log2 x 2^block_log2 pixeles da una celda (320 x 240 con bloques
//de 4 x 4 = 80 x 60 celdas). El promedio es un filtro pasa-bajas: quita el ruido del
//sensor antes de comparar contra el fondo.
//row_sum junta los pixeles de un renglon del bloque; acc[col] junta los renglones.
//acc se lee al llegar el primer pixel del bloque y se usa al llegar el ultimo.
module block_avg #(
	parameter width = 320,
	parameter block_log2 = 2
)(
	input clk,   //25 MHz
	//brillo de cada pixel (cam_capture)
	input pix_valid,
	input [8:0] pix_x,
	input [7:0] pix_y,
	input [7:0] pix_lum,
	//promedio de cada celda
	output reg avg_valid,
	output reg [6:0] avg_x,
	output reg [5:0] avg_y,
	output reg [7:0] avg_data
);

	localparam cells = width >> block_log2;
	localparam [8:0] mask = (1 << block_log2) - 1;

	wire [8:0] bx = pix_x & mask;                 //posicion dentro del bloque
	wire [8:0] by = {1'b0, pix_y} & mask;
	wire [6:0] col = pix_x >> block_log2;         //celda
	wire [5:0] row = pix_y >> block_log2;

	reg [11:0] row_sum;
	reg [15:0] acc [0:cells-1];
	reg [15:0] acc_q;
	reg [6:0] acc_addr;
	wire [15:0] total_row = row_sum + pix_lum;    //renglon completo del bloque
	wire [15:0] total_block = acc_q + total_row;  //bloque completo

	integer i;
	initial begin
		for (i = 0; i < cells; i = i + 1)
			acc[i] = 16'd0;
	end

	always @(posedge clk) begin
		acc_q <= acc[acc_addr];
	end

	always @(posedge clk)
	begin
		avg_valid <= 1'b0;
		if(pix_valid)
		begin
			if(bx == 9'd0)
			begin
				row_sum <= {4'd0, pix_lum};
				acc_addr <= col;
			end else
			begin
				row_sum <= row_sum + pix_lum;
			end
			if(bx == mask)
			begin
				if(by == 9'd0)
				begin
					acc[col] <= total_row;
				end else
				begin
					acc[col] <= total_block;
				end
				if(by == mask)
				begin
					avg_valid <= 1'b1;
					avg_x <= col;
					avg_y <= row;
					avg_data <= total_block >> (2 * block_log2);
				end
			end
		end
	end

endmodule
