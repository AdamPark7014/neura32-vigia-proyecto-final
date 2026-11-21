// ============================================================
// NEURA-32 — definiciones compartidas (opcodes RISC-V, seleccion de
// resultado y tipos de inmediato)
// ============================================================
`ifndef NEURA32_DEFS_VH
`define NEURA32_DEFS_VH

// Opcodes RV32I / RV32M / Zicsr / custom-0 (Xneura)
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_BRANCH   7'b1100011
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OP_IMM      7'b0010011
`define OP_R        7'b0110011
`define OP_MISC_MEM 7'b0001111
`define OP_SYSTEM   7'b1110011
`define OP_CUSTOM0  7'b0001011   // instrucciones propias de la clase: nota, passb, sla
`define OP_CUSTOM1  7'b0101011   // propias del proyecto (Xneura): abs, sgt, clamp

// Instruccion NOP (addi x0, x0, 0)
`define NOP         32'h00000013

// Seleccion del resultado que llega al banco de registros
`define RES_ALU     2'd0
`define RES_MEM     2'd1
`define RES_PC4     2'd2
`define RES_CSR     2'd3

// Tipo de inmediato
`define INM_I       3'd0
`define INM_S       3'd1
`define INM_B       3'd2
`define INM_U       3'd3
`define INM_J       3'd4
`define INM_Z       3'd5   // uimm de 5 bits de csrrwi/csrrsi/csrrci

// Operacion CSR
`define CSR_RW      2'd1
`define CSR_RS      2'd2
`define CSR_RC      2'd3

// Direcciones CSR implementadas
`define CSR_MSCRATCH  12'h340
`define CSR_MCYCLE    12'hB00
`define CSR_MINSTRET  12'hB02
`define CSR_MCYCLEH   12'hB80
`define CSR_MINSTRETH 12'hB82
`define CSR_CYCLE     12'hC00
`define CSR_TIME      12'hC01
`define CSR_INSTRET   12'hC02
`define CSR_CYCLEH    12'hC80
`define CSR_TIMEH     12'hC81
`define CSR_INSTRETH  12'hC82
`define CSR_MISA      12'h301
`define CSR_MVENDORID 12'hF11
`define CSR_MARCHID   12'hF12
`define CSR_MIMPID    12'hF13
`define CSR_MHARTID   12'hF14

// misa: MXL=1 (32 bits), I, M, X (extension no estandar)
`define VALOR_MISA    32'h40801100
`define VALOR_MARCHID 32'h4E455541   // "NEUA"
`define VALOR_MIMPID  32'h20261009   // fecha de la version

`endif
