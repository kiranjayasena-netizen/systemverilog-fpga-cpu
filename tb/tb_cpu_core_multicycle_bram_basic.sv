`timescale 1ns / 1ps

module tb_cpu_core_multicycle_bram_basic;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH_ADDR     = 3'd0;
    localparam logic [2:0] STATE_FETCH_CAPTURE  = 3'd1;
    localparam logic [2:0] STATE_DECODE         = 3'd2;
    localparam logic [2:0] STATE_EXECUTE        = 3'd3;
    localparam logic [2:0] STATE_MEMORY_ADDR    = 3'd4;
    localparam logic [2:0] STATE_MEMORY_CAPTURE = 3'd5;
    localparam logic [2:0] STATE_WRITEBACK      = 3'd6;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [2:0]  state;
    logic [31:0] pc;
    logic [31:0] instruction_reg;
    logic [31:0] instruction_pc;
    logic [3:0]  opcode_reg;
    logic [4:0]  rd_reg;
    logic [4:0]  rs1_reg;
    logic [4:0]  rs2_reg;
    logic [12:0] imm13_reg;
    logic [31:0] imm_ext_reg;
    logic        valid_instr;
    logic        reg_write;
    logic        mem_write;
    logic [31:0] alu_result;
    logic [31:0] memory_read_data;
    logic [31:0] instruction_addr;
    logic [31:0] data_addr;

    int unsigned tests_run;
    int unsigned tests_failed;
    int unsigned store_write_pulses;
    int unsigned invalid_reg_write_pulses;
    int unsigned invalid_mem_write_pulses;
    bit          mem_write_wrong_state;
    bit          reg_write_wrong_state;

    cpu_core_multicycle_bram dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .state(state),
        .pc(pc),
        .instruction_reg(instruction_reg),
        .instruction_pc(instruction_pc),
        .opcode_reg(opcode_reg),
        .rd_reg(rd_reg),
        .rs1_reg(rs1_reg),
        .rs2_reg(rs2_reg),
        .imm13_reg(imm13_reg),
        .imm_ext_reg(imm_ext_reg),
        .valid_instr(valid_instr),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_result(alu_result),
        .memory_read_data(memory_read_data),
        .instruction_addr(instruction_addr),
        .data_addr(data_addr)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] build_instruction(
        input logic [3:0]  build_opcode,
        input logic [4:0]  build_rd,
        input logic [4:0]  build_rs1,
        input logic [4:0]  build_rs2,
        input logic [12:0] build_imm13
    );
        begin
            build_instruction = {
                build_opcode,
                build_rd,
                build_rs1,
                build_rs2,
                build_imm13
            };
        end
    endfunction

    task automatic check_value(
        input string       case_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected=0x%08h got=0x%08h",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s | value=0x%08h", case_name, actual);
            end
        end
    endtask

    task automatic clock_tick;
        logic [2:0] state_before;
        logic [3:0] opcode_before;
        logic [31:0] instruction_before;
        begin
            state_before       = state;
            opcode_before      = opcode_reg;
            instruction_before = instruction_reg;

            if (mem_write) begin
                store_write_pulses++;

                if ((state != STATE_MEMORY_ADDR) || (opcode_reg != OP_STORE)) begin
                    mem_write_wrong_state = 1'b1;
                end
            end

            if (reg_write && (state != STATE_WRITEBACK)) begin
                reg_write_wrong_state = 1'b1;
            end

            @(posedge clk);
            #1;

            if ((state_before == STATE_DECODE) &&
                ((instruction_before[31:28] == 4'hb) || (instruction_before[31:28] == 4'hf))) begin
                if (reg_write) begin
                    invalid_reg_write_pulses++;
                end

                if (mem_write) begin
                    invalid_mem_write_pulses++;
                end
            end
        end
    endtask

    task automatic preload_program;
        begin
            for (int i = 0; i < 256; i++) begin
                dut.instr_mem_inst.mem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end

            dut.instr_mem_inst.mem[0]  = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
            dut.instr_mem_inst.mem[1]  = build_instruction(OP_ADDI,  5'd1, 5'd0, 5'd0, 13'd5);
            dut.instr_mem_inst.mem[2]  = build_instruction(OP_ADDI,  5'd2, 5'd0, 5'd0, 13'd7);
            dut.instr_mem_inst.mem[3]  = build_instruction(OP_ADD,   5'd3, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[4]  = build_instruction(OP_SUB,   5'd4, 5'd3, 5'd1, 13'd0);
            dut.instr_mem_inst.mem[5]  = build_instruction(OP_AND,   5'd7, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[6]  = build_instruction(OP_OR,    5'd8, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[7]  = build_instruction(OP_XOR,   5'd9, 5'd1, 5'd2, 13'd0);
            dut.instr_mem_inst.mem[8]  = build_instruction(OP_STORE, 5'd0, 5'd0, 5'd3, 13'd0);
            dut.instr_mem_inst.mem[9]  = build_instruction(OP_LOAD,  5'd5, 5'd0, 5'd0, 13'd0);
            dut.instr_mem_inst.mem[10] = build_instruction(OP_ADDI,  5'd0, 5'd0, 5'd0, 13'd99);
            dut.instr_mem_inst.mem[11] = build_instruction(4'hf,     5'd6, 5'd0, 5'd3, 13'd4);
            dut.instr_mem_inst.mem[12] = build_instruction(OP_NOP,   5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_bram_basic.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_bram_basic);

        $display("Starting Phase 10F BRAM-aware multi-cycle CPU basic simulation...");

        rst                    = 1'b1;
        enable                 = 1'b0;
        tests_run              = 0;
        tests_failed           = 0;
        store_write_pulses     = 0;
        invalid_reg_write_pulses = 0;
        invalid_mem_write_pulses = 0;
        mem_write_wrong_state  = 1'b0;
        reg_write_wrong_state  = 1'b0;

        preload_program();

        @(posedge clk);
        #1;
        check_value("reset state is FETCH_ADDR", {29'd0, state}, {29'd0, STATE_FETCH_ADDR});
        check_value("reset PC is zero", pc, 32'h0000_0000);
        check_value("reset instruction register is NOP", instruction_reg, 32'h0000_0000);
        check_value("reset valid_instr is low", {31'd0, valid_instr}, 32'd0);

        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;

        clock_tick();
        check_value("first active state is FETCH_CAPTURE", {29'd0, state}, {29'd0, STATE_FETCH_CAPTURE});
        check_value("FETCH_ADDR drives PC to instruction memory", instruction_addr, 32'h0000_0000);

        clock_tick();
        check_value("FETCH_CAPTURE moves to DECODE", {29'd0, state}, {29'd0, STATE_DECODE});
        check_value("instruction register captures NOP after synchronous read", instruction_reg, 32'h0000_0000);
        check_value("instruction_pc captures first PC", instruction_pc, 32'h0000_0000);
        check_value("PC advances after instruction capture", pc, 32'h0000_0004);

        repeat (58) begin
            clock_tick();
        end

        @(negedge clk);
        enable = 1'b0;
        #1;

        check_value("x0 remains hardwired to zero", dut.regs[0], 32'd0);
        check_value("ADDI x1, x0, 5", dut.regs[1], 32'd5);
        check_value("ADDI x2, x0, 7", dut.regs[2], 32'd7);
        check_value("ADD x3, x1, x2", dut.regs[3], 32'd12);
        check_value("SUB x4, x3, x1", dut.regs[4], 32'd7);
        check_value("AND x7, x1, x2", dut.regs[7], 32'd5);
        check_value("OR x8, x1, x2", dut.regs[8], 32'd7);
        check_value("XOR x9, x1, x2", dut.regs[9], 32'd2);
        check_value("BRAM data memory word 0 after STORE", dut.data_mem_inst.mem[0], 32'd12);
        check_value("LOAD x5, [x0 + 0]", dut.regs[5], 32'd12);
        check_value("invalid opcode does not write x6", dut.regs[6], 32'd0);
        check_value("STORE mem_write pulse count", store_write_pulses, 32'd1);
        check_value("mem_write only during STORE MEMORY_ADDR", {31'd0, mem_write_wrong_state}, 32'd0);
        check_value("reg_write only during WRITEBACK", {31'd0, reg_write_wrong_state}, 32'd0);
        check_value("invalid opcode never asserts reg_write", invalid_reg_write_pulses, 32'd0);
        check_value("invalid opcode never asserts mem_write", invalid_mem_write_pulses, 32'd0);
        check_value("final PC advanced past program", pc, 32'h0000_0034);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 10F BRAM-AWARE CPU BASIC TEST FAILED");
            $fatal(1, "%0d of %0d Phase 10F tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 10F BRAM-AWARE CPU BASIC TEST PASSED");
        $finish;
    end

endmodule
