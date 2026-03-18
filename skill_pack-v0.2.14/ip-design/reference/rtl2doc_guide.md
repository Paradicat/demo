# Reverse Documentation Guide

How to extract spec.md from existing RTL, and cross-check spec vs RTL for accuracy.

## Phase 1: RTL Reconnaissance

Before writing anything, systematically scan the RTL codebase:

```
1. Module hierarchy:
   grep -rn "module " rtl/*.sv | extract module names
   grep -rn "\.\w\+\s*(" rtl/*.sv | extract instantiations
   → Build parent-child tree

2. Port extraction (per module):
   - input/output/inout declarations
   - Record: name, direction, width, type (wire/reg/logic)

3. Parameter extraction:
   - parameter / localparam declarations
   - Record: name, default value, where used

4. Clock & reset identification:
   - Signals used in always @(posedge/negedge ...)
   - Signals used in if (!rst_n) or if (rst)
   - Map each always block to its clock/reset domain

5. FSM detection:
   - Enum types or localparam state encodings
   - case/casez statements on state variables
   - Record: state names, transitions

6. CDC structures:
   - Multi-stage synchronizer chains (2+ FFs on same signal)
   - (* ASYNC_REG *) attributes
   - Gray code encoders/decoders
   - Record: which signals cross, source domain, dest domain
```

## Phase 2: Structured Extraction to spec.md

Map reconnaissance results to spec.md template sections:

| RTL Finding | spec.md Section |
|-------------|----------------|
| `always @(posedge clk_x)` patterns | Clock definition table |
| `if (!rst_n)` patterns | Reset definition table |
| Top-module port list | I/O definition table |
| `parameter` declarations | Parameter table |
| Instantiation tree | Module hierarchy |
| CDC synchronizers | CDC description + diagram clock domains |
| FSM states + transitions | Feature list / behavior description |
| Assertion / checker logic | Verification plan (derive testcases from what code already checks) |

**Key rule**: Do NOT just copy RTL comments into spec. Spec describes *what and why*; RTL comments describe *how*. Rewrite from the design-intent perspective.

## Phase 3: Cross-Check Checklist

After writing spec.md from RTL, verify completeness with this checklist:

### Ports
- [ ] Every port in RTL top-module appears in spec I/O table
- [ ] Width matches exactly
- [ ] Direction matches
- [ ] Clock/reset domain assignment is correct
- [ ] No phantom ports in spec that don't exist in RTL

### Parameters
- [ ] Every `parameter` (not `localparam`) in RTL appears in spec parameter table
- [ ] Default values match
- [ ] Valid ranges are documented (infer from usage if not obvious)

### Clock Domains
- [ ] Every distinct `posedge clk_x` in RTL has a row in clock definition table
- [ ] Frequency is documented (ask user if not inferable)
- [ ] All CDC crossings are identified and described

### Module Hierarchy
- [ ] Spec module tree matches RTL instantiation tree exactly
- [ ] No missing modules, no extra modules
- [ ] Diagram matches both text and RTL

### Behavior
- [ ] Every FSM is described with states and transitions
- [ ] Edge cases (reset behavior, overflow, underflow, full, empty) are documented
- [ ] Timing relationships (latency, throughput) are specified

### Verification Plan
- [ ] At least one testcase per feature/FSM-path
- [ ] Stimulus is specific (not "test various inputs")
- [ ] Pass criteria are automatable (not "visually inspect waveform")

## When to Use This Guide

- **Step 2 (HAS_RTL entry)**: Use Phase 1-2 to extract spec content from existing RTL
- **Step 3 (HAS_RTL entry)**: Use Phase 3 checklist as additional review criteria alongside `doc_review_checklist.md`
- **Step 5 (any entry with existing RTL)**: Use Phase 3 checklist to verify RTL-spec consistency
