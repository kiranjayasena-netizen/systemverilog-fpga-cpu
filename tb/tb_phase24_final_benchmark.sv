`timescale 1ns/1ps

module tb_phase24_final_benchmark;
    localparam int unsigned IMEM_DEPTH     = 256;
    localparam int unsigned DMEM_DEPTH     = 256;
    localparam int unsigned MEASURE_CYCLES = 20_000;
    localparam real         BASELINE_CPI   = 1.236552;
    localparam real         PHASE22_CPI    = 1.181963;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;

    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic [31:0] fetch_request_pc;
    logic        fetch_request_valid;
    logic        if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic [3:0]  decoded_opcode;
    logic        decoded_valid;
    logic        id_ex_valid;
    logic        ex_mem_valid;
    logic        mem_wb_valid;
    logic [31:0] alu_result;
    logic [31:0] data_addr;
    logic [31:0] memory_read_data;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [3:0]  retire_opcode;
    logic [4:0]  retire_rd;
    logic        retire_reg_write;
    logic [31:0] retire_write_data;
    logic        retire_mem_write;
    logic [31:0] retire_mem_addr;
    logic [31:0] retire_mem_data;
    logic        reg_write;
    logic        mem_write;
    logic        pc_redirect;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;
    logic [31:0] pipeline_fill_cycles;
    logic [31:0] data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles;
    logic [31:0] control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles;
    logic [31:0] memory_wait_cycles;
    logic [31:0] taken_branches;
    logic [31:0] not_taken_branches;
    logic [31:0] jumps;
    logic [31:0] wrong_path_instructions_flushed;

    int unsigned enabled_cycles;
    int unsigned retired_count;
    int unsigned no_retire_cycles;
    real cpi;
    real predicted_mips_100;
    real predicted_mips_115;
    real predicted_mips_117;
    real predicted_mips_119;
    real predicted_mips_120;
    real cpi_improvement_pct;
    real cpi_delta_vs_phase22_pct;

    always #5 clk = ~clk;

    cpu_core_pipeline_forwardtiming_phase24 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("programs/final_benchmark.mem")
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
        .id_ex_valid(id_ex_valid),
        .ex_mem_valid(ex_mem_valid),
        .mem_wb_valid(mem_wb_valid),
        .alu_result(alu_result),
        .data_addr(data_addr),
        .memory_read_data(memory_read_data),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_opcode(retire_opcode),
        .retire_rd(retire_rd),
        .retire_reg_write(retire_reg_write),
        .retire_write_data(retire_write_data),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .pc_redirect(pc_redirect),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches),
        .not_taken_branches(not_taken_branches),
        .jumps(jumps),
        .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
    );

    initial begin
        enabled_cycles = 0;
        retired_count = 0;
        no_retire_cycles = 0;

        repeat (8) @(posedge clk);
        rst = 1'b0;
        enable = 1'b1;

        for (int unsigned i = 0; i < MEASURE_CYCLES; i++) begin
            @(posedge clk);
            enabled_cycles++;
            if (retire_valid) begin
                retired_count++;
                no_retire_cycles = 0;
            end else begin
                no_retire_cycles++;
            end

            if (no_retire_cycles > 1_000) begin
                $fatal(1, "Phase 24 benchmark stopped retiring instructions for %0d cycles at fetch_pc=%08h",
                       no_retire_cycles, fetch_pc);
            end
        end

        enable = 1'b0;

        if (retired_count == 0) begin
            $fatal(1, "Phase 24 benchmark retired zero instructions");
        end

        cpi = real'(enabled_cycles) / real'(retired_count);
        predicted_mips_100 = 100.000 / cpi;
        predicted_mips_115 = 115.000 / cpi;
        predicted_mips_117 = 117.000 / cpi;
        predicted_mips_119 = 119.000 / cpi;
        predicted_mips_120 = 120.000 / cpi;
        cpi_improvement_pct = ((BASELINE_CPI - cpi) / BASELINE_CPI) * 100.000;
        cpi_delta_vs_phase22_pct = ((cpi - PHASE22_CPI) / PHASE22_CPI) * 100.000;

        $display("Phase 24 FINAL BENCHMARK SUMMARY");
        $display("  enabled cycles            = %0d", enabled_cycles);
        $display("  retired instructions      = %0d", retired_count);
        $display("  CPI                       = %0.6f", cpi);
        $display("  predicted MIPS @100 MHz   = %0.3f", predicted_mips_100);
        $display("  predicted MIPS @115 MHz   = %0.3f", predicted_mips_115);
        $display("  predicted MIPS @117 MHz   = %0.3f", predicted_mips_117);
        $display("  predicted MIPS @119 MHz   = %0.3f", predicted_mips_119);
        $display("  predicted MIPS @120 MHz   = %0.3f", predicted_mips_120);
        $display("  CPI improvement vs baseline = %0.3f%%", cpi_improvement_pct);
        $display("  CPI delta vs Phase 22       = %0.3f%%", cpi_delta_vs_phase22_pct);
        $display("  CPI <= 1.190 target met    = %0s", (cpi <= 1.190) ? "yes" : "no");
        $display("  core total_cycles         = %0d", total_cycles);
        $display("  core retired_instructions = %0d", retired_instructions);
        $display("  data hazard stalls        = %0d", data_hazard_stall_cycles);
        $display("  load-use stalls           = %0d", load_use_stall_cycles);
        $display("  control flush cycles      = %0d", control_hazard_flush_cycles);
        $display("  fetch wait cycles         = %0d", instruction_fetch_wait_cycles);
        $display("  memory wait cycles        = %0d", memory_wait_cycles);
        $display("  taken branches            = %0d", taken_branches);
        $display("  not-taken branches        = %0d", not_taken_branches);
        $display("  jumps                     = %0d", jumps);
        $display("  wrong-path flushed        = %0d", wrong_path_instructions_flushed);
        $display("Phase 24 FINAL BENCHMARK TEST PASSED");
        $finish;
    end
endmodule
