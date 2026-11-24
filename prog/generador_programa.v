`timescale 1ns / 1ps

// generador
module generador_programa #(
    parameter PROGRAMA = 3,
    parameter PALABRAS = 4096
) ();
    reg [31:0] memoria [0:PALABRAS-1];

    `include "codificador_riscv.vh"
    `include "pesos_red.vh"
    `include "pesos_vigia.vh"
    `include "programa_red_neuronal.vh"
    `include "programa_prueba_isa.vh"
    `include "programa_vigia.vh"
    `include "programa_demo.vh"

    integer i;
    initial begin
        for (i = 0; i < PALABRAS; i = i + 1) memoria[i] = NOP_WORD;
        cargar_pesos;
        cargar_pesos_vigia;
        case (PROGRAMA)
            1: begin pasada_ens = 0; programa_red(0);    pasada_ens = 1; programa_red(1);    end
            2: begin pasada_ens = 0; programa_isa(0);    pasada_ens = 1; programa_isa(1);    end
            3: begin pasada_ens = 0; programa_vigia(0);  pasada_ens = 1; programa_vigia(1);  end
            4: begin pasada_ens = 0; programa_demo(0);   pasada_ens = 1; programa_demo(1);   end
            default: ;
        endcase
        if (pc_ens > PALABRAS * 4) begin
            $display("ENSAMBLADOR: el programa (%0d bytes) no cabe en la ROM", pc_ens);
            errores_ens = errores_ens + 1;
        end
        if (errores_ens != 0) $display("ENSAMBLADOR: %0d errores", errores_ens);
    end
endmodule
