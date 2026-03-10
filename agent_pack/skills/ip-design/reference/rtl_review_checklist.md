# RTL Design Feasibility Review Checklist

This document provides structured criteria for evaluating RTL/IP design proposals. It is used by the feasibility-reviewer agent to perform independent design reviews.

---

## 1. Synthesizability

Check whether the proposed approach can be implemented in synthesizable RTL.

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Language constructs | All constructs must be synthesizable (no `$display`, `#delay`, `initial` in RTL) | Using behavioral constructs that only work in simulation |
| Clock domain structure | Each signal must belong to exactly one clock domain | Signals driven by combinational mixes of multiple clocks |
| Reset strategy | Synchronous or asynchronous reset must be clearly defined; no mixed reset in same module | Reset deassertion not synchronized to clock domain |
| Memory inference | RAM/ROM structures must follow synthesis tool patterns | Non-standard memory access patterns that prevent inference |
| State machines | FSM should use standard coding style (enum + case) | One-hot with incomplete case coverage |

**Red flags:**
- "We'll handle that in simulation" — if it can't be synthesized, it's not RTL
- Proposed use of vendor-specific primitives without fallback
- Reliance on specific synthesis tool optimizations for correctness

---

## 2. Clock Domain Crossing (CDC)

If the design involves multiple clock domains, CDC is usually the highest-risk area.

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Synchronization scheme | Must use a proven CDC pattern (2-stage FF, Gray code, handshake, async FIFO) | Single-stage synchronizer, combinational output crossing domains |
| Encoding correctness | Gray code: only 1 bit changes per transition. Bitmap/thermometer: monotonic transitions | Binary counter crossing domains (multiple bits change simultaneously) |
| Data width vs. encoding width | Encoding must be wide enough to represent full state space | N-bit pointer encoded in N-bit Gray (correct) vs. under-sized encoding |
| Full/Empty detection | For FIFOs: full/empty must be conservative (safe-side error is ok, data loss is not) | Full flag too optimistic → data overwrite; Empty flag too optimistic → reading garbage |
| Metastability MTBF | 2-stage synchronizer MTBF must be >> product lifetime at target frequency | High-frequency clock with wide bus → MTBF drops below acceptable threshold |
| Reset synchronization | Reset release must be synchronized to each clock domain | Asynchronous reset release causing metastability in state machines |

**Red flags:**
- Any multi-bit signal crossing clock domains without proper encoding
- Custom CDC scheme "because Gray code is too slow" — almost always wrong
- No false_path or set_max_delay constraints planned for CDC paths
- Bitmap/thermometer encoding used without analyzing bit-width requirements (need N+1 bits for N-depth FIFO)

---

## 3. Timing & Frequency

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Critical path estimate | Longest combinational path must close timing at target frequency | Deep combinational logic without pipeline stages |
| Pipeline depth | Operations per cycle must be achievable within one clock period | Multi-step computation in single cycle at high frequency |
| Fan-out | High fan-out signals need buffering or replication | Clock-enable or reset driving hundreds of flops |
| Memory access timing | RAM read latency (1 or 2 cycle) must be consistent with pipeline | Assuming single-cycle RAM read when synthesis infers 2-cycle |
| Clock frequency reasonableness | Target frequency must be achievable in target technology | >500MHz in FPGA, >2GHz in modern ASIC without careful design |

**Red flags:**
- "We'll fix timing in synthesis" — critical path issues should be addressed in architecture
- Multiple levels of MUX/priority logic in a single cycle
- No consideration of wire delay in large designs

---

## 4. Area & Resource

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Resource estimation | Rough resource count should be reasonable for target | Designing 1MB SRAM for FPGA that has 256KB total |
| Parameter scalability | Parameterized designs should be checked at actual deployment size | Works at depth=4 but combinational explosion at depth=256 |
| Encoding efficiency | Chosen encoding should not waste excessive resources | One-hot encoding for >32 states; bitmap encoding where binary would suffice |
| Duplication vs. sharing | Replicated resources should be justified | Duplicating expensive multipliers instead of time-sharing |

**Red flags:**
- No area estimate at all — "we'll see after synthesis"
- Parameters with exponential resource growth (e.g., full crossbar NxN)
- Encoding choice driven by "simplicity" without considering area impact at actual width

---

## 5. Functional Correctness

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Corner cases identified | Boundary conditions explicitly addressed (empty, full, overflow, underflow) | Assuming "normal" operation without testing limits |
| Error handling | Behavior on invalid input is defined (not undefined) | Relying on "that won't happen" for illegal state transitions |
| Protocol compliance | Interface behavior matches documented protocol | AXI handshake violations, valid/ready protocol errors |
| Initialization | All state elements have defined initial values after reset | Undefined state after reset leading to non-deterministic behavior |
| Wraparound handling | Counters, pointers, and encodings handle wraparound correctly | Pointer comparison fails when counter wraps (signed vs. unsigned) |

**Red flags:**
- "That case shouldn't happen in normal operation" — it will happen
- No explicit handling of simultaneous read/write, full+write, empty+read
- Counter overflow behavior not analyzed

---

## 6. Verifiability

| Check Item | Criteria | Common Pitfalls |
|------------|----------|-----------------|
| Observability | Key internal signals can be monitored in simulation | Black-box design with no internal visibility |
| Deterministic behavior | Same inputs produce same outputs (no race conditions) | Sensitivity to simulation event ordering |
| Testcase coverage | Proposed test plan covers all functional scenarios | Only happy-path tests, no error injection |
| Debug infrastructure | Waveform dump, assertion, coverage points planned | "We'll add debug later" — no, add it in architecture |

**Red flags:**
- Design complexity exceeds verification capability
- CDC behavior that requires very specific timing to trigger bugs
- No plan for coverage measurement

---

## 7. Comparison with Proven Alternatives

| Check Item | Criteria |
|------------|----------|
| Industry standard exists? | Is there a well-known solution for this problem? (e.g., Gray code FIFO for async FIFO) |
| Deviation justified? | If deviating from standard, is the reason clearly documented? |
| Prior art? | Has this approach been used successfully in published designs or open-source IP? |
| Risk/benefit ratio | Does the non-standard approach offer sufficient benefit to justify additional risk? |

**Key question:** If a proven approach exists and the proposal deviates from it, the burden of proof is on the proposer to explain why. The reviewer should clearly document this deviation and its justification.

---

## Review Output Template

After evaluating all categories, produce:

```markdown
## Feasibility Review Report

### Verdict: [✅ FEASIBLE / ⚠️ FEASIBLE WITH RISKS / ❌ NOT FEASIBLE]

### Summary
<Overall assessment in 2-3 sentences>

### Category Results

| # | Category | Status | Key Finding |
|---|----------|--------|-------------|
| 1 | Synthesizability | ✅/⚠️/❌ | ... |
| 2 | CDC | ✅/⚠️/❌ | ... |
| 3 | Timing & Frequency | ✅/⚠️/❌ | ... |
| 4 | Area & Resource | ✅/⚠️/❌ | ... |
| 5 | Functional Correctness | ✅/⚠️/❌ | ... |
| 6 | Verifiability | ✅/⚠️/❌ | ... |
| 7 | Proven Alternatives | ✅/⚠️/❌ | ... |

### Risk Register (⚠️ and ❌ items only)

| Risk | Severity | Mitigation |
|------|----------|------------|
| ... | HIGH/MEDIUM/LOW | ... |

### Recommendation
- PROCEED / PROCEED WITH MODIFICATIONS / STOP AND REDESIGN
- <specific action items if any>
```
