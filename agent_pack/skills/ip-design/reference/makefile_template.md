# Makefile Template for IP Testbench

## Usage

Read this before writing `tb/Makefile` in Step 9. Adapt the template to the specific project.

## Template

```makefile
# Makefile for <project_name> testbench
# Usage: make -f tb/Makefile [SIM=iverilog|vcs] [target]
#
# Targets:
#   compile_<tc>  - Compile a single testcase
#   run_<tc>      - Compile + run a single testcase
#   regression    - Run all testcases
#   clean         - Remove simulation artifacts

SIM ?= iverilog

# ---- Path derivation (robust: works regardless of invocation directory) ----
PROJ_DIR  := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
RTL_FLIST := $(PROJ_DIR)/filelist/rtl.f
TB_FLIST  := $(PROJ_DIR)/filelist/tb.f
TC_DIR    := $(PROJ_DIR)/testcase
WORK_DIR  := $(PROJ_DIR)/work

# ---- Testcase list (update when adding testcases) ----
TESTCASES := tc001_xxx \
             tc002_yyy

# ---- PHONY declarations ----
# All compile_* and run_* targets MUST be PHONY — they are actions, not files.
# Without this, Make may skip them with "Nothing to be done".
.PHONY: all regression clean FORCE \
        $(addprefix compile_,$(TESTCASES)) \
        $(addprefix run_,$(TESTCASES))

all: regression

$(WORK_DIR):
	mkdir -p $(WORK_DIR)

# ==============================================================
# Simulator-specific compile & run
# ==============================================================

ifeq ($(SIM),vcs)

compile_%: FORCE | $(WORK_DIR)
	cd $(PROJ_DIR) && vcs -full64 -sverilog -timescale=1ns/1ps \
		-f filelist/rtl.f -f filelist/tb.f \
		testcase/$*.sv \
		-top tb_top -top $* \
		-o work/simv_$*

run_%: compile_%
	cd $(WORK_DIR) && ./simv_$* | tee $*.log
	@grep -q "PASSED" $(WORK_DIR)/$*.log
	@echo "✅ $* PASSED"

else
# Default: iverilog

compile_%: FORCE | $(WORK_DIR)
	cd $(PROJ_DIR) && iverilog -g2012 \
		-f filelist/rtl.f -f filelist/tb.f \
		testcase/$*.sv \
		-s tb_top -s $* \
		-o work/simv_$*

run_%: compile_%
	cd $(WORK_DIR) && vvp ./simv_$* | tee $*.log
	@grep -q "PASSED" $(WORK_DIR)/$*.log
	@echo "✅ $* PASSED"

endif

# ==============================================================
# Regression
# ==============================================================

regression: $(addprefix run_,$(TESTCASES))
	@echo "============================================"
	@echo "  All $(words $(TESTCASES)) testcases PASSED"
	@echo "============================================"

# ==============================================================
# Clean
# ==============================================================

clean:
	rm -rf $(WORK_DIR)/simv_* $(WORK_DIR)/*.log $(WORK_DIR)/*.vcd \
	       $(WORK_DIR)/csrc $(WORK_DIR)/dump.* $(WORK_DIR)/*.key

# ==============================================================
# Coverage (Step 10) — only for VCS with COV=1
# ==============================================================

COV     ?= 0
COV_DIR := $(WORK_DIR)/cov_merge.vdb

ifeq ($(COV),1)
ifeq ($(SIM),vcs)

# Override VCS binary to a coverage-capable version if needed
# (older VCS versions may fail with -cm, see eda-toolchain-debug/issues/vcs/003)
# VCS_BIN := /path/to/vcs/W-2024.09-SP1/bin/vcs

COV_CM_FLAGS := -cm line+tgl+branch+cond+fsm -cm_dir $(COV_DIR)

# Optional: DUT-only hierarchy filter (recommended)
# Create cm_hier.cfg with: +tree tb_top.u_dut
COV_HIER_CFG := $(PROJ_DIR)/tb/cm_hier.cfg
ifneq (,$(wildcard $(COV_HIER_CFG)))
COV_CM_FLAGS += -cm_hier $(COV_HIER_CFG)
endif

.PHONY: cov_compile cov_regression cov_report cov_clean

cov_compile: FORCE | $(WORK_DIR)
	cd $(PROJ_DIR) && $(VCS_BIN) -full64 -sverilog -timescale=1ns/1ps \
		-f filelist/rtl.f -f filelist/tb.f \
		$(COV_CM_FLAGS) \
		-o work/simv_cov

cov_run_%: cov_compile
	cd $(WORK_DIR) && ./simv_cov +tc_name=$* \
		$(COV_CM_FLAGS) | tee $*_cov.log
	@grep -q "PASSED" $(WORK_DIR)/$*_cov.log
	@echo "✅ $* PASSED (coverage collected)"

cov_regression: $(addprefix cov_run_,$(TESTCASES))
	@echo "============================================"
	@echo "  Coverage regression: $(words $(TESTCASES)) testcases PASSED"
	@echo "  VDB at: $(COV_DIR)"
	@echo "============================================"

cov_report:
	@echo "Reading coverage with cov_reader..."
	cov_reader open $(COV_DIR)
	cov_reader summary

cov_clean:
	rm -rf $(COV_DIR) $(WORK_DIR)/simv_cov $(WORK_DIR)/*_cov.log

endif # SIM=vcs
endif # COV=1

# Force target — ensures pattern rules always re-run
FORCE:
```

## Key Design Decisions

### 1. PHONY + FORCE pattern

`compile_%` and `run_%` are pattern rules. Make treats pattern rules differently from explicit rules — `.PHONY` alone may not prevent "Nothing to be done" if Make's implicit rule resolution decides the target is already satisfied.

Adding `FORCE` as a prerequisite guarantees re-execution:
- `FORCE` is declared `.PHONY` so it's always "out of date"
- Any target depending on `FORCE` will always re-run

### 2. Path derivation

```makefile
PROJ_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
```

This works regardless of how the Makefile is invoked:
- `make -f tb/Makefile` (from project root)
- `cd tb && make` (from tb/ directory)
- `make -f /absolute/path/tb/Makefile` (absolute path)

### 3. Self-contained commands

All recipes use `cd $(PROJ_DIR) &&` to establish a known working directory. Never rely on the user's `$PWD` or shell environment.

### 4. Simulator detection

Use `SIM ?= iverilog` (not `SIM := ...`) so users can override: `make SIM=vcs regression`.

To auto-detect, add before the `ifeq`:
```makefile
# Optional auto-detection (uncomment if desired):
# SIM := $(if $(shell which vcs 2>/dev/null),vcs,iverilog)
```

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| "Nothing to be done for run_tcXXX" | Pattern rule target appears up-to-date | Add `FORCE` prerequisite |
| "No rule to make target" | Testcase not in `TESTCASES` list | Add to list |
| Wrong files compiled | Stale `work/` directory | `make clean` first |
| VCS linker errors | Shell aliases not expanding | See `eda_toolchain_debug/issues/common/001_bash_alias_noninteractive.md` |
| VCS `-cm` linker failure | Old VCS version incompatible with coverage runtime | See `eda_toolchain_debug/issues/vcs/003_vcs_cm_linker_version.md` |
| `urg` missing ncurses | Ubuntu 22.04+ lacks libncursesw.so.5 | Skip urg, use `-cm_dir` auto-merge. See `eda_toolchain_debug/issues/vcs/004` |
| TB code pollutes coverage | Coverage includes testbench lines | Use `-cm_hier cm_hier.cfg` with `+tree tb_top.u_dut` |
