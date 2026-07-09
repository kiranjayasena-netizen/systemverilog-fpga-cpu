`timescale 1ns / 1ps

module tb_cpu_core_multicycle_fsm;

    import cpu_defs_pkg::*;

    localparam logic [2:0] STATE_FETCH     = 3'd0;
    localparam logic [2:0] STATE_DECODE    = 3'd1;

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

    logic [31:0] imem [0:3];

    int unsigned tests_run;
    int unsigned tests_failed;

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

    assign fetched_instruction = imem[instruction_addr[5:2]];

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

    task automatic clock_tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

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

    task automatic check_bit(
        input string case_name,
        input logic  actual,
        input logic  expected
    );
        begin
            tests_run++;

            if (actual !== expected) begin
                tests_failed++;
                $error(
                    "FAIL: %s | expected=%0b got=%0b",
                    case_name,
                    expected,
                    actual
                );
            end else begin
                $display("PASS: %s | value=%0b", case_name, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_multicycle_fsm.vcd");
        $dumpvars(0, tb_cpu_core_multicycle_fsm);

        $display("Starting Phase 8B multi-cycle CPU FSM skeleton simulation...");

        imem[0] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        imem[1] = build_instruction(4'hb, 5'd10, 5'd1, 5'd2, 13'h1fff);
        imem[2] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        imem[3] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);

        rst          = 1'b1;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        clock_tick();

        check_value("reset state is FETCH", {29'd0, state}, {29'd0, STATE_FETCH});
        check_value("reset PC is zero", pc, 32'h0000_0000);
        check_value("reset instruction register is NOP", instruction_reg, 32'h0000_0000);
        check_bit("reset deasserts reg_write", reg_write, 1'b0);
        check_bit("reset deasserts mem_write", mem_write, 1'b0);

        @(negedge clk);
        rst    = 1'b0;
        enable = 1'b1;

        clock_tick();

        check_value("FETCH captures NOP into instruction_reg", instruction_reg, imem[0]);
        check_value("FETCH captures instruction PC", instruction_pc, 32'h0000_0000);
        check_value("FETCH advances PC by 4", pc, 32'h0000_0004);
        check_value("state advances to DECODE after FETCH", {29'd0, state}, {29'd0, STATE_DECODE});

        clock_tick();

        check_value("NOP decode returns to FETCH", {29'd0, state}, {29'd0, STATE_FETCH});
        check_value("NOP opcode decode", {28'd0, opcode_reg}, {28'd0, OP_NOP});
        check_value("NOP rd decode", {27'd0, rd_reg}, 32'd0);
        check_value("NOP rs1 decode", {27'd0, rs1_reg}, 32'd0);
        check_value("NOP rs2 decode", {27'd0, rs2_reg}, 32'd0);
        check_value("NOP imm13 decode", {19'd0, imm13_reg}, 32'd0);
        check_value("NOP imm_ext decode", imm_ext_reg, 32'h0000_0000);
        check_bit("NOP is a valid instruction", valid_instr, 1'b1);
        check_bit("NOP does not assert reg_write", reg_write, 1'b0);
        check_bit("NOP does not assert mem_write", mem_write, 1'b0);

        clock_tick();

        check_value("FETCH captures invalid opcode instruction", instruction_reg, imem[1]);
        check_value("invalid instruction PC captured", instruction_pc, 32'h0000_0004);
        check_value("second FETCH advances PC to 8", pc, 32'h0000_0008);
        check_value("state returns to DECODE for invalid instruction", {29'd0, state}, {29'd0, STATE_DECODE});

        clock_tick();

        check_value("invalid decode returns to FETCH", {29'd0, state}, {29'd0, STATE_FETCH});
        check_value("invalid opcode decode", {28'd0, opcode_reg}, 32'h0000_000b);
        check_value("invalid rd decode", {27'd0, rd_reg}, 32'd10);
        check_value("invalid rs1 decode", {27'd0, rs1_reg}, 32'd1);
        check_value("invalid rs2 decode", {27'd0, rs2_reg}, 32'd2);
        check_value("invalid imm13 decode", {19'd0, imm13_reg}, 32'h0000_1fff);
        check_value("invalid imm_ext sign extension", imm_ext_reg, 32'hffff_ffff);
        check_bit("invalid opcode clears valid_instr", valid_instr, 1'b0);
        check_bit("invalid opcode does not assert reg_write", reg_write, 1'b0);
        check_bit("invalid opcode does not assert mem_write", mem_write, 1'b0);

        clock_tick();

        check_value("third FETCH advances PC to 12", pc, 32'h0000_000c);

        $display("----------------------------------");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------");

        if (tests_failed != 0) begin
            $display("PHASE 8B MULTI-CYCLE FSM TEST FAILED");
            $fatal(1, "%0d of %0d Phase 8B FSM tests failed.", tests_failed, tests_run);
        end

        $display("PHASE 8B MULTI-CYCLE FSM TEST PASSED");
        $finish;
    end

endmodule
