`timescale 1ns / 1ps

module register_file_tb;

    logic        clk;
    logic        rst;
    logic        we;
    logic [4:0]  waddr;
    logic [31:0] wdata;
    logic [4:0]  raddr_a;
    logic [4:0]  raddr_b;
    logic [31:0] rdata_a;
    logic [31:0] rdata_b;

    logic [31:0] ref_regs [0:31];
    int unsigned tests_run;
    int unsigned tests_failed;

    register_file dut (
        .clk(clk),
        .rst(rst),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr_a(raddr_a),
        .raddr_b(raddr_b),
        .rdata_a(rdata_a),
        .rdata_b(rdata_b)
    );

    always #5 clk = ~clk;

    function automatic logic [31:0] ref_read(input logic [4:0] addr);
        ref_read = (addr == 5'd0) ? 32'h0000_0000 : ref_regs[addr];
    endfunction

    function automatic logic [4:0] addr_from_int(input int unsigned index);
        addr_from_int = index[4:0];
    endfunction

    function automatic logic [31:0] pattern_for_reg(input int unsigned index);
        logic [31:0] index_value;
        begin
            index_value = index[31:0];
            pattern_for_reg = 32'hA500_0000 ^ (index_value * 32'h0101_0101);
        end
    endfunction

    task automatic report_mismatch(
        input string case_name,
        input string port_name,
        input logic [4:0] addr,
        input logic [31:0] expected,
        input logic [31:0] actual
    );
        begin
            tests_failed++;
            $error(
                "%s %s mismatch: addr=%0d expected=0x%08h got=0x%08h",
                case_name,
                port_name,
                addr,
                expected,
                actual
            );
        end
    endtask

    task automatic check_read(
        input string case_name,
        input logic [4:0] addr_a,
        input logic [4:0] addr_b
    );
        logic [31:0] expected_a;
        logic [31:0] expected_b;
        begin
            raddr_a = addr_a;
            raddr_b = addr_b;
            #1;

            expected_a = ref_read(addr_a);
            expected_b = ref_read(addr_b);
            tests_run++;

            if (rdata_a !== expected_a) begin
                report_mismatch(case_name, "port A", addr_a, expected_a, rdata_a);
            end

            if (rdata_b !== expected_b) begin
                report_mismatch(case_name, "port B", addr_b, expected_b, rdata_b);
            end
        end
    endtask

    task automatic write_reg(
        input logic [4:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge clk);
            we    = 1'b1;
            waddr = addr;
            wdata = data;

            @(posedge clk);
            #1;
            we = 1'b0;

            if (addr != 5'd0) begin
                ref_regs[addr] = data;
            end
        end
    endtask

    task automatic disabled_write(
        input logic [4:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge clk);
            we    = 1'b0;
            waddr = addr;
            wdata = data;

            @(posedge clk);
            #1;
        end
    endtask

    task automatic apply_reset;
        begin
            @(negedge clk);
            rst   = 1'b1;
            we    = 1'b0;
            waddr = 5'd0;
            wdata = 32'h0000_0000;

            for (int i = 0; i < 32; i++) begin
                ref_regs[i] = 32'h0000_0000;
            end

            repeat (2) @(posedge clk);
            #1;

            @(negedge clk);
            rst = 1'b0;
            #1;
        end
    endtask

    task automatic check_write_visible_after_clock(
        input logic [4:0] addr,
        input logic [31:0] data
    );
        logic [31:0] old_value;
        begin
            @(negedge clk);
            raddr_a = addr;
            raddr_b = addr;
            we      = 1'b1;
            waddr   = addr;
            wdata   = data;
            #1;

            old_value = ref_read(addr);
            tests_run++;

            if (rdata_a !== old_value) begin
                report_mismatch("read before write clock", "port A", addr, old_value, rdata_a);
            end

            if (rdata_b !== old_value) begin
                report_mismatch("read before write clock", "port B", addr, old_value, rdata_b);
            end

            @(posedge clk);
            #1;
            tests_run++;

            if (addr != 5'd0) begin
                ref_regs[addr] = data;
            end

            if (rdata_a !== ref_read(addr)) begin
                report_mismatch("read after write clock", "port A", addr, ref_read(addr), rdata_a);
            end

            if (rdata_b !== ref_read(addr)) begin
                report_mismatch("read after write clock", "port B", addr, ref_read(addr), rdata_b);
            end

            we = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("register_file_tb.vcd");
        $dumpvars(0, register_file_tb);

        $display("Starting register file simulation...");

        clk          = 1'b0;
        rst          = 1'b0;
        we           = 1'b0;
        waddr        = 5'd0;
        wdata        = 32'h0000_0000;
        raddr_a      = 5'd0;
        raddr_b      = 5'd0;
        tests_run    = 0;
        tests_failed = 0;

        for (int i = 0; i < 32; i++) begin
            ref_regs[i] = 32'h0000_0000;
        end

        apply_reset();

        for (int i = 0; i < 32; i += 2) begin
            check_read("reset clears registers", addr_from_int(i), addr_from_int(i + 1));
        end

        write_reg(5'd0, 32'hFFFF_FFFF);
        check_read("x0 ignores writes", 5'd0, 5'd0);

        for (int i = 1; i < 32; i++) begin
            write_reg(addr_from_int(i), pattern_for_reg(i));
        end

        for (int i = 0; i < 32; i += 2) begin
            check_read("read back written registers", addr_from_int(i), addr_from_int(i + 1));
        end

        check_read("two ports read different registers", 5'd5, 5'd17);
        check_read("two ports read same register", 5'd9, 5'd9);

        disabled_write(5'd7, 32'hDEAD_BEEF);
        check_read("disabled write preserves data", 5'd7, 5'd7);

        write_reg(5'd7, 32'h1234_5678);
        check_read("overwrite existing register", 5'd7, 5'd7);

        check_write_visible_after_clock(5'd12, 32'hCAFE_BABE);

        apply_reset();
        for (int i = 0; i < 32; i += 2) begin
            check_read("second reset clears registers", addr_from_int(i), addr_from_int(i + 1));
        end

        if (tests_failed != 0) begin
            $fatal(1, "%0d failures across %0d register file checks.", tests_failed, tests_run);
        end

        $display("All %0d register file checks passed.", tests_run);
        $finish;
    end

endmodule
