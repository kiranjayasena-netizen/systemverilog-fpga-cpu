import cpu_defs_pkg::*;

module tb_cpu_core_pipeline_mac;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;

    logic clk;

    logic        focused_rst;
    logic        focused_enable;
    logic        focused_retire_valid;
    logic [3:0]  focused_retire_opcode;
    logic        focused_retire_mem_write;
    logic [31:0] focused_load_use_stalls;
    logic [31:0] focused_retired_instructions;

    logic        baseline_rst;
    logic        baseline_enable;
    logic        baseline_retire_valid;
    logic        baseline_retire_mem_write;
    logic [31:0] baseline_retire_write_data;
    logic [31:0] baseline_total_cycles;

    logic        mac_rst;
    logic        mac_enable;
    logic        mac_retire_valid;
    logic        mac_retire_mem_write;
    logic [31:0] mac_retire_write_data;
    logic [31:0] mac_total_cycles;

    int tests_run;
    int tests_failed;
    int focused_retired_seen;

    cpu_core_pipeline_full #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) focused_dut (
        .clk(clk),
        .rst(focused_rst),
        .enable(focused_enable),
        .retire_valid(focused_retire_valid),
        .retire_opcode(focused_retire_opcode),
        .retire_mem_write(focused_retire_mem_write),
        .retired_instructions(focused_retired_instructions),
        .load_use_stall_cycles(focused_load_use_stalls)
    );

    cpu_core_pipeline_full #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("programs/ai_dot_product_baseline.mem")
    ) baseline_dut (
        .clk(clk),
        .rst(baseline_rst),
        .enable(baseline_enable),
        .retire_valid(baseline_retire_valid),
        .retire_write_data(baseline_retire_write_data),
        .retire_mem_write(baseline_retire_mem_write),
        .total_cycles(baseline_total_cycles)
    );

    cpu_core_pipeline_full #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("programs/ai_dot_product_mac.mem")
    ) mac_dut (
        .clk(clk),
        .rst(mac_rst),
        .enable(mac_enable),
        .retire_valid(mac_retire_valid),
        .retire_write_data(mac_retire_write_data),
        .retire_mem_write(mac_retire_mem_write),
        .total_cycles(mac_total_cycles)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] instr(
        input logic [3:0]  opcode,
        input logic [4:0]  rd,
        input logic [4:0]  rs1,
        input logic [4:0]  rs2,
        input logic [12:0] imm13
    );
        instr = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [12:0] imm13_signed(input int value);
        imm13_signed = value[12:0];
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
            $display("PASS: %s | value=0x%08h", name, actual);
        end else begin
            tests_failed++;
            $display("FAIL: %s | actual=0x%08h expected=0x%08h", name, actual, expected);
        end
    endtask

    task automatic clear_focused_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) begin
            focused_dut.instr_mem_inst.mem[i] = instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0);
        end
        for (int i = 0; i < DMEM_DEPTH; i++) begin
            focused_dut.data_mem_inst.mem[i] = 32'h0000_0000;
        end
    endtask

    task automatic reset_focused();
        focused_enable = 1'b0;
        focused_rst = 1'b1;
        repeat (4) step_clock();
        focused_rst = 1'b0;
        repeat (2) step_clock();
        check_equal32("reset clears x0", focused_dut.regs[0], 32'h0000_0000);
        check_equal32("reset clears x31", focused_dut.regs[31], 32'h0000_0000);
        check_equal32("reset clears retired count", focused_retired_instructions, 32'd0);
        check_true("reset leaves retirement invalid", focused_retire_valid === 1'b0);
    endtask

    task automatic prepare_focused();
        clear_focused_memories();
        reset_focused();
    endtask

    task automatic put_focused(input int word_index, input logic [31:0] instruction);
        focused_dut.instr_mem_inst.mem[word_index] = instruction;
    endtask

    task automatic run_focused(input int expected_retired, input int max_cycles);
        int cycles;
        focused_retired_seen = 0;
        focused_enable = 1'b1;
        cycles = 0;
        while ((focused_retired_seen < expected_retired) && (cycles < max_cycles)) begin
            step_clock();
            if (focused_retire_valid) begin
                focused_retired_seen++;
                check_true(
                    "focused test retires only base ISA or MAC8",
                    opcode_is_valid(focused_retire_opcode) || (focused_retire_opcode == OP_MAC8)
                );
            end
            cycles++;
        end
        focused_enable = 1'b0;
        step_clock();
        check_equal32("focused retired instruction count", focused_retired_seen, expected_retired);
        check_true("focused test completed before timeout", cycles < max_cycles);
    endtask

    task automatic run_mac_arithmetic_cases();
        $display("\n---- MAC8 signed arithmetic and forwarding ----");
        prepare_focused();

        put_focused(0,  instr(OP_ADDI, 5'd1,  5'd0,  5'd0, imm13_signed(3)));
        put_focused(1,  instr(OP_ADDI, 5'd2,  5'd0,  5'd0, imm13_signed(4)));
        put_focused(2,  instr(OP_ADDI, 5'd3,  5'd0,  5'd0, imm13_signed(10)));
        put_focused(3,  instr(OP_MAC8, 5'd3,  5'd1,  5'd2, 13'd0));
        put_focused(4,  instr(OP_ADDI, 5'd4,  5'd0,  5'd0, imm13_signed(-3)));
        put_focused(5,  instr(OP_ADDI, 5'd5,  5'd0,  5'd0, imm13_signed(-4)));
        put_focused(6,  instr(OP_ADDI, 5'd6,  5'd0,  5'd0, imm13_signed(0)));
        put_focused(7,  instr(OP_MAC8, 5'd6,  5'd4,  5'd5, 13'd0));
        put_focused(8,  instr(OP_ADDI, 5'd7,  5'd0,  5'd0, imm13_signed(-3)));
        put_focused(9,  instr(OP_ADDI, 5'd8,  5'd0,  5'd0, imm13_signed(4)));
        put_focused(10, instr(OP_ADDI, 5'd9,  5'd0,  5'd0, imm13_signed(0)));
        put_focused(11, instr(OP_MAC8, 5'd9,  5'd7,  5'd8, 13'd0));
        put_focused(12, instr(OP_ADDI, 5'd10, 5'd0,  5'd0, imm13_signed(0)));
        put_focused(13, instr(OP_MAC8, 5'd10, 5'd7, 5'd10, 13'd0));
        put_focused(14, instr(OP_MAC8, 5'd0,  5'd1,  5'd2, 13'd0));
        put_focused(15, instr(OP_NOP,  5'd0,  5'd0,  5'd0, 13'd0));

        run_focused(16, 80);
        check_equal32("positive MAC8", focused_dut.regs[3], 32'd22);
        check_equal32("negative times negative MAC8", focused_dut.regs[6], 32'd12);
        check_equal32("mixed-sign MAC8", focused_dut.regs[9], 32'hffff_fff4);
        check_equal32("zero operand MAC8", focused_dut.regs[10], 32'd0);
        check_equal32("MAC8 write to x0 ignored", focused_dut.regs[0], 32'd0);
    endtask

    task automatic run_mac_boundaries_and_dependencies();
        $display("\n---- MAC8 boundaries and dependency forwarding ----");
        prepare_focused();

        put_focused(0,  instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(127)));
        put_focused(1,  instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(-128)));
        put_focused(2,  instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(0)));
        put_focused(3,  instr(OP_MAC8, 5'd3, 5'd1, 5'd2, 13'd0));
        put_focused(4,  instr(OP_MAC8, 5'd3, 5'd2, 5'd2, 13'd0));
        put_focused(5,  instr(OP_ADDI, 5'd4, 5'd0, 5'd0, imm13_signed(1)));
        put_focused(6,  instr(OP_ADDI, 5'd5, 5'd0, 5'd0, imm13_signed(2)));
        put_focused(7,  instr(OP_MAC8, 5'd4, 5'd3, 5'd5, 13'd0));
        put_focused(8,  instr(OP_MAC8, 5'd4, 5'd1, 5'd5, 13'd0));
        put_focused(9,  instr(OP_STORE,5'd0, 5'd0, 5'd4, imm13_signed(0)));
        put_focused(10, instr(OP_NOP, 5'd0, 5'd0, 5'd0, 13'd0));

        run_focused(11, 80);
        check_equal32("INT8 extrema accumulate without product truncation", focused_dut.regs[3], 32'd128);
        // x3 holds 128, whose low INT8 lane is 8'h80 (-128), so the two
        // dependent MAC8 operations produce 1 + (-128*2) + (127*2) = -1.
        check_equal32("MAC result forwarded as next source and accumulator", focused_dut.regs[4], 32'hffff_ffff);
        check_equal32("MAC result forwarded to STORE", focused_dut.data_mem_inst.mem[0], 32'hffff_ffff);
    endtask

    task automatic run_mac_load_hazards();
        $display("\n---- MAC8 load-use hazards ----");
        prepare_focused();
        focused_dut.data_mem_inst.mem[16] = 32'hffff_fffe;
        focused_dut.data_mem_inst.mem[17] = 32'd5;
        focused_dut.data_mem_inst.mem[18] = 32'd10;

        put_focused(0,  instr(OP_ADDI, 5'd2,  5'd0,  5'd0, imm13_signed(4)));
        put_focused(1,  instr(OP_ADDI, 5'd3,  5'd0,  5'd0, imm13_signed(1)));
        put_focused(2,  instr(OP_ADDI, 5'd10, 5'd0,  5'd0, imm13_signed(64)));
        put_focused(3,  instr(OP_LOAD,  5'd1,  5'd10, 5'd0, imm13_signed(0)));
        put_focused(4,  instr(OP_MAC8, 5'd3,  5'd1,  5'd2, 13'd0));
        put_focused(5,  instr(OP_LOAD,  5'd2,  5'd10, 5'd0, imm13_signed(4)));
        put_focused(6,  instr(OP_MAC8, 5'd3,  5'd1,  5'd2, 13'd0));
        put_focused(7,  instr(OP_LOAD,  5'd3,  5'd10, 5'd0, imm13_signed(8)));
        put_focused(8,  instr(OP_MAC8, 5'd3,  5'd1,  5'd2, 13'd0));
        put_focused(9,  instr(OP_NOP,  5'd0,  5'd0,  5'd0, 13'd0));

        run_focused(10, 100);
        check_equal32("load-to-rs1/rs2/accumulator MAC8 result", focused_dut.regs[3], 32'd0);
        check_equal32("three MAC8 load-use stalls", focused_load_use_stalls, 32'd3);
    endtask

    task automatic run_mac_overflow();
        $display("\n---- MAC8 defined modulo-2^32 overflow ----");
        prepare_focused();
        focused_dut.regs[1] = 32'd1;
        focused_dut.regs[2] = 32'd1;
        focused_dut.regs[3] = 32'h7fff_ffff;
        focused_dut.regs[4] = 32'hffff_ffff;
        focused_dut.regs[5] = 32'h8000_0000;

        put_focused(0, instr(OP_MAC8, 5'd3, 5'd1, 5'd2, 13'd0));
        put_focused(1, instr(OP_MAC8, 5'd5, 5'd4, 5'd1, 13'd0));
        put_focused(2, instr(OP_NOP,  5'd0, 5'd0, 5'd0, 13'd0));

        run_focused(3, 40);
        check_equal32("positive accumulator overflow wraps", focused_dut.regs[3], 32'h8000_0000);
        check_equal32("negative accumulator overflow wraps", focused_dut.regs[5], 32'h7fff_ffff);
    endtask

    task automatic run_dot_product_integration();
        int baseline_retired;
        int mac_retired;
        int baseline_cycles_to_store;
        int mac_cycles_to_store;
        int timeout_cycles;
        bit baseline_done;
        bit mac_done;

        $display("\n---- Existing-ISA versus MAC8 dot product ----");
        baseline_enable = 1'b0;
        mac_enable = 1'b0;
        baseline_rst = 1'b1;
        mac_rst = 1'b1;
        repeat (4) step_clock();
        baseline_rst = 1'b0;
        mac_rst = 1'b0;
        repeat (2) step_clock();

        baseline_retired = 0;
        mac_retired = 0;
        baseline_cycles_to_store = 0;
        mac_cycles_to_store = 0;
        baseline_done = 1'b0;
        mac_done = 1'b0;
        baseline_enable = 1'b1;
        mac_enable = 1'b1;

        timeout_cycles = 0;
        while (!(baseline_done && mac_done) && (timeout_cycles < 120)) begin
            step_clock();

            if (baseline_retire_valid && !baseline_done) begin
                baseline_retired++;
                if (baseline_retire_mem_write) begin
                    baseline_done = 1'b1;
                    baseline_cycles_to_store = baseline_total_cycles;
                    baseline_enable = 1'b0;
                end
            end

            if (mac_retire_valid && !mac_done) begin
                mac_retired++;
                if (mac_retire_mem_write) begin
                    mac_done = 1'b1;
                    mac_cycles_to_store = mac_total_cycles;
                    mac_enable = 1'b0;
                end
            end

            timeout_cycles++;
        end

        check_true("baseline benchmark completed", baseline_done);
        check_true("MAC8 benchmark completed", mac_done);
        check_equal32("baseline dot-product result", baseline_dut.data_mem_inst.mem[0], 32'hffff_fff2);
        check_equal32("MAC8 dot-product result", mac_dut.data_mem_inst.mem[0], 32'hffff_fff2);
        check_equal32(
            "baseline and MAC8 numerical results match",
            baseline_dut.data_mem_inst.mem[0],
            mac_dut.data_mem_inst.mem[0]
        );
        check_equal32("baseline retired instructions through STORE", baseline_retired, 32'd24);
        check_equal32("MAC8 retired instructions through STORE", mac_retired, 32'd14);

        $display("DOT PRODUCT PERFORMANCE RESULT");
        $display("  Baseline retired instructions: %0d", baseline_retired);
        $display("  MAC8 retired instructions:     %0d", mac_retired);
        $display("  Baseline cycles through STORE: %0d", baseline_cycles_to_store);
        $display("  MAC8 cycles through STORE:     %0d", mac_cycles_to_store);
        if (mac_cycles_to_store != 0) begin
            $display(
                "  Measured cycle speed-up:        %0.3f x",
                real'(baseline_cycles_to_store) / real'(mac_cycles_to_store)
            );
        end
    endtask

    initial begin
        $dumpfile("tb_cpu_core_pipeline_mac.vcd");
        $dumpvars(0, tb_cpu_core_pipeline_mac);

        tests_run = 0;
        tests_failed = 0;
        focused_rst = 1'b1;
        focused_enable = 1'b0;
        baseline_rst = 1'b1;
        baseline_enable = 1'b0;
        mac_rst = 1'b1;
        mac_enable = 1'b0;

        run_mac_arithmetic_cases();
        run_mac_boundaries_and_dependencies();
        run_mac_load_hazards();
        run_mac_overflow();
        run_dot_product_integration();

        $display("\nTests run:    %0d", tests_run);
        $display("Tests failed: %0d", tests_failed);
        if (tests_failed == 0) begin
            $display("PIPELINE MAC8 TEST PASSED");
        end else begin
            $display("PIPELINE MAC8 TEST FAILED");
            $fatal(1, "Pipeline MAC8 test failed");
        end
        $finish;
    end

endmodule
