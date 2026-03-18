---
name: verification-testplan
description: Guide for writing testplan.md for RTL/IP verification. Covers testplan format, testcase naming conventions, TB timing/scheduling rules (driver offset, monitor sampling, cross-clock drain), parameter test matrix, coverage targets, and review checklist. Use this skill whenever writing or reviewing a testplan, defining testcase naming, specifying simulation timing rules, setting coverage targets, or checking testplan completeness for an RTL design.
---

# Verification Testplan Skill

Use this skill when writing `docs/testplan.md` for an RTL/IP project.

---

## 1. Required Sections

| Section | Content | Required |
|---------|---------|----------|
| Testbench architecture | Block diagram, scoreboard strategy, clock/reset description, simulator choice | ✅ |
| TB timing/scheduling rules | Driver timing, monitor sampling, cross-clock considerations, drain wait | ✅ |
| Parameter test matrix | Parameter configuration table, annotated with which testcases use which configs | ✅ |
| Testcase list | ID, name, **filename**, stimulus description, pass criteria | ✅ |
| Coverage targets | Line/condition/toggle/functional coverage target values | ✅ |

---

## 2. Testcase Naming Rules

**ID = filename prefix. No aliases.**

```
✅ Correct:
  testplan ID tc006 → file testcase/tc006_concurrent_rw.sv

❌ Wrong:
  testplan ID tc006 → file testcase/tc006_sim_read_write.sv
  ("sim_read_write" does not match "concurrent_rw" in the testplan)

❌ Worse:
  testplan writes tc006, file is named tc006a or test_006
```

**Naming convention**:
- Prefix: `tc` + 3-digit number (`tc001`, `tc002`, ..., `tc100`)
- Suffix: `_<short_desc>.sv` using lowercase underscore-separated English
- The description in the filename must be semantically consistent with the testcase name in testplan
- The testplan table **must include a "filename" column** explicitly specifying the source file

**Cross-check** (before starting verification):
- Compare the filename column in testplan.md against actual files in `testcase/` — must be 1:1
- Fix any mismatch in testplan or filenames before proceeding

---

## 3. TB Timing / Scheduling Rules

### 3.1 Driver Timing

Drivers must add an offset after the clock edge to avoid scheduling races:

```systemverilog
// ✅ Correct: offset 1ns after posedge
@(posedge clk);
#1;
wr_en   = 1;
wr_data = data;

// ✅ Correct: clocking block approach
clocking cb @(posedge clk);
    default input #1step output #1;
    output wr_en, wr_data;
endclocking
```

```systemverilog
// ❌ Wrong: zero-delay drive at posedge → race with DUT sampling
@(posedge clk);
wr_en = 1;  // race condition!
```

**Why**: The DUT samples inputs at `posedge clk`. If the driver also drives at `posedge` with zero delay, simulator scheduling order is non-deterministic. The `#1` offset ensures DUT samples first; the driver update is not seen by DUT until the next cycle.

### 3.2 Monitor / Scoreboard Sampling

Sample DUT outputs at `@(posedge clk)`:

```systemverilog
// ✅ Correct: sample after NBA updates settle
forever begin
    @(posedge rclk);
    if (rd_en_d && !empty_d) begin
        actual   = rd_data;
        expected = ref_queue.pop_front();
        assert(actual === expected);
    end
end
```

**Key points**:
- At `@(posedge clk)`, all NBA (`<=`) assignments have already completed for this timestep
- If RTL output has N-cycle pipeline latency, scoreboard must compare N cycles later

### 3.3 Registered Output Delay

If DUT output is registered (e.g., async FIFO `rd_data` is valid 1 cycle after `rd_en`):

```
Timeline:
  cycle N:   rd_en=1, empty=0  → DUT latches mem[raddr]
  cycle N+1: rd_data is valid  → monitor compares here
```

Scoreboard should record "expected data will appear next cycle" when `rd_en && !empty`, then compare at the next `posedge rclk`.

### 3.4 Cross-Clock Domain Considerations

1. **full/empty signal latency**: 2-stage synchronizer adds 2–3 cycle delay. Stimulus must not assume full/empty updates immediately after write/read.

2. **Independent queues**: Use separate queues for write and read domains in the scoreboard:
   ```systemverilog
   logic [DW-1:0] ref_queue[$];

   always @(posedge wclk) begin
       if (wr_en && !full) ref_queue.push_back(wr_data);
   end

   always @(posedge rclk) begin
       if (rd_en_d && !empty_d) begin
           expected = ref_queue.pop_front();
       end
   end
   ```

3. **Drain wait**: After stimulus ends, wait long enough for data to propagate through CDC synchronizers.
   - Minimum: `2 × sync_stages × slow_clk_period` + `FIFO_depth × rd_clk_period`
   - Conservative default: **100 slow clock cycles**

---

## 4. Testcase List Format

The table must include these columns:

| Column | Description | Required |
|--------|-------------|----------|
| ID | `tcNNN` format | ✅ |
| Name | Short description | ✅ |
| Filename | `tcNNN_<desc>.sv`, must match ID | ✅ |
| Stimulus | Specific step-by-step operations, not vague "test XX feature" | ✅ |
| Pass criteria | **Automatically verifiable** — e.g., "scoreboard comparison all pass" | ✅ |

**Pass criteria rules**:
- Must be automatically determinable by simulation (e.g., `grep "PASSED"`)
- No subjective judgments (e.g., "functionally correct")
- Must specify the check mechanism (scoreboard comparison, signal assertion, counter check, etc.)

---

## 5. Coverage Target Format

```markdown
| Coverage type      | Target  |
|--------------------|---------|
| Line coverage      | ≥ N%    |
| Condition coverage | ≥ N%    |
| Toggle coverage    | ≥ N%    |
| Functional bins    | all hit |
```

Functional coverage points should explicitly list the scenarios that must be exercised.

---

## 6. Review Checklist

After writing testplan.md, verify each item:

- [ ] All testcase IDs are unique and sequential (tc001, tc002, ...)
- [ ] Every ID has a corresponding filename column, format `tcNNN_<desc>.sv`
- [ ] No aliases — the ID in testplan is the exact filename prefix
- [ ] Stimulus descriptions are specific enough to code from directly
- [ ] Pass criteria are automatable, no subjective judgments
- [ ] TB timing rules are defined (driver offset, monitor sampling, drain wait)
- [ ] Parameter matrix annotates which testcases use which configurations
- [ ] Coverage targets are defined
- [ ] Consistent with spec.md (DUT name, signal names, parameter names)
