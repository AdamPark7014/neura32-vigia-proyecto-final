`timescale 1ns / 1ps

// JTAG simulado
module sld_virtual_jtag #(
    parameter sld_auto_instance_index = "NO",
    parameter sld_instance_index = 0,
    parameter sld_ir_width = 2
) (
    output reg                     tck,
    output reg                     tdi,
    output reg  [sld_ir_width-1:0] ir_in,
    input  wire                    tdo,
    input  wire [sld_ir_width-1:0] ir_out,
    output reg                     virtual_state_cdr,
    output reg                     virtual_state_sdr,
    output reg                     virtual_state_udr
);
    reg     datos [0:1048575];
    integer n_datos = 0;

    initial begin
        tck = 0; tdi = 0; ir_in = 0;
        virtual_state_cdr = 0; virtual_state_sdr = 0; virtual_state_udr = 0;
    end

    task pulso;
        begin
            #83 tck = 1;
            #83 tck = 0;
        end
    endtask

    task poner_ir;
        input [sld_ir_width-1:0] valor;
        begin
            pulso; pulso;
            ir_in = valor;
            pulso; pulso; pulso;
        end
    endtask

    task correr_dr;
        input integer n;
        integer i;
        begin
            pulso;
            pulso;
            virtual_state_cdr = 1; pulso; virtual_state_cdr = 0;
            virtual_state_sdr = 1;
            for (i = 0; i < n; i = i + 1) begin
                datos[i] = tdo;
                pulso;
            end
            virtual_state_sdr = 0;
            n_datos = n;
            virtual_state_udr = 1; pulso; virtual_state_udr = 0;
            pulso;
        end
    endtask

    task escribir_dr;
        input integer n;
        input [63:0]  valor;
        integer i;
        begin
            pulso;
            pulso;
            virtual_state_cdr = 1; pulso; virtual_state_cdr = 0;
            virtual_state_sdr = 1;
            for (i = 0; i < n; i = i + 1) begin
                tdi = valor[i];
                pulso;
            end
            virtual_state_sdr = 0;
            tdi = 0;
            virtual_state_udr = 1; pulso; virtual_state_udr = 0;
            pulso;
        end
    endtask
endmodule

// sonda simulada
module altsource_probe #(
    parameter sld_auto_instance_index = "NO",
    parameter sld_instance_index = 0,
    parameter instance_id = "NONE",
    parameter probe_width = 1,
    parameter source_width = 1,
    parameter source_initial_value = "0",
    parameter enable_metastability = "NO"
) (
    input  wire [probe_width-1:0]  probe,
    output reg  [source_width-1:0] source
);
    initial source = 0;
endmodule
