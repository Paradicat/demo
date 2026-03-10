# Critical Path Analysis Patterns

Reference for identifying timing-critical paths in common digital design patterns. Use as a checklist during Step 3 of the floorplan guide workflow.

## Processor Core Patterns

### 1. Writeback → Scoreboard → Re-dispatch Loop
**Typical priority:** 🔴 P0

```
exec_unit.reg_wr_en ──→ scoreboard.lock_release ──→ scoreboard.lock_reg
    ──→ decoder.dep_check ──→ dispatch.inst_rdy ──→ exec_unit.inst_vld
```

**What makes it critical:**
- Single-cycle write-back + unlock + re-issue forms a combinational loop through FFs
- Fan-in: multiple execution units OR their write-enables into one lock bitmap
- Fan-out: lock bitmap feeds dependency check for every new instruction

**RTL signals to look for (use hier paths):**\n- `u_core/u_dispatch.register_lock`, `u_core/u_dispatch.register_lock_release`\n- `u_core/u_dispatch.wr_ch*_en_bitmap` OR'd together\n- `u_core/u_dispatch/u_dec.dec_inst_vld`, `u_core/u_dispatch/u_dec.fetched_inst_rdy`\n- Boundary wire count: each exec unit → dispatch writeback ~44 wires (5b index + 1b en + 32b val + 5b idx + 1b commit)

**PD action:**
- Place regfile at physical center — all write-back paths converge here
- Minimize interconnect from execution units to regfile write ports
- Consider buffer insertion between writeback and scoreboard

### 2. Branch Target → Fetch PC Redirect
**Typical priority:** 🔴 P0

```
alu.rs1_val + alu.inst_imm ──→ alu.pc_val ──→ fetch.pc_update ──→ fetch.mem_req_addr
```

**What makes it critical:**
- Branch compare (32-bit == / < / >=) determines taken/not-taken
- Target address calculation (32-bit add, possibly + mask for JALR)
- Result must arrive at fetch unit to redirect PC within same cycle

**RTL signals to look for (use hier paths):**\n- `u_core/u_alu.pc_update_en`, `u_core/u_alu.pc_val` → `u_core/u_fetch.jb_pc_val`\n- `u_core/u_fetch.fetch_pc_nxt`, `u_core/u_fetch.mem_req_addr`\n- Branch comparisons in u_alu: `rs1_val == rs2_val`, `$signed(rs1) < $signed(rs2)`\n- Boundary wire count: u_alu → u_fetch redirect ~34 wires (1b release + 1b update + 32b pc_val)

**PD action:**
- Place ALU/branch unit adjacent to fetch unit
- Keep branch redirect signal wire length minimal
- ALU adder orientation should face toward fetch

### 3. Memory Address Calculation → Request
**Typical priority:** 🟡 P1

```
regfile.rs1_val ──→ lsu.(rs1 + imm) ──→ mem_req_addr ──→ bus.request
```

**PD action:**
- LSU should be adjacent to bus network
- If TCM is used, LSU should be close to DTCM SRAM port

### 4. Single-Cycle Multiplier
**Typical priority:** 🟡 P1

```
rs1_val ──→ DW02_mult (NxN) ──→ product ──→ reg_val
```

**Area notes:**
- 33×33 multiplier is significant area
- Late-arriving operand selection adds to path

**PD action:**
- Give multiplier generous area allocation
- Input-to-output placement direction should be consistent with data flow

### 5. Single-Cycle Divider (⚠ Design Risk)
**Typical priority:** 🟡 P1 → may become 🔴 P0

```
rs1_val ──→ DW_div (N/N) ──→ quotient/remainder ──→ reg_val
```

**This is almost always an RTL risk at high frequency.** Combinational dividers have O(N²) gate delay. For 32-bit or 33-bit dividers, this is typically the longest path in the entire design.

**PD action:**
- Flag to design team for potential multi-cycle redesign
- If must stay single-cycle: widest possible placement channel, lowest utilization zone

### 6. Floating-Point Operations
**Typical priority:** 🟡 P1

FP division and square root are the longest. FP multiply is medium. FP add is relatively short.

```
Longest paths (descending):
  DW_fp_div > DW_fp_sqrt > DW_fp_mult > DW_fp_add > DW_fp_flt2i/i2flt
```

**PD action:**
- Place float unit in largest available area zone
- Keep away from timing-critical P0 paths
- Individual DW IPs can be freely arranged relative to each other (no intra-FPU dependencies)

### 7. Multi-Port Register File Access
**Typical priority:** 🟡 P1

```
Read: 5-bit index ──→ 32:1 MUX (per read port) ──→ 32-bit data
Write: 5-bit index ──→ 1:32 decoder ──→ bitmap ──→ 32 write-enables
```

**Scaling concern:** Area and delay grow roughly as:
- Read ports: O(N_read × N_entries × data_width)
- Write ports: O(N_write × N_entries × data_width)
- Each additional port: ~+30-50% over single-port base

**PD action:**
- Regfile at center (critical for timing)
- For >4 write ports or >6 read ports, consider register file compiler or SRAM-based implementation
- Write decode MUX fan-out is the key concern

## Bus/Interconnect Patterns

### 8. Multi-Master Arbitration
**Typical priority:** 🟢 P2

```
master0_req + master1_req ──→ arbiter (age matrix / priority) ──→ grant ──→ slave_access
```

**Usually not critical** because bus has inherent latency tolerance. But can become P1 if:
- Arbitration feeds directly into memory access (zero-wait-state TCM)
- Grant signal also drives the next-cycle request generation

**PD action:**
- Place bus logic between master blocks and slave blocks (memory macros)
- Separate fetch-path bus logic from LSU-path bus logic if independent

## SoC-Level Patterns

### 9. Clock Domain Crossing
**Typical priority:** 🟡 P1 (for metastability, not comb delay)

CDC synchronizers should be placed close to the receiving domain's clock tree.

### 10. Interrupt Path
**Typical priority:** 🟢 P2

Interrupt → CSR → trap handler PC → fetch redirect. Functional correctness matters more than timing — interrupts are inherently asynchronous events.

**PD action:**
- CSR near fetch (for trap PC redirect), but low priority since interrupts are rare
