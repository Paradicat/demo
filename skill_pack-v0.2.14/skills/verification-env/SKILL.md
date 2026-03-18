---
name: verification-env
description: Build a verification environment (testbench, testcases, simulation, regression, coverage) for RTL/IP. Default simulator is VCS when no explicit preference is given. Default regression management tool is simforge when no explicit tool is specified. Use this skill whenever the user wants to set up a verification platform, build a testbench, write SystemVerilog testcases, run simulations, manage regressions, or collect/analyze coverage — even if they don't mention a specific tool. Also consult this skill from ip-design Steps 6/7/9/10.
---

# Verification Environment Skill

Use this skill when building, running, or managing a verification environment for RTL.

## Default Tool Choices

**Always apply these defaults when the user has not expressed an explicit preference:**

| Category | Default | Apply when |
|----------|---------|-----------|
| Simulator | **VCS** | No explicit simulator mentioned |
| Regression management | **simforge** | No explicit tool / script mentioned |

When the user says "跑仿真", "写TB", "搭验证平台", "run simulation", "build testbench", and no tool is named — use VCS + simforge.

---

## Directory Structure

```
<project>/
  tb/                     ← TB infrastructure only (no test stimulus)
  testcase/               ← one file per test: tc001_*.sv, tc002_*.sv
  work/                   ← simulation artifacts (gitignored)
  filelist/
    rtl.f
    tb.f
  cases/
    testplan.yaml          ← simforge testplan
  regress.cfg.yaml         ← simforge config (optional)
```

The `work/` directory is always gitignored. All VCS intermediate files (`csrc/`, `simv`, logs) go there.

---

## Testbench Architecture

Load the **`verification-tbarch`** skill for:
- **Pattern A** (hierarchical reference) and **Pattern B** (include-based) code templates
- Critical rules: `import`, cross-clock, scoreboard timing, `@(posedge)` traps

---

## Simulator: VCS (Default)

Read `skills/ip-design/reference/vcs_sim.md` for full VCS flags and linker notes.

### Detect VCS

```bash
which vcs || { echo "⏸️ BLOCKED: VCS not found. Check PATH and license."; exit 1; }
```

If VCS is not found: report BLOCKED to the user. **Do NOT mark the step complete.**

### Compile One Testcase

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
    -f filelist/rtl.f -f filelist/tb.f \
    testcase/tc001_basic.sv \
    -top tb_top -top tc001_basic \
    -Mdir=work/csrc_tc001 -o work/simv_tc001 \
    -l work/compile_tc001.log
```

Must exit with **0 errors** before running. Check `work/compile_tc001.log` on any failure.

### Run One Testcase

```bash
./work/simv_tc001 -l work/sim_tc001.log
grep "PASSED" work/sim_tc001.log || echo "FAILED"
```

### Smoke Test Protocol

1. `which vcs` → not found → **BLOCKED**
2. Compile → must be 0 errors
3. Run smoke testcase → `grep "PASSED"` in sim.log
4. Record result in `status.md`

---

## Regression Management: simforge (Default)

Consult the `simforge` skill for full CLI reference and daemon lifecycle.

### testplan.yaml for simforge

```yaml
global:
  simulator: vcs
  top_module: tb_top
  compile_opts: "-full64 -sverilog -timescale=1ns/1ps -f ../filelist/rtl.f -f ../filelist/tb.f"
  sim_opts: ""
  timeout: 3600

cases:
  - name: tc001_basic
    tags: [smoke]
    compile_opts: "testcase/tc001_basic.sv -top tc001_basic"

  - name: tc002_edge
    tags: [smoke, regress]
    compile_opts: "testcase/tc002_edge.sv -top tc002_edge"
```

### Submit and Monitor

```bash
cd <project_dir>
simforge submit --tags smoke -j 4
simforge status           # poll until run_status == "completed"
simforge results --filter failed
```

### Full Regression

```bash
simforge submit --tags regress -j 16
simforge status --json    # check total/passed/failed
simforge results --filter failed --json
```

---

## Makefile

Read `skills/ip-design/reference/makefile_template.md` for the full template.

Key rules:
- `SIM ?= vcs` — default simulator variable; **do not hard-code** vcs/iverilog
- Targets: `compile_<tc>`, `run_<tc>`, `regression`, `cov_regression`, `clean`
- Put all artifacts under `work/`; Makefile must be self-contained (no shell aliases)

---

## Coverage Collection (VCS)

Read `skills/ip-design/reference/coverage_closure.md` for DUT-only strategy, waiver practices, and industry targets.

### Add Coverage Flags to Makefile

```makefile
COV ?= 0
CM_FLAGS = $(if $(filter 1,$(COV)),-cm line+tgl+branch+cond+fsm -cm_dir work/cov_merge.vdb -cm_hier cm_hier.cfg,)

compile_%:
    vcs -full64 -sverilog $(CM_FLAGS) \
        -f filelist/rtl.f \
        -f filelist/tb.f \
        testcase/$*.sv ...
```

**cm_hier.cfg** — exclude TB modules from coverage collection:

```
-tree tb_top  exclude
```

⚠️ Some older VCS versions have linker issues with `-cm` — consult `eda-toolchain-debug` (see `issues/vcs/003`).

### Run Coverage Regression

```bash
make cov_regression    # clean → compile COV=1 → run all TCs → VDB at work/cov_merge.vdb
```

Verify all TCs still PASS with coverage flags enabled.

### Analyze with cov-reader

Consult the `cov-reader` skill for CLI commands and Python API.

```bash
cov_reader open work/cov_merge.vdb
cov_reader summary
cov_reader navigate <tb_top>.u_dut
```

### Coverage Closure Loop

```
while coverage < target:
1. Identify highest-impact uncovered area (cov_reader drill-down)
2. Write 1-2 targeted testcases
3. Re-run cov_regression → check incremental gain
4. If hole is untestable after 3 attempts → write waiver (.cwv.yaml)
```

Every waiver must have a `reason`. Validate with `validate_waiver()`. Always compare before/after `get_summary()`.

---

## Related Skills

| Skill | When |
|-------|------|
| `simforge` | Regression submission, parallel jobs, `merge-cov`, past run history |
| `cov-reader` | Coverage analysis, hole identification, waivers |
| `eda-toolchain-debug` | VCS linker/license/environment errors during compile or sim |
