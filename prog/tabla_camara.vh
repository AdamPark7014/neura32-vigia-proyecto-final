// Tabla de registros de la camara OV7670: {registro, valor}
// La escribe sw/generar_tabla_camara.py a partir de prog/ajustes_camara.txt
        emitir(32'h1101);   // CLKRC: preescala entre 2
        emitir(32'h6B4A);   // DBLV: PLL x4
        emitir(32'h1716);   // HSTART (ventana de 320 x 240)
        emitir(32'h1804);   // HSTOP
        emitir(32'h3224);   // HREF: bits bajos de inicio y fin
        emitir(32'h1902);   // VSTRT
        emitir(32'h1A7A);   // VSTOP
        emitir(32'h030A);   // VREF
        emitir(32'h1200);   // COM7
        emitir(32'h3A04);   // TSLB
        emitir(32'h8C00);   // RGB444 apagado
        emitir(32'h0400);   // COM1
        emitir(32'h40C0);   // COM15: salida 00..FF
        emitir(32'h0C04);   // COM3: escalado dentro del sensor (promedia 2 x 2 pixeles)
        emitir(32'h3E19);   // COM14: escalado manual y PCLK entre 2
        emitir(32'h703A);   // SCALING_XSC
        emitir(32'h7135);   // SCALING_YSC
        emitir(32'h7211);   // SCALING_DCWCTR: reducir a la mitad en x y en y
        emitir(32'h73F1);   // SCALING_PCLK_DIV: PCLK entre 2
        emitir(32'hA202);   // SCALING_PCLK_DELAY
        emitir(32'h1500);   // COM10
        emitir(32'h7A20);
        emitir(32'h7B10);
        emitir(32'h7C1E);
        emitir(32'h7D35);
        emitir(32'h7E5A);
        emitir(32'h7F69);
        emitir(32'h8076);
        emitir(32'h8180);
        emitir(32'h8288);
        emitir(32'h838F);
        emitir(32'h8496);
        emitir(32'h85A3);
        emitir(32'h86AF);
        emitir(32'h87C4);
        emitir(32'h88D7);
        emitir(32'h89E8);
        emitir(32'h13E0);   // COM8: AEC rapido, paso sin limite, filtro de bandas
        emitir(32'h0000);   // GAIN
        emitir(32'h1000);   // AECH
        emitir(32'h0D40);   // COM4
        emitir(32'h1438);   // COM9: tope de ganancia 16x
        emitir(32'hA505);   // BD50MAX
        emitir(32'hAB07);   // BD60MAX
        emitir(32'h2495);   // AEW: limite alto de brillo estable
        emitir(32'h2533);   // AEB: limite bajo
        emitir(32'h26E3);   // VPT: zona de ajuste rapido
        emitir(32'h9F78);   // HAECC1
        emitir(32'hA068);   // HAECC2
        emitir(32'hA103);
        emitir(32'hA6D8);   // HAECC3
        emitir(32'hA7D8);   // HAECC4
        emitir(32'hA8F0);   // HAECC5
        emitir(32'hA990);   // HAECC6
        emitir(32'hAA94);   // HAECC7
        emitir(32'h13E5);   // COM8: + AGC + AEC
        emitir(32'h0E61);   // COM5
        emitir(32'h0F4B);   // COM6
        emitir(32'h1602);
        emitir(32'h1E07);   // MVFP (los bits 5 y 4 son espejo y volteo vertical)
        emitir(32'h2102);
        emitir(32'h2291);
        emitir(32'h2907);
        emitir(32'h330B);
        emitir(32'h350B);
        emitir(32'h371D);
        emitir(32'h3871);
        emitir(32'h392A);
        emitir(32'h3C78);   // COM12
        emitir(32'h4D40);
        emitir(32'h4E20);
        emitir(32'h6900);   // GFIX
        emitir(32'h7410);
        emitir(32'h8D4F);
        emitir(32'h8E00);
        emitir(32'h8F00);
        emitir(32'h9000);
        emitir(32'h9100);
        emitir(32'h9600);
        emitir(32'h9A00);
        emitir(32'hB084);
        emitir(32'hB10C);
        emitir(32'hB20E);
        emitir(32'hB382);
        emitir(32'hB80A);
        emitir(32'h430A);
        emitir(32'h44F0);
        emitir(32'h4534);
        emitir(32'h4658);
        emitir(32'h4728);
        emitir(32'h483A);
        emitir(32'h5988);
        emitir(32'h5A88);
        emitir(32'h5B44);
        emitir(32'h5C67);
        emitir(32'h5D49);
        emitir(32'h5E0E);
        emitir(32'h6C0A);
        emitir(32'h6D55);
        emitir(32'h6E11);
        emitir(32'h6F9F);
        emitir(32'h6A40);
        emitir(32'h0140);   // BLUE
        emitir(32'h0260);   // RED
        emitir(32'h13E7);   // COM8: + AWB
        emitir(32'h4F80);
        emitir(32'h5080);
        emitir(32'h5100);
        emitir(32'h5222);
        emitir(32'h535E);
        emitir(32'h5480);
        emitir(32'h589E);
        emitir(32'h4108);   // COM16: ganancia AWB
        emitir(32'h3F00);   // EDGE
        emitir(32'h7505);   // limite bajo del realce de bordes
        emitir(32'h76E1);   // limite alto + correccion de pixeles malos
        emitir(32'h4C00);   // DNSTH: umbral de reduccion de ruido
        emitir(32'h7701);   // desplazamiento de la reduccion de ruido
        emitir(32'h3DC0);   // COM13: gamma + saturacion automatica
        emitir(32'h4B09);
        emitir(32'hC960);
        emitir(32'h4138);   // COM16: realce de bordes y reduccion de ruido automaticos
        emitir(32'h5640);   // contraste
        emitir(32'h3411);
        emitir(32'h3B12);   // COM11: deteccion automatica 50/60 Hz, exposicion menor a una banda
        emitir(32'hA488);
        emitir(32'h9600);
        emitir(32'h9730);
        emitir(32'h9820);
        emitir(32'h9930);
        emitir(32'h9A84);
        emitir(32'h9B29);
        emitir(32'h9C03);
        emitir(32'h9D4C);
        emitir(32'h9E3F);
        emitir(32'h7804);
        emitir(32'h7901);
        emitir(32'hC8F0);
        emitir(32'h790F);
        emitir(32'hC800);
        emitir(32'h7910);
        emitir(32'hC87E);
        emitir(32'h790A);
        emitir(32'hC880);
        emitir(32'h790B);
        emitir(32'hC801);
        emitir(32'h790C);
        emitir(32'hC80F);
        emitir(32'h790D);
        emitir(32'hC820);
        emitir(32'h7909);
        emitir(32'hC880);
        emitir(32'h7902);
        emitir(32'hC8C0);
        emitir(32'h7903);
        emitir(32'hC840);
        emitir(32'h7905);
        emitir(32'hC830);
        emitir(32'h7926);
