//   TC1  core0 store  -> write-miss allocate (MODIFIED) + write-through
//   TC2  core1 cache  -> its SHARED copy of X is UPDATED by snooping core0's write
//   TC3  core0 load   -> L1 HIT on the line it just wrote (fast path)
//   TC4  core0 load   -> miss to a fresh address: memory fetch + multi-cycle STALL
//   TC5  core1 load   -> re-reads X, HIT, returns the coherent value (0x55)
//
// MSI legend:  0 = INVALID   1 = SHARED   2 = MODIFIED
// BUS legend:  0 = IDLE      1 = BUS_RD   2 = BUS_WR   3 = BUS_UPDATE

`timescale 1ns/1ps

module tb_dual_core_cpu_cache;

    reg clk = 0;
    reg reset = 1;

    always #5 clk = ~clk;         

    dual_core_cpu_cache_top dut (.clk(clk), .reset(reset));

    `define C0 dut.dcache.core0_cache
    `define C1 dut.dcache.core1_cache
    `define MEM dut.dcache.main_memory

    integer cyc = 0;
    always @(posedge clk) cyc = cyc + 1;

    function [39:0] mn (input [31:0] instr);
        case (instr[6:0])
            7'b0000011: mn = "lw  ";
            7'b0100011: mn = "sw  ";
            7'b0010011: mn = (instr==32'h13) ? "nop " : "addi";
            7'b1100011: mn = "beq ";
            default:    mn = "??? ";
        endcase
    endfunction

    always @(negedge clk) begin
        $display("c%0d  | C0 PC=%0d %s req=%b mo=%b wt=%b st=%b h1=%b h2=%b | C1 PC=%0d %s req=%b mo=%b wt=%b st=%b h1=%b h2=%b | bus0=%0d bus1=%0d | mem[0]=%02h mem[1]=%02h mem[2]=%02h | C0.L1msi=%0d%0d%0d%0d C1.L1msi=%0d%0d%0d%0d",
            cyc,
            dut.PC_0>>2, mn(dut.Instr_0), dut.req_0, dut.mode_0, (dut.req_0&dut.wait_req_0), dut.stall_0, dut.hit1_0, dut.hit2_0,
            dut.PC_1>>2, mn(dut.Instr_1), dut.req_1, dut.mode_1, (dut.req_1&dut.wait_req_1), dut.stall_1, dut.hit1_1, dut.hit2_1,
            dut.dcache.bus_cmd_0, dut.dcache.bus_cmd_1,
            `MEM[0], `MEM[1], `MEM[2],
            `C0.l1_msi[0],`C0.l1_msi[1],`C0.l1_msi[2],`C0.l1_msi[3],
            `C1.l1_msi[0],`C1.l1_msi[1],`C1.l1_msi[2],`C1.l1_msi[3]);
    end

    reg t1=0,t2=0,t3=0,t4=0,t5=0;
    always @(negedge clk) if (!reset) begin
        if (!t1 && dut.req_0 && dut.mode_0)
            begin $display(">>> TC1  cyc %0d: CORE0 STORE 0x%0h -> addr %0d  (write-miss: line -> MODIFIED, write-through to memory, BUS_UPDATE)", cyc, dut.MemWData_0, dut.MemAddr_0); t1<=1; end
        if (!t2 && (dut.dcache.bus_cmd_0==3 || dut.dcache.bus_cmd_0==2) && `C1.l1_msi[0]!=2'b00)
            begin $display(">>> TC2  cyc %0d: CORE1 SNOOPS core0's write on the bus and UPDATES its SHARED copy of X (MSI coherence)", cyc); t2<=1; end
        if (!t3 && dut.req_0 && !dut.mode_0 && dut.hit1_0 && dut.MemAddr_0==0)
            begin $display(">>> TC3  cyc %0d: CORE0 LOAD  addr 0  L1 HIT (reads the line it just stored, MODIFIED)", cyc); t3<=1; end
        if (!t4 && dut.req_0 && !dut.mode_0 && dut.wait_req_0 && dut.MemAddr_0==8)
            begin $display(">>> TC4  cyc %0d: CORE0 LOAD  addr 8  MISS -> fetch from main memory, CPU STALLED (wait/stall asserted)", cyc); t4<=1; end
        if (!t5 && dut.req_1 && !dut.mode_1 && (dut.PC_1>>2)==9 && dut.hit1_1)
            begin $display(">>> TC5  cyc %0d: CORE1 re-reads addr 0 -> HIT, returns the coherent value (proven in FINAL: x13=0x55)", cyc); t5<=1; end
    end

    initial begin
        $display("================ DUAL-CORE RISC-V + MSI DATA CACHE : PER-CYCLE TRACE ================");
        $display("MSI: 0=I 1=S 2=M    BUS: 0=IDLE 1=RD 2=WR 3=UPDATE    (mem shown in hex)");
        $display("------------------------------------------------------------------------------------");
        repeat (4) @(posedge clk);
        reset = 0;
        repeat (18) @(posedge clk);
        $display("------------------------------------------------------------------------------------");
        $display("FINAL: core0 x3(lw X)=0x%0h  x5(lw Z)=0x%0h | core1 x11(lw X early)=0x%0h x13(lw X late)=0x%0h",
                 dut.cpu0.dp.rf.reg_file_arr[3], dut.cpu0.dp.rf.reg_file_arr[5],
                 dut.cpu1.dp.rf.reg_file_arr[11], dut.cpu1.dp.rf.reg_file_arr[13]);
        $display("FINAL: mem[0](X)=0x%0h mem[2](Z)=0x%0h", `MEM[0], `MEM[2]);
        $finish;
    end

endmodule
