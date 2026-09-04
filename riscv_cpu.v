// top module of riscv used
// riscv_cpu.v - single-cycle RISC-V CPU Processor

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

wire        ALUSrc, RegWrite, Jump, Jalr, Zero;  // (edited): Jalr
wire [1:0]  ResultSrc, ImmSrc;
wire [3:0]  ALUControl; // (edited)

controller  c   (Instr[6:0], Instr[14:12], Instr[30], Zero, Result[0], // (edited) : Result[0]
                ResultSrc, MemWrite, PCSrc, ALUSrc, RegWrite, Jump, Jalr,  // (edited): Jalr
                ImmSrc, ALUControl);

datapath    dp  (clk, reset, ResultSrc, PCSrc,
                ALUSrc, RegWrite, ImmSrc, ALUControl, Jalr,// (edited): Jalr
                Zero, PC, Instr, Mem_WrAddr, Mem_WrData, ReadData, Result);

endmodule
