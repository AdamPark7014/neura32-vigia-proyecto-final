`timescale 1ns / 1ps
// ============================================================
// MODELOS DE SIMULACION de las megafunciones de Quartus que usan la vista
// en la PC y el cargador de programas (no son hardware).
// sld_virtual_jtag trae tareas con las que el banco de pruebas hace lo
// mismo que quartus_stp desde la PC:
//   poner_ir(valor)     carga el registro de instruccion virtual
//   correr_dr(n)        corre n bits del registro de datos; lo que sale queda en datos[]
//   escribir_dr(n, v)   corre n bits metiendo el valor v (primero el bit 0)
// TCK va a 6 MHz, como el USB-Blaster.
// ============================================================
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
            pulso;                                   // Select-DR
            pulso;                                   // entra a Capture-DR
            virtual_state_cdr = 1; pulso; virtual_state_cdr = 0;
            virtual_state_sdr = 1;
            for (i = 0; i < n; i = i + 1) begin
                datos[i] = tdo;                      // la PC lee TDO antes del flanco que corre
                pulso;
            end
            virtual_state_sdr = 0;
            n_datos = n;
            virtual_state_udr = 1; pulso; virtual_state_udr = 0;
            pulso;                                   // Run-Test/Idle
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

// La sonda de fuentes y pruebas (solo se usa en la prueba de la camara)
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
