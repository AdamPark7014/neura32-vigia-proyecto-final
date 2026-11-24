`timescale 1ns / 1ps
module tb_programa_ab_c;
    reg clk = 1'b0;
    reg rst = 1'b0;
    always #10 clk = ~clk;

    wire [31:0] result_out;
    wire        halted, illegal;

    riscv_neura #(.A_INIT(32'd7), .B_INIT(32'd5), .C_INIT(32'd5),
                  .INIT_FILE("docs/base-clase/programa_ab_c.txt")) dut (
        .clk(clk), .rst(rst), .result_out(result_out),
        .io_addr_pre(), .io_addr(), .io_wdata(), .io_we(), .io_re(), .io_rdata(32'd0),
        .load_we(1'b0), .load_addr(12'd0), .load_data(32'd0),
        .halted(halted), .illegal(illegal), .cycles(), .instrs()
    );

    integer pruebas = 0, errores = 0;
    task revisar;
        input            bien;
        input [8*48-1:0] nombre;
        begin
            pruebas = pruebas + 1;
            if (bien) $display("  ok    %0s", nombre);
            else begin errores = errores + 1; $display("  FALLA %0s", nombre); end
        end
    endtask

    // nombre de la fase
    function [8*10-1:0] fase;
        input [3:0] s;
        case (s)
            4'd0: fase = "FETCH";     4'd1: fase = "DECODE";    4'd2: fase = "EXEC_R";
            4'd3: fase = "EXEC_DIV";  4'd4: fase = "EXEC_BR";   4'd5: fase = "JUMP_WAIT";
            4'd6: fase = "MEM_ADDR";  4'd7: fase = "MEM_READ";  4'd8: fase = "MEM_WRITE";
            4'd9: fase = "WRITEBACK"; default: fase = "HALT";
        endcase
    endfunction

    integer n = 0;
    always @(negedge clk)
        if (rst && n < 9) begin
            $display("  ciclo %0d  %0s  PC=%02h  IR=%08h  resultado=%0d", n, fase(dut.state), dut.pc, dut.instr, result_out);
            n = n + 1;
        end

    initial begin
        $display("=== El programa de la clase, (a + b) * c, en NEURA-32 ===");
        repeat (3) @(posedge clk);
        rst = 1'b1;
        repeat (8) @(posedge clk);
        #1;
        revisar(dut.RF.regs[4] == 32'd12, "x4 = a + b = 12");
        revisar(dut.RF.regs[5] == 32'd60, "x5 = (a + b) * c = 60");
        revisar(dut.RF.regs[1] == 32'd7 && dut.RF.regs[2] == 32'd5 && dut.RF.regs[3] == 32'd5, "a, b y c no cambian");
        $display("PRUEBAS: %0d  ERRORES: %0d", pruebas, errores);
        $finish;
    end
endmodule
