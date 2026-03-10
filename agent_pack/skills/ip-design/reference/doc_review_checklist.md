# Spec Document Review Checklist

This document provides structured criteria for evaluating IP design specification documents (`spec.md`). It is used by the spec-reviewer sub-agent to improve document quality **before** presenting to the user for confirmation.

**Goal**: Catch ambiguities, missing details, and internal inconsistencies so the user receives a polished, complete specification.

---

## 1. Completeness

Every spec **must** contain the following sections. Flag any that are missing or empty.

| Required Section | What to Check |
|-----------------|---------------|
| Clock definition table | All clocks listed with name, frequency, period, domain, description |
| Reset definition | Reset names, polarity (active-high/low), synchronous/asynchronous, associated clock domain |
| I/O definition table | Every port with name, direction, width, associated clock/reset |
| Feature list | All supported functionality clearly enumerated |
| Verification plan | Test framework, testbench architecture, testcase list with pass criteria |
| Parameter table | All configurable parameters with name, type, default value, valid range |

**Red flags:**
- "TBD" or "to be determined" anywhere in the spec
- Sections with only placeholder text
- Features mentioned in one section but absent from test plan

---

## 2. Internal Consistency

Cross-check information across different sections of the spec.

| Check Item | How to Verify |
|------------|---------------|
| Clock frequency alignment | Frequencies in clock table must match any timing calculations elsewhere (e.g., throughput estimates, latency budgets) |
| I/O width vs. parameters | If `DATA_WIDTH` is a parameter, all data-related I/O widths must reference it, not hardcode values |
| Feature ↔ test mapping | Every feature in the feature list must have at least one testcase in the verification plan |
| Port ↔ feature mapping | Every I/O port should be exercised by at least one feature; no orphan ports |
| Parameter ↔ constraint mapping | Every parameter that affects timing should be referenced in constraint notes |
| Reset ↔ clock mapping | Every reset signal should specify which clock domain it belongs to |

**Red flags:**
- Clock frequency mentioned as "100MHz" in one place and "10ns period" in another (consistent, but check all instances)
- Data width hardcoded as "8" in I/O table but "DATA_WIDTH" in feature description
- Testcase list doesn't cover all listed features

---

## 3. Clarity & Unambiguity

Check whether a competent engineer could implement the design from this spec alone, without asking questions.

| Check Item | Criteria |
|------------|----------|
| Behavioral specification | For each feature, is the expected behavior fully described (inputs → outputs, timing, edge cases)? |
| Edge cases documented | What happens at boundary conditions? (empty, full, overflow, underflow, simultaneous operations) |
| Priority/arbitration rules | If multiple events can occur simultaneously, is the priority order defined? |
| Protocol descriptions | Are handshake protocols (valid/ready, req/ack) fully specified with timing diagrams or state descriptions? |
| Error handling | What happens on invalid input or illegal state? Is it defined or left ambiguous? |
| Terminology consistency | Are the same terms used consistently throughout? (e.g., don't mix "pointer" and "counter" for the same concept) |

**Red flags:**
- "Behavior is undefined" or "implementation-defined" for important cases
- Vague phrases: "should be fast", "reasonable latency", "approximately N cycles"
- Implicit assumptions not stated (e.g., assuming inputs are always valid)

---

## 4. Parameter Specification

Parameterized designs need especially careful spec review.

| Check Item | Criteria |
|------------|----------|
| Default values | Every parameter has a sensible default value |
| Valid range | Min and max values are specified; what happens outside range? |
| Dependencies | If changing one parameter requires changing another, is this documented? |
| Derived values | Values computed from parameters (e.g., pointer width = $\lceil\log_2(\text{DEPTH})\rceil$) are explicitly stated |
| Power-of-2 constraints | If depth/width must be power-of-2, is this stated and enforced? |
| Typical vs. tested | What parameter combinations will actually be verified? |

**Red flags:**
- Parameter with no valid range (e.g., `DEPTH` can be 0? 1? 2^31?)
- Derived width calculations missing (pointer width, encoding width)
- No mention of which parameter combinations are tested

---

## 5. Verification Plan Quality

The test plan must be concrete enough to implement without further design decisions.

| Check Item | Criteria |
|------------|----------|
| Testcase specificity | Each testcase describes specific stimulus, not just a category (e.g., "write 16 entries then read all" not just "basic read/write") |
| Pass criteria | Each testcase has a clear, automatable pass/fail criterion |
| Coverage | Corner cases, boundary conditions, and error scenarios are included |
| Testbench architecture | DUT instantiation approach, clock generation, reset sequence are described |
| Reference model | If needed, is the reference model approach described? |
| Reusability | Common test infrastructure is identified (tasks, interfaces, checkers) |

**Red flags:**
- Testcase described as "verify basic functionality" — too vague
- No error injection tests
- No test for simultaneous operations (e.g., read+write at same time for FIFO)
- Pass criteria is "check waveform" — not automatable

---

## 6. Design Approach Justification

If the spec proposes a specific implementation approach, verify it's well-justified.

| Check Item | Criteria |
|------------|----------|
| Standard vs. custom | If a well-known approach exists (e.g., Gray-code async FIFO), does the spec use it or explain why not? |
| Trade-off analysis | If multiple approaches exist, are trade-offs briefly discussed? |
| Known risks | Are any known risks or limitations of the chosen approach documented? |
| CDC strategy | For multi-clock designs, is the CDC approach explicitly stated and justified? |

**Red flags:**
- Custom approach with no justification when standard exists
- No mention of CDC strategy in a multi-clock design
- Claims of "novel approach" without explaining advantages over proven methods

---

## 7. Formatting & Professionalism

The spec should be well-organized and easy to navigate.

| Check Item | Criteria |
|------------|----------|
| Table formatting | All tables render correctly in Markdown; columns aligned |
| Section ordering | Logical flow: overview → clocks → I/O → features → verification |
| Cross-references | If one section refers to another, the reference is correct |
| Units | All values have units (MHz, ns, bits, etc.) |
| Naming conventions | Signal names follow a consistent convention (e.g., `snake_case` for RTL signals) |

---

## Review Output Template

After evaluating all categories, produce:

```markdown
## Spec Document Review Report

### Verdict: [✅ READY / ⚠️ NEEDS IMPROVEMENT / ❌ MAJOR GAPS]

### Summary
<Overall assessment in 2-3 sentences>

### Category Results

| # | Category | Status | Key Finding |
|---|----------|--------|-------------|
| 1 | Completeness | ✅/⚠️/❌ | ... |
| 2 | Internal Consistency | ✅/⚠️/❌ | ... |
| 3 | Clarity & Unambiguity | ✅/⚠️/❌ | ... |
| 4 | Parameter Specification | ✅/⚠️/❌ | ... |
| 5 | Verification Plan Quality | ✅/⚠️/❌ | ... |
| 6 | Design Approach Justification | ✅/⚠️/❌ | ... |
| 7 | Formatting & Professionalism | ✅/⚠️/❌ | ... |

### Issues Found

| # | Severity | Category | Issue | Suggested Fix |
|---|----------|----------|-------|---------------|
| 1 | 🔴 CRITICAL / 🟡 MODERATE / 🔵 MINOR | ... | ... | ... |

### Recommendation
- READY FOR USER REVIEW / FIX ISSUES THEN PRESENT / MAJOR REWRITE NEEDED
- <specific action items>
```
