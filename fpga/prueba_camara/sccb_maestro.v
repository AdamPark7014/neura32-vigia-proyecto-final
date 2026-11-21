`timescale 1ns / 1ps
// ============================================================
// MAESTRO SCCB EN HARDWARE (solo para la prueba de la camara)
// Configura la OV7670 sin procesador: pulso de reset, reinicio de
// registros, lectura de PID y VER, y la tabla de registros. SCL de ~100 kHz.
// Al terminar la tabla queda en espera y acepta ordenes de fuera
// (ext_wr / ext_rd): asi la PC puede escribir o leer cualquier registro
// de la camara en vivo para afinar la imagen.
// Cada transaccion es una lista de simbolos:
//   escritura: S B(0x42) B(reg) B(valor) P
//   lectura:   S B(0x42) B(reg) P S B(0x43) R P
//   S = inicio, P = fin, B = byte enviado + 9.o bit, R = byte recibido + NA
// ============================================================
module sccb_maestro #(
    parameter CICLOS_CUARTO = 63,      // 25 MHz / (4 x 63) = 99 kHz
    parameter CICLOS_MS     = 25000    // ciclos de 25 MHz en 1 ms
) (
    input  wire       clk,
    input  wire       rst,
    output reg        sioc,
    output reg        siod_bajo,       // 1 = poner SIOD en 0 (drenador abierto)
    input  wire       siod_in,
    output reg        cam_reset_n,
    output reg  [7:0] pid,
    output reg  [7:0] ver,
    output reg        hecho,
    // ordenes de fuera (un pulso de un ciclo cuando hecho = 1 y ext_libre = 1)
    input  wire       ext_wr,
    input  wire       ext_rd,
    input  wire [7:0] ext_reg,
    input  wire [7:0] ext_val,
    output reg  [7:0] ext_dato,
    output wire       ext_libre
);
    // ---------------- tabla de comandos {tipo, registro, valor} ----------------
    localparam C_ESPERA = 2'd0, C_ESCRIBE = 2'd1, C_LEE = 2'd2, C_FIN = 2'd3;
    reg [7:0]  pc;
    wire [17:0] comando;

    tabla_ov7670 tabla (.indice(pc), .comando(comando));

    // ---------------- simbolos de la transaccion ----------------
    localparam S_INI = 2'd0, S_BYTE = 2'd1, S_LEE = 2'd2, S_FIN = 2'd3;
    reg [1:0] tipo_sim [0:7];
    reg [7:0] byte_sim [0:7];
    reg [3:0] nsim, sim;
    reg [3:0] bit_n;                  // 0..8 dentro de un byte
    reg [1:0] cuarto;                 // 4 cuartos por bit
    reg [15:0] cuenta;
    reg [7:0]  ms;
    reg [7:0]  rx;
    reg [1:0]  siod_s;
    reg        destino_ver;
    reg        externo;               // la transaccion en curso la pidio la PC

    localparam E_CMD = 3'd0, E_ESPERA = 3'd1, E_SIM = 3'd2, E_FIN = 3'd3;
    reg [2:0] estado;
    assign ext_libre = (estado == E_FIN);

    // nivel deseado de SCL y SDA segun el simbolo y el cuarto
    reg scl_d, sda_d;
    always @(*) begin
        scl_d = 1'b1; sda_d = 1'b1;
        if (estado == E_SIM) begin
            case (tipo_sim[sim])
                S_INI: begin scl_d = (cuarto <= 2'd1); sda_d = (cuarto == 2'd0); end
                S_FIN: begin scl_d = (cuarto != 2'd0); sda_d = (cuarto >= 2'd2); end
                S_BYTE: begin
                    scl_d = (cuarto == 2'd1) || (cuarto == 2'd2);
                    sda_d = (bit_n < 4'd8) ? byte_sim[sim][3'd7 - bit_n[2:0]] : 1'b1;
                end
                S_LEE: begin
                    scl_d = (cuarto == 2'd1) || (cuarto == 2'd2);
                    sda_d = 1'b1;                          // suelta SIOD; en el 9.o bit es el NA
                end
            endcase
        end
    end

    wire fin_cuarto = (cuenta == CICLOS_CUARTO - 1);
    wire fin_ms     = (cuenta == CICLOS_MS - 1);
    wire sim_largo  = (tipo_sim[sim] == S_BYTE) || (tipo_sim[sim] == S_LEE);

    always @(posedge clk) begin
        siod_s <= {siod_s[0], siod_in};
        sioc      <= scl_d;
        siod_bajo <= ~sda_d;
        if (rst) begin
            estado <= E_CMD; pc <= 8'd0; cuenta <= 16'd0; hecho <= 1'b0; externo <= 1'b0;
            cam_reset_n <= 1'b0; pid <= 8'h00; ver <= 8'h00; ext_dato <= 8'h00;
        end else begin
            case (estado)
                E_CMD: begin
                    cuenta <= 16'd0; sim <= 4'd0; bit_n <= 4'd0; cuarto <= 2'd0;
                    if (pc == 8'd1) cam_reset_n <= 1'b1;
                    case (comando[17:16])
                        C_ESPERA: begin ms <= comando[7:0]; estado <= E_ESPERA; end
                        C_ESCRIBE: begin
                            tipo_sim[0] <= S_INI;  tipo_sim[1] <= S_BYTE; byte_sim[1] <= 8'h42;
                            tipo_sim[2] <= S_BYTE; byte_sim[2] <= comando[15:8];
                            tipo_sim[3] <= S_BYTE; byte_sim[3] <= comando[7:0];
                            tipo_sim[4] <= S_FIN;  nsim <= 4'd5; estado <= E_SIM;
                        end
                        C_LEE: begin
                            tipo_sim[0] <= S_INI;  tipo_sim[1] <= S_BYTE; byte_sim[1] <= 8'h42;
                            tipo_sim[2] <= S_BYTE; byte_sim[2] <= comando[15:8];
                            tipo_sim[3] <= S_FIN;  tipo_sim[4] <= S_INI;
                            tipo_sim[5] <= S_BYTE; byte_sim[5] <= 8'h43;
                            tipo_sim[6] <= S_LEE;  tipo_sim[7] <= S_FIN;
                            nsim <= 4'd8; destino_ver <= comando[0]; estado <= E_SIM;
                        end
                        default: estado <= E_FIN;
                    endcase
                end

                E_ESPERA: begin
                    if (fin_ms) begin
                        cuenta <= 16'd0;
                        if (ms == 8'd1) begin pc <= pc + 8'd1; estado <= E_CMD; end
                        else ms <= ms - 8'd1;
                    end else cuenta <= cuenta + 16'd1;
                end

                E_SIM: begin
                    if (fin_cuarto) begin
                        cuenta <= 16'd0;
                        // muestra el bit leido al final del segundo cuarto en alto
                        if (tipo_sim[sim] == S_LEE && cuarto == 2'd2 && bit_n < 4'd8)
                            rx <= {rx[6:0], siod_s[1]};
                        cuarto <= cuarto + 2'd1;
                        if (cuarto == 2'd3) begin
                            if (sim_largo && bit_n != 4'd8) begin
                                bit_n <= bit_n + 4'd1;
                            end else begin
                                bit_n <= 4'd0;
                                if (sim == nsim - 4'd1) begin
                                    if (externo) begin
                                        if (nsim == 4'd8) ext_dato <= rx;
                                        externo <= 1'b0; estado <= E_FIN;
                                    end else begin
                                        if (nsim == 4'd8) begin
                                            if (destino_ver) ver <= rx; else pid <= rx;
                                        end
                                        pc <= pc + 8'd1; estado <= E_CMD;
                                    end
                                end else sim <= sim + 4'd1;
                            end
                        end
                    end else cuenta <= cuenta + 16'd1;
                end

                // tabla terminada: se atienden las ordenes de la PC
                E_FIN: begin
                    hecho  <= 1'b1;
                    cuenta <= 16'd0; sim <= 4'd0; bit_n <= 4'd0; cuarto <= 2'd0;
                    if (ext_wr) begin
                        tipo_sim[0] <= S_INI;  tipo_sim[1] <= S_BYTE; byte_sim[1] <= 8'h42;
                        tipo_sim[2] <= S_BYTE; byte_sim[2] <= ext_reg;
                        tipo_sim[3] <= S_BYTE; byte_sim[3] <= ext_val;
                        tipo_sim[4] <= S_FIN;  nsim <= 4'd5;
                        externo <= 1'b1; estado <= E_SIM;
                    end else if (ext_rd) begin
                        tipo_sim[0] <= S_INI;  tipo_sim[1] <= S_BYTE; byte_sim[1] <= 8'h42;
                        tipo_sim[2] <= S_BYTE; byte_sim[2] <= ext_reg;
                        tipo_sim[3] <= S_FIN;  tipo_sim[4] <= S_INI;
                        tipo_sim[5] <= S_BYTE; byte_sim[5] <= 8'h43;
                        tipo_sim[6] <= S_LEE;  tipo_sim[7] <= S_FIN;
                        nsim <= 4'd8;
                        externo <= 1'b1; estado <= E_SIM;
                    end
                end
                default: estado <= E_FIN;
            endcase
        end
    end
endmodule
