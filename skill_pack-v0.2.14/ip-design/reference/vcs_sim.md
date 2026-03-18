# VCS Simulation Reference

This reference documents VCS compilation and simulation patterns for ip-design workflow.

## Environment Prerequisites

- VCS installed and in PATH (`which vcs`)
- Valid Synopsys license
- GCC compatible with VCS version (VCS will auto-select, e.g. `gcc-4.8`)

## Compilation

### Basic Compilation

```bash
vcs -full64 -sverilog \
    -timescale=1ns/1ps \
    -f filelist/rtl.f \
    -f filelist/tb.f \
    -o simv \
    -l compile.log
```

### Compilation with Debug Access

```bash
vcs -full64 -sverilog \
    -timescale=1ns/1ps \
    -f filelist/rtl.f \
    -f filelist/tb.f \
    -o simv \
    -debug_access+all \
    -l compile.log
```

### Compilation Flags Reference

| Flag | Purpose |
|------|---------|
| `-full64` | 64-bit mode |
| `-sverilog` | Enable SystemVerilog |
| `-timescale=1ns/1ps` | Default timescale |
| `-o simv` | Output executable name |
| `-debug_access+all` | Enable waveform dump and debug |
| `-f <file>` | Read file list |
| `-l <log>` | Log file |
| `-Mdir=<dir>` | Intermediate file directory |
| `+lint=all` | Enable all lint warnings |
| `-assert enable_abort` | Abort on assertion failure |

## Running Simulation

### Basic Run

```bash
./simv +TEST=<test_name> -l sim.log
```

### Run with VCD Waveform Dump

```bash
./simv +TEST=<test_name> +DUMP_VCD -l sim.log
```

### Run with FSDB Waveform (Verdi)

```bash
./simv +TEST=<test_name> +DUMP_FSDB -l sim.log
```

### Plusargs

| Plusarg | Purpose |
|--------|---------|
| `+TEST=<name>` | Select testcase by name |
| `+DUMP_VCD` | Enable VCD waveform dump |
| `+DUMP_FSDB` | Enable FSDB waveform dump (Verdi) |
| `+seed=<N>` | Set random seed |
| `+ntb_random_seed=<N>` | Set SystemVerilog random seed |

## Batch Regression

Run all tests in sequence:

```bash
#!/bin/bash
TESTS="smoke_test full_test empty_test wrap_around simultaneous_wr_rd random_wr_rd"
PASS=0; FAIL=0

for t in $TESTS; do
    echo "=== Running $t ==="
    ./simv +TEST=$t -l sim_${t}.log 2>&1
    if grep -q "Status: PASSED" sim_${t}.log; then
        echo "  RESULT: PASSED"
        PASS=$((PASS + 1))
    else
        echo "  RESULT: FAILED"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "=== Regression Summary ==="
echo "PASSED: $PASS / $((PASS + FAIL))"
echo "FAILED: $FAIL / $((PASS + FAIL))"
```

## Makefile Integration

Recommended Makefile targets:

```makefile
SIM = vcs
RTL_SRC = $(shell cat ../filelist/rtl.f | grep -v "^[#+\-]" | grep -v "^$$")
TB_SRC = $(shell cat ../filelist/tb.f | grep -v "^[#+\-]" | grep -v "^$$" | grep -v "\-f")

TEST ?= smoke_test

compile:
	vcs -full64 -sverilog -timescale=1ns/1ps \
	    -f ../filelist/rtl.f \
	    tb_async_fifo.sv \
	    -o simv -debug_access+all -l compile.log

run: compile
	./simv +TEST=$(TEST) -l sim_$(TEST).log

regress: compile
	@for t in smoke_test full_test empty_test wrap_around simultaneous_wr_rd random_wr_rd; do \
	    echo "=== $$t ===" && ./simv +TEST=$$t -l sim_$$t.log 2>&1 | grep "Status:"; \
	done

clean:
	rm -rf simv simv.daidir csrc *.log *.vcd *.vpd *.fsdb DVEfiles ucli.key
```

## Common Issues

### Compilation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `gcc not found` | VCS needs compatible GCC | Install `gcc-4.8` or set `VCS_CC` |
| `License checkout failed` | No valid license | Check `LM_LICENSE_FILE` env var |
| `Undefined module` | Missing source file | Check filelist includes all files |
| `Syntax error` near SV features | Missing `-sverilog` flag | Add `-sverilog` to VCS command |
| `R_X86_64_32S ... PIE object` | New ld defaults to PIE | Add `-LDFLAGS "-Wl,--no-as-needed -rdynamic"` |
| `undefined reference to snps*` | Missing linker flags | Same fix: `-LDFLAGS "-Wl,--no-as-needed -rdynamic"` |

### VCS 2016 + Modern Linux Workaround

VCS L-2016.06 on modern Linux (Ubuntu 18+, GCC 7+, ld with PIE default) requires:

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
    -cc gcc-4.8 -cpp g++-4.8 -ld g++-4.8 \
    -LDFLAGS "-Wl,--no-as-needed -rdynamic" \
    <sources> -o simv
```

Key flags:
- `-cc gcc-4.8 -cpp g++-4.8 -ld g++-4.8`: Force compatible compiler
- `-LDFLAGS "-Wl,--no-as-needed -rdynamic"`: Fix PIE and symbol resolution issues

### Runtime Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `+TEST plusarg not matched` | Testcase not in case statement | Add test to TB case block |
| `Simulation timeout` | Test hangs | Check for deadlocks; increase timeout |
| `$finish not called` | Test flow incomplete | Ensure all test paths call `$finish` |

## Waveform Debugging

### VCD (open-source compatible)

In testbench:
```systemverilog
initial begin
    if ($test$plusargs("DUMP_VCD")) begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end
end
```

View with GTKWave: `gtkwave dump.vcd`

### FSDB (Verdi)

In testbench:
```systemverilog
initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb_top, "+all");
    end
end
```

View with Verdi: `verdi -ssf dump.fsdb`
