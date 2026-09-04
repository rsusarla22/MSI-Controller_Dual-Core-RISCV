//INTERFACE BETWEEN 2 RV32I CORES AND AN MSI WRITE-INVALIDATE WRITE-THROUGH BASED CACHE CONTROLLER
// NOTE: software is restricted to lw / sw memory ops (no sub-word lb/lh/sb/sh).
// -----------------------------------------------------------------------------

module dual_core_cpu_cache_top #(
    parameter ADDR_BITS    = 11,
    parameter DATA_BITS    = 32,
    parameter BLOCK_BYTES  = 4,
    parameter BLOCK_OFFSET = 2
)(
    input  wire clk,
    input  wire reset
);

    localparam OP_LOAD  = 7'b0000011; // lw
    localparam OP_STORE = 7'b0100011; // sw

    wire [31:0] PC_0, Instr_0;
    wire        MemWrite_0;
    wire [31:0] MemAddr_0, MemWData_0, Result_0;

    wire [31:0] PC_1, Instr_1;
    wire        MemWrite_1;
    wire [31:0] MemAddr_1, MemWData_1, Result_1;

    wire [DATA_BITS-1:0] cache_dout_0, cache_dout_1;
    wire                 hit1_0, hit2_0, wait_req_0;
    wire                 hit1_1, hit2_1, wait_req_1;

    wire is_load_0  = (Instr_0[6:0] == OP_LOAD);
    wire is_store_0 = (Instr_0[6:0] == OP_STORE);
    wire req_0      = is_load_0 | is_store_0;   // cache engaged only for lw/sw
    wire mode_0     = MemWrite_0;               // 1 = write (sw), 0 = read (lw)

    wire is_load_1  = (Instr_1[6:0] == OP_LOAD);
    wire is_store_1 = (Instr_1[6:0] == OP_STORE);
    wire req_1      = is_load_1 | is_store_1;
    wire mode_1     = MemWrite_1;


    reg  load_armed_0, load_armed_1;

    wire stall_0 = req_0 ? (is_store_0 ? wait_req_0
                                       : (wait_req_0 | ~load_armed_0))
                         : 1'b0;
    wire stall_1 = req_1 ? (is_store_1 ? wait_req_1
                                       : (wait_req_1 | ~load_armed_1))
                         : 1'b0;

    wire cpu_clk_en_0 = ~stall_0;
    wire cpu_clk_en_1 = ~stall_1;

    always @(posedge clk) begin
        if (reset) begin
            load_armed_0 <= 1'b0;
            load_armed_1 <= 1'b0;
        end else begin
            // Core 0
            if (cpu_clk_en_0)                 load_armed_0 <= 1'b0; // core advanced -> clear
            else if (is_load_0 & ~wait_req_0) load_armed_0 <= 1'b1; // data valid next cycle
            // Core 1
            if (cpu_clk_en_1)                 load_armed_1 <= 1'b0;
            else if (is_load_1 & ~wait_req_1) load_armed_1 <= 1'b1;
        end
    end

    wire gated_clk_0, gated_clk_1;
    clk_gate cg0 (.clk(clk), .en(cpu_clk_en_0), .gclk(gated_clk_0));
    clk_gate cg1 (.clk(clk), .en(cpu_clk_en_1), .gclk(gated_clk_1));

    riscv_cpu cpu0 (
        .clk(gated_clk_0), .reset(reset),
        .PC(PC_0), .Instr(Instr_0),
        .MemWrite(MemWrite_0),
        .Mem_WrAddr(MemAddr_0), .Mem_WrData(MemWData_0),
        .ReadData(cache_dout_0), .Result(Result_0)
    );
    instr_mem #(.INIT_FILE("rv32i_test_core0.hex")) imem0 (
        .instr_addr(PC_0), .instr(Instr_0)
    );

    riscv_cpu cpu1 (
        .clk(gated_clk_1), .reset(reset),
        .PC(PC_1), .Instr(Instr_1),
        .MemWrite(MemWrite_1),
        .Mem_WrAddr(MemAddr_1), .Mem_WrData(MemWData_1),
        .ReadData(cache_dout_1), .Result(Result_1)
    );
    instr_mem #(.INIT_FILE("rv32i_test_core1.hex")) imem1 (
        .instr_addr(PC_1), .instr(Instr_1)
    );

    dual_core_cache_system #(
        .ADDR_BITS   (ADDR_BITS),
        .DATA_BITS   (DATA_BITS),
        .BLOCK_BYTES (BLOCK_BYTES),
        .BLOCK_OFFSET(BLOCK_OFFSET)
    ) dcache (
        .clk(clk), .rst(reset),
        .addr_0    (MemAddr_0[ADDR_BITS-1:0]),
        .data_in_0 (MemWData_0),
        .mode_0    (mode_0),
        .req_0     (req_0),
        .data_out_0(cache_dout_0),
        .hit1_0(hit1_0), .hit2_0(hit2_0), .wait_req_0(wait_req_0),
        .addr_1    (MemAddr_1[ADDR_BITS-1:0]),
        .data_in_1 (MemWData_1),
        .mode_1    (mode_1),
        .req_1     (req_1),
        .data_out_1(cache_dout_1),
        .hit1_1(hit1_1), .hit2_1(hit2_1), .wait_req_1(wait_req_1)
    );

endmodule


module clk_gate (
    input  wire clk,
    input  wire en,
    output wire gclk
);
    reg en_latch;
    always @(*) begin
        if (~clk)            
            en_latch = en;
    end
    assign gclk = clk & en_latch;
endmodule
