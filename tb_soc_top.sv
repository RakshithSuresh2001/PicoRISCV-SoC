`default_nettype none
`timescale 1ns/1ps

module tb_soc_top;

localparam CLK_PERIOD = 2;

reg clk   = 1'b0;
reg rst_n = 1'b0;

always #(CLK_PERIOD/2) clk = ~clk;

wire uart_tx_wire;
wire uart_rx_wire = 1'b1;

soc_top u_dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .uart_tx (uart_tx_wire),
    .uart_rx  (uart_rx_wire),
    .spi_clk  (1'b0),
    .spi_cs_n (1'b1),
    .spi_mosi (1'b0),
    .spi_miso ()
);

// Watchdog
initial begin
    #(CLK_PERIOD * 50_000_000);
    $display("FAIL [Watchdog] timeout");
    $finish(1);
end

// PC trace every 5000 cycles
integer cycle_cnt = 0;
always @(posedge clk) begin
    cycle_cnt <= cycle_cnt + 1;
    if (cycle_cnt % 5000 == 0)
        $display("t=%0t cycle=%0d PC=0x%08X", $time, cycle_cnt, u_dut.u_cpu.reg_pc);
end

// Main test
reg [31:0] sentinel, result, flag, sp_val;
string firmware_file;

initial begin
    $dumpfile("soc_top.vcd");
    $dumpvars(0, tb_soc_top);

    $readmemh("firmware.hex", u_dut.isram);

    // Reset
    repeat(10) @(posedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released at t=%0t", $time);

    // Test 1: boot check
    repeat(500) @(posedge clk);
    if (u_dut.u_cpu.reg_pc < 32'h10)
        $display("FAIL [Test 1] PC=0x%08X", u_dut.u_cpu.reg_pc);
    else
        $display("PASS [Test 1] CPU boot PC=0x%08X", u_dut.u_cpu.reg_pc);

    // Wait for done flag at dsram[0x49] = 0x600DC0DE
    begin : wait_fw
        integer i;
        for (i = 0; i < 500000; i = i + 1) begin
            if (u_dut.dsram[8'h49] === 32'h600DC0DE)
                i = 600000;
            else
                repeat(10) @(posedge clk);
        end
    end

    if (u_dut.dsram[8'h49] === 32'h600DC0DE)
        $display("INFO firmware completed OK");
    else
        $display("FAIL firmware did not complete");

    // Test 3: sentinel
    sentinel = u_dut.dsram[8'h40];
    if (sentinel === 32'hDEADBEEF)
        $display("PASS [Test 3] DSRAM sentinel correct");
    else
        $display("FAIL [Test 3] sentinel=0x%08X", sentinel);

    // Test 4: stack
    sp_val = u_dut.u_cpu.cpuregs[2];
    if (sp_val >= 32'h0001_0000 && sp_val <= 32'h0001_7FFC)
        $display("PASS [Test 4] Stack sp=0x%08X", sp_val);
    else
        $display("FAIL [Test 4] Stack sp=0x%08X", sp_val);

    // Test 5: SA results — identity x [1,2,3,4,5,6,7,8] = [1,2,3,4,5,6,7,8]
    begin
        integer fail5;
        integer r;
        fail5 = 0;
        for (r = 0; r < 8; r = r + 1) begin
            result = u_dut.dsram[8'h41 + r];
            if (result !== r + 1) begin
                $display("FAIL [Test 5] col%0d got=%0d exp=%0d", r, result, r+1);
                fail5 = 1;
            end
        end
        if (!fail5)
            $display("PASS [Test 5] SA all 8 outputs correct");
    end

    $display("[TB] All tests complete");
    $finish;
end

endmodule
`default_nettype wire
