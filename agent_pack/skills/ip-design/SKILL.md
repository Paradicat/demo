---
name: ip-design
description: Guide for RTL/IP design — new designs from scratch, existing-RTL documentation, or existing-doc implementation. Covers spec-first workflow, user confirmation gates, project structure, RTL/filelist/testbench/testcase/SDC synchronization. Use when user asks to design new IP, write docs for existing RTL, implement RTL from existing docs, add testbenches, or any combination of RTL design deliverables.
---

# IP Design Skill (RTL)

Use this skill for any RTL/IP design task. Three entry points, one unified flow.

## Core Principles

1. **Plan-first**: Enter plan mode, enumerate steps, execute step-by-step.
2. **Spec-first**: Always produce a spec.md to our standard → Review → User confirms → Then downstream work.
3. **Synchronize downstream**: Any requirement/RTL change triggers updates to filelist, TB, testcases, SDC.
4. **Pure RTL**: Synthesizable Verilog/SystemVerilog. No macros. Plain and portable.
5. **Honest status**: Never mark a task complete when it is blocked or unverified. See `reference/status_template.md`.
6. **Language consistency**: All docs follow user's communication language.
7. **Transparent consensus**: Never secretly change confirmed approach. See `reference/consensus_rules.md`.
8. **Atomic doc updates**: Text + diagrams + structure = the specification. Update all together. See `reference/change_management.md`.

## Workflow Overview

```
Step 0: Determine entry point + deliverables + design targets
  → Step 1: Project structure
    → Step 2: Write spec.md + testplan.md (source depends on entry point)
      → Step 3: Spec & testplan review
        → ⛔ GATE: User confirms spec + testplan + drawio
          → Step 4: RTL        ← user selectable
            → Step 5: RTL review  ← if Step 4 runs or RTL exists
              → Step 5b: Logic depth analysis (fast_elab) ← if RTL exists
                → Step 6: TB + smoke   ← user selectable
                  → Step 7: All tests  ← user selectable
                → Step 8: SDC          ← user selectable
                  → Step 9: Makefile   ← user selectable
                    → Step 10: Coverage ← user selectable
```

**Steps 0–3 and GATE are always executed.** Steps 4–10 are user-selectable deliverables.

**Blocking rules** (always enforced on active steps):
- Unconfirmed spec + testplan → no downstream work.
- Missing drawio diagram → GATE cannot proceed.
- Unreviewed RTL → no TB.
- Failed or never-run compilation → Step 6 is NOT complete.
- Any failed test → Step 7 is NOT complete.

---

## Workflow

### Step 0: Entry Point & Deliverables

**0a. Determine entry point from user's request.**

| User says (examples) | Entry | Spec source |
|----------------------|-------|-------------|
| "设计一个 XX" / "从零开始" / "design a new XX" | **NEW** | Write from requirements |
| "我有 RTL" / "已有代码" / "I have existing RTL" | **HAS_RTL** | Extract from RTL, see `reference/rtl2doc_guide.md` |
| "我有文档" / "已有 spec" / "I have a design doc" | **HAS_DOC** | Rewrite from existing doc, see `reference/doc2doc_guide.md` |

⚠️ **The user decides the entry point. Never auto-detect from filesystem.**

**If unclear**, ask once: "请问您的起点是什么？（从零设计 / 已有 RTL / 已有文档）"

**If HAS_RTL but no RTL files found**, ask: "请提供 RTL 文件路径，或放入 `<project>/rtl/`。"

**If HAS_DOC but no doc found**, ask: "请提供现有文档路径。"

**0b. Determine deliverables.**

After GATE, the default deliverables depend on entry:

| Entry | Default deliverables after GATE | User can override? |
|-------|-------------------------------|-------------------|
| **NEW** | RTL → Review → TB → Tests → SDC → Makefile (all) | Can remove any |
| **HAS_RTL** | Review → TB → Tests → SDC → Makefile (skip RTL) | Can add RTL rewrite, can remove any |
| **HAS_DOC** | RTL → Review → TB → Tests → SDC → Makefile (all) | Can remove any |

Ask user: "GATE 通过后，您需要以下哪些交付物？（默认：[列出默认项]）"

Or user may specify upfront: "只要文档" / "文档和TB" / "全部" — respect their choice.

Record entry point and selected deliverables in status.md.

**0c. Determine design targets.**

Ask the user for the following two design targets (translate to user's language):

```
请确认以下设计目标：
1️⃣ 目标覆盖率是多少？（常见选项：90% / 95% / 100%，默认 95%）
2️⃣ 可接受的最大组合逻辑级数（gate levels）是多少？（常见选项：10 / 15 / 20 级，默认 15）
   — 组合逻辑级数影响最高可达频率，级数越少频率越高。
```

If user doesn't specify, use defaults: **coverage 95%, max logic depth 15 levels**.

Record in status.md:
```
## Design Targets
- Target coverage: <user_value>%
- Max combinational logic depth: <user_value> gate levels
```

These targets will be used in:
- **Step 5b**: `fast_elab` logic depth analysis and optimization
- **Step 10**: Coverage closure target

**DONE CRITERIA**: Entry point, deliverables, and design targets determined. Proceed to Step 1.

---

### Step 1: Project Structure

Create folder layout:

```
<project>/
  status.md       ← from reference/status_template.md
  docs/
    spec.md        ← design specification (no verification plan)
    testplan.md    ← verification plan (testcase list + pass criteria)
    *_arch.drawio  ← editable diagram source
    *_arch.png     ← exported real PNG (not ASCII text)
  rtl/
  tb/              ← infrastructure ONLY (no test stimulus)
  testcase/        ← each test in separate file (tc001_*.sv, tc002_*.sv)
  work/            ← gitignored simulation artifacts
  filelist/
    rtl.f
    tb.f
  constraint/
    design.sdc
```

**DONE CRITERIA**: All directories exist. status.md created from template. Proceed to Step 2.

---

### Step 2: Write spec.md + testplan.md

**This step always runs. The spec must conform to our standard regardless of entry point.**

**Information source by entry:**

| Entry | Action |
|-------|--------|
| **NEW** | Write spec from user requirements. Propose defaults for unspecified parameters. |
| **HAS_RTL** | Read `reference/rtl2doc_guide.md`. Systematically extract from RTL. Do NOT invent behavior — document what RTL actually does. If information is missing from RTL (e.g., clock frequency), ask user. |
| **HAS_DOC** | Read `reference/doc2doc_guide.md`. Rewrite existing doc into our standard format. Preserve all information. If existing doc has gaps, flag them and ask user to fill. |

**spec.md must include** (all entries):

- Clock definition table (name, frequency, period, domain)
- Reset definition (name, polarity, sync/async, domain)
- I/O definition table (signal, direction, width, clock/reset)
- Parameter table (name, default, valid range, derived values)
- Feature list with edge case behavior
- Module hierarchy tree + microarchitecture diagram (see `reference/microarch_diagram_guidelines.md`)
  - Create `docs/*_arch.drawio` → export PNG using VS Code drawio extension (see §7.2 of diagram guidelines) → embed `![](./xxx_arch.png)` in spec
  - If drawio export tool unavailable → **report to user**, do NOT silently skip PNG
- Design constraints summary (clock frequencies, CDC, reset)

**spec.md must NOT include**: verification plan / testcase list. Those go in `testplan.md`.

**testplan.md must include** (see `reference/testplan_guide.md` for full format):

- Testbench architecture overview (block diagram, scoreboard strategy)
- Testcase list table: 编号 (tc001, tc002...), 名称, 激励描述, 通过标准
- **Testcase naming rule**: 编号 = testcase 文件名前缀（e.g., tc001 → `testcase/tc001_*.sv`），不可有别名
- Parameter test matrix (which configs × which testcases)
- Coverage targets
- TB timing/scheduling rules (driver timing, monitor sampling, cross-clock considerations)

**Consistency verification** (mandatory after writing):

1. Extract module names from: text spec, diagram, deliverables list
2. All three lists must match exactly
3. For HAS_RTL / HAS_DOC: cross-check spec against source material — no info loss
4. If mismatch → fix ALL before proceeding

**Annotation rules** (apply to ALL project files written after this point):

- File header: ≤ 10 lines
- Inline comments: only for non-obvious design decisions
- Prohibited: textbook explanations, repeating spec content in code
- Target ratio: code ≥ 60%, comments ≤ 40%

**DONE CRITERIA**: spec.md has all required sections. testplan.md has testcase list with automatable pass criteria. Testcase naming matches filename convention. Diagram is real PNG matching text. Proceed to Step 3.

---

### Step 3: Spec & Testplan Review — MANDATORY

This review MUST happen. Choose one option based on tool availability:

**Option A — Sub-agent (preferred):**

Invoke `runSubagent` with description "Spec and testplan review" and this prompt:

```
You are an independent spec reviewer. Execute these steps:
1. Read file: skills/skills/ip-design/reference/doc_review_checklist.md
2. Read file: skills/skills/ip-design/reference/testplan_guide.md
3. Read file: <project_path>/docs/spec.md
4. Read file: <project_path>/docs/testplan.md
5. Evaluate spec against ALL 7 checklist categories:
   Completeness, Internal Consistency, Clarity, Parameter Spec,
   Design Justification, Formatting, Diagram Quality
6. Evaluate testplan against testplan_guide.md:
   - Testcase naming: 编号 must equal filename prefix (tc001 → tc001_*.sv)
   - Each testcase has specific stimulus description and automatable pass criteria
   - TB timing rules are specified (driver/monitor scheduling)
   - Coverage targets defined
7. Cross-check: spec module list matches testplan DUT references
8. For each category: Status (✅/⚠️/❌) + Finding + Suggested Fix
9. Return structured report with:
   - Verdict: ✅ READY / ⚠️ NEEDS IMPROVEMENT / ❌ MAJOR GAPS
   - Issues table: # | Severity 🔴/🟡/🔵 | Category | Issue | Fix
```

**HAS_RTL addition**: After standard review, cross-check spec against RTL using Phase 3 of `reference/rtl2doc_guide.md`.

**HAS_DOC addition**: After standard review, cross-check spec against original doc — verify no information was lost during rewrite.

**Option B — Self-review fallback**: Same checklist, record in status.md, note "Self-review mode".

⚠️ **User pre-authorization does NOT skip review.** Review is an internal quality gate, independent of user confirmation. Even if user said "不用问我", execute review normally.

**Self-review minimum recording**: If using Option B, status.md must include at least:
- Each of the 7 checklist categories explicitly listed with ✅/⚠️/❌ verdict
- At least one specific judgment per category (not just "OK")
- A bare "READY" or "CLEAN" without per-category detail is NOT acceptable

**After review**: Fix all ⚠️ and ❌ issues. Proceed to GATE.

**DONE CRITERIA**: Review report in status.md with per-category detail. All issues resolved.

---

### ⛔ GATE: User Confirmation — RIGID PROTOCOL

**G-1. Pre-authorization check:**
If user explicitly stated upfront that spec is pre-approved (e.g., "你输出的SPEC我确认",
"skip review", "直接做", "不用问我"), treat as valid pre-authorization:
- Still execute Steps 2–3 (spec writing + review) normally — quality gates are internal, not user-facing
- At GATE, skip G2 (don't send confirmation request)
- Record in status.md: `## ⛔ GATE: PASSED — User pre-authorized on <date>`
- Include the user's exact pre-authorization statement as evidence
- Proceed directly to selected deliverables

**G0.** Pre-GATE mandatory checklist — verify before presenting to user:
- [ ] `docs/spec.md` exists with all required sections
- [ ] `docs/testplan.md` exists with testcase list and pass criteria
- [ ] `docs/*_arch.drawio` exists (editable diagram source)
- [ ] `docs/*_arch.png` exists and is a **real PNG image** (not ASCII art saved as .png)
- If ANY item is missing → go back and create it. **Do NOT proceed to GATE without all deliverables.**

**G1.** Write in status.md: `## ⛔ GATE: AWAITING USER CONFIRMATION`

**G2.** Send this message (translate to user's language):
```
✅ spec.md + testplan.md 已完成并经过内部评审。
📋 请审阅：
   - docs/spec.md — 特别注意：[列出 3-5 个关键参数]
   - docs/testplan.md — 测试用例列表与通过标准
   - docs/*_arch.drawio / .png — 微架构图
⏸️ 等待您的确认。请回复"确认"或提出修改意见。
⚠️ 在您明确确认之前，我不会开始任何下游工作。
📦 确认后将执行：[列出已选定的交付物]
```

**G3.** Check for explicit confirmation:
- ✅ Valid: "确认" / "没问题" / "可以" / "同意" / "通过" / "好的" / "confirmed" / "OK" / "yes"
- ❌ Invalid: "继续" / "你继续" alone → Reply: "我需要您对 spec 的明确确认。请回复'确认'。"

**G4.** After confirmed: write `## ⛔ GATE: PASSED — User confirmed on <date>` in status.md.

**G5.** Proceed to selected deliverables.

---

### Step 4: RTL + Filelist

**Runs when**: User selected RTL as deliverable (default for NEW, HAS_DOC; default skip for HAS_RTL unless user requests rewrite).

**If HAS_RTL and not rewriting**: Only create `filelist/rtl.f` if missing, then skip to Step 5.

Create synthesizable RTL. Update `filelist/rtl.f` (dependency order: leaves first).

**Coding rules**:

- File header ≤ 10 lines
- No textbook explanations in comments
- `output wire` for combinational; `output reg` only when driven by always block
- Active `(* ASYNC_REG = "TRUE" *)` on synchronizer registers — never commented out
- No `assign` driving an `output reg`
- Async FIFO full/empty: compare **in Gray code domain only** (Cummings method)

**DONE CRITERIA**: All RTL files created. filelist/rtl.f in dependency order.

---

### Step 5: RTL Code Review — MANDATORY (when RTL exists)

**Runs when**: Step 4 was executed, OR entry is HAS_RTL (review existing code).

Invoke `runSubagent` (or self-review) with `reference/rtl_review_checklist.md`. Check all 7 categories: Synthesizability, CDC, Timing, Area, Functional Correctness, Verifiability, Spec Compliance.

⚠️ **Self-review minimum recording**: If not using sub-agent, status.md must list all 7 categories with explicit ✅/⚠️/❌ verdict and at least one specific finding per category. A bare "CLEAN" is NOT acceptable.

**After review**: Fix all 🔴 items. If bugs suggest spec misunderstanding → return to user.

**DONE CRITERIA**: Review report in status.md. All 🔴 items fixed.

---

### Step 5b: Logic Depth Analysis — fast_elab (when RTL exists)

**Runs when**: Step 5 completed (RTL exists and reviewed). Automatically runs if user specified max logic depth target in Step 0c.

**Purpose**: Use `fast_elab` (consult `fast-elaborator` skill) to analyze combinational logic depth. If any path exceeds the user's target, attempt optimization. If optimization cannot meet the target, **prioritize functional correctness** and report the achievable minimum.

**5b-1. Load design into fast_elab**

```bash
fast_elab load filelist/rtl.f --top <top_module> --json
```

**5b-2. Analyze logic depth**

```bash
fast_elab timing --max-paths 10 --json
```

Extract the worst-case logic depth from the report. Compare against user's target (from Step 0c).

**5b-3. Classification**

| Worst-case depth vs target | Action |
|---------------------------|--------|
| depth ≤ target | ✅ PASS — record in status.md, proceed |
| depth > target | Enter optimization loop (5b-4) |

**5b-4. Optimization loop** (max 3 iterations)

For each violating path:

1. `fast_elab timing --from <startpoint> --to <endpoint> --json` — get gate-by-gate breakdown
2. Identify the deepest combinational cone — use `fast_elab navigate` and `fast_elab stat` to locate the module
3. Apply RTL optimizations (in priority order):
   - **Pipeline insertion**: add register stage to split the critical path
   - **Logic restructuring**: refactor wide MUX/decoder/priority logic into balanced tree
   - **Pre-computation**: move partial results to earlier pipeline stage
4. After each RTL change → re-run `fast_elab load` + `fast_elab timing` to verify improvement
5. After each RTL change → re-run Step 5 review items affected (Functional Correctness, Spec Compliance)

⚠️ **Function-first principle**: If an optimization would:
- Break functional correctness (testcases fail)
- Violate spec requirements
- Require spec changes the user hasn't approved

→ **STOP optimizing. Revert the change. Keep the functional version.**

**5b-5. If target cannot be met**

After 3 optimization iterations, if logic depth still exceeds the user's target:

1. Run final `fast_elab timing --max-paths 10 --json` to get the actual minimum achievable depth
2. Report to the user (translate to user's language):

```
⚠️ 组合逻辑级数优化结果：
- 您的目标：≤ <target> 级
- 当前最优：<actual> 级（路径：<from> → <to>）
- 已尝试优化 <N> 轮，进一步优化会影响功能正确性。
- 📌 优先保证功能正确，当前设计的最大组合逻辑级数为 <actual> 级。
- 如需进一步降低，可能需要：
  (a) 架构级重构（增加流水级数，需修改 spec）
  (b) 放宽时序目标
  请确认是否接受当前结果，或需要调整设计方案。
```

3. Wait for user's decision:
   - User accepts → record actual depth in status.md, proceed
   - User requests spec change → return to Step 2 for spec update → re-run GATE

**5b-6. Cleanup**

```bash
fast_elab close
```

**DONE CRITERIA**: Logic depth ≤ target (or user accepted actual achievable depth). Result recorded in status.md. `fast_elab` daemon closed.

---

### Step 6: Testbench + Smoke Test — MUST COMPILE AND RUN

**Runs when**: User selected TB as deliverable.

**Read `reference/testbench_architecture.md` for code templates.**

Key rules:
- tb/ = infrastructure only. testcase/ = stimulus only.
- **❌ NEVER use `import module_name::*`** — module is not a package.
- Use hierarchical references or include-based pattern.
- Cross-clock shared resources: separate queues per domain.

**Compilation protocol**:

```
C1. Detect: which vcs / which iverilog
C2. Neither → ⏸️ BLOCKED, tell user. DO NOT mark COMPLETED.
C3. Compile → 0 errors required.
C4. Run smoke → grep "PASSED" required.
C5. Record in status.md.
```

**⚠️ On compile/link/runtime errors**:
- If the error is **not an RTL logic bug** (e.g., toolchain, linker, environment, license) → consult `eda_toolchain_debug` skill first before guessing fixes.
- If the same command works interactively but fails in scripts → suspect environment differences (aliases, PATH, shell mode), not the command itself.
- After 3 failed fix attempts → stop and re-analyze root cause.

**Scoreboard debugging**: If simulation passes but scoreboard reports data mismatches, check the sampling-timing rules in `reference/testbench_architecture.md` — combinational vs registered output requires different monitor timing.

**DONE CRITERIA**: Compile 0 errors. Smoke PASSED. Evidence in status.md.

---

### Step 7: All Testcases — MUST EXECUTE EACH ONE

**Runs when**: User selected tests as deliverable (requires Step 6).

Implement all testcases from `docs/testplan.md`. Each in separate file. **Filename must match testplan 编号**: tc001 → `testcase/tc001_*.sv`.

For each: compile → run → verify PASSED → record in status.md. Debug failures.

**⚠️ On compile/runtime failure**: Same as Step 6 — non-RTL errors go to `eda_toolchain_debug` first. Simulator-specific syntax limitations should use alternative implementations.

**DONE CRITERIA**: All testcases PASSED. If any not executed → NOT complete.

---

### Step 8: SDC Constraints

**Runs when**: User selected SDC as deliverable.

Create `constraint/design.sdc` consistent with spec. Include: clock defs, async groups, CDC constraints, I/O delays, reset false paths, clock uncertainty.

**Consistency rule**: `set_clock_groups -asynchronous` and `set_max_delay` on same path pair are mutually exclusive.

**DONE CRITERIA**: SDC exists. Frequencies match spec. No contradictions.

---

### Step 9: Makefile

**Runs when**: User selected Makefile as deliverable (requires Step 6).

**Read `reference/makefile_template.md` before writing Makefile.**

Create `tb/Makefile`. Targets: `compile_<tc>`, `run_<tc>`, `regression`, `clean`. Parameterize: `SIM ?= vcs`.

**⚠️ Regression scripts vs interactive terminals**:
- Commands that work in interactive terminals may fail in scripts due to environment differences (aliases, env vars, shell mode). On regression failure, consult `eda_toolchain_debug` for known cases.
- Makefile/scripts should be self-contained — never rely on user shell aliases or implicit environment setup.

**DONE CRITERIA**: `make regression` succeeds.

---

### Step 10: Coverage Closure

**Runs when**: User selected coverage as deliverable, or asks for coverage analysis after all testcases pass.

**Pre-requisite**: Step 7 (all testcases PASSED) and Step 9 (Makefile exists).

**Read `reference/coverage_closure.md` before starting.** It contains DUT-only strategy, coverage types, waiver best practices, VCS flags, and industry-standard targets.

**10a. Add coverage flags to Makefile**
- Add `COV ?= 0` flag to Makefile; conditionally add `-cm line+tgl+branch+cond+fsm` when `COV=1`
- Add `cm_hier.cfg` to collect DUT-only coverage (exclude TB/TC at collection time)
- ⚠️ Some older VCS versions have linker issues with `-cm` — consult `eda_toolchain_debug` (see `issues/vcs/003`)
- Use `-cm_dir <shared_dir>` so all testcases auto-merge into a single VDB

**10b. Run coverage regression**
- `make cov_regression` (clean → compile with COV=1 → run all TCs → coverage data in VDB)
- Verify all TCs still PASS with coverage flags enabled

**10c. Analyze with cov-reader** (consult `cov-reader` skill)
- **Prefer direct VDB read**: `cov_reader open work/cov_merge.vdb` — do NOT convert to UCIS XML
- Follow summary-first strategy: `cov_reader summary` → identify lowest-coverage types → drill down
- Navigate to DUT scope: `cov_reader navigate <tb_top>.u_dut`

**10d. Classify coverage holes**
- **DUT holes** → fix with new targeted testcases (see `reference/coverage_closure.md` §8 for strategies)
- **TB/TC infrastructure holes** → waiver (scope-level)
- **DFT/debug/reserved in DUT** → waiver with documented reason
- If DUT submodules already at 100% → all remaining holes are infrastructure → waiver only

**10e. Write waivers** (consult `cov-reader` skill for `.cwv.yaml` format)
- Use **scope-level waivers** (no `items`) for entire TB/TC module exclusion — most reliable
- Per-item waivers (`{line: N, arm: M}`) may silently fail on some DB formats — avoid for bulk exclusion
- Every waiver must have a `reason` explaining why it's not testable
- Validate with `validate_waiver()` before applying
- Always compare before/after `get_summary()` to confirm waivers took effect

**10f. Process — incremental closure loop**
```
while coverage < target:
    1. Identify highest-impact uncovered area
    2. Write 1-2 targeted testcases
    3. Re-run cov_regression → check incremental gain
    4. If a hole is untestable after 3 attempts → waiver
```

**10g. Verify and report**
- Run `get_summary()` with waivers loaded → all types ≥ target%
- Generate coverage report (summary + waiver list + uncovered justifications)

**DONE CRITERIA**: All coverage types ≥ target% (effective, after waivers). Coverage report exists. Waiver file (`.cwv.yaml`) committed.

---

## Plan Mode Checklist

```
- [ ] [Step 0] Entry point + deliverables + targets  ← ALWAYS
- [ ] [Step 1] Project structure + status.md         ← ALWAYS
- [ ] [Step 2] spec.md + testplan.md                 ← ALWAYS
- [ ] [Step 3] Spec & testplan review                ← ALWAYS
- [ ] [GATE]   User confirms spec + testplan + drawio← ALWAYS, BLOCKING
- [ ] [Step 4] RTL + rtl.f                           ← if selected
- [ ] [Step 5] RTL review                            ← if RTL exists (new or existing)
- [ ] [Step 5b] Logic depth analysis (fast_elab)     ← if RTL exists + depth target set
- [ ] [Step 6] TB + smoke test                       ← if selected
- [ ] [Step 7] All testcases                         ← if selected
- [ ] [Step 8] SDC                                   ← if selected
- [ ] [Step 9] Makefile + regression                 ← if selected
- [ ] [Step 10] Coverage closure                     ← if selected
```

## Reference Documents

| Document | Path | When to Read |
|------|------|---------|
| RTL-to-doc guide | `reference/rtl2doc_guide.md` | Step 2 when HAS_RTL — extract spec from code |
| Doc-to-doc guide | `reference/doc2doc_guide.md` | Step 2 when HAS_DOC — rewrite existing doc to standard |
| Doc review checklist | `reference/doc_review_checklist.md` | Step 3 — spec review criteria |
| Testplan guide | `reference/testplan_guide.md` | Step 2/3 — testplan format, naming rules, TB timing |
| RTL review checklist | `reference/rtl_review_checklist.md` | Step 5 — code review criteria |
| TB architecture | `reference/testbench_architecture.md` | Step 6/7 — code templates |
| VCS simulation | `reference/vcs_sim.md` | Step 6/7 — compilation and debugging |
| Diagram guidelines | `reference/microarch_diagram_guidelines.md` | Step 2 — architecture diagram standards |
| Diagram examples | `reference/microarch_examples.md` | Step 2 — correct/incorrect comparisons |
| Consensus rules | `reference/consensus_rules.md` | All steps — stop-and-discuss protocol |
| Change management | `reference/change_management.md` | Any change — atomic update rules |
| Status template | `reference/status_template.md` | Step 1 — initial status.md content |
| Makefile template | `reference/makefile_template.md` | Step 9 — Makefile structure and pitfalls |
| Coverage closure | `reference/coverage_closure.md` | Step 10 — DUT-only strategy, coverage types, waiver practices, VCS flags |

## Related Skills

| Skill | When to Jump | What to Do |
|-------|-------------|------------|
| `eda_toolchain_debug` | Non-RTL errors in Step 6/7/9 (toolchain, linker, environment, license) | Read its SKILL.md → search `issues/` with error keywords |
| `eda_toolchain_debug` | Same command works interactively but fails in scripts/Makefile/CI | Check for environment difference cases |
| `cov-reader` | Step 10 — coverage analysis, hole identification, waiver application | Read its SKILL.md for CLI commands and Python API |
| `fast-elaborator` | Step 5b — logic depth analysis, combinational path optimization | Run `fast_elab load` → `timing` → optimize → `close` |
| `theme-factory` | Need unified theme for docs/diagrams | Read SKILL.md to select theme |
