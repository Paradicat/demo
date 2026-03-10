# Doc-to-Doc Rewrite Guide

Rewrite an existing non-standard document into the skill's standard `spec.md` format.

## When to Use

- Entry point is **HAS_DOC** — user provides an existing design document
- The document may be in any format: Word, PDF, Markdown, plain text, wiki page, etc.

## Phase 1: Source Document Analysis

Read the entire source document. Classify each section into one of these categories:

| Category | Maps to spec.md section | Example content |
|----------|------------------------|-----------------|
| Clock/timing | Clock definition table | "System clock 100 MHz", "dual clock design" |
| Reset | Reset definition | "Active-low async reset" |
| Interfaces | I/O definition table | Pin lists, bus descriptions, protocol specs |
| Parameters | Parameter table | Configurable widths, depths, thresholds |
| Architecture | Module hierarchy + diagram | Block diagrams, data flow descriptions |
| Behavior | Feature list + edge cases | FSM descriptions, algorithm details, timing diagrams |
| Verification | Verification plan | Test scenarios, coverage goals |
| Context | Background (keep as reference, don't copy) | Project history, alternatives considered |

**Create a mapping table** in your working notes:

```
Source Section → Target spec.md Section → Status
"Section 2.1 Clock Architecture" → Clock definition table → ✅ mapped
"Section 3 Pin Description" → I/O definition table → ✅ mapped
"Appendix A" → (background, skip) → ⏭️ skip
"???" → Reset definition → ❌ MISSING — ask user
```

## Phase 2: Gap Analysis

Check source document against ALL required spec.md sections:

### Required Sections Checklist

- [ ] Clock definition table (name, frequency, period, domain)
- [ ] Reset definition (name, polarity, sync/async, domain)
- [ ] I/O definition table (signal, direction, width, clock/reset domain)
- [ ] Parameter table (name, default, valid range, derived values)
- [ ] Feature list with edge case behavior
- [ ] Module hierarchy tree
- [ ] Microarchitecture diagram
- [ ] Verification plan with specific stimulus and automatable pass criteria

For each missing item:

1. Check if the information is **implied** elsewhere in the document (e.g., clock frequency mentioned in a timing diagram but not in a table)
2. If truly missing → add to **gap list** → ask user to fill

**Gap report format:**

```
## Information Gaps in Source Document

| # | Required Section | Status | Notes |
|---|-----------------|--------|-------|
| 1 | Clock definition | ⚠️ Partial | Frequency mentioned but no domain assignment |
| 2 | Reset definition | ❌ Missing | Not found anywhere in source |
| 3 | Verification plan | ❌ Missing | Source has no test scenarios |
```

Present gap report to user. Wait for answers before proceeding.

## Phase 3: Rewrite Rules

### 3.1 Preserve ALL Information

- Every technical fact in the source must appear in the output spec.md
- If a fact doesn't fit any standard section, add a "Design Notes" section at the end
- **NEVER silently drop information** — if you choose to omit something, note it explicitly

### 3.2 Normalize Formats

| Source format | Standard format |
|--------------|-----------------|
| Prose description of pins | I/O table with columns: Signal, Direction, Width, Clock Domain, Description |
| Inline clock mentions | Clock definition table with columns: Name, Frequency, Period, Domain |
| Scattered parameter values | Parameter table with columns: Name, Default, Valid Range, Description |
| Text-based architecture | Proper `.drawio` diagram + exported PNG |

### 3.3 Resolve Ambiguities

When source document is ambiguous:

1. List possible interpretations
2. State which interpretation you chose and why
3. Mark with `<!-- ASSUMPTION: ... -->` in spec.md
4. These will be flagged during Step 3 review for user to confirm

### 3.4 Structural Mapping Template

```markdown
# <Module Name> Specification

## 1. Overview
← Source: introduction/abstract sections

## 2. Clock & Reset
← Source: clock/timing sections + scattered references

## 3. Parameters
← Source: configuration/parameter sections

## 4. I/O Definition
← Source: interface/pin sections

## 5. Architecture
← Source: block diagram/architecture sections
← Create .drawio diagram from any visual or textual architecture description

## 6. Functional Description
← Source: behavior/algorithm/FSM sections
← Organize by feature, include edge cases

## 7. Verification Plan
← Source: test plan sections (or create from feature list if missing)
```

## Phase 4: Post-Rewrite Verification

After writing spec.md, verify:

1. **Completeness**: Every row in Phase 1 mapping table has been transferred
2. **No invention**: Every fact in spec.md traces back to source document or user-provided gap fill
3. **No loss**: Diff source sections against spec.md — nothing dropped
4. **Format compliance**: All required tables present with correct columns
5. **Diagram**: Architecture description converted to `.drawio` + PNG

Record verification result in status.md before proceeding to Step 3 review.
