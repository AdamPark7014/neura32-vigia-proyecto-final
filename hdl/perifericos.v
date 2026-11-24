`timescale 1ns / 1ps

// perifericos
module perifericos #(
    parameter SIMULACION = 0
) (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] dir,
    input  wire [31:0] dato_esc,
    input  wire        we,
    output reg  [31:0] dato_lec,

    input  wire [9:0]  interruptores,
    input  wire [1:0]  botones,
    output reg  [9:0]  leds,
    output reg  [23:0] hex,
    output reg  [7:0]  consola_char,
    output reg         consola_we,
    output reg  [31:0] control,
    output reg  [31:0] ticks,
    output reg  [31:0] lfsr
);
    wire [7:0] offset = dir[7:0];

    always @(*) begin
        case (offset)
            8'h00:   dato_lec = {22'b0, leds};
            8'h04:   dato_lec = {22'b0, interruptores};
            8'h08:   dato_lec = {8'b0, hex};
            8'h0C:   dato_lec = {30'b0, botones};
            8'h10:   dato_lec = ticks;
            8'h18:   dato_lec = control;
            8'h1C:   dato_lec = lfsr;
            8'h24:   dato_lec = {16'h5647, 15'd0, (SIMULACION != 0)};
            default: dato_lec = 32'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            leds <= 10'd0; hex <= 24'd0; control <= 32'd0; ticks <= 32'd0;
            consola_char <= 8'd0; consola_we <= 1'b0;
            lfsr <= 32'hACE1_2026;
        end else begin
            ticks      <= ticks + 32'd1;
            consola_we <= 1'b0;
            // LFSR
            lfsr <= {lfsr[0], lfsr[31:1]} ^ (lfsr[0] ? 32'h80200003 : 32'd0);

            if (we) begin
                case (offset)
                    8'h00: leds         <= dato_esc[9:0];
                    8'h08: hex          <= dato_esc[23:0];
                    8'h14: begin consola_char <= dato_esc[7:0]; consola_we <= 1'b1; end
                    8'h18: control      <= dato_esc;
                    8'h20: lfsr         <= dato_esc;
                    default: ;
                endcase
            end
        end
    end
endmodule
