# Floorplan Guide Document Template

Use this template when generating the floorplan guide markdown. Replace all `<placeholders>` with actual values from RTL analysis.

---

```markdown
# <Design Name> Floorplan Guide for Physical Design

**Document Version:** 1.0  
**Date:** <YYYY-MM-DD>  
**Target:** High-frequency implementation  
**Architecture:** <e.g., RV32IMFC scalar in-order pipeline>

---

## 1. Design Overview

<Brief description of the design's function and architecture.>

<Module hierarchy tree — use EXACT instance names from RTL:>
```
<top_module>
├── <instance_name>           (<module_type>)     ← <role>
│   ├── <child_instance>      (<child_module>)    ← <role>
│   │   ├── <grandchild>      (<gchild_module>, PARAM=V) ← <details>
│   │   └── <grandchild>      (<gchild_module>)   ← <details>
│   └── <child_instance>      (<child_module>)    ← <role>
└── <instance_name>           (<module_type>)     ← <role>
```

NOTE: PD engineers will use these hier paths directly in placement constraint scripts.
Always use `instance_name (module_type)` format. Verify instance names from RTL instantiation lines.

**Data widths:** <addr_width>-bit address / <data_width>-bit data  
**Key parameters:** <list notable parameters>

---

## 2. Pipeline Structure

```
  Stage1  →  Stage2  →  Stage3  →  Stage4  →  Stage5
  (XX)       (XX)       (XX)       (XX)       (XX)
```

- **Stage1 (XX):** <description>
- **Stage2 (XX):** <description>
- ...

---

## 3. Critical Timing Paths Analysis

### 3.N 🔴 P0 — <Path Name> (most critical)

**Path:** `<source_module.signal>` → `<intermediate>` → `<sink_module.signal>`

**Analysis:**
- <why this path is critical>
- <what logic is on this path>
- <what makes it long>

**PD Recommendation:**
- <specific placement guidance>
- <buffer insertion guidance>
- <any RTL feedback>

### 3.N 🟡 P1 — <Path Name>

...

### 3.N 🟢 P2 — <Path Name>

...

---

## 4. Module Area Estimation (Relative)

| Hier Path | Module Type | Relative Area | Key Resources |
|-----------|-------------|--------------|---------------|
| <hier_path> | <module_type> | ~XX% | <resources> |
| <hier_path> | <module_type> | ~XX% | <resources> |
| ... | ... | ... | ... |

## 4.5 Inter-Module Connectivity & Wire Counts

The following table lists all significant inter-module connections with wire counts.
PD should use this to estimate routing demand between placement regions.

| Source (hier)        | Sink (hier)          | A→B wires | B→A wires | Total | Key signals |
|----------------------|----------------------|-----------|-----------|-------|-------------|
| <hier_a> | <hier_b> | ~NNN | ~NNN | ~NNN | <signal groups> |
| ... | ... | ... | ... | ... | ... |

**Connectivity-driven placement priority** (modules with most wires should be adjacent):
1. <highest wire count pair>
2. <second highest pair>
3. ...

---

## 5. Floorplan Placement Strategy

### 5.1 Overall Layout Principle

```
<Zone strategy description, e.g.:>
Zone A (Top)     — Memory Interface Zone: SRAM macros
Zone B (Center)  — Core Pipeline Zone: Fetch → Decode → Dispatch → ALU  
Zone C (Bottom)  — Compute Heavy Zone: MUL/DIV, Float
```

### 5.2 Placement Constraints

#### Hard Constraints
1. <SRAM macro positions>
2. <Regfile centrality>
3. <Critical-path adjacency>

#### Soft Constraints  
4. <Pipeline linear layout>
5. <Execution unit placement>
6. <Bus network placement>

### 5.3 Aspect Ratio
<Recommendation, typically 0.8~1.2>

---

## 6. Floorplan Diagram

See [floorplan_diagram.svg](floorplan_diagram.svg)

<Also include ASCII art version for inline reference>

---

## 7. Clock & Reset Strategy

| Signal | Description | PD Notes |
|--------|------------|----------|
| `clk` | <description> | <notes> |
| `rst_n` | <description> | <notes> |

- **CTS:** <considerations>
- **Reset tree:** <considerations>

---

## 8. Power Grid & Decoupling

### High Power Zones
1. <zone 1>
2. <zone 2>

### Recommendations
- <power stripe guidance>
- <decap placement>
- <SRAM power ring>

---

## 9. Special Considerations for High Frequency

### RTL-Level Risks
1. <risk 1 — e.g., single-cycle divider>
2. <risk 2>

### Congestion Hotspots
- <hotspot 1>
- <hotspot 2>

### Utilization Targets
- <zone>: XX% utilization
- Overall: not exceeding XX%

---

## 10. Pin/Port Assignment Recommendation

| Port Group | Direction | Suggested Side |
|-----------|-----------|---------------|
| <group 1> | <dir> | <N/S/E/W> |
| <group 2> | <dir> | <N/S/E/W> |

---

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | <date> | <author> | Initial release |
```
