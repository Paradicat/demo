---
name: cov-reader
description: Read and analyze chip verification coverage databases (UCIS XML, Synopsys VDB, Cadence UCD, Siemens UCDB) using the cov_reader CLI tool and Python API. Use this skill whenever the user mentions coverage data, coverage reports, coverage holes, uncovered bins, covergroups, line/toggle/branch/condition/FSM/assertion coverage, or wants to inspect verification results. Also trigger when the user mentions waivers, exclusions, .cwv.yaml files, .el files, .vRefine files, coverage filtering, excluding DFT signals, or wants to see "effective coverage" after excluding known gaps. Also trigger when you see .xml (UCIS), .vdb, .ucd, .ucdb file extensions in the workspace, when the user mentions coverage metrics like "line coverage 80%", "toggle coverage", "coverpoint", "cross coverage", or when debugging verification gaps — even if they don't explicitly say "cov_reader".
---

# cov_reader — Coverage Database Reader

A standalone CLI tool for reading chip verification coverage databases. Invoke it via shell commands — no SDK, no Python import, no REST API.

Each coverage file is served by a background daemon process that starts automatically on `open`. Subsequent commands talk to the daemon over TCP. This is fully transparent — just run CLI commands sequentially.

## Supported Formats

| Format | Extension/Dir | Vendor | Engine |
|--------|--------------|--------|--------|
| UCIS XML | `.xml` | Accellera standard (all vendors) | Native Python parser |
| VDB | `.vdb/` directory | Synopsys VCS | Requires `urg` in PATH |
| UCD | `cov_work/` directory | Cadence Xcelium | Requires `iccr` in PATH |
| UCDB | `.ucdb` | Siemens Questa | Requires `vcover` in PATH |

## Coverage Types

The tool supports 8 coverage types (use with `--type` flag):

- **line** — statement/line coverage
- **toggle** — signal toggle coverage (0→1, 1→0)
- **branch** — branch/decision coverage (if/case)
- **condition** — condition/expression coverage
- **fsm** — FSM state and transition coverage
- **covergroup** — SystemVerilog covergroup/coverpoint/cross bin coverage
- **assertion** — SVA assertion coverage
- **expression** — expression coverage

## Workflow

Follow this order — it reflects how the daemon lifecycle works:

1. **`cov_reader open <file>`** — load the coverage database, start daemon, learn coverage types and summary
2. **`cov_reader summary`** — get overall coverage percentages (agent should do this first)
3. **`cov_reader navigate`** / **`search`** — explore hierarchy, find module scopes
4. **`cov_reader query`** — read detailed coverage for a specific scope or covergroup
5. **`cov_reader holes`** — find verification gaps (this is the most useful analytical command)
6. **`cov_reader close`** — release resources when done

The `open` → work → `close` structure matters because the daemon holds parsed data in memory. Skipping `open` causes `NO_FILE_OPEN` errors; skipping `close` wastes resources (though daemons auto-exit after 30 min idle).

## Strategy for Coverage Analysis

**Summary-first, then drill down.** This saves agent context tokens:

1. `summary` → identify which coverage types are low
2. `holes --type <lowest_type> --threshold 90` → find the worst scopes
3. `query <worst_scope> --type <type>` → see individual uncovered items
4. `navigate <scope>` → explore child modules if needed

**Never dump everything at once.** Use `--type` filters and `--max` limits to keep output small.

---

## Commands

### open

Load a coverage database and start its daemon.

```
cov_reader open <file_or_dir> [--format F] [--idle-timeout N] [--session ID] [--json] [--bsub]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `file_or_dir` | yes | — | Path to `.xml`, `.ucdb` file, or `.vdb`/`cov_work` directory |
| `--format F` | no | auto-detect | Force format: `ucis_xml`, `vdb`, `ucd`, `ucdb` |
| `--idle-timeout N` | no | 1800 | Auto-shutdown after N seconds idle |
| `--session ID` | no | auto | Isolate daemons across parallel analyses |
| `--json` | no | off | Structured JSON output |
| `--bsub` | no | off | Launch daemon on HPC compute node (not yet implemented) |

**Returns:** format, file size, number of tests, coverage types present, total instances, summary percentages per type, test list.

**JSON output `file_info` fields:**
- `format` — e.g. "ucis_xml"
- `file_size` — human readable, e.g. "10.5 KB"
- `num_tests` — how many tests contributed coverage
- `coverage_types` — list: ["line", "toggle", "branch", ...]
- `total_instances` — number of design scopes
- `summary` — dict: `{"line": 80.0, "toggle": 89.3, ...}`
- `tests` — list of `{"name": "test_basic", "status": "PASSED", "tool": "VCS"}`

### summary

Display overall coverage summary. Start here after `open` to understand the coverage landscape.

```
cov_reader summary [--type T] [--file F] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--type T` | no | all | Filter: `line`, `toggle`, `branch`, `condition`, `fsm`, `covergroup`, `assertion` |
| `--file F` | no | auto | Target file (needed when multiple files are open) |
| `--json` | no | off | Structured JSON output |

**Returns:** per-type coverage: covered count, total count, percentage, goal.

### navigate

Browse the design coverage hierarchy — like `ls` for a chip's module tree with coverage annotations.

```
cov_reader navigate [path] [--type T] [--file F] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `path` | no | top level | Dotted scope path (e.g. `tb_top.dut.u_cpu`) |
| `--type T` | no | all | Filter by coverage type |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Returns:** child scopes with name, full path, child count, signal count, per-type coverage percentage.

Start with no path to see top-level scopes, then drill down.

### search

Find coverage scopes/items by name pattern.

```
cov_reader search <pattern> [--type T] [--scope S] [--regex] [--max N] [--file F] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `pattern` | yes | — | Glob pattern (e.g. `'*axi*'`). Use `--regex` for regex. **Shell-quote it** |
| `--type T` | no | all | Filter by coverage type |
| `--scope S` | no | global | Restrict search to this scope subtree |
| `--regex` | no | off | Treat pattern as Python regex |
| `--max N` | no | 50 | Maximum number of results |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Returns:** matching scopes/items with full path and coverage info. Case-insensitive.

### query ⭐

Read detailed coverage data for a specific scope or covergroup — this is for drilling into specific modules.

```
cov_reader query <path> [--type T] [--detail] [--max N] [--file F] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `path` | yes | — | Full scope path (e.g. `tb_top.dut.u_cpu`) or covergroup path |
| `--type T` | no | all | Filter: `line`, `toggle`, `branch`, etc. |
| `--detail` | no | off | Expand bin-level detail for covergroups |
| `--max N` | no | 200 | Maximum output items |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**For design scopes:** Returns items grouped by type — each with name, hit count, covered status. Line items include line numbers; toggle items include direction.

**For covergroups:** Returns coverpoints with coverage %, bin count, covered/uncovered counts. With `--detail`, expands all bins with name, hit count, type (user/auto/illegal/ignore/cross).

### holes ⭐⭐

Find coverage holes — the most useful command for verification gap analysis. Returns items sorted worst-first.

```
cov_reader holes [--type T] [--threshold N] [--scope S] [--max N] [--file F] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--type T` | no | all | Filter by coverage type |
| `--threshold N` | no | 100.0 | Coverage percentage threshold — items below this are "holes" |
| `--scope S` | no | global | Limit to items under this scope |
| `--max N` | no | 50 | Maximum results |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Returns:** list of holes: item type, scope, name, full path, current score, gap (how far below threshold).

**Typical usage patterns:**
- `cov_reader holes` — all holes at 100% (anything not fully covered)
- `cov_reader holes --type line --threshold 90` — line coverage below 90%
- `cov_reader holes --type covergroup --scope tb_top.dut` — covergroup gaps under DUT
- `cov_reader holes --threshold 80 --max 100` — broad sweep of all types below 80%

### close

Stop the daemon and free resources.

```
cov_reader close [--file F] [--all] [--session ID] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--file` | no | — | Close daemon for this specific file |
| `--all` | no | off | Close ALL daemons in current session |
| `--json` | no | off | Structured JSON output |

With one file open, bare `cov_reader close` suffices. With multiple files, use `--file` or `--all`.

### list

Show all active daemons — useful when managing multiple open files.

```
cov_reader list [--session ID] [--json]
```

**Returns:** daemon ID, file name, host, port, session, status.

---

## Error Handling

| Error Code | Meaning | Fix |
|------------|---------|-----|
| `NO_FILE_OPEN` | No coverage database is open | Run `cov_reader open <file>` first |
| `AMBIGUOUS_TARGET` | Multiple files open without `--file` | Add `--file <path>` to specify |
| `FILE_NOT_FOUND` | File/directory doesn't exist | Check path |
| `LAUNCH_FAILED` | Daemon failed to start | Check `~/.cov-reader/logs/` for details |
| `DAEMON_ERROR` | Daemon started but not responding | Close and re-open |
| `TOOL_NOT_FOUND` | Vendor tool (urg/iccr/vcover) not in PATH | Set up tool environment |

## Constraints & Best Practices

1. **Always use `--json` when parsing output programmatically.** Human-readable tables are for display only.
2. **Use `--type` to narrow queries.** Without it, all 8 coverage types are returned, which can be verbose.
3. **Shell-quote glob patterns:** `'*clk*'` not `*clk*`, to prevent shell expansion.
4. **Use `--session`** when running parallel coverage analyses to avoid daemon conflicts.
5. **Coverage percentages are per-instance**, not weighted by module size. Use `holes` to find the worst spots.
6. **Scope paths use dot notation:** `tb_top.dut.u_cpu.u_alu` — same as Verilog hierarchy.
7. **One-shot load architecture:** The engine parses the full file once on `open`, then all queries run from memory (sub-millisecond). Large files may take a few seconds to open but queries are instant.

## Debug Strategy

If a command fails or returns unexpected results:

1. Check `cov_reader list --json` — is the daemon running?
2. Check `~/.cov-reader/logs/<daemon_id>.log` for daemon errors
3. Try `cov_reader summary --json` — does the file have the coverage types you expect?
4. For VDB/UCD/UCDB: verify the vendor tool is in PATH (`which urg`, `which iccr`, `which vcover`)
5. Re-open with `cov_reader close --all && cov_reader open <file>` to reset

## Example Session

```bash
# Open a UCIS XML coverage database
cov_reader open /path/to/coverage.xml --json

# Check overall coverage
cov_reader summary --json

# Find all line coverage holes below 90%
cov_reader holes --type line --threshold 90 --json

# Drill into the worst module
cov_reader query tb_top.dut.u_cpu --type line --json

# Search for a specific module
cov_reader search '*axi*' --json

# Explore module hierarchy
cov_reader navigate tb_top.dut --json

# Check covergroup details with bins
cov_reader query tb_top.dut.cg_bus_txn --type covergroup --detail --json

# Done — release resources
cov_reader close --all
```

---

## Waiver System

cov_reader includes a **waiver subsystem** for excluding specific coverage items from verification metrics — analogous to Synopsys `.el` files, Cadence `.vRefine` files, or Questa `coverage exclude` commands, but using a **unified YAML format** (`.cwv.yaml`) that is vendor-neutral.

### When to Use Waivers

Use waivers when the user needs to:
- **Exclude known-untestable items** — DFT signals, debug modules, synthesis-only paths
- **View "effective coverage"** — coverage after waiving expected gaps
- **Add / remove exclusion rules** — incrementally manage waiver sets
- **Validate waiver correctness** — syntax, semantic, and match checks
- **Export to EDA-native formats** — produce `.el` / `.vRefine` / `.do` for handoff to other teams' tools

Waivers are **NOT** a CLI subcommand yet. They are a **Python-level API** on the engine object. When an agent needs waiver functionality, it must write and execute a short Python script.

### Waiver YAML Format (`.cwv.yaml`)

The universal waiver file format. Every rule consists of a **scope** (which hierarchy), a **type** (which coverage metric), optional **items** (which specific things), and a **reason** (why excluded).

```yaml
version: "1.0"

metadata:                        # optional block
  project: "my_chip"
  author: "engineer_name"
  created: "2026-02-28"
  description: "DFT waivers"

rules:
  # Exclude an entire module (all coverage types)
  - id: "W001"
    scope: "tb_top.dut.u_debug"
    type: all
    reason: "Debug module, not verification target"
    ticket: "JIRA-1234"          # optional

  # Exclude specific lines
  - id: "W002"
    scope: "tb_top.dut.u_cpu"
    type: line
    items:
      - line: 125
      - line: 126
    reason: "Dead code after synthesis optimization"

  # Exclude specific toggle signals (wildcard supported)
  - id: "W003"
    scope: "tb_top.dut.*"        # wildcard: all children of dut
    type: toggle
    items:
      - signal: "scan_*"         # wildcard: all scan_ signals
    reason: "DFT signals not exercised in functional sim"

  # Exclude a specific branch arm
  - id: "W004"
    scope: "tb_top.dut.u_cpu"
    type: branch
    items:
      - line: 45
        arm: 1
    reason: "Unreachable else: valid always high"

  # Exclude a condition row
  - id: "W005"
    scope: "tb_top.dut.u_cpu"
    type: condition
    items:
      - line: 88
        row: 3
    reason: "Mutually exclusive inputs"

  # Exclude a covergroup bin
  - id: "W006"
    scope: "tb_top.dut"
    type: covergroup
    items:
      - covergroup: "cg_bus_txn"
        coverpoint: "cp_addr"
        bin: "reserved"
    reason: "Reserved address space, never used"

  # Exclude an FSM transition
  - id: "W007"
    scope: "tb_top.dut.u_cpu"
    type: fsm
    items:
      - fsm: "main_fsm"
        transition: "ERROR->IDLE"
    reason: "Error recovery verified by formal"
```

#### Field Reference

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `version` | yes | string | Fixed `"1.0"` |
| `metadata` | no | object | Project, author, created, description |
| `rules` | yes | list | List of waiver rules |
| `rules[].id` | yes | string | Unique ID within file (e.g. `"W001"`) — used for add/remove |
| `rules[].scope` | yes | string | Hierarchy path, supports `*` (one level) and `**` (recursive) |
| `rules[].type` | yes | enum | `all` / `line` / `toggle` / `branch` / `condition` / `fsm` / `covergroup` |
| `rules[].items` | no | list | Specific items; **omit to exclude ALL items of that type under scope** |
| `rules[].reason` | yes | string | Justification (mandatory for signoff audit) |
| `rules[].ticket` | no | string | Issue tracker reference |
| `rules[].author` | no | string | Rule author |
| `rules[].date` | no | string | Creation date |

#### Item Fields by Type

| Rule type | Item fields | Example |
|-----------|------------|---------|
| `line` | `line` (int) | `{line: 125}` |
| `toggle` | `signal` (str, glob ok) | `{signal: "scan_*"}` |
| `branch` | `line` + `arm` (int) | `{line: 45, arm: 1}` |
| `condition` | `line` + `row` (int) | `{line: 88, row: 3}` |
| `covergroup` | `covergroup` + `coverpoint` + `bin` (str, glob ok) | `{covergroup: "cg_bus", coverpoint: "cp_addr", bin: "reserved"}` |
| `fsm` | `fsm` + `transition` (str) | `{fsm: "main_fsm", transition: "IDLE->RUN"}` |

### Python API Usage

Waivers are used through Python imports. The agent should write a Python script and execute it.

#### Module Imports

```python
from coverage_reader.waiver import (
    load_waiver,          # parse .cwv.yaml → WaiverFile
    dump_waiver,          # WaiverFile → YAML string / file
    validate_waiver,      # 3-level validation
    ValidationResult,     # validation finding dataclass
    WaiverFilter,         # app-layer exclusion filter
    WaiverFile,           # top-level waiver model
    WaiverRule,           # single rule
    export_synopsys_el,   # → .el
    export_cadence_vrefine, # → .vRefine XML
    export_questa_do,     # → .do Tcl script
)
```

#### Loading and Applying Waivers to a VDB

The most common workflow — load a coverage database, apply waivers, then observe the adjusted coverage:

```python
from coverage_reader.engine.vdb_engine import VdbEngine

eng = VdbEngine()
eng.open("/path/to/simv.vdb")

# Before waivers
summary_before = eng.get_summary("all")
print("Line coverage before:", summary_before["line"]["percentage"])

# Load waivers — marks matching CoverItems as excluded,
# recalculates all coverage percentages automatically
result = eng.load_waivers(["waivers.cwv.yaml"])
print(f"Applied {result['rules_loaded']} rules, "
      f"excluded {result['items_excluded']} items")

# After waivers — percentages are now recalculated
summary_after = eng.get_summary("all")
print("Line coverage after:", summary_after.get("line", {}).get("percentage"))

# Check waiver status
status = eng.get_waiver_status()
print(status)
# {"status": "ok", "waiver_files": 1, "total_rules": 5,
#  "total_excluded": 42, "excluded_by_type": {"line": 20, "toggle": 22}}

# Undo all waivers
eng.unload_waivers()  # restores original coverage

eng.close()
```

**Key points for `load_waivers()`:**
- Accepts a **list** of YAML file paths (multiple files merged)
- Returns `{"status": "ok", "rules_loaded": N, "items_excluded": N, "ucapi_loaded": bool}`
- Automatically recalculates all coverage summaries, scope coverage, and hole data
- Dual strategy: tries UCAPI `.el` loading first (VDB only), always applies app-layer filter
- Can be called multiple times to load additional waivers
- Rule IDs must be globally unique across all loaded files

**Key points for `unload_waivers()`:**
- Removes **all** exclusion marks and restores original coverage
- Returns `{"status": "ok", "items_restored": N}`

**Key points for `get_waiver_status()`:**
- Returns breakdown of excluded items by coverage type
- No arguments needed

#### Creating a Waiver File Programmatically

When the agent needs to **generate** a waiver (e.g. user says "exclude all DFT signals"):

```python
from coverage_reader.waiver import WaiverFile, WaiverRule, WaiverItem, dump_waiver

wf = WaiverFile(version="1.0")
wf.add_rule(WaiverRule(
    id="W001",
    scope="tb_top.dut.*",
    type="toggle",
    reason="DFT signals not exercised in functional simulation",
    items=[
        WaiverItem(signal="scan_en"),
        WaiverItem(signal="scan_in"),
        WaiverItem(signal="scan_clk"),
    ],
    ticket="PROJECT-123",
))
wf.add_rule(WaiverRule(
    id="W002",
    scope="tb_top.dut.u_debug",
    type="all",
    reason="Debug module excluded from coverage",
))

# Write to file
dump_waiver(wf, "project_waivers.cwv.yaml")

# Or get as string
yaml_text = dump_waiver(wf)
```

#### Validating a Waiver File

Three validation levels — use before applying to catch errors early:

```python
from coverage_reader.waiver import validate_waiver

# L1 (format) + L2 (semantic) — no engine needed
results = validate_waiver("waivers.cwv.yaml")
for r in results:
    print(r)  # e.g. "[L2] W003: error: Invalid type 'invalid_type'"

# L3 (match) — requires an open engine to check scope/item matching
results = validate_waiver("waivers.cwv.yaml", engine=eng)
for r in results:
    if r.severity == "error":
        print(f"ERROR: {r}")
```

| Level | Checks | Requires Engine |
|-------|--------|-----------------|
| **L1** | YAML syntax, required fields (`id`, `scope`, `type`, `reason`), unique IDs | No |
| **L2** | Type is valid enum, scope non-empty, type-specific item field presence | No |
| **L3** | Scope matches actual instances in DB, rule matches at least one coverage item | **Yes** |

#### Exporting to EDA-Native Formats

Convert unified YAML to vendor-specific format for handoff:

```python
from coverage_reader.waiver import (
    load_waiver, export_synopsys_el, export_cadence_vrefine, export_questa_do,
)

wf = load_waiver("waivers.cwv.yaml")

# Synopsys .el (for urg -elfile)
export_synopsys_el(wf, "output.el")

# Cadence .vRefine (for imc -refinement)
export_cadence_vrefine(wf, "output.vRefine")

# Questa .do (for source in vsim)
export_questa_do(wf, "output.do")

# Or get string without writing file
el_text = export_synopsys_el(wf)
```

**Export format details:**

| Target | Scope separator | Path prefix | Type mapping |
|--------|----------------|-------------|--------------|
| Synopsys `.el` | `.` | none | `line`→`-line`, `toggle`→`-toggle`, `branch`→`-branch`, `condition`→`-cond`, `fsm`→`-fsm`, `covergroup`→`-covgroup` |
| Cadence `.vRefine` | `.` | none | XML `<waiver type="...">` |
| Questa `.do` | `/` | `/` prefix added | Tcl `coverage exclude -line/-toggle/-branch/-cond/-fsm/-covergroup` |

### Strategy for Waiver Tasks

**Agent should follow this pattern when user asks about waivers:**

1. **Discover what to waive** — use `holes`, `query`, `search` to identify the items
2. **Create the `.cwv.yaml` file** — generate YAML with appropriate rules
3. **Validate** — run `validate_waiver()` to catch errors
4. **Apply** — call `engine.load_waivers([path])` and show before/after comparison
5. **Export if needed** — convert to `.el` / `.vRefine` / `.do` for other teams

**When user says "exclude" / "waive" / "ignore" coverage items:**
- Write a `.cwv.yaml` file with the rules
- Use `type: all` to exclude entire modules
- Use `*` wildcards in scope for bulk operations (e.g. `"tb_top.dut.*"`)
- Use `signal: "scan_*"` for pattern-based toggle exclusion
- Omit `items` to exclude ALL items of that type under scope

**When user asks "what's coverage after waiver":**
- Open the DB, call `load_waivers()`, then `get_summary()` / `holes()` / `query()`

**When user provides an existing `.el` or `.vRefine` file and wants to see its effect:**
- There is no import command yet — help the user manually translate rules to `.cwv.yaml`

**Important constraints:**
- Waivers are in-memory only — they do NOT modify the original VDB/coverage database
- `load_waivers()` accepts ONLY `.cwv.yaml` files, not `.el` / `.vRefine` directly
- Each rule ID must be unique across ALL loaded waiver files
- `unload_waivers()` removes ALL waivers (no partial unload by file)
- Coverage percentages are automatically recalculated after load/unload

### Waiver Python Script Template

When the agent needs to perform waiver operations, generate and run a script like this:

```python
#!/usr/bin/env python3
"""Waiver analysis script — generated by agent."""
import json
from coverage_reader.engine.vdb_engine import VdbEngine
from coverage_reader.waiver import load_waiver, validate_waiver, dump_waiver

# 1. Open database
eng = VdbEngine()
info = eng.open("/path/to/simv.vdb")
print("=== Before Waivers ===")
print(json.dumps(eng.get_summary("all"), indent=2))

# 2. Validate waiver file
results = validate_waiver("waivers.cwv.yaml", engine=eng)
errors = [r for r in results if r.severity == "error"]
if errors:
    for e in errors:
        print(f"VALIDATION ERROR: {e}")
    eng.close()
    raise SystemExit(1)

# 3. Apply waivers
result = eng.load_waivers(["waivers.cwv.yaml"])
print(f"\n=== Waiver Applied ===")
print(f"Rules loaded: {result['rules_loaded']}")
print(f"Items excluded: {result['items_excluded']}")

# 4. Show adjusted coverage
print(f"\n=== After Waivers ===")
print(json.dumps(eng.get_summary("all"), indent=2))

# 5. Show remaining holes
holes = eng.get_holes(threshold=100.0, max_results=20)
if holes:
    print(f"\n=== Remaining Holes ({len(holes)}) ===")
    for h in holes:
        print(f"  {h.item_type:12s} {h.full_path:50s} {h.score:.1f}%")

eng.close()
```
