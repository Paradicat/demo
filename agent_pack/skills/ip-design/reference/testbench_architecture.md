# Testbench Architecture Reference

## Directory Responsibilities

- **tb/**: Infrastructure ONLY — DUT wrapper, clock generators, reference models, reusable tasks, interfaces, common utilities. **No test stimulus.**
- **testcase/**: Each testcase in a **separate file** (`tc001_*.sv`, `tc002_*.sv`, etc.). Each file contains one test module with stimulus and checking for one specific scenario.
- **work/**: All simulation artifacts. Gitignored.

## Testcase-to-TB Connection Patterns

### Pattern A: Hierarchical Reference (Recommended)

tb_top and testcase are both top-level modules, compiled together. Testcase accesses tb_top's tasks and signals via hierarchical paths.

```systemverilog
//============================================================
// tb/tb_top.sv — Infrastructure only
//============================================================
`timescale 1ns/1ps

module tb_top;
    parameter DATA_WIDTH = 8;

    // Signal declarations
    logic clk, rst_n;
    logic wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    // ... other signals ...

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    my_design #(.DATA_WIDTH(DATA_WIDTH)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data)
        // ...
    );

    // Reusable tasks
    task automatic apply_reset(int cycles = 10);
        rst_n = 0;
        repeat(cycles) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);
    endtask

    task automatic write_data(input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        wr_en = 1;
        wr_data = data;
        @(posedge clk);
        wr_en = 0;
    endtask

    // Test control
    string test_name = "Unknown";

    task automatic finish_test();
        #100;
        $display("Test '%s' completed at %0t", test_name, $time);
        $finish;
    endtask

    // Waveform dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

    // Timeout watchdog
    initial begin
        #1_000_000;
        $error("TIMEOUT!");
        $finish;
    end
endmodule
```

```systemverilog
//============================================================
// testcase/tc001_basic.sv — Stimulus only
//============================================================
module tc001_basic;
    initial begin
        tb_top.test_name = "TC001: Basic Read/Write";

        // Use tb infrastructure via hierarchical reference
        tb_top.apply_reset(10);
        tb_top.write_data(8'hAB);
        tb_top.write_data(8'hCD);

        // Wait and check
        repeat(20) @(posedge tb_top.clk);

        $display("PASSED: tc001_basic");
        tb_top.finish_test();
    end
endmodule
```

**Compilation** (both modules as top-level):
```bash
# VCS
vcs -full64 -sverilog -timescale=1ns/1ps \
    -f ../filelist/rtl.f -f ../filelist/tb.f \
    ../testcase/tc001_basic.sv \
    -top tb_top -top tc001_basic \
    -o simv_tc001

# Icarus Verilog
iverilog -g2012 \
    -f ../filelist/rtl.f -f ../filelist/tb.f \
    ../testcase/tc001_basic.sv \
    -s tb_top -s tc001_basic \
    -o simv_tc001
```

### Pattern B: Include-based

Testcase stimulus is included into tb_top via preprocessor. Only one top-level module.

```systemverilog
//============================================================
// tb/tb_top.sv — with include slot
//============================================================
module tb_top;
    // ... infrastructure (same as above) ...

    // Testcase include slot (at the end of module)
`ifdef TESTCASE_FILE
    `include `TESTCASE_FILE
`endif
endmodule
```

```systemverilog
//============================================================
// testcase/tc001_basic.sv — Just an initial block (no module wrapper)
//============================================================
initial begin
    test_name = "TC001: Basic";
    apply_reset(10);
    write_data(8'hAB);
    // ...
    $display("PASSED: tc001_basic");
    finish_test();
end
```

**Compilation**:
```bash
vcs ... +define+TESTCASE_FILE=\"../testcase/tc001_basic.sv\" -o simv_tc001
```

## Critical Rules

1. **❌ NEVER use `import module_name::*`** — `import` works only with `package`, not `module`. This is the #1 most common testbench error.

2. **❌ NEVER use blocking assignments (`=`) for sequential logic counters in always @(posedge clk) blocks** — use `<=` for all sequential assignments.

3. **Cross-clock-domain shared resources**: If a reference model or monitor is accessed from multiple clock domains (e.g., write in wclk, read in rclk), use a mailbox or separate queues per domain, not a shared class instance driven by two asynchronous always blocks.

4. **Read data comparison timing**: If RTL has registered output (1-cycle latency), the comparison logic must account for this delay. Push expected data into a pipeline queue and compare after the correct number of cycles.

5. **Combinational vs registered output — scoreboard sampling timing**: This is the **#1 most common scoreboard bug** in async FIFO and similar designs.

   - **Combinational output** (e.g., `assign rd_data = mem[raddr]`): `rd_data` changes **in the same cycle** as the read pointer advances. The monitor must capture `rd_data` **at the same posedge** as `rd_en`, not one cycle later.
   - **Registered output** (e.g., `always @(posedge clk) rd_data <= mem[raddr]`): `rd_data` appears **one cycle after** `rd_en`. The monitor must delay comparison by one cycle.
   - **How to check**: Read the RTL source for the output assignment. If it's `assign` → combinational. If it's `always @(posedge)` → registered.
   - **Typical symptom**: Scoreboard reports mismatches where expected data is "shifted by one" — e.g., expected `0xAB` but got `0xCD` (the next value in the queue).
   - **Fix pattern for combinational output**:
     ```systemverilog
     // Capture rd_data at the SAME posedge as rd_en
     logic [DATA_WIDTH-1:0] rd_data_captured;
     logic rd_en_d, empty_d;

     always @(posedge rclk or negedge rrst_n) begin
         if (!rrst_n) begin
             rd_en_d <= 0;
             empty_d <= 1;
         end else begin
             rd_en_d <= rd_en;
             empty_d <= empty;
             if (rd_en && !empty)
                 rd_data_captured <= rd_data;  // capture NOW, compare NEXT cycle
         end
     end

     // Compare one cycle later using captured value
     always @(posedge rclk) begin
         if (rd_en_d && !empty_d) begin
             exp = ref_queue.pop_front();
             if (rd_data_captured !== exp)
                 $error("MISMATCH: got %0h, expected %0h", rd_data_captured, exp);
         end
     end
     ```

6. **❌ NEVER use `@(posedge signal)` to wait for a level condition** — `@(posedge x)` is an **edge trigger**: it blocks until `x` transitions from 0→1. If `x` is **already 1**, this statement blocks forever.

   - **Common traps**:
     - `@(posedge rst_n)` after reset has already been released → hangs
     - `@(posedge valid)` when handshake `valid` is already asserted → hangs
     - `@(posedge done)` when the operation completed before the wait → hangs
   - **Fix**: Use level-based wait patterns:
     ```systemverilog
     // ❌ WRONG — hangs if rst_n is already 1
     @(posedge rst_n);

     // ✅ CORRECT — works regardless of current level
     wait(rst_n === 1'b1);
     @(posedge clk);   // optional: synchronize to clock edge

     // ✅ CORRECT — explicit level check loop
     while (!rst_n) @(posedge clk);
     ```
   - **General rule**: If you want to ensure a signal IS at a certain level (not that it TRANSITIONS to it), use `wait()` or a `while` loop, never `@(posedge/negedge)`.

## filelist/tb.f Format

```
# TB infrastructure (always compiled)
../tb/tb_top.sv
../tb/ref_model.sv
../tb/monitor.sv

# Testcase files are NOT listed here — they are added per-test at compile time
```

Note: Testcase files are specified on the command line, not in tb.f. This allows each testcase to compile independently.
