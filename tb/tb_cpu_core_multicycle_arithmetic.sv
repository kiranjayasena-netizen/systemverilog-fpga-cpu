`timescale 1ns / 1ps

module tb_cpu_core_multicycle_arithmetic;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_WRITEBACK = 3'd4;
    localparam int unsigned PROGRAM_CYCLES = 50;
    localparam int unsigned EXPECTED_REG_WRITES = 9;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] fetched_instruction;
    logic [31:0] instruction_addr;
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

    logic [31:0] imem [0:31];

    int unsigned tests_run;
    int unsigned tests_failed;
    int unsigned reg_write_pulses;
    int unsigned bad_reg_write_pulses;
    int unsigned mem_write_pulses;

    cpu_core_multicycle dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .fetched_instruction(fetched_instruction),
        .instruction_addr(instruction_addr),
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
        .alu_result(alu_result)
    );

    assign fetched_instruction = imem[instruction_addr[6:2]];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] build_instruction(
        input logic [3:0]  opcode,
        input logic [4:0]  rd,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [12:0] imm13
    );
        begin
            build_instruction = {opcode, rd, rs1, rs2, imm13};
        end
    endfunction

    function automatic logic opcode_is_arithmetic(input logic [3:0] opcode);
        begin
            unique case (opcode)
                OP_ADD,
                OP_SUB,
                OP_AND,
                OP_OR,
                OP_XOR,
                OP_ADDI: opcode_is_arithmetic = 1'b1;
                default: opcode_is_arithmetic = 1'b0;
            endcase
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

    task automatic step_and_monitor;
        logic [2:0] state_before;
        logic [3:0] opcode_before;
        logic [4:0] rd_before;
        begin
            state_before  = state;
            opcode_before = opcode_reg;
            rd_before     = rd_reg;

            @(posedge clk);
            #1;

            if (!rst && enable) begin
                if (mem_write !== 1'b0) begin
                    mem_write_pulses++;
                    $error("FAIL: mem_write asserted during arithmetic-only test");
                end

                if (reg_write) begin
                    reg_write_pulses++;

                    if ((state_before != STATE_WRITEBACK) ||
                        !opcode_is_arithmetic(opcode_before) ||
                        (rd_before == 5'd0)) begin
                        bad_reg_write_pulses++;
                        $error(
                            "FAIL: unexpected reg_write pulse | state_before=%0d opcode=0x%0h rd=%0d",
                            state_before,
                            opcode_before,
                            rd_before
                        );
                    end
                end
            end
        end
    endtask

    task automatic load_program;
        int unsigned i;
        begin
            for (i = 0; i < 32; i++) begin
                imem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end

            imem[0]  = build_instruction(OP_ADDI, 5'd1, 5'd0, 5'd0, 13'd10);
            imem[1]  = build_instruction(OP_ADDI, 5'd2, 5'd0, 5'd0, 13'd20);
            imem[2]  = build_instruction(OP_ADD,  5'd3, 5'd1, 5'd2, 13'd0);
            imem[3]  = build_instruction(OP_SUB,  5'd4, 5'd2, 5'd1, 13'd0);
            imem[4]  = build_instruction(OP_AND,  5'd5, 5'd1, 5'd2, 13'd0);
            imem[5]  = build_instruction(OP_OR,   5'd6, 5'd1, 5'd2, 13'd0);
            imem[6]  = build_instruction(OP_XOR,  5'd7, 5'd1, 5'd2, 13'd0);
            imem[7]  = build_instruction(OP_ADDI, 5'd8, 5'd0, 5'd0, 13'h1fff);
            imem[8]  = build_instruction(OP_ADD,  5'd9, 5'd8, 5'd1, 13'd0);
            imem[9]  = build_instruction(OP_ADDI, 5'd0, 5'd0, 5'd0, 13'd123);
            imem[10] = build_instruction(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_arithmetic.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_arithmetic);

        $display("Starting Phase 8C multi-cycle CPU arithmetic simulation...");

        load_program();

        rst                  = 1'b1;
        enable               = 1'b0;
        tests_run            = 0;
        tests_failed         = 0;
        reg_write_pulses     = 0;
        bad_reg_write_pulses = 0;
        mem_write_pulses     = 0;

        @(posedge clk);
        #1;

        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;

        repeat (PROGRAM_CYCLES) begin
            step_and_monitor();
        end

        @(negedge clk);
        enable = 1'b0;
        #1;

        check_value("x0 remains hardwired to zero", dut.regs[0], 32'd0);
        check_value("ADDI x1, x0, 10", dut.regs[1], 32'd10);
        check_value("ADDI x2, x0, 20", dut.regs[2], 32'd20);
        check_value("ADD x3, x1, x2", dut.regs[3], 32'd30);
        check_value("SUB x4, x2, x1", dut.regs[4], 32'd10);
        check_value("AND x5, x1, x2", dut.regs[5], 32'd0);
        check_value("OR x6, x1, x2", dut.regs[6], 32'd30);
        check_value("XOR x7, x1, x2", dut.regs[7], 32'd30);
        check_value("ADDI x8, x0, -1", dut.regs[8], 32'hffff_ffff);
        check_value("ADD x9, x8, x1", dut.regs[9], 32'd9);
        check_value(
            "reg_write pulse count for non-x0 arithmetic writebacks",
            reg_write_pulses,
            EXPECTED_REG_WRITES
        );
        check_value("reg_write only during arithmetic WRITEBACK", bad_reg_write_pulses, 32'd0);
        check_value("mem_write never asserted", mem_write_pulses, 32'd0);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 8C MULTI-CYCLE ARITHMETIC TEST FAILED");
            $fatal(1, "%0d of %0d Phase 8C arithmetic tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 8C MULTI-CYCLE ARITHMETIC TEST PASSED");
        $finish;
    end

endmodule
