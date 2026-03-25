---
name: floorplan-guide
description: Generate floorplan guide documents and layout diagrams for physical design (PD) teams based on RTL source code analysis. Use this skill whenever the user mentions floorplan, floor plan, FP guide, PD guide, physical design planning, chip layout, macro placement, timing-driven placement, module placement strategy, die floorplan, or asks to analyze RTL for physical implementation. Also trigger when the user wants to create placement constraints, identify critical timing paths for PD, estimate module areas, plan power grid strategy, or produce any deliverable intended for a physical design team — even if they don't explicitly say "floorplan".
---

# Floorplan Guide Skill

Generate a PD-ready floorplan guide and visual layout diagram by systematically analyzing RTL source code. The output helps physical design engineers understand module hierarchy, timing-critical paths, area distribution, and optimal placement strategy.

## Core Principles

1. **RTL-driven**: Every recommendation must trace back to actual RTL code — signal names, module instances, data widths, pipeline stages. Never fabricate microarchitecture details.
2. **Timing-first**: The primary value of this guide is identifying critical timing paths and translating them into placement constraints. Area and power are secondary.
3. **PD-actionable**: Output hard constraints (must-do) and soft constraints (guidance) separately. PD engineers need to know what's negotiable.
4. **Visual**: Always produce both a text document and a diagram. PD teams think spatially.
5. **Language consistency**: Match the user's communication language (Chinese / English / mixed).

## Bundled References

When executing this skill, read the relevant reference files on-demand:
- `references/guide_template.md` — Markdown template for the floorplan guide document (read at Step 5)
- `references/svg_template.md` — SVG structure, color palette, and layout grid (read at Step 6)
- `references/critical_path_patterns.md` — Checklist of common critical path patterns (read at Step 3)

Do NOT read all references upfront. Read each when you reach the relevant step.

## Workflow

```
Step 1: RTL Discovery & Hierarchy Extraction
  → Step 2: Module-by-Module Analysis
    → Step 3: Critical Path Identification  ← read references/critical_path_patterns.md
      → Step 4: Area Estimation
        → Step 5: Write Floorplan Guide Document  ← read references/guide_template.md
          → Step 6: Draw Floorplan Diagram (SVG)  ← read references/svg_template.md
            → Step 7: Deliver & Summarize
```

### Step 1: RTL Discovery & Hierarchy Extraction

Read the design top-level and build the full module hierarchy tree.

**Actions:**
1. Find the filelist (`.f` file) or top-level module to understand the complete file set.
2. Read the top-level module to identify all sub-module instantiations and port interfaces.
3. Recursively read each instantiated module to build a hierarchy tree.
4. Identify the package/parameter file (e.g., `*_pack.sv`) for global constants: data widths, address widths, queue depths, index widths.

**Capture these per module:**
- Module name and instance name
- Port list with widths (especially data buses)
- Key parameters (DEPTH, WIDTH, MODE, etc.)
- Whether the module contains hardened IP (SRAM, DesignWare, analog) — look for `DW_`, `DW02_`, SRAM-like `mem` arrays, or behavioral memory models

**CRITICAL RULE — Use exact RTL instance names for hierarchy paths:**
- PD engineers need **directly usable hier paths** for placement constraints (e.g., `u_core/u_dispatch/u_rf` not "the integer register file")
- Module names shown in the hierarchy tree MUST match the RTL instance names exactly, NOT the module type names
- Always verify by reading the instantiation line in RTL: `module_type instance_name(...)` → use `instance_name`
- Format hierarchy as `parent/child/grandchild` (slash-separated, no `u_top.` prefix unless needed)

**Output:** A hierarchy tree with **exact instance names** like:
```
top_module
├── u_core                          (toy_core)       ← processor core
│   ├── u_fetch                     (toy_fecth3)     ← [IF] fetch unit
│   │   ├── u_fifo                  (toy_fetch_queue2, DEPTH=16)
│   │   └── u_crdt                  (toy_fetch_credit, DEPTH=16)
│   ├── u_dispatch                  (toy_dispatch)   ← [IS] dispatch + decode + regfile
│   │   ├── u_dec                   (toy_decoder)    ← [ID] instruction decoder
│   │   ├── u_rf                    (toy_regfile, MODE=0) ← INT regfile 32×32b 6W10R
│   │   └── u_float_rf              (toy_regfile, MODE=1) ← FP regfile 32×32b 2W3R
│   ├── u_alu                       (toy_alu)        ← [EX] ALU + branch
│   ├── u_lsu                       (toy_lsu)        ← [EX] load/store
│   ├── u_mext                      (toy_mext)       ← [EX] mul/div
│   │   ├── metx_dw_mult            (DW02_mult, 33×33)
│   │   └── metx_dw_div             (DW_div, 33/33)
│   ├── u_float                     (toy_float)      ← [EX] FP unit
│   │   ├── u_fp_flt2i / u_fp_u_flt2i  (DW_fp_flt2i)
│   │   ├── u_fp_i2flt              (DW_fp_i2flt)
│   │   ├── u_fp_add                (DW_fp_add_DG)
│   │   ├── u_fp_mult               (DW_fp_mult_DG)
│   │   ├── u_fp_div                (DW_fp_div_DG)
│   │   ├── u_fp_sqrt               (DW_fp_sqrt)
│   │   └── u_fp_cmp                (DW_fp_cmp_DG)
│   └── u_csr                       (toy_csr)        ← [EX] CSR + trap
└── u_bus                           (toy_bus_DWrap_network_toy_bus) ← interconnect
```

### Step 2: Module-by-Module Analysis

For each module, read the RTL and extract:

#### 2a. Datapath Structure
- Input operands: where do they come from? (regfile read ports, immediate, PC, memory)
- Output results: where do they go? (regfile write ports, PC update, memory request)
- Internal pipeline registers: are there `always_ff` stages between input and output, or is it purely combinational?

#### 2b. Execution Characteristics
- **Combinational depth**: Does the module do its work in one cycle (comb logic) or multiple cycles (FSM/pipeline)?
- **Handshake protocol**: Does it use `vld/rdy`? Is `rdy` always `1'b1` (always ready) or conditional?
- **Resource weight**: Count adders, comparators, multiplexers, shifters, multipliers, dividers.

#### 2c. Hardened IP Identification
Look for these patterns that indicate large physical blocks:
- `DW02_mult`, `DW_div`, `DW_fp_*` → DesignWare IP (area-heavy, fixed structure)
- SRAM behavioral models with `readmemh` → will be replaced with SRAM macros
- Regfile with many read/write ports → may need register file compiler or SRAM

#### 2d. Inter-Module Connectivity (Wire Count)
For each module pair that communicates, **count the total number of wires** crossing the boundary:

**Counting methodology:**
1. List every port connection between the two module instances in the parent RTL
2. Sum all bit widths: a `[31:0]` bus = 32 wires, a `logic` scalar = 1 wire
3. Count both directions separately, then report total
4. Include handshake signals (vld/rdy) in the count

**Record for each module pair:**
- Instance pair: `parent/inst_a` ↔ `parent/inst_b`
- Direction A→B wire count and Direction B→A wire count
- Total wires (A→B + B→A)
- Dominant signal groups (e.g., "operand buses 2×32b", "instruction payload 32b")
- Timing criticality potential (is this on the pipeline forwarding path? branch redirect path? memory access path?)

**Present as a connectivity table:**
```
| Source (hier)        | Sink (hier)          | A→B wires | B→A wires | Total | Key signals |
|----------------------|----------------------|-----------|-----------|-------|-------------|
| u_core/u_dispatch    | u_core/u_alu         | ~173      | ~44       | ~217  | rs1/rs2 2×32b, inst 32b, imm 32b; WB: reg_val 32b |
| ...                  | ...                  | ...       | ...       | ...   | ... |
```

**Why this matters for PD:**
- Wire count directly correlates with routing demand between placement regions
- High wire-count pairs MUST be placed adjacent to avoid congestion
- Asymmetric connections (many A→B, few B→A) suggest data flow direction for placement

### Step 3: Critical Path Identification

This is the most important step. Enumerate all timing-critical paths with priority.

#### Classification Framework

| Priority | Symbol | Criteria |
|----------|--------|----------|
| P0 | 🔴 | Single-cycle loop spanning multiple modules; directly limits Fmax |
| P1 | 🟡 | Long combinational chain within one module; limits Fmax under tight constraints |
| P2 | 🟢 | Multi-module path but with slack; or low-frequency-of-occurrence path |

#### Common Critical Path Patterns in Processors

**Always check these patterns** (ordered by typical severity):

1. **Writeback → Scoreboard → Dispatch loop** (P0 typical)
   - Execution unit writes back → lock/scoreboard release → dependency check → next instruction dispatch
   - Look for: `register_lock`, `scoreboard`, `bypass`, `forward` in dispatch/decode
   - The more write channels feeding back, the worse (fan-in OR tree)

2. **Branch/Jump target → Fetch PC redirect** (P0 typical)
   - ALU/branch unit computes target → updates fetch PC → drives next memory request address
   - Look for: `pc_update_en`, `pc_val`, `jb_pc`, `branch_target` signals crossing from execute to fetch

3. **Memory address calculation** (P1 typical)
   - `rs1_val + immediate` → memory address → request valid
   - Especially bad when combined with AMO (read-modify-write in same cycle)

4. **Multiplier/Divider** (P1 typical)
   - Large DesignWare IPs with deep combinational logic
   - Dividers are almost always the longest single-module path
   - Check if they are single-cycle-combinational or multi-cycle-FSM

5. **Floating-point unit** (P1 typical)
   - FP division and square root are notoriously long
   - FP multiply-add chains can also be critical

6. **Regfile read → execute → regfile write** (P1 typical)
   - Full execute-stage latency from register read to register write
   - Multi-port regfile read MUX adds to the front, write decode adds to the back

7. **Bus arbitration** (P2 typical)
   - Multi-master arbitration, especially with age matrix or priority encoder
   - Usually has slack but can become P1 in complex SoC

**For each path, record (using exact hier paths):**
```
Path ID: P0-001
Priority: 🔴 P0
Source: u_core/u_alu.pc_val            ← use EXACT hier path + signal name
Sink: u_core/u_fetch.fetch_pc_nxt      ← use EXACT hier path + signal name
Intermediate: u_core/u_alu.pc_val → [32-bit branch target] → u_core/u_fetch.pc_val → u_core/u_fetch.fetch_pc_nxt
Cross-boundary wires: ~34 (jb_pc_release_en[1] + jb_pc_update_en[1] + jb_pc_val[32])
Why critical: [explanation of the timing loop/chain]
PD action: [specific placement/routing guidance]
```

**Naming rules for critical paths:**
- Always use `instance_hier.signal_name` format (e.g., `u_core/u_dispatch/u_rf` not "regfile")
- Signal names must match the RTL wire names exactly
- When a path crosses module boundaries, annotate the wire count at each crossing

### Step 4: Area Estimation

Estimate relative area percentages for each module. This doesn't need to be precise — the goal is to help PD understand proportions for floorplanning.

#### Estimation Heuristics

| Resource | Relative Area Weight |
|----------|---------------------|
| 32-bit register (FF) | 1x (baseline) |
| 32-bit adder | ~0.5x per bit |
| 32-bit comparator | ~0.3x per bit |
| 32x32-bit multiplier | ~30-50x |
| 32/32-bit divider | ~60-100x |
| 32-entry × 32-bit regfile (1R1W) | ~32x |
| Each additional R/W port | ~+50% of base regfile |
| FP adder (DW) | ~40-60x |
| FP multiplier (DW) | ~50-80x |
| FP divider (DW) | ~80-120x |
| FP sqrt (DW) | ~80-120x |
| SRAM macro | Separately sized, not in logic area |

Present as a table **with hier paths**:
```
| Hier Path                      | Module Type    | Relative Area | Key Resources |
|--------------------------------|----------------|---------------|---------------|
| u_core/u_fetch                 | toy_fecth3     | ~5%           | 16-entry FIFO, PC logic |
| u_core/u_dispatch/u_rf         | toy_regfile    | ~12%          | 32×32b 6W10R |
| ...                            | ...            | ...           | ...           |
```

### Step 5: Write Floorplan Guide Document

Output a Markdown document saved to `doc/floorplan_guide.md` (or user-specified path).

**Required sections — use this template structure:**

```markdown
# <Design Name> Floorplan Guide for Physical Design

**Document Version:** 1.0
**Date:** <date>
**Target:** High-frequency implementation
**Architecture:** <brief arch description>

---

## 1. Design Overview
- Module hierarchy tree (from Step 1)
- Data widths, key parameters
- Pipeline structure diagram (text-based)

## 2. Pipeline Structure
- Stage-by-stage description
- Which module maps to which stage
- Handshake/stall mechanism

## 3. Critical Timing Paths Analysis
- P0 paths (with 🔴 marker)
- P1 paths (with 🟡 marker)
- P2 paths (with 🟢 marker)
- Each path: source → sink, analysis, PD recommendation

## 4. Module Area Estimation
- Relative area table (percentage)
- Key resource breakdown per module

## 5. Floorplan Placement Strategy
### 5.1 Overall Layout Principle
- Zone-based strategy (e.g., Memory Zone / Pipeline Zone / Compute Zone)

### 5.2 Placement Constraints
- Hard constraints (MUST): SRAM positions, regfile centrality, critical-path adjacency
- Soft constraints (SHOULD): general guidance, aspect ratio, margin

## 6. Floorplan Diagram
- Reference to SVG file

## 7. Clock & Reset Strategy
- Clock domains (how many, relationships)
- Reset type (sync/async) and fan-out concerns
- CTS considerations

## 8. Power Grid & Decoupling
- High-power zones
- Power stripe density recommendations
- Decap placement

## 9. Special Considerations for High Frequency
- RTL-level risks that PD should be aware of (e.g., single-cycle divider)
- Congestion hotspots
- Recommended utilization targets per zone

## 10. Pin/Port Assignment Recommendation
- External I/O grouping and direction
```

**Writing guidelines:**
- **MANDATORY: Use exact RTL hier paths everywhere** — PD engineers will directly copy these into placement constraint scripts. Write `u_core/u_dispatch/u_rf` not "the integer regfile" or "INT Regfile".
- **MANDATORY: Include inter-module wire count table** — Every module pair that communicates must have a wire count. This drives PD's congestion estimation.
- Be specific: name actual signals, actual module instances, actual bit widths
- In the hierarchy tree, show `instance_name (module_type)` format
- For each critical path, explain both *why* it's critical and *what PD should do*, and annotate wire counts at boundary crossings
- Use the priority markers (🔴🟡🟢) consistently
- Include ASCII art pipeline diagrams where helpful
- Power/clock sections can be brief for single-clock designs
- Placement constraints should reference hier paths directly:
  ```tcl
  # Example: PD can paste directly
  create_bound -name fp_core_center -type soft \
    -boundary {{x1 y1} {x2 y2}} \
    u_core/u_dispatch/u_rf u_core/u_dispatch/u_float_rf
  ```

### Step 6: Draw Floorplan Diagram (SVG)

Create an SVG diagram saved to `doc/floorplan_diagram.svg`.

**Diagram requirements:**

1. **Die outline** — Rectangle representing the chip/block boundary
2. **Module blocks** — Rectangles sized roughly proportional to estimated area, **labeled with exact hier paths** (e.g., `u_core/u_dispatch/u_rf`, not "INT Regfile")
3. **SRAM macros** — Distinctly colored (typically green), placed at edges/corners
4. **Pipeline flow** — Arrows showing data flow direction
5. **Critical path highlight** — Red dashed arrows for P0 paths
6. **Inter-module wire counts** — Annotate arrows/connections with approximate wire counts (e.g., "~217") using small text labels near the midpoint of each connection line
7. **Zone indication** — Background color or labels for placement zones
8. **Legend** — Color key for module types, and explanation of wire count labels

**SVG style guidelines:**
- Use gradient fills for visual quality — different color families per module type:
  - SRAM/Memory: greens (`#2d6a4f` → `#1b4332`)
  - Pipeline stages: blues (`#457b9d` → `#1d3557`)
  - Regfile (critical): reds (`#e63946` → `#a8201a`)
  - Execution units: dark teals (`#264653` → `#1a323d`)
  - FP/large compute: purples (`#7b2cbf` → `#5a189a`)
  - Bus/interconnect: grays (`#6c757d` → `#495057`)
  - ALU/branch: oranges (`#f4a261` → `#e07a30`)
- White text on dark fills for labels
- `font-family: 'Helvetica Neue', Arial, sans-serif`
- Include `<defs>` section with reusable gradients, arrow markers, drop shadows
- Canvas size: ~900×1000px is a good default
- Title and subtitle at the top
- Legend at the bottom

**Layout principle:**
- Modules that communicate heavily should be placed adjacent
- Critical paths should be physically short in the diagram
- The diagram should visually communicate the placement strategy from the guide

**Spatial mapping:**
- SRAMs at top/edges (as they'd be in real silicon)
- Pipeline flows top-to-bottom or left-to-right
- Large compute blocks at bottom/corners (they need space, less constrained)

### Step 7: Deliver & Summarize

After creating both files, provide a summary to the user with:
1. The critical path findings (P0 paths highlighted)
2. Any RTL-level risks that may need design changes (e.g., single-cycle divider that PD cannot close timing on)
3. Key placement constraints
4. File locations

## Edge Cases & Special Handling

### Multi-Clock Designs
If the design has multiple clock domains:
- Identify all clock domains and their relationships (async/sync, ratio)
- Mark CDC (Clock Domain Crossing) boundaries as placement constraints
- CDC cells should be placed close to the receiving clock domain

### Designs with Many SRAMs
If there are >4 SRAM macros:
- Group SRAMs by access pattern (instruction vs. data vs. tag)
- Consider SRAM channel routing — avoid creating routing blockage corridors
- May need to split into SRAM "islands" with logic fill between them

### Very Small Designs
If the design is very simple (< 5 modules, no SRAM, no hard IP):
- A lightweight guide is fine — skip power grid deep-dive
- Diagram can be simpler
- Focus on timing paths and basic placement

### SoC-Level Floorplanning
If the user asks about a full SoC (not just a core):
- Identify subsystems and their bandwidth requirements
- Bus topology becomes a primary constraint
- Memory controller placement drives everything else
- Consider thermal: high-power blocks should not all cluster together
