import cpu_defs_pkg::*;
import dot4acc_reference_pkg::*;

module tb_dot4acc_stage_h12_benchmark;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;
    localparam int unsigned SCALE_CASES = 6;
    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};
    // Per four lanes: A=[3,-2,1,-1], B=[127,-128,0,5]. The scalar
    // implementation performs 3+2+1+1 repeated ADD/SUB instructions, while
    // MAC8 performs four instructions and DOT4ACC performs one.
    localparam logic [31:0] SCALE_PACKED_A = 32'hff01_fe03;
    localparam logic [31:0] SCALE_PACKED_B = 32'h0500_807f;
    localparam logic [31:0] SCALE_ACCUMULATOR = 32'd37;

    typedef struct {
        int cycles;
        int retired;
        int loads;
        int dots;
        int stores;
        int hold_cycles;
        int h0_load_use_cycles;
        int h0_dot_hold_cycles;
        int h0_dot_issue_cycles;
        int h0_dot_complete_cycles;
        int h0_dot_retire_cycles;
        int h0_fetch_wait_cycles;
        int h0_other_cycles;
        int h12_deferred_rs1_forward_used;
        int h12_deferred_rs2_forward_used;
        int h12_dot_issue_while_deferred;
        int h12_second_load_blocked;
        int h13_second_load_admitted;
        int h13_second_load_idex_held;
        int h13_second_load_precompletion_held;
        int first_issue;
        int last_issue;
        int first_completion;
        int last_completion;
        int first_dot_retire;
        int last_dot_retire;
        logic [31:0] result;
    } measurement_t;

    logic clk;

    logic scalar_rst;
    logic scalar_enable;
    logic scalar_retire_valid;
    logic [3:0] scalar_retire_opcode;
    logic scalar_retire_mem_write;
    logic [31:0] scalar_total_cycles;
    logic [31:0] scalar_retired_instructions;

    logic mac_rst;
    logic mac_enable;
    logic mac_retire_valid;
    logic [3:0] mac_retire_opcode;
    logic mac_retire_mem_write;
    logic [31:0] mac_total_cycles;
    logic [31:0] mac_retired_instructions;

    logic dot_rst;
    logic dot_enable;
    logic dot_retire_valid;
    logic [3:0] dot_retire_opcode;
    logic dot_retire_mem_write;
    logic [31:0] dot_total_cycles;
    logic [31:0] dot_retired_instructions;
    logic dot_issue_valid;
    logic dot_complete_valid;
    logic dot_retire_is_dot;
    logic dot_frontend_hold;

    int checks_run;
    int checks_failed;
    int csv_fd;

    int scale_lengths [0:SCALE_CASES-1];
    int dot_scale_cycles [0:SCALE_CASES-1];

    cpu_core_pipeline_mac8_timingopt #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) scalar_dut (
        .clk(clk),
        .rst(scalar_rst),
        .enable(scalar_enable),
        .retire_valid(scalar_retire_valid),
        .retire_opcode(scalar_retire_opcode),
        .retire_mem_write(scalar_retire_mem_write),
        .total_cycles(scalar_total_cycles),
        .retired_instructions(scalar_retired_instructions)
    );

    cpu_core_pipeline_mac8_timingopt #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) mac_dut (
        .clk(clk),
        .rst(mac_rst),
        .enable(mac_enable),
        .retire_valid(mac_retire_valid),
        .retire_opcode(mac_retire_opcode),
        .retire_mem_write(mac_retire_mem_write),
        .total_cycles(mac_total_cycles),
        .retired_instructions(mac_retired_instructions)
    );

    cpu_core_pipeline_dot4acc_memopt_h12 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dot_dut (
        .clk(clk),
        .rst(dot_rst),
        .enable(dot_enable),
        .retire_valid(dot_retire_valid),
        .retire_opcode(dot_retire_opcode),
        .retire_mem_write(dot_retire_mem_write),
        .total_cycles(dot_total_cycles),
        .retired_instructions(dot_retired_instructions),
        .dot_issue_valid(dot_issue_valid),
        .dot_complete_valid(dot_complete_valid),
        .dot_retire_valid(dot_retire_is_dot),
        .dot_frontend_hold(dot_frontend_hold)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] instr(
        input logic [3:0] opcode,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [12:0] imm13
    );
        instr = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [12:0] imm13_signed(input int value);
        imm13_signed = value[12:0];
    endfunction

    function automatic logic [31:0] repeated_expected(input int vector_length);
        logic [31:0] value;
        value = SCALE_ACCUMULATOR;
        repeat (vector_length / 4) begin
            value = dot4acc_reference(value, SCALE_PACKED_A, SCALE_PACKED_B);
        end
        repeated_expected = value;
    endfunction

    function automatic int matrix_coefficient(input int row, input int lane);
        case (row)
            0: case (lane) 0: matrix_coefficient = 3; 1: matrix_coefficient = -2; 2: matrix_coefficient = 1; default: matrix_coefficient = -1; endcase
            1: case (lane) 0: matrix_coefficient = -1; 1: matrix_coefficient = 1; 2: matrix_coefficient = -2; default: matrix_coefficient = 3; endcase
            2: case (lane) 0: matrix_coefficient = 2; 1: matrix_coefficient = 1; 2: matrix_coefficient = -1; default: matrix_coefficient = -2; endcase
            default: case (lane) 0: matrix_coefficient = -2; 1: matrix_coefficient = -1; 2: matrix_coefficient = 3; default: matrix_coefficient = 1; endcase
        endcase
    endfunction

    function automatic logic [31:0] matrix_packed_coefficients(input int row);
        case (row)
            0: matrix_packed_coefficients = 32'hff01_fe03;
            1: matrix_packed_coefficients = 32'h03fe_01ff;
            2: matrix_packed_coefficients = 32'hfeff_0102;
            default: matrix_packed_coefficients = 32'h0103_fffe;
        endcase
    endfunction

    function automatic real interval_value(
        input int first_cycle,
        input int last_cycle,
        input int count
    );
        if (count <= 1) begin
            interval_value = 0.0;
        end else begin
            interval_value = real'(last_cycle - first_cycle) / real'(count - 1);
        end
    endfunction

    task automatic step_clock();
        @(posedge clk);
        #1;
    endtask

    task automatic check_true(input string name, input bit condition);
        checks_run++;
        if (!condition) begin
            checks_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic check_equal32(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        checks_run++;
        if (actual !== expected) begin
            checks_failed++;
            $display("FAIL: %s actual=0x%08h expected=0x%08h", name, actual, expected);
        end
    endtask

    task automatic clear_scalar_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) scalar_dut.instr_mem_inst.mem[i] = NOP_INSTRUCTION;
        for (int i = 0; i < DMEM_DEPTH; i++) scalar_dut.data_mem_inst.mem[i] = 32'd0;
    endtask

    task automatic clear_mac_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) mac_dut.instr_mem_inst.mem[i] = NOP_INSTRUCTION;
        for (int i = 0; i < DMEM_DEPTH; i++) mac_dut.data_mem_inst.mem[i] = 32'd0;
    endtask

    task automatic clear_dot_memories();
        for (int i = 0; i < IMEM_DEPTH; i++) dot_dut.instr_mem_inst.mem[i] = NOP_INSTRUCTION;
        for (int i = 0; i < DMEM_DEPTH; i++) dot_dut.data_mem_inst.mem[i] = 32'd0;
    endtask

    task automatic prepare_scalar();
        scalar_enable = 1'b0;
        scalar_rst = 1'b1;
        repeat (4) step_clock();
        scalar_rst = 1'b0;
        repeat (2) step_clock();
        clear_scalar_memories();
    endtask

    task automatic prepare_mac();
        mac_enable = 1'b0;
        mac_rst = 1'b1;
        repeat (4) step_clock();
        mac_rst = 1'b0;
        repeat (2) step_clock();
        clear_mac_memories();
    endtask

    task automatic prepare_dot();
        dot_enable = 1'b0;
        dot_rst = 1'b1;
        repeat (4) step_clock();
        dot_rst = 1'b0;
        repeat (2) step_clock();
        clear_dot_memories();
    endtask

    task automatic init_measurement(output measurement_t m);
        m.cycles = 0;
        m.retired = 0;
        m.loads = 0;
        m.dots = 0;
        m.stores = 0;
        m.hold_cycles = 0;
        m.h0_load_use_cycles = 0;
        m.h0_dot_hold_cycles = 0;
        m.h0_dot_issue_cycles = 0;
        m.h0_dot_complete_cycles = 0;
        m.h0_dot_retire_cycles = 0;
        m.h0_fetch_wait_cycles = 0;
        m.h0_other_cycles = 0;
        m.h12_deferred_rs1_forward_used = 0;
        m.h12_deferred_rs2_forward_used = 0;
        m.h12_dot_issue_while_deferred = 0;
        m.h12_second_load_blocked = 0;
        m.h13_second_load_admitted = 0;
        m.h13_second_load_idex_held = 0;
        m.h13_second_load_precompletion_held = 0;
        m.first_issue = -1;
        m.last_issue = -1;
        m.first_completion = -1;
        m.last_completion = -1;
        m.first_dot_retire = -1;
        m.last_dot_retire = -1;
        m.result = 32'd0;
    endtask

    task automatic run_scalar_to_store(output measurement_t m, input int max_cycles);
        int timeout;
        bit done;
        init_measurement(m);
        timeout = 0;
        done = 1'b0;
        scalar_enable = 1'b1;
        while (!done && (timeout < max_cycles)) begin
            step_clock();
            if (scalar_retire_valid) begin
                m.retired++;
                if (scalar_retire_opcode == OP_LOAD) m.loads++;
                if (scalar_retire_mem_write) begin
                    m.stores++;
                    m.cycles = scalar_total_cycles;
                    done = 1'b1;
                end
            end
            timeout++;
        end
        scalar_enable = 1'b0;
        m.result = scalar_dut.data_mem_inst.mem[0];
        check_true("scalar benchmark completed", done);
        check_true("scalar retired counter matches monitor", scalar_retired_instructions == m.retired);
    endtask

    task automatic run_mac_to_store(output measurement_t m, input int max_cycles);
        int timeout;
        bit done;
        init_measurement(m);
        timeout = 0;
        done = 1'b0;
        mac_enable = 1'b1;
        while (!done && (timeout < max_cycles)) begin
            step_clock();
            if (mac_retire_valid) begin
                m.retired++;
                if (mac_retire_opcode == OP_LOAD) m.loads++;
                if (mac_retire_opcode == OP_MAC8) m.dots++;
                if (mac_retire_mem_write) begin
                    m.stores++;
                    m.cycles = mac_total_cycles;
                    done = 1'b1;
                end
            end
            timeout++;
        end
        mac_enable = 1'b0;
        m.result = mac_dut.data_mem_inst.mem[0];
        check_true("MAC8 benchmark completed", done);
        check_true("MAC8 retired counter matches monitor", mac_retired_instructions == m.retired);
    endtask

    task automatic run_dot_to_store(output measurement_t m, input int max_cycles);
        int timeout;
        bit done;
        init_measurement(m);
        timeout = 0;
        done = 1'b0;
        dot_enable = 1'b1;
        while (!done && (timeout < max_cycles)) begin
            // Observe H1.2/H1.3 ownership predicates before the advancing
            // edge; sampling after step_clock would miss transient IF/ID
            // decisions.
            if (dot_dut.dot_deferred_rs1_match && dot_dut.dot_issue_accept)
                m.h12_deferred_rs1_forward_used++;
            if (dot_dut.dot_deferred_rs2_match && dot_dut.dot_issue_accept)
                m.h12_deferred_rs2_forward_used++;
            if (dot_dut.deferred_load_valid && dot_dut.dot_issue_accept)
                m.h12_dot_issue_while_deferred++;
            if (dot_dut.if_id_opcode_valid &&
                (dot_dut.if_id_opcode == OP_LOAD) &&
                dot_dut.dot_younger_non_dot_hold)
                m.h12_second_load_blocked++;
            if (dot_dut.if_id_opcode_valid &&
                (dot_dut.if_id_opcode == OP_LOAD) &&
                dot_dut.load_overlap_allowed &&
                dot_dut.load_overlap_reserved)
                m.h13_second_load_admitted++;
            if (dot_dut.id_ex_reg.valid &&
                (dot_dut.id_ex_reg.opcode == OP_LOAD) &&
                dot_dut.load_overlap_reserved && dot_dut.dot_frontend_hold)
                m.h13_second_load_idex_held++;
            if (dot_dut.id_ex_reg.valid &&
                (dot_dut.id_ex_reg.opcode == OP_LOAD) &&
                dot_dut.deferred_load_valid)
                m.h13_second_load_precompletion_held++;
            step_clock();
            // H0 deterministic priority: classify each measured enabled
            // cycle exactly once, with event/hold causes before fetch/other.
            if (dot_dut.load_use_stall) begin
                m.h0_load_use_cycles++;
            end else if (dot_frontend_hold) begin
                m.hold_cycles++;
                m.h0_dot_hold_cycles++;
            end else if (dot_dut.dot_issue_accept) begin
                m.h0_dot_issue_cycles++;
            end else if (dot_complete_valid) begin
                m.h0_dot_complete_cycles++;
            end else if (dot_retire_valid) begin
                m.h0_dot_retire_cycles++;
            end else if (dot_dut.fetch_pending_valid || dot_dut.fetch_buffer_valid) begin
                m.h0_fetch_wait_cycles++;
            end else begin
                m.h0_other_cycles++;
            end
            if (dot_issue_valid) begin
                if (m.first_issue < 0) m.first_issue = dot_total_cycles;
                m.last_issue = dot_total_cycles;
            end
            if (dot_complete_valid) begin
                if (m.first_completion < 0) m.first_completion = dot_total_cycles;
                m.last_completion = dot_total_cycles;
            end
            if (dot_retire_valid) begin
                m.retired++;
                if (dot_retire_opcode == OP_LOAD) m.loads++;
                if (dot_retire_is_dot) begin
                    m.dots++;
                    if (m.first_dot_retire < 0) m.first_dot_retire = dot_total_cycles;
                    m.last_dot_retire = dot_total_cycles;
                end
                if (dot_retire_mem_write) begin
                    m.stores++;
                    m.cycles = dot_total_cycles;
                    done = 1'b1;
                end
            end
            timeout++;
        end
        dot_enable = 1'b0;
        m.result = dot_dut.data_mem_inst.mem[0];
        check_true("DOT benchmark completed", done);
        check_true("DOT retired counter matches monitor", dot_retired_instructions == m.retired);
    endtask

    task automatic preload_scale_scalar();
        scalar_dut.regs[1] = 32'd127;
        scalar_dut.regs[3] = 32'hffff_ff80;
        scalar_dut.regs[5] = 32'd0;
        scalar_dut.regs[7] = 32'd5;
        scalar_dut.regs[9] = SCALE_ACCUMULATOR;
    endtask

    task automatic preload_scale_mac();
        mac_dut.regs[1] = 32'd3;
        mac_dut.regs[2] = 32'd127;
        mac_dut.regs[3] = 32'hffff_fffe;
        mac_dut.regs[4] = 32'hffff_ff80;
        mac_dut.regs[5] = 32'd1;
        mac_dut.regs[6] = 32'd0;
        mac_dut.regs[7] = 32'hffff_ffff;
        mac_dut.regs[8] = 32'd5;
        mac_dut.regs[9] = SCALE_ACCUMULATOR;
    endtask

    task automatic preload_scale_dot();
        dot_dut.regs[1] = SCALE_PACKED_A;
        dot_dut.regs[2] = SCALE_PACKED_B;
        dot_dut.regs[9] = SCALE_ACCUMULATOR;
    endtask

    task automatic build_scalar_scale_program(input int vector_length);
        int pc;
        pc = 0;
        for (int block = 0; block < (vector_length / 4); block++) begin
            repeat (3) scalar_dut.instr_mem_inst.mem[pc++] = instr(OP_ADD, 5'd9, 5'd9, 5'd1, 13'd0);
            repeat (2) scalar_dut.instr_mem_inst.mem[pc++] = instr(OP_SUB, 5'd9, 5'd9, 5'd3, 13'd0);
            scalar_dut.instr_mem_inst.mem[pc++] = instr(OP_ADD, 5'd9, 5'd9, 5'd5, 13'd0);
            scalar_dut.instr_mem_inst.mem[pc++] = instr(OP_SUB, 5'd9, 5'd9, 5'd7, 13'd0);
        end
        scalar_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
    endtask

    task automatic build_mac_scale_program(input int vector_length);
        int pc;
        pc = 0;
        for (int i = 0; i < vector_length; i++) begin
            case (i % 4)
                0: mac_dut.instr_mem_inst.mem[pc] = instr(OP_MAC8, 5'd9, 5'd1, 5'd2, 13'd0);
                1: mac_dut.instr_mem_inst.mem[pc] = instr(OP_MAC8, 5'd9, 5'd3, 5'd4, 13'd0);
                2: mac_dut.instr_mem_inst.mem[pc] = instr(OP_MAC8, 5'd9, 5'd5, 5'd6, 13'd0);
                default: mac_dut.instr_mem_inst.mem[pc] = instr(OP_MAC8, 5'd9, 5'd7, 5'd8, 13'd0);
            endcase
            pc++;
        end
        mac_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
    endtask

    task automatic build_dot_chain_program(input int dot_count);
        for (int i = 0; i < dot_count; i++) begin
            dot_dut.instr_mem_inst.mem[i] = encode_dot4acc(5'd9, 5'd1, 5'd2);
        end
        dot_dut.instr_mem_inst.mem[dot_count] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
    endtask

    task automatic record_result(
        input string benchmark,
        input string implementation_name,
        input int vector_length,
        input int useful_macs,
        input int program_instructions,
        input measurement_t m,
        input string speedup_scalar,
        input string speedup_mac,
        input string peak_utilisation,
        input string notes
    );
        real cpi;
        real macs_per_cycle;
        real mmac;
        real issue_interval;
        real completion_interval;
        real retirement_interval;
        cpi = real'(m.cycles) / real'(m.retired);
        macs_per_cycle = real'(useful_macs) / real'(m.cycles);
        mmac = macs_per_cycle * 100.0;
        issue_interval = interval_value(m.first_issue, m.last_issue, m.dots);
        completion_interval = interval_value(m.first_completion, m.last_completion, m.dots);
        retirement_interval = interval_value(m.first_dot_retire, m.last_dot_retire, m.dots);
        $fdisplay(csv_fd,
            "\"%s\",\"%s\",%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.6f,%0.6f,%s,%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.6f,%0.6f,%0d,%0d,%0d,%0d,0x%08h,PASS,\"%s\"",
            benchmark, implementation_name, vector_length, useful_macs,
            program_instructions, m.retired, m.cycles, m.cycles, cpi,
            macs_per_cycle, mmac, speedup_scalar, speedup_mac,
            peak_utilisation, m.first_issue, m.last_issue,
            m.first_completion, m.last_completion, m.first_dot_retire,
            m.last_dot_retire, issue_interval, completion_interval,
            retirement_interval, m.loads, m.dots, m.stores, m.hold_cycles,
            m.result, notes);
    endtask

    task automatic record_three_way(
        input string benchmark,
        input int vector_length,
        input int useful_macs,
        input int scalar_program_instructions,
        input int mac_program_instructions,
        input int dot_program_instructions,
        input measurement_t scalar_m,
        input measurement_t mac_m,
        input measurement_t dot_m,
        input string notes
    );
        record_result(benchmark, "Scalar", vector_length, useful_macs,
                      scalar_program_instructions, scalar_m, "1.000000",
                      $sformatf("%0.6f", real'(mac_m.cycles) / real'(scalar_m.cycles)),
                      "", notes);
        record_result(benchmark, "MAC8", vector_length, useful_macs,
                      mac_program_instructions, mac_m,
                      $sformatf("%0.6f", real'(scalar_m.cycles) / real'(mac_m.cycles)),
                      "1.000000", "", notes);
        record_result(benchmark, "DOT4ACC", vector_length, useful_macs,
                      dot_program_instructions, dot_m,
                      $sformatf("%0.6f", real'(scalar_m.cycles) / real'(dot_m.cycles)),
                      $sformatf("%0.6f", real'(mac_m.cycles) / real'(dot_m.cycles)),
                      $sformatf("%0.6f", 25.0 * real'(useful_macs) / real'(dot_m.cycles)),
                      notes);
    endtask

    task automatic benchmark_historical();
        measurement_t scalar_m;
        measurement_t mac_m;
        measurement_t dot_m;
        logic [31:0] expected;
        $display("---- Stage E A: exact historical dot product ----");

        prepare_scalar();
        $readmemh("programs/ai_dot_product_baseline.mem", scalar_dut.instr_mem_inst.mem, 0, 24);
        run_scalar_to_store(scalar_m, 100);

        prepare_mac();
        $readmemh("programs/ai_dot_product_mac.mem", mac_dut.instr_mem_inst.mem, 0, 14);
        run_mac_to_store(mac_m, 100);

        prepare_dot();
        $readmemh("programs/ai_dot_product_dot4acc.mem", dot_dut.instr_mem_inst.mem, 0, 6);
        dot_dut.data_mem_inst.mem[16] = 32'hfc05_fe03;
        dot_dut.data_mem_inst.mem[17] = 32'hfeff_04fd;
        run_dot_to_store(dot_m, 100);

        expected = dot4acc_reference(32'd0, 32'hfc05_fe03, 32'hfeff_04fd);
        check_equal32("historical Stage A1 oracle", expected, 32'hffff_fff2);
        check_equal32("historical scalar result", scalar_m.result, expected);
        check_equal32("historical MAC8 result", mac_m.result, expected);
        check_equal32("historical DOT result", dot_m.result, expected);
        check_true("historical scalar cycles preserved", scalar_m.cycles == 29);
        check_true("historical MAC8 cycles preserved", mac_m.cycles == 19);
        check_true("historical scalar retirement preserved", scalar_m.retired == 24);
        check_true("historical MAC8 retirement preserved", mac_m.retired == 14);
        record_three_way("historical_dot4", 4, 4, 24, 14, 6,
                         scalar_m, mac_m, dot_m,
                         "exact committed scalar and MAC8 images; DOT uses two packed LOADs");
    endtask

    task automatic benchmark_vector_scaling();
        logic [31:0] expected;
        measurement_t scalar_m;
        measurement_t mac_m;
        measurement_t dot_m;
        int case_index;
        int n;
        $display("---- Stage E B/C/I: register-resident vector scaling ----");
        scale_lengths[0] = 4;
        scale_lengths[1] = 8;
        scale_lengths[2] = 16;
        scale_lengths[3] = 32;
        scale_lengths[4] = 64;
        scale_lengths[5] = 128;
        for (case_index = 0; case_index < SCALE_CASES; case_index++) begin
            n = scale_lengths[case_index];
            $display("  vector N=%0d start", n);
            expected = repeated_expected(n);

            prepare_scalar();
            $display("  vector N=%0d scalar prepared", n);
            preload_scale_scalar();
            build_scalar_scale_program(n);
            run_scalar_to_store(scalar_m, 400);
            $display("  vector N=%0d scalar done", n);

            prepare_mac();
            preload_scale_mac();
            build_mac_scale_program(n);
            run_mac_to_store(mac_m, 400);
            $display("  vector N=%0d MAC8 done", n);

            prepare_dot();
            preload_scale_dot();
            build_dot_chain_program(n / 4);
            run_dot_to_store(dot_m, 400);
            $display("  vector N=%0d DOT done", n);
            dot_scale_cycles[case_index] = dot_m.cycles;

            check_equal32("scaled scalar result", scalar_m.result, expected);
            check_equal32("scaled MAC8 result", mac_m.result, expected);
            check_equal32("scaled DOT result", dot_m.result, expected);
            check_true("scaled scalar retirement", scalar_m.retired == (7*(n/4)) + 1);
            check_true("scaled MAC8 retirement", mac_m.retired == n + 1);
            check_true("scaled DOT retirement", dot_m.retired == (n / 4) + 1);
            if (n == 4) begin
                record_three_way("packed4", n, n, (7*(n/4)) + 1, n + 1,
                                 (n / 4) + 1, scalar_m, mac_m, dot_m,
                                 "register-resident repeated signed edge pattern");
            end else begin
                record_three_way("vector_scaling", n, n, (7*(n/4)) + 1, n + 1,
                                 (n / 4) + 1, scalar_m, mac_m, dot_m,
                                 "register-resident repeated signed edge pattern");
            end
            if (n == 64) begin
                record_three_way("neuron_64", n, n, (7*(n/4)) + 1, n + 1,
                                 (n / 4) + 1, scalar_m, mac_m, dot_m,
                                 "headline signed INT8 neuron kernel");
            end
        end
    endtask

    task automatic benchmark_chain_scaling();
        int chain_lengths [0:5];
        measurement_t m;
        logic [31:0] expected;
        $display("---- Stage E D: same-rd chain scaling ----");
        chain_lengths[0] = 1;
        chain_lengths[1] = 2;
        chain_lengths[2] = 4;
        chain_lengths[3] = 8;
        chain_lengths[4] = 16;
        chain_lengths[5] = 32;
        for (int i = 0; i < 6; i++) begin
            int k;
            k = chain_lengths[i];
            prepare_dot();
            preload_scale_dot();
            build_dot_chain_program(k);
            run_dot_to_store(m, 300);
            expected = repeated_expected(k * 4);
            check_equal32("chain final accumulator", m.result, expected);
            check_true("chain retires every DOT and STORE", m.retired == k + 1);
            check_true("chain observes every DOT issue", (k == 1) ||
                       ((m.last_issue - m.first_issue) == k - 1));
            record_result("same_rd_chain", "DOT4ACC", k * 4, k * 4, k + 1,
                          m, "", "", $sformatf("%0.6f", 25.0 * real'(k * 4) / real'(m.cycles)),
                          $sformatf("K=%0d recurrence; measured issue II=%0.3f", k,
                                    interval_value(m.first_issue, m.last_issue, k)));
        end
    endtask

    task automatic benchmark_independent_stream();
        int lengths [0:4];
        measurement_t m;
        logic [31:0] expected;
        $display("---- Stage E E: independent DOT stream ----");
        lengths[0] = 1;
        lengths[1] = 2;
        lengths[2] = 4;
        lengths[3] = 8;
        lengths[4] = 16;
        expected = dot4acc_reference(SCALE_ACCUMULATOR, SCALE_PACKED_A, SCALE_PACKED_B);
        for (int index = 0; index < 5; index++) begin
            int k;
            k = lengths[index];
            prepare_dot();
            dot_dut.regs[1] = SCALE_PACKED_A;
            dot_dut.regs[2] = SCALE_PACKED_B;
            for (int i = 0; i < k; i++) begin
                dot_dut.regs[10+i] = SCALE_ACCUMULATOR;
                dot_dut.instr_mem_inst.mem[i] = encode_dot4acc(5'(10+i), 5'd1, 5'd2);
            end
            dot_dut.instr_mem_inst.mem[k] = instr(OP_STORE, 5'd0, 5'd0, 5'(9+k), 13'd0);
            run_dot_to_store(m, 200);
            for (int i = 0; i < k; i++) begin
                check_equal32("independent destination result", dot_dut.regs[10+i], expected);
            end
            check_equal32("independent final STORE", m.result, expected);
            check_true("independent issue II=1", (k == 1) ||
                       ((m.last_issue - m.first_issue) == k - 1));
            record_result("independent_dot", "DOT4ACC", k * 4, k * 4, k + 1,
                          m, "", "", $sformatf("%0.6f", 25.0 * real'(k * 4) / real'(m.cycles)),
                          $sformatf("K=%0d independent destinations; measured issue II=%0.3f", k,
                                    interval_value(m.first_issue, m.last_issue, k)));
        end
    endtask

    task automatic benchmark_memory_fed();
        int lengths [0:3];
        measurement_t m;
        logic [31:0] expected;
        $display("---- Stage E F: memory-fed DOT workload ----");
        lengths[0] = 16;
        lengths[1] = 32;
        lengths[2] = 64;
        lengths[3] = 128;
        for (int index = 0; index < 4; index++) begin
            int n;
            int k;
            int pc;
            n = lengths[index];
            k = n / 4;
            prepare_dot();
            dot_dut.regs[9] = SCALE_ACCUMULATOR;
            dot_dut.regs[10] = 32'd64;
            pc = 0;
            for (int block = 0; block < k; block++) begin
                dot_dut.data_mem_inst.mem[16 + (2*block)] = SCALE_PACKED_A;
                dot_dut.data_mem_inst.mem[17 + (2*block)] = SCALE_PACKED_B;
                dot_dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd1, 5'd10, 5'd0, imm13_signed(block * 8));
                dot_dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd2, 5'd10, 5'd0, imm13_signed((block * 8) + 4));
                dot_dut.instr_mem_inst.mem[pc++] = encode_dot4acc(5'd9, 5'd1, 5'd2);
            end
            dot_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
            run_dot_to_store(m, 800);
            expected = repeated_expected(n);
            check_equal32("memory-fed final result", m.result, expected);
            check_true("memory-fed LOAD count", m.loads == 2*k);
            check_true("memory-fed DOT count", m.dots == k);
            $display("H0 memory N=%0d cycles=%0d load_use=%0d dot_hold=%0d dot_issue=%0d dot_complete=%0d dot_retire=%0d fetch_wait=%0d other=%0d sum=%0d",
                     n, m.cycles, m.h0_load_use_cycles, m.h0_dot_hold_cycles,
                     m.h0_dot_issue_cycles, m.h0_dot_complete_cycles,
                     m.h0_dot_retire_cycles, m.h0_fetch_wait_cycles,
                     m.h0_other_cycles,
                     m.h0_load_use_cycles + m.h0_dot_hold_cycles +
                     m.h0_dot_issue_cycles + m.h0_dot_complete_cycles +
                     m.h0_dot_retire_cycles + m.h0_fetch_wait_cycles +
                     m.h0_other_cycles);
            $display("H1.3 diagnostics N=%0d deferred_rs1=%0d deferred_rs2=%0d dot_issue_deferred=%0d second_load_blocked=%0d",
                     n, m.h12_deferred_rs1_forward_used,
                     m.h12_deferred_rs2_forward_used,
                     m.h12_dot_issue_while_deferred,
                     m.h12_second_load_blocked);
            $display("H1.3 ownership N=%0d second_admitted=%0d second_idex_held=%0d precompletion_held=%0d",
                     n, m.h13_second_load_admitted,
                     m.h13_second_load_idex_held,
                     m.h13_second_load_precompletion_held);
            record_result("memory_fed", "DOT4ACC", n, n, (3*k)+1, m,
                          "", "", $sformatf("%0.6f", 25.0 * real'(n) / real'(m.cycles)),
                          $sformatf("register-resident cycle ratio=%0.6f",
                                    real'(m.cycles) / real'(dot_scale_cycles[index+2])));
        end
    endtask

    task automatic benchmark_hold_cost();
        int lengths [0:2];
        measurement_t m;
        logic [31:0] expected;
        $display("---- Stage E G: conservative non-DOT hold ----");
        lengths[0] = 4;
        lengths[1] = 8;
        lengths[2] = 16;
        for (int index = 0; index < 3; index++) begin
            int k;
            int pc;
            k = lengths[index];
            prepare_dot();
            preload_scale_dot();
            pc = 0;
            for (int i = 0; i < k; i++) begin
                dot_dut.instr_mem_inst.mem[pc++] = encode_dot4acc(5'd9, 5'd1, 5'd2);
                if (i != k-1) begin
                    dot_dut.instr_mem_inst.mem[pc++] = instr(OP_ADDI, 5'd20, 5'd20, 5'd0, 13'd1);
                end
            end
            dot_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
            run_dot_to_store(m, 600);
            expected = repeated_expected(k * 4);
            check_equal32("interleaved hold final DOT result", m.result, expected);
            check_equal32("interleaved scalar executes once per gap", dot_dut.regs[20], k-1);
            check_true("interleaving creates DOT issue gaps", (k == 1) ||
                       ((m.last_issue - m.first_issue) > k - 1));
            record_result("hold_interleaved", "DOT4ACC", k * 4, k * 4, (2*k), m,
                          "", "", $sformatf("%0.6f", 25.0 * real'(k * 4) / real'(m.cycles)),
                          $sformatf("K=%0d; pure-chain cycles=%0d; added independent ADDI=%0d",
                                    k, dot_scale_cycles[(index == 0) ? 2 : ((index == 1) ? 3 : 4)],
                                    k-1));
        end
    endtask

    task automatic benchmark_consumers();
        measurement_t m;
        logic [31:0] dot_value;
        $display("---- Stage E H: DOT result consumers ----");
        dot_value = dot4acc_reference(SCALE_ACCUMULATOR, SCALE_PACKED_A, SCALE_PACKED_B);

        prepare_dot();
        preload_scale_dot();
        dot_dut.regs[3] = 32'd7;
        dot_dut.instr_mem_inst.mem[0] = encode_dot4acc(5'd9, 5'd1, 5'd2);
        dot_dut.instr_mem_inst.mem[1] = instr(OP_ADD, 5'd11, 5'd9, 5'd3, 13'd0);
        dot_dut.instr_mem_inst.mem[2] = instr(OP_STORE, 5'd0, 5'd0, 5'd11, 13'd0);
        run_dot_to_store(m, 100);
        check_equal32("DOT-to-ADD stored result", m.result, dot_value + 32'd7);
        record_result("consumer_add", "DOT4ACC", 4, 4, 3, m, "", "",
                      $sformatf("%0.6f", 25.0 * 4.0 / real'(m.cycles)),
                      "dependent ADD then STORE");

        prepare_dot();
        preload_scale_dot();
        dot_dut.instr_mem_inst.mem[0] = encode_dot4acc(5'd9, 5'd1, 5'd2);
        dot_dut.instr_mem_inst.mem[1] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
        run_dot_to_store(m, 100);
        check_equal32("DOT-to-STORE result", m.result, dot_value);
        record_result("consumer_store", "DOT4ACC", 4, 4, 2, m, "", "",
                      $sformatf("%0.6f", 25.0 * 4.0 / real'(m.cycles)),
                      "direct dependent STORE");

        prepare_dot();
        preload_scale_dot();
        dot_dut.regs[10] = dot_value;
        dot_dut.instr_mem_inst.mem[0] = encode_dot4acc(5'd9, 5'd1, 5'd2);
        dot_dut.instr_mem_inst.mem[1] = instr(OP_BEQ, 5'd0, 5'd9, 5'd10, imm13_signed(2));
        dot_dut.instr_mem_inst.mem[2] = instr(OP_ADDI, 5'd20, 5'd0, 5'd0, 13'd1);
        dot_dut.instr_mem_inst.mem[3] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
        run_dot_to_store(m, 120);
        check_equal32("DOT-to-BEQ stored result", m.result, dot_value);
        check_equal32("DOT-to-BEQ takes expected branch", dot_dut.regs[20], 32'd0);
        record_result("consumer_branch", "DOT4ACC", 4, 4, 3, m, "", "",
                      $sformatf("%0.6f", 25.0 * 4.0 / real'(m.cycles)),
                      "dependent taken BEQ skips wrong-path ADDI");
    endtask

    task automatic benchmark_matrix_vector();
        measurement_t scalar_m;
        measurement_t mac_m;
        measurement_t dot_m;
        logic [31:0] expected [0:3];
        int pc;
        $display("---- Stage E J: 4x16 matrix-vector kernel ----");
        for (int row = 0; row < 4; row++) begin
            expected[row] = row;
            repeat (4) begin
                expected[row] = dot4acc_reference(
                    expected[row], matrix_packed_coefficients(row), SCALE_PACKED_B);
            end
        end

        prepare_scalar();
        scalar_dut.regs[1] = 32'd127;
        scalar_dut.regs[2] = 32'hffff_ff80;
        scalar_dut.regs[3] = 32'd0;
        scalar_dut.regs[4] = 32'd5;
        for (int row = 0; row < 4; row++) scalar_dut.regs[20+row] = row;
        pc = 0;
        for (int row = 0; row < 4; row++) begin
            for (int block = 0; block < 4; block++) begin
                for (int lane = 0; lane < 4; lane++) begin
                    int coefficient;
                    int magnitude;
                    coefficient = matrix_coefficient(row, lane);
                    magnitude = (coefficient < 0) ? -coefficient : coefficient;
                    for (int rep = 0; rep < magnitude; rep++) begin
                        scalar_dut.instr_mem_inst.mem[pc++] = instr(
                            (coefficient < 0) ? OP_SUB : OP_ADD,
                            5'(20+row), 5'(20+row), 5'(1+lane), 13'd0);
                    end
                end
            end
        end
        scalar_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd23, 13'd0);
        run_scalar_to_store(scalar_m, 300);
        for (int row = 0; row < 4; row++) begin
            check_equal32("matrix scalar output", scalar_dut.regs[20+row], expected[row]);
        end

        prepare_mac();
        mac_dut.regs[1] = 32'd127;
        mac_dut.regs[2] = 32'hffff_ff80;
        mac_dut.regs[3] = 32'd0;
        mac_dut.regs[4] = 32'd5;
        for (int row = 0; row < 4; row++) begin
            mac_dut.regs[21+row] = row;
            for (int lane = 0; lane < 4; lane++) begin
                mac_dut.regs[5 + (row*4) + lane] = matrix_coefficient(row, lane);
            end
        end
        pc = 0;
        for (int row = 0; row < 4; row++) begin
            for (int block = 0; block < 4; block++) begin
                for (int lane = 0; lane < 4; lane++) begin
                    mac_dut.instr_mem_inst.mem[pc++] = instr(
                        OP_MAC8, 5'(21+row), 5'(1+lane),
                        5'(5+(row*4)+lane), 13'd0);
                end
            end
        end
        mac_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd24, 13'd0);
        run_mac_to_store(mac_m, 200);
        for (int row = 0; row < 4; row++) begin
            check_equal32("matrix MAC8 output", mac_dut.regs[21+row], expected[row]);
        end

        prepare_dot();
        dot_dut.regs[1] = SCALE_PACKED_B;
        for (int row = 0; row < 4; row++) begin
            dot_dut.regs[2+row] = matrix_packed_coefficients(row);
            dot_dut.regs[20+row] = row;
        end
        pc = 0;
        for (int row = 0; row < 4; row++) begin
            for (int block = 0; block < 4; block++) begin
                dot_dut.instr_mem_inst.mem[pc++] = encode_dot4acc(
                    5'(20+row), 5'(2+row), 5'd1);
            end
        end
        dot_dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd23, 13'd0);
        run_dot_to_store(dot_m, 200);
        for (int row = 0; row < 4; row++) begin
            check_equal32("matrix DOT output", dot_dut.regs[20+row], expected[row]);
        end
        check_equal32("matrix scalar final STORE", scalar_m.result, expected[3]);
        check_equal32("matrix MAC8 final STORE", mac_m.result, expected[3]);
        check_equal32("matrix DOT final STORE", dot_m.result, expected[3]);
        record_three_way("matrix_vector_4x16", 64, 64, 109, 65, 17,
                         scalar_m, mac_m, dot_m,
                         "four deterministic 16-element output dot products");
    endtask

    initial begin
        checks_run = 0;
        checks_failed = 0;
        scalar_rst = 1'b1;
        scalar_enable = 1'b0;
        mac_rst = 1'b1;
        mac_enable = 1'b0;
        dot_rst = 1'b1;
        dot_enable = 1'b0;

        csv_fd = $fopen("reports/dot4acc_stage_e/results.csv", "w");
        if (csv_fd == 0) $fatal(1, "Could not open Stage E results CSV");
        $fdisplay(csv_fd, "benchmark,implementation,vector_length,useful_macs,program_instructions,retired_instructions,cycles_to_store,total_cycles,cpi,macs_per_cycle,mmac_per_s_100mhz,speedup_vs_scalar,speedup_vs_mac8,dot_peak_utilisation_percent,first_issue_cycle,last_issue_cycle,first_completion_cycle,last_completion_cycle,first_dot_retire_cycle,last_dot_retire_cycle,dot_issue_interval,dot_completion_interval,dot_retirement_interval,load_count,dot_count,store_count,hold_cycles,final_result,pass_fail,notes");

        benchmark_historical();
        benchmark_vector_scaling();
        benchmark_chain_scaling();
        benchmark_independent_stream();
        benchmark_memory_fed();
        benchmark_hold_cost();
        benchmark_consumers();
        benchmark_matrix_vector();

        $fclose(csv_fd);
        $display("Stage E benchmark checks: %0d failures: %0d", checks_run, checks_failed);
        if (checks_failed != 0) begin
            $fatal(1, "TEST FAILED: Stage E DOT4ACC performance benchmarking");
        end
        $display("TEST PASSED: Stage E DOT4ACC performance benchmarking");
        $finish;
    end

endmodule
