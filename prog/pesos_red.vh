// ============================================================
// PESOS DE LA RED NEURONAL 9 -> 16 -> 8 (generado por sw/entrenar_red.py)
// Enteros de 8 bits con signo; sesgos de 32 bits. No editar a mano.
// Exactitud cuantizada sobre el conjunto de entrenamiento: 87.5%
// ============================================================
localparam RED_ENTRADAS = 9, RED_OCULTAS = 16, RED_SALIDAS = 8, RED_SH1 = 2;
reg signed [7:0]  RED_W1 [0:143];   // W1[j*9 + i]
reg signed [31:0] RED_B1 [0:15];
reg signed [7:0]  RED_W2 [0:127];  // W2[k*16 + j]
reg signed [31:0] RED_B2 [0:7];

task cargar_pesos;
    begin
        RED_W1[  0] =   -1; RED_W1[  1] =   17; RED_W1[  2] =  -92; RED_W1[  3] =  -11; RED_W1[  4] =   40; RED_W1[  5] =  -10; RED_W1[  6] =  -76; RED_W1[  7] =   19; RED_W1[  8] =   21;
        RED_W1[  9] =  115; RED_W1[ 10] =    7; RED_W1[ 11] =   35; RED_W1[ 12] =   -5; RED_W1[ 13] =   -6; RED_W1[ 14] =   -5; RED_W1[ 15] =    5; RED_W1[ 16] =    3; RED_W1[ 17] =   86;
        RED_W1[ 18] =    9; RED_W1[ 19] =  -13; RED_W1[ 20] =    0; RED_W1[ 21] =    9; RED_W1[ 22] =   -8; RED_W1[ 23] =    1; RED_W1[ 24] =   10; RED_W1[ 25] =   16; RED_W1[ 26] =    2;
        RED_W1[ 27] =   26; RED_W1[ 28] =  -36; RED_W1[ 29] =   14; RED_W1[ 30] =  -26; RED_W1[ 31] =   31; RED_W1[ 32] =  -17; RED_W1[ 33] =   45; RED_W1[ 34] =  -33; RED_W1[ 35] =   55;
        RED_W1[ 36] =   -4; RED_W1[ 37] =  125; RED_W1[ 38] =   10; RED_W1[ 39] =   16; RED_W1[ 40] =   -1; RED_W1[ 41] =   15; RED_W1[ 42] =    8; RED_W1[ 43] =  127; RED_W1[ 44] =   -6;
        RED_W1[ 45] =  -10; RED_W1[ 46] =   -4; RED_W1[ 47] =  -45; RED_W1[ 48] =   70; RED_W1[ 49] =   57; RED_W1[ 50] =   58; RED_W1[ 51] =  -24; RED_W1[ 52] =  -25; RED_W1[ 53] =    4;
        RED_W1[ 54] =  -16; RED_W1[ 55] =   -6; RED_W1[ 56] =  -12; RED_W1[ 57] =    8; RED_W1[ 58] =   24; RED_W1[ 59] =    4; RED_W1[ 60] =   -9; RED_W1[ 61] =  -12; RED_W1[ 62] =  -11;
        RED_W1[ 63] =  -53; RED_W1[ 64] =  -22; RED_W1[ 65] =   80; RED_W1[ 66] =   -9; RED_W1[ 67] =   29; RED_W1[ 68] =  -14; RED_W1[ 69] =   96; RED_W1[ 70] =  -28; RED_W1[ 71] =  -42;
        RED_W1[ 72] =   71; RED_W1[ 73] =  -32; RED_W1[ 74] =   46; RED_W1[ 75] =  -18; RED_W1[ 76] =   20; RED_W1[ 77] =  -30; RED_W1[ 78] =   50; RED_W1[ 79] =  -27; RED_W1[ 80] =   80;
        RED_W1[ 81] =  -11; RED_W1[ 82] =    1; RED_W1[ 83] =    6; RED_W1[ 84] =    4; RED_W1[ 85] =  -13; RED_W1[ 86] =   -7; RED_W1[ 87] =   -1; RED_W1[ 88] =   -9; RED_W1[ 89] =    4;
        RED_W1[ 90] =   13; RED_W1[ 91] =  -20; RED_W1[ 92] =  -19; RED_W1[ 93] =  -14; RED_W1[ 94] =    4; RED_W1[ 95] =   21; RED_W1[ 96] =   -4; RED_W1[ 97] =    0; RED_W1[ 98] =   -9;
        RED_W1[ 99] =   -6; RED_W1[100] =  -30; RED_W1[101] =    1; RED_W1[102] =   98; RED_W1[103] =   -8; RED_W1[104] =  103; RED_W1[105] =    4; RED_W1[106] =  -15; RED_W1[107] =   -2;
        RED_W1[108] =   14; RED_W1[109] =   28; RED_W1[110] =   13; RED_W1[111] =  -66; RED_W1[112] =   32; RED_W1[113] =  -66; RED_W1[114] =  -19; RED_W1[115] =   32; RED_W1[116] =  -29;
        RED_W1[117] =   13; RED_W1[118] =   23; RED_W1[119] =    1; RED_W1[120] =   31; RED_W1[121] =  -64; RED_W1[122] =   29; RED_W1[123] =   24; RED_W1[124] =   21; RED_W1[125] =   28;
        RED_W1[126] =    4; RED_W1[127] =   16; RED_W1[128] =    0; RED_W1[129] =  -13; RED_W1[130] =  -18; RED_W1[131] =  -13; RED_W1[132] =   11; RED_W1[133] =  -17; RED_W1[134] =   -4;
        RED_W1[135] =   63; RED_W1[136] =   30; RED_W1[137] =   74; RED_W1[138] =   -5; RED_W1[139] =   22; RED_W1[140] =   -3; RED_W1[141] =  -48; RED_W1[142] =   30; RED_W1[143] =  -54;
        RED_B1[0] = 137; RED_B1[1] = 1; RED_B1[2] = -9; RED_B1[3] = -15; RED_B1[4] = 5; RED_B1[5] = 25; RED_B1[6] = 20; RED_B1[7] = 95; RED_B1[8] = 41; RED_B1[9] = 2; RED_B1[10] = 2; RED_B1[11] = 56; RED_B1[12] = 69; RED_B1[13] = -23; RED_B1[14] = 1; RED_B1[15] = -28;
        RED_W2[  0] =  -60; RED_W2[  1] =   60; RED_W2[  2] =   15; RED_W2[  3] =   67; RED_W2[  4] =  -29; RED_W2[  5] =  -16; RED_W2[  6] =  -18; RED_W2[  7] =   13; RED_W2[  8] =   79; RED_W2[  9] =   -9; RED_W2[ 10] =    6; RED_W2[ 11] =  -34; RED_W2[ 12] =  -24; RED_W2[ 13] =  -33; RED_W2[ 14] =    7; RED_W2[ 15] =  -13;
        RED_W2[ 16] =  -44; RED_W2[ 17] =   68; RED_W2[ 18] =   13; RED_W2[ 19] =  -24; RED_W2[ 20] =   47; RED_W2[ 21] =  -34; RED_W2[ 22] =    3; RED_W2[ 23] =  -10; RED_W2[ 24] =   11; RED_W2[ 25] =   13; RED_W2[ 26] =    3; RED_W2[ 27] =   36; RED_W2[ 28] =  -48; RED_W2[ 29] =   77; RED_W2[ 30] =   -9; RED_W2[ 31] =  -23;
        RED_W2[ 32] =   24; RED_W2[ 33] =  -42; RED_W2[ 34] =   -2; RED_W2[ 35] =    8; RED_W2[ 36] =   89; RED_W2[ 37] =   44; RED_W2[ 38] =    4; RED_W2[ 39] =  -35; RED_W2[ 40] =  -61; RED_W2[ 41] =   11; RED_W2[ 42] =    1; RED_W2[ 43] =   26; RED_W2[ 44] =  -68; RED_W2[ 45] =   -6; RED_W2[ 46] =    1; RED_W2[ 47] =    4;
        RED_W2[ 48] =   25; RED_W2[ 49] =  -28; RED_W2[ 50] =    3; RED_W2[ 51] =  -38; RED_W2[ 52] =  -75; RED_W2[ 53] =   72; RED_W2[ 54] =   21; RED_W2[ 55] =    4; RED_W2[ 56] =  -33; RED_W2[ 57] =    4; RED_W2[ 58] =   11; RED_W2[ 59] =   91; RED_W2[ 60] =  -27; RED_W2[ 61] =   -1; RED_W2[ 62] =   -5; RED_W2[ 63] =   -5;
        RED_W2[ 64] =   74; RED_W2[ 65] =  -43; RED_W2[ 66] =   -4; RED_W2[ 67] =  -11; RED_W2[ 68] =   61; RED_W2[ 69] =  -28; RED_W2[ 70] =    7; RED_W2[ 71] =   -5; RED_W2[ 72] =  -51; RED_W2[ 73] =   -6; RED_W2[ 74] =  -16; RED_W2[ 75] =  -69; RED_W2[ 76] =   55; RED_W2[ 77] =   -7; RED_W2[ 78] =   -6; RED_W2[ 79] =  -39;
        RED_W2[ 80] =  -32; RED_W2[ 81] =  -49; RED_W2[ 82] =   -6; RED_W2[ 83] =    1; RED_W2[ 84] =  -42; RED_W2[ 85] =  -28; RED_W2[ 86] =    0; RED_W2[ 87] =  127; RED_W2[ 88] =   20; RED_W2[ 89] =   15; RED_W2[ 90] =   18; RED_W2[ 91] =  -16; RED_W2[ 92] =   10; RED_W2[ 93] =    1; RED_W2[ 94] =    7; RED_W2[ 95] =    2;
        RED_W2[ 96] =   88; RED_W2[ 97] =   60; RED_W2[ 98] =    5; RED_W2[ 99] =   15; RED_W2[100] =  -78; RED_W2[101] =    7; RED_W2[102] =   -3; RED_W2[103] =  -67; RED_W2[104] =   54; RED_W2[105] =    3; RED_W2[106] =   12; RED_W2[107] =  -31; RED_W2[108] =    0; RED_W2[109] =   -3; RED_W2[110] =    0; RED_W2[111] =  -22;
        RED_W2[112] =  -16; RED_W2[113] =   46; RED_W2[114] =    5; RED_W2[115] =  -47; RED_W2[116] =   37; RED_W2[117] =  -37; RED_W2[118] =  -26; RED_W2[119] =  -18; RED_W2[120] =  -11; RED_W2[121] =   -7; RED_W2[122] =  -21; RED_W2[123] =  -47; RED_W2[124] =   49; RED_W2[125] =  -23; RED_W2[126] =    5; RED_W2[127] =  109;
        RED_B2[0] = -406; RED_B2[1] = -422; RED_B2[2] = -404; RED_B2[3] = 158; RED_B2[4] = 705; RED_B2[5] = 225; RED_B2[6] = 378; RED_B2[7] = -234;
    end
endtask

// Plantillas de las 8 clases (valor de SW[8:0]) para el testbench
function [8:0] red_plantilla; input integer k;
    case (k)
        0: red_plantilla = 9'h155;  // X
        1: red_plantilla = 9'h1EF;  // O (anillo)
        2: red_plantilla = 9'h0BA;  // +
        3: red_plantilla = 9'h038;  // - (barra)
        4: red_plantilla = 9'h092;  // | (palo)
        5: red_plantilla = 9'h054;  // / diagonal
        6: red_plantilla = 9'h111;  // \ diagonal
        7: red_plantilla = 9'h097;  // T
        default: red_plantilla = 9'h000;
    endcase
endfunction
