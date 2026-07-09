`timescale 1ns / 1ps

module tb_cpu_core_multicycle_branch_jump;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_EXECUTE = 3'd2;
    localparam int unsigned PROGRAM_CYCLES = 160;

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
    logic [31:0] memory_read_data;

    logic [31:0] imem [0:255];

    int unsigned tests_run;
    int unsigned tests_failed;
    int unsigned control_reg_write_pulses;
    int unsigned control_mem_write_pulses;
    int unsigned control_bad_pc_updates;
    int unsigned beq_taken_count;
    int unsigned beq_not_taken_count;
    int unsigned jump_forward_count;
    int unsigned jump_backward_count;

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
        .alu_result(alu_result),
        .memory_read_data(memory_read_data)
    );

    assign fetched_instruction = imem[instruction_addr[9:2]];

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
        logic [2:0]  state_before;
        logic [3:0]  opcode_before;
        logic [31:0] instruction_pc_before;
        begin
            state_before          = state;
            opcode_before         = opcode_reg;
            instruction_pc_before = instruction_pc;

            @(posedge clk);
            #1;

            if (!rst && enable && (state_before == STATE_EXECUTE) &&
                ((opcode_before == OP_BEQ) || (opcode_before == OP_JUMP))) begin
                if (reg_write) begin
                    control_reg_write_pulses++;
                    $error("FAIL: control instruction asserted reg_write");
                end

                if (mem_write) begin
                    control_mem_write_pulses++;
                    $error("FAIL: control instruction asserted mem_write");
                end

                if (opcode_before == OP_BEQ) begin
                    unique case (instruction_pc_before)
                        32'd8: begin
                            if (pc !== 32'd16) begin
                                control_bad_pc_updates++;
                                $error("FAIL: first BEQ should branch to PC 16, got PC %0d", pc);
                            end
                            beq_taken_count++;
                        end

                        32'd28: begin
                            if (pc !== 32'd32) begin
                                control_bad_pc_updates++;
                                $error("FAIL: not-taken BEQ should fall through to PC 32, got PC %0d", pc);
                            end
                            beq_not_taken_count++;
                        end

                        32'd76: begin
                            if (pc === 32'd84) begin
                                beq_taken_count++;
                            end else if (pc === 32'd80) begin
                                beq_not_taken_count++;
                            end else begin
                                control_bad_pc_updates++;
                                $error("FAIL: loop BEQ produced unexpected PC %0d", pc);
                            end
                        end

                        default: begin
                            control_bad_pc_updates++;
                            $error("FAIL: unexpected BEQ at instruction PC %0d", instruction_pc_before);
                        end
                    endcase
                end else begin
                    unique case (instruction_pc_before)
                        32'd44: begin
                            if (pc !== 32'd52) begin
                                control_bad_pc_updates++;
                                $error("FAIL: forward JUMP should branch to PC 52, got PC %0d", pc);
                            end
                            jump_forward_count++;
                        end

                        32'd80: begin
                            if (pc !== 32'd68) begin
                                control_bad_pc_updates++;
                                $error("FAIL: backward JUMP should branch to PC 68, got PC %0d", pc);
                            end
                            jump_backward_count++;
                        end

                        default: begin
                            control_bad_pc_updates++;
                            $error("FAIL: unexpected JUMP at instruction PC %0d", instruction_pc_before);
                        end
                    endcase
                end
            end
        end
    endtask

    task automatic load_program;
        int unsigned i;
        begin
            for (i = 0; i < 256; i++) begin
                imem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
            end

            imem[0]  = build_instruction(OP_ADDI,  5'd1,  5'd0,  5'd0,  13'd5);
            imem[1]  = build_instruction(OP_ADDI,  5'd2,  5'd0,  5'd0,  13'd5);
            imem[2]  = build_instruction(OP_BEQ,   5'd0,  5'd1,  5'd2,  13'd2);
            imem[3]  = build_instruction(OP_ADDI,  5'd3,  5'd0,  5'd0,  13'd99);
            imem[4]  = build_instruction(OP_ADDI,  5'd3,  5'd0,  5'd0,  13'd42);
            imem[5]  = build_instruction(OP_ADDI,  5'd4,  5'd0,  5'd0,  13'd1);
            imem[6]  = build_instruction(OP_ADDI,  5'd5,  5'd0,  5'd0,  13'd2);
            imem[7]  = build_instruction(OP_BEQ,   5'd0,  5'd4,  5'd5,  13'd2);
            imem[8]  = build_instruction(OP_ADDI,  5'd6,  5'd0,  5'd0,  13'd77);
            imem[9]  = build_instruction(OP_ADDI,  5'd7,  5'd0,  5'd0,  13'd88);
            imem[10] = build_instruction(OP_ADDI,  5'd8,  5'd0,  5'd0,  13'd11);
            imem[11] = build_instruction(OP_JUMP,  5'd0,  5'd0,  5'd0,  13'd2);
            imem[12] = build_instruction(OP_ADDI,  5'd9,  5'd0,  5'd0,  13'd99);
            imem[13] = build_instruction(OP_ADDI,  5'd9,  5'd0,  5'd0,  13'd22);
            imem[14] = build_instruction(OP_ADDI,  5'd10, 5'd0,  5'd0,  13'd0);
            imem[15] = build_instruction(OP_ADDI,  5'd11, 5'd0,  5'd0,  13'd3);
            imem[16] = build_instruction(OP_ADDI,  5'd12, 5'd0,  5'd0,  13'd1);
            imem[17] = build_instruction(OP_ADD,   5'd10, 5'd10, 5'd12, 13'd0);
            imem[18] = build_instruction(OP_SUB,   5'd11, 5'd11, 5'd12, 13'd0);
            imem[19] = build_instruction(OP_BEQ,   5'd0,  5'd11, 5'd0,  13'd2);
            imem[20] = build_instruction(OP_JUMP,  5'd0,  5'd0,  5'd0,  13'h1ffd);
            imem[21] = build_instruction(OP_STORE, 5'd0,  5'd0,  5'd10, 13'd0);
            imem[22] = build_instruction(OP_NOP,   5'd0,  5'd0,  5'd0,  13'd0);
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_branch_jump.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_branch_jump);

        $display("Starting Phase 8E multi-cycle CPU branch/jump simulation...");

        load_program();

        rst                      = 1'b1;
        enable                   = 1'b0;
        tests_run                = 0;
        tests_failed             = 0;
        control_reg_write_pulses = 0;
        control_mem_write_pulses = 0;
        control_bad_pc_updates   = 0;
        beq_taken_count          = 0;
        beq_not_taken_count      = 0;
        jump_forward_count       = 0;
        jump_backward_count      = 0;

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
        check_value("ADDI x1, x0, 5", dut.regs[1], 32'd5);
        check_value("ADDI x2, x0, 5", dut.regs[2], 32'd5);
        check_value("taken BEQ skips x3 = 99", dut.regs[3], 32'd42);
        check_value("ADDI x4, x0, 1", dut.regs[4], 32'd1);
        check_value("ADDI x5, x0, 2", dut.regs[5], 32'd2);
        check_value("not-taken BEQ allows x6 = 77", dut.regs[6], 32'd77);
        check_value("fall-through after not-taken BEQ writes x7", dut.regs[7], 32'd88);
        check_value("ADDI x8, x0, 11", dut.regs[8], 32'd11);
        check_value("JUMP skips x9 = 99", dut.regs[9], 32'd22);
        check_value("loop accumulator x10", dut.regs[10], 32'd3);
        check_value("loop counter x11", dut.regs[11], 32'd0);
        check_value("loop step x12", dut.regs[12], 32'd1);
        check_value("STORE after loop writes data memory word 0", dut.data_mem[0], 32'd3);
        check_value("x3 is not skipped value 99", (dut.regs[3] == 32'd99), 32'd0);
        check_value("x9 is not skipped value 99", (dut.regs[9] == 32'd99), 32'd0);
        check_value("BEQ/JUMP never assert reg_write", control_reg_write_pulses, 32'd0);
        check_value("BEQ/JUMP never assert mem_write", control_mem_write_pulses, 32'd0);
        check_value("control-flow PC updates match expected targets", control_bad_pc_updates, 32'd0);
        check_value("BEQ taken count", beq_taken_count, 32'd2);
        check_value("BEQ not-taken count", beq_not_taken_count, 32'd3);
        check_value("forward JUMP count", jump_forward_count, 32'd1);
        check_value("backward JUMP count", jump_backward_count, 32'd2);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 8E MULTI-CYCLE BRANCH/JUMP TEST FAILED");
            $fatal(1, "%0d of %0d Phase 8E branch/jump tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 8E MULTI-CYCLE BRANCH/JUMP TEST PASSED");
        $finish;
    end

endmodule
