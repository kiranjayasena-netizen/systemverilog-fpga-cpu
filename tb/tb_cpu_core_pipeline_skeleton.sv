import cpu_defs_pkg::*;

module tb_cpu_core_pipeline_skeleton;

    localparam int unsigned IMEM_DEPTH = 64;

    logic        clk;
    logic        rst;
    logic        enable;
    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic [31:0] fetch_request_pc;
    logic        fetch_request_valid;
    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic [3:0]  decoded_opcode;
    logic        decoded_valid;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;

    int tests_run;
    int tests_failed;

    cpu_core_pipeline #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .fetch_pc(fetch_pc),
        .instruction_addr(instruction_addr),
        .fetch_request_pc(fetch_request_pc),
        .fetch_request_valid(fetch_request_valid),
        .if_id_valid(if_id_valid),
        .if_id_pc(if_id_pc),
        .if_id_instruction(if_id_instruction),
        .decoded_opcode(decoded_opcode),
        .decoded_valid(decoded_valid),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_opcode(retire_opcode),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect)
    );

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
        build_instruction = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [31:0] pc_from_word(input int word_index);
        pc_from_word = word_index * 32'd4;
    endfunction

    task automatic step_clock();
        @(posedge clk);
        #1;
    endtask

    task automatic check_true(input string name, input bit condition);
        tests_run++;
        if (condition) begin
            $display("PASS: %s", name);
        end else begin
            tests_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic check_equal32(
        input string       name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        tests_run++;
        if (actual === expected) begin
            $display("PASS: %s actual=0x%08h", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s actual=0x%08h expected=0x%08h", name, actual, expected);
        end
    endtask

    task automatic check_equal4(
        input string      name,
        input logic [3:0] actual,
        input logic [3:0] expected
    );
        tests_run++;
        if (actual === expected) begin
            $display("PASS: %s actual=0x%0h", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s actual=0x%0h expected=0x%0h", name, actual, expected);
        end
    endtask

    task automatic check_equal_int(input string name, input int actual, input int expected);
        tests_run++;
        if (actual == expected) begin
            $display("PASS: %s actual=%0d", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s actual=%0d expected=%0d", name, actual, expected);
        end
    endtask

    task automatic check_control_known(input string prefix);
        check_true($sformatf("%s fetch_request_valid known", prefix), !$isunknown(fetch_request_valid));
        check_true($sformatf("%s if_id_valid known", prefix), !$isunknown(if_id_valid));
        check_true($sformatf("%s decoded_valid known", prefix), !$isunknown(decoded_valid));
        check_true($sformatf("%s retire_valid known", prefix), !$isunknown(retire_valid));
        check_true($sformatf("%s reg_write known", prefix), !$isunknown(reg_write));
        check_true($sformatf("%s mem_write known", prefix), !$isunknown(mem_write));
        check_true($sformatf("%s pc_redirect known", prefix), !$isunknown(pc_redirect));
    endtask

    task automatic check_aligned(input string name, input logic [31:0] value);
        check_true(name, (value[1:0] === 2'b00));
    endtask

    task automatic clear_imem();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            dut.instr_mem_inst.mem[i] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
    endtask

    task automatic reset_core(input string prefix);
        enable = 1'b0;
        rst    = 1'b1;
        repeat (3) begin
            step_clock();
        end

        check_equal32($sformatf("%s reset fetch_pc", prefix), fetch_pc, 32'h0000_0000);
        check_equal32($sformatf("%s reset fetch_request_pc", prefix), fetch_request_pc, 32'h0000_0000);
        check_true($sformatf("%s reset fetch_request_valid clear", prefix), fetch_request_valid === 1'b0);
        check_true($sformatf("%s reset IF/ID valid clear", prefix), if_id_valid === 1'b0);
        check_true($sformatf("%s reset retire_valid clear", prefix), retire_valid === 1'b0);
        check_true($sformatf("%s reset reg_write clear", prefix), reg_write === 1'b0);
        check_true($sformatf("%s reset mem_write clear", prefix), mem_write === 1'b0);
        check_control_known($sformatf("%s reset", prefix));

        rst = 1'b0;
        repeat (2) begin
            step_clock();
        end

        check_equal32($sformatf("%s held fetch_pc after reset release", prefix), fetch_pc, 32'h0000_0000);
        check_true($sformatf("%s no stale IF/ID accept after reset", prefix), if_id_valid === 1'b0);
        check_true($sformatf("%s no stale retirement after reset", prefix), retire_valid === 1'b0);
    endtask

    task automatic run_reset_test();
        $display("");
        $display("---- Phase 12B reset and stale BRAM response test ----");

        clear_imem();
        dut.instr_mem_inst.mem[0] = build_instruction(4'hf, 5'd31, 5'd31, 5'd31, 13'h1fff);
        reset_core("reset test");

        check_true("stale invalid BRAM output was not accepted", if_id_valid === 1'b0);
        check_true("stale invalid BRAM output did not retire", retire_valid === 1'b0);
    endtask

    task automatic run_sequential_fetch_test();
        int retire_counts [0:4];
        int idx;

        $display("");
        $display("---- Phase 12B sequential fetch, NOP and retirement test ----");

        clear_imem();
        dut.instr_mem_inst.mem[0] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        dut.instr_mem_inst.mem[1] = build_instruction(OP_NOP, 5'd1, 5'd0, 5'd0, 13'd1);
        dut.instr_mem_inst.mem[2] = build_instruction(OP_NOP, 5'd2, 5'd0, 5'd0, 13'd2);
        dut.instr_mem_inst.mem[3] = build_instruction(OP_NOP, 5'd3, 5'd0, 5'd0, 13'd3);
        dut.instr_mem_inst.mem[4] = build_instruction(OP_NOP, 5'd4, 5'd0, 5'd0, 13'd4);

        for (int i = 0; i < 5; i++) begin
            retire_counts[i] = 0;
        end

        reset_core("sequential test");
        enable = 1'b1;

        for (int cycle = 0; cycle < 7; cycle++) begin
            step_clock();
            check_control_known($sformatf("sequential cycle %0d", cycle));
            check_aligned($sformatf("sequential cycle %0d fetch_pc aligned", cycle), fetch_pc);
            check_aligned($sformatf("sequential cycle %0d request_pc aligned", cycle), fetch_request_pc);
            check_aligned($sformatf("sequential cycle %0d IF/ID pc aligned", cycle), if_id_pc);

            if (cycle < 5) begin
                check_true($sformatf("request valid cycle %0d", cycle), fetch_request_valid === 1'b1);
                check_equal32(
                    $sformatf("request PC cycle %0d", cycle),
                    fetch_request_pc,
                    pc_from_word(cycle)
                );
            end

            if ((cycle >= 1) && (cycle <= 5)) begin
                idx = cycle - 1;
                check_true($sformatf("IF/ID valid cycle %0d", cycle), if_id_valid === 1'b1);
                check_equal32($sformatf("IF/ID PC cycle %0d", cycle), if_id_pc, pc_from_word(idx));
                check_equal32(
                    $sformatf("IF/ID instruction paired cycle %0d", cycle),
                    if_id_instruction,
                    dut.instr_mem_inst.mem[idx]
                );
                check_true($sformatf("decoded valid cycle %0d", cycle), decoded_valid === 1'b1);
                check_equal4($sformatf("decoded opcode NOP cycle %0d", cycle), decoded_opcode, OP_NOP);
            end

            if (retire_valid) begin
                check_equal4($sformatf("retire opcode NOP cycle %0d", cycle), retire_opcode, OP_NOP);
                check_aligned($sformatf("retire PC aligned cycle %0d", cycle), retire_pc);
                idx = int'(retire_pc >> 2);
                if ((idx >= 0) && (idx < 5)) begin
                    retire_counts[idx]++;
                end else begin
                    check_true($sformatf("unexpected retire PC 0x%08h", retire_pc), 1'b0);
                end
            end
        end

        enable = 1'b0;

        for (int i = 0; i < 5; i++) begin
            check_equal_int($sformatf("NOP at PC %0d retired exactly once", i * 4), retire_counts[i], 1);
        end
    endtask

    task automatic run_invalid_opcode_test();
        int retire_counts [0:3];
        int idx;

        $display("");
        $display("---- Phase 12B invalid opcode bubble test ----");

        clear_imem();
        dut.instr_mem_inst.mem[0] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        dut.instr_mem_inst.mem[1] = build_instruction(4'hf, 5'd9, 5'd1, 5'd2, 13'h123);
        dut.instr_mem_inst.mem[2] = build_instruction(OP_NOP, 5'd2, 5'd0, 5'd0, 13'd2);
        dut.instr_mem_inst.mem[3] = build_instruction(OP_NOP, 5'd3, 5'd0, 5'd0, 13'd3);

        for (int i = 0; i < 4; i++) begin
            retire_counts[i] = 0;
        end

        reset_core("invalid test");
        enable = 1'b1;

        for (int cycle = 0; cycle < 6; cycle++) begin
            step_clock();
            check_control_known($sformatf("invalid cycle %0d", cycle));

            if (cycle == 2) begin
                check_equal32("invalid instruction paired with PC 4", if_id_pc, 32'h0000_0004);
                check_equal4("invalid opcode visible for debug", if_id_instruction[31:28], 4'hf);
                check_true("invalid opcode converted to IF/ID bubble", if_id_valid === 1'b0);
                check_true("invalid opcode decoded_valid low", decoded_valid === 1'b0);
                check_true("invalid opcode has no reg write", reg_write === 1'b0);
                check_true("invalid opcode has no mem write", mem_write === 1'b0);
                check_true("invalid opcode has no PC redirect", pc_redirect === 1'b0);
            end

            if (retire_valid) begin
                idx = int'(retire_pc >> 2);
                if ((idx >= 0) && (idx < 4)) begin
                    retire_counts[idx]++;
                end else begin
                    check_true($sformatf("unexpected invalid-test retire PC 0x%08h", retire_pc), 1'b0);
                end
            end
        end

        enable = 1'b0;

        check_equal_int("NOP PC 0 retired once", retire_counts[0], 1);
        check_equal_int("invalid PC 4 did not retire", retire_counts[1], 0);
        check_equal_int("NOP PC 8 retired once after invalid", retire_counts[2], 1);
        check_equal_int("NOP PC 12 retired once after invalid", retire_counts[3], 1);
    endtask

    task automatic run_enable_pause_test();
        logic [31:0] saved_fetch_pc;
        logic [31:0] saved_request_pc;
        logic        saved_request_valid;
        logic        saved_if_id_valid;
        logic [31:0] saved_if_id_pc;
        logic [31:0] saved_if_id_instruction;

        $display("");
        $display("---- Phase 12B enable/pause test ----");

        clear_imem();
        dut.instr_mem_inst.mem[0] = build_instruction(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        dut.instr_mem_inst.mem[1] = build_instruction(OP_NOP, 5'd1, 5'd0, 5'd0, 13'd1);
        dut.instr_mem_inst.mem[2] = build_instruction(OP_NOP, 5'd2, 5'd0, 5'd0, 13'd2);

        reset_core("pause test");
        enable = 1'b1;
        step_clock();
        step_clock();

        saved_fetch_pc          = fetch_pc;
        saved_request_pc        = fetch_request_pc;
        saved_request_valid     = fetch_request_valid;
        saved_if_id_valid       = if_id_valid;
        saved_if_id_pc          = if_id_pc;
        saved_if_id_instruction = if_id_instruction;

        enable = 1'b0;
        repeat (3) begin
            step_clock();
            check_equal32("pause holds fetch_pc", fetch_pc, saved_fetch_pc);
            check_equal32("pause holds request PC", fetch_request_pc, saved_request_pc);
            check_true("pause holds request valid", fetch_request_valid === saved_request_valid);
            check_true("pause holds IF/ID valid", if_id_valid === saved_if_id_valid);
            check_equal32("pause holds IF/ID PC", if_id_pc, saved_if_id_pc);
            check_equal32("pause holds IF/ID instruction", if_id_instruction, saved_if_id_instruction);
            check_true("pause produces no retirement event", retire_valid === 1'b0);
            check_true("pause produces no register write", reg_write === 1'b0);
            check_true("pause produces no memory write", mem_write === 1'b0);
        end

        enable = 1'b1;
        step_clock();
        check_equal32("resume accepts held response PC 4", if_id_pc, 32'h0000_0004);
        check_equal32("resume keeps instruction paired with PC 4", if_id_instruction, dut.instr_mem_inst.mem[1]);
        check_true("resume retires earlier NOP exactly once", retire_valid === 1'b1);
        check_equal32("resume retired earlier PC 0", retire_pc, 32'h0000_0000);

        step_clock();
        check_true("resume continues sequential IF/ID", if_id_valid === 1'b1);
        check_equal32("resume continues to PC 8", if_id_pc, 32'h0000_0008);
        check_true("resume second NOP retires once", retire_valid === 1'b1);
        check_equal32("resume retired PC 4", retire_pc, 32'h0000_0004);

        enable = 1'b0;
    endtask

    initial begin
        $dumpfile("tb_cpu_core_pipeline_skeleton.vcd");
        $dumpvars(0, tb_cpu_core_pipeline_skeleton);

        rst          = 1'b1;
        enable       = 1'b0;
        tests_run    = 0;
        tests_failed = 0;

        run_reset_test();
        run_sequential_fetch_test();
        run_invalid_opcode_test();
        run_enable_pause_test();

        $display("");
        $display("Tests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("PHASE 12B PIPELINE SKELETON TEST PASSED");
        end else begin
            $display("PHASE 12B PIPELINE SKELETON TEST FAILED");
            $fatal(1, "Phase 12B pipeline skeleton test failed");
        end

        $finish;
    end

endmodule
