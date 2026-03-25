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
                → Step 6: Verification ← user selectable
                → Step 7: SDC          ← user selectable
```

**Steps 0–3 and GATE are always executed.** Steps 4–7 are user-selectable deliverables.

**Blocking rules** (always enforced on active steps):
- Unconfirmed spec + testplan → no downstream work.
- Missing drawio diagram → GATE cannot proceed.
- Unreviewed RTL → no verification.

---

## Workflow

### Step 0: Entry Point & Deliverables

**0a. Determine entry point from user's request.**

| User says (examples) | Entry | Spec source |
|----------------------|-------|-------------|
| "design a XX" / "from scratch" / "new design" | **NEW** | Write from requirements |
| "I have RTL" / "existing code" | **HAS_RTL** | Extract from RTL, see `reference/rtl2doc_guide.md` |
| "I have a doc" / "existing spec" | **HAS_DOC** | Rewrite from existing doc, see `reference/doc2doc_guide.md` |

⚠️ **The user decides the entry point. Never auto-detect from filesystem.**

**If unclear**, ask once: "What is your starting point? (new design / existing RTL / existing doc)"

**If HAS_RTL but no RTL files found**, ask: "Please provide the RTL file path, or place files in `<project>/rtl/`."

**If HAS_DOC but no doc found**, ask: "Please provide the path to the existing document."

**0b. Determine deliverables.**

After GATE, the default deliverables depend on entry:

| Entry | Default deliverables after GATE | User can override? |
|-------|-------------------------------|-------------------|
| **NEW** | RTL → Review → TB → Tests → SDC → Makefile (all) | Can remove any |
| **HAS_RTL** | Review → TB → Tests → SDC → Makefile (skip RTL) | Can add RTL rewrite, can remove any |
| **HAS_DOC** | RTL → Review → TB → Tests → SDC → Makefile (all) | Can remove any |

Ask user: "Which deliverables do you need after GATE? (default: [list defaults])"

Or user may specify upfront: "docs only" / "docs and TB" / "everything" — respect their choice.

Record entry point and selected deliverables in status.md.

**0c. Determine design targets.**

Ask the user for the following two design targets:

```
Please confirm the design targets:
1. Target coverage? (common: 90% / 95% / 100%, default 95%)
2. Max acceptable combinational logic depth (gate levels)? (common: 10 / 15 / 20, default 15)
   — Fewer levels = higher achievable frequency.
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
  filelist/
    rtl.f
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

**testplan.md** must cover the verification strategy: testcase list (each with automatable pass criteria), coverage targets, and TB timing rules. Agent should consult relevant verification skills for detailed format requirements.

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
2. Read file: <project_path>/docs/spec.md
3. Read file: <project_path>/docs/testplan.md
4. Evaluate spec against ALL 7 checklist categories:
   Completeness, Internal Consistency, Clarity, Parameter Spec,
   Design Justification, Formatting, Diagram Quality
5. Evaluate testplan: each testcase has specific stimulus and automatable pass criteria;
   coverage targets defined; testcase naming is consistent with filename convention
6. Cross-check: spec module list matches testplan DUT references
7. For each category: Status (✅/⚠️/❌) + Finding + Suggested Fix
8. Return structured report with:
   - Verdict: ✅ READY / ⚠️ NEEDS IMPROVEMENT / ❌ MAJOR GAPS
   - Issues table: # | Severity 🔴/🟡/🔵 | Category | Issue | Fix
```

**HAS_RTL addition**: After standard review, cross-check spec against RTL using Phase 3 of `reference/rtl2doc_guide.md`.

**HAS_DOC addition**: After standard review, cross-check spec against original doc — verify no information was lost during rewrite.

**Option B — Self-review fallback**: Same checklist, record in status.md, note "Self-review mode".

⚠️ **User pre-authorization does NOT skip review.** Review is an internal quality gate, independent of user confirmation. Even if user said "skip review" or "just do it", execute review normally.

**Self-review minimum recording**: If using Option B, status.md must include at least:
- Each of the 7 checklist categories explicitly listed with ✅/⚠️/❌ verdict
- At least one specific judgment per category (not just "OK")
- A bare "READY" or "CLEAN" without per-category detail is NOT acceptable

**After review**: Fix all ⚠️ and ❌ issues. Proceed to GATE.

**DONE CRITERIA**: Review report in status.md with per-category detail. All issues resolved.

---

### ⛔ GATE: User Confirmation — RIGID PROTOCOL

**G-1. Pre-authorization check:**
If user explicitly stated upfront that spec is pre-approved (e.g., "confirmed", "skip review", "just do it", "no need to ask"), treat as valid pre-authorization:
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
✅ spec.md + testplan.md complete and internally reviewed.
📋 Please review:
   - docs/spec.md — pay attention to: [list 3-5 key parameters]
   - docs/testplan.md — testcase list and pass criteria
   - docs/*_arch.drawio / .png — microarchitecture diagram
⏸️ Waiting for your confirmation. Reply "confirmed" or provide feedback.
⚠️ I will not start any downstream work until you explicitly confirm.
📦 After confirmation, will execute: [list selected deliverables]
```

**G3.** Check for explicit confirmation:
- ✅ Valid: "confirmed" / "OK" / "yes" / "looks good" / "proceed"
- ❌ Invalid: "continue" alone → Reply: "I need explicit confirmation on the spec. Please reply 'confirmed'."

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
⚠️ Combinational logic depth optimization result:
- Your target: ≤ <target> levels
- Current best: <actual> levels (path: <from> → <to>)
- Attempted <N> optimization iterations; further optimization would break functional correctness.
- Functional correctness takes priority. Current minimum achievable depth is <actual> levels.
- To reduce further, options are:
  (a) Architectural refactoring (add pipeline stages, requires spec change)
  (b) Relax the timing target
  Please confirm whether to accept the current result or adjust the design.
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

### Step 6: Verification

**Runs when**: User selected verification as deliverable.

Complete verification of the IP according to `docs/testplan.md`. All testcases must pass. Coverage must reach the target defined in Step 0c. Apply waivers only for signals that are not testable by design (TB infrastructure, DFT, reserved).

**DONE CRITERIA**: All testcases PASSED. All coverage types ≥ target% (effective, after waivers). Evidence in status.md.

---

### Step 7: SDC Constraints

**Runs when**: User selected SDC as deliverable.

Create `constraint/design.sdc` consistent with spec. Include: clock defs, async groups, CDC constraints, I/O delays, reset false paths, clock uncertainty.

**Consistency rule**: `set_clock_groups -asynchronous` and `set_max_delay` on same path pair are mutually exclusive.

**DONE CRITERIA**: SDC exists. Frequencies match spec. No contradictions.

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
- [ ] [Step 6] Verification                          ← if selected
- [ ] [Step 7] SDC                                   ← if selected
```

## Reference Documents

| Document | Path | When to Read |
|------|------|---------|
| RTL-to-doc guide | `reference/rtl2doc_guide.md` | Step 2 when HAS_RTL — extract spec from code |
| Doc-to-doc guide | `reference/doc2doc_guide.md` | Step 2 when HAS_DOC — rewrite existing doc to standard |
| Doc review checklist | `reference/doc_review_checklist.md` | Step 3 — spec review criteria |
| RTL review checklist | `reference/rtl_review_checklist.md` | Step 5 — code review criteria |
| Diagram guidelines | `reference/microarch_diagram_guidelines.md` | Step 2 — architecture diagram standards |
| Diagram examples | `reference/microarch_examples.md` | Step 2 — correct/incorrect comparisons |
| Consensus rules | `reference/consensus_rules.md` | All steps — stop-and-discuss protocol |
| Change management | `reference/change_management.md` | Any change — atomic update rules |
| Status template | `reference/status_template.md` | Step 1 — initial status.md content |

## Related Skills

| Skill | When to Jump | What to Do |
|-------|-------------|------------|
| `fast-elaborator` | Step 5b — logic depth analysis, combinational path optimization | Run `fast_elab load` → `timing` → optimize → `close` |
| `theme-factory` | Need unified theme for docs/diagrams | Read SKILL.md to select theme |
