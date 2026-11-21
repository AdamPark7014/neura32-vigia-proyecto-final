`timescale 1ns / 1ps
// Prueba rapida del maestro SCCB contra el modelo de la camara
module tb_sccb;
    reg clk = 0, rst = 1;
    always #20 clk = ~clk;
    wire sioc, siod_bajo, reset_n, hecho, siod;
    wire [7:0] pid, ver, ext_dato;
    wire ext_libre;
    reg  ext_wr = 0, ext_rd = 0;
    reg  [7:0] ext_reg = 0, ext_val = 0;
    pullup (siod);
    assign siod = siod_bajo ? 1'b0 : 1'bz;
    sccb_maestro #(.CICLOS_CUARTO(8), .CICLOS_MS(50)) dut (
        .ext_wr(ext_wr), .ext_rd(ext_rd), .ext_reg(ext_reg), .ext_val(ext_val), .ext_dato(ext_dato), .ext_libre(ext_libre),
        .clk(clk), .rst(rst), .sioc(sioc), .siod_bajo(siod_bajo), .siod_in(siod),
        .cam_reset_n(reset_n), .pid(pid), .ver(ver), .hecho(hecho));
    wire pclk, href, vsync; wire [7:0] d;
    modelo_ov7670 #(.ANCHO(16), .ALTO(8)) camara (.xclk(clk), .resetb(reset_n), .pwdn(1'b0),
        .pclk(pclk), .href(href), .vsync(vsync), .d(d), .sioc(sioc), .siod(siod));
    initial begin
        #200 rst = 0;
        wait (hecho);
        $display("PID=%h VER=%h  CLKRC=%h COM7=%h TSLB=%h COM13=%h COM15=%h escrituras=%0d lecturas=%0d",
                 pid, ver, camara.regs[8'h11], camara.regs[8'h12], camara.regs[8'h3A], camara.regs[8'h3D],
                 camara.regs[8'h40], camara.escrituras, camara.lecturas);
        if (pid == 8'h76 && ver == 8'h73 && camara.regs[8'h11] == 8'h01 && camara.regs[8'h3A] == 8'h04)
            $display("SCCB OK"); else $display("SCCB FALLA");
        // ordenes de fuera: escribir 0x55 = 0x3C y leerlo de vuelta
        @(posedge clk); ext_reg = 8'h55; ext_val = 8'h3C; ext_wr = 1; @(posedge clk); ext_wr = 0;
        @(posedge clk); wait (ext_libre); @(posedge clk);
        ext_rd = 1; @(posedge clk); ext_rd = 0; @(posedge clk); wait (ext_libre); @(posedge clk);
        $display("externo: registro 55 = %h, leido %h  %s", camara.regs[8'h55], ext_dato,
                 (camara.regs[8'h55] == 8'h3C && ext_dato == 8'h3C) ? "OK" : "FALLA");
        $finish;
    end
    initial #50000000 begin $display("TIEMPO AGOTADO"); $finish; end
endmodule
