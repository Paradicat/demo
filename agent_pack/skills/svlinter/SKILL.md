---
name: svlinter
description: "Use this skill whenever the user wants to lint, analyze, or check SystemVerilog (.sv) design files. Triggers include: any mention of 'SystemVerilog lint', 'SV lint', 'svlinter', 'check RTL', 'check design', 'AST dump', or requests to find errors/warnings in hardware designs. Also use when filtering or querying design instances/modules, dumping syntax trees, or running diagnostics on Verilog/SystemVerilog source files. If the user asks to 'lint my design', 'check my SV files', 'find errors in RTL', or wants to analyze module hierarchies, use this skill."
---

# SVLinter

A SystemVerilog static analysis tool powered by pyslang. It provides lint diagnostics, AST export, and design instance queries — all from a single standalone executable.

## Quick Reference

| Task | Command |
|------|---------|
| Lint a design | `svlinter --filelist design.f check --output work/` |
| Dump AST | `svlinter --filelist design.f ast --depth 3` |
| Query instances | `svlinter --filelist design.f filter --module "*alu*"` |
| Combined analysis | `svlinter --filelist design.f check --output work/ ast --depth 2 filter --module "*"` |

## Prerequisites

- **Platform**: Linux x86_64 (CentOS 7+, Ubuntu 18.04+, or any glibc ≥ 2.17 system)
- **No other dependencies**: `svlinter` is a self-contained executable — no Python, no pip, no libraries needed.
- **Filelist**: A `.f` file listing the SystemVerilog source files to analyze.

## Setting Up

The user provides a `svlinter` executable. Place it somewhere on `$PATH` or reference it directly:

```bash
chmod +x svlinter
./svlinter --version
```

## Filelist Format

Before running svlinter, the user needs a filelist (`.f` file) that lists the SV source files. Here's the format:

```
// Comments start with // or #
# This is also a comment

${DESIGN_ROOT}/rtl/alu.sv
${DESIGN_ROOT}/rtl/regfile.sv
${DESIGN_ROOT}/rtl/cpu_top.sv
```

Rules:
- One file path per line
- `//` or `#` at the start of a line marks a comment
- `${VAR_NAME}` expands environment variables at runtime
- Relative paths resolve against the filelist's own directory

The user typically sets `DESIGN_ROOT` to point to their design directory before running svlinter:

```bash
export DESIGN_ROOT=/path/to/my/design
```

## Command Structure

```
svlinter [global options] [subcommand [subcommand options]] ...
```

### Global Options

| Option | Required | Description |
|--------|----------|-------------|
| `--filelist <path>` | Yes | Path to the filelist file |
| `--top <module>` | No | Top-level module name |
| `--verbose` / `-v` | No | Verbose output |
| `--version` | No | Print version and exit |
| `--help` / `-h` | No | Show help |

### Subcommands

svlinter supports three subcommands. They can be used individually or combined in a single invocation — the design is parsed once and shared across all subcommands.

---

## check — Lint Diagnostics

Runs full lint diagnostics and outputs a structured report.

```bash
export DESIGN_ROOT=/path/to/design
svlinter --filelist design.f check --output work/
```

### check Options

| Option | Default | Description |
|--------|---------|-------------|
| `--output <path>` | (required) | Output directory or file path |
| `--format <fmt>` | `jsonl` | Output format: `jsonl`, `json`, or `text` |
| `--severity <level>` | `note` | Minimum severity: `error`, `warning`, `note` |
| `--top <module>` | — | Override global `--top` |
| `--no-fail-on-error` | — | Don't return nonzero exit code on errors |
| `--suppress <code>` | — | Suppress a diagnostic code (repeatable) |

### Output: JSONL (default)

The report is written to `<output>/report.jsonl` — one JSON object per line:

```jsonl
{"type": "error", "code": "UndeclaredIdentifier", "message": "use of undeclared identifier 'extended_a'", "file": "/path/to/alu.sv", "line": 19, "column": 25}
{"type": "warning", "code": "IndexOOB", "message": "cannot refer to element 16 of 'logic[15:0]'", "file": "/path/to/alu.sv", "line": 32, "column": 45}
```

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"error"`, `"warning"`, or `"note"` |
| `code` | string | Diagnostic code name (e.g. `"UndeclaredIdentifier"`) |
| `message` | string | Human-readable diagnostic message |
| `file` | string | Absolute path to the source file |
| `line` | int | Line number (1-indexed) |
| `column` | int | Column number (1-indexed) |

### Reading the Report

```bash
# Count diagnostics
wc -l work/report.jsonl

# View first few
head -5 work/report.jsonl

# Pretty-print
cat work/report.jsonl | python3 -m json.tool --no-ensure-ascii

# Count by severity
grep -c '"type": "error"' work/report.jsonl
grep -c '"type": "warning"' work/report.jsonl
```

---

## ast — AST Export

Dumps the design's syntax tree or semantic tree structure.

```bash
svlinter --filelist design.f ast --depth 3 --format json --output work/ast.json
```

### ast Options

| Option | Default | Description |
|--------|---------|-------------|
| `--depth <n>` | unlimited | Maximum tree depth to output |
| `--format <fmt>` | `text` | Output format: `text`, `json`, or `jsonl` |
| `--tree-type <t>` | `ast` | Tree type: `ast` (semantic) or `cst` (concrete syntax) |
| `--output <path>` | stdout | Output file path |
| `--scope <path>` | — | Hierarchical path to start from (e.g. `cpu_top.alu`) |
| `--kinds <kind>` | — | Filter node kinds (repeatable) |
| `--show-loc` | off | Show source locations |

### ast Output: text (default)

Tree-structured text with box-drawing characters:

```
RootSymbol
└── InstanceSymbol: cpu_top (module cpu_top)
    ├── PortSymbol: clk (In logic)
    ├── PortSymbol: rst_n (In logic)
    ├── InstanceSymbol: u_alu (module alu)
    │   ├── PortSymbol: a (In logic[15:0])
    │   └── PortSymbol: b (In logic[15:0])
    └── InstanceSymbol: u_regfile (module regfile)
        └── ... (depth limit reached)
```

### ast Output: json

```json
{
  "version": "0.2.0",
  "command": "ast",
  "tree_type": "ast",
  "filelist": "design.f",
  "root": {
    "kind": "RootSymbol",
    "path": "",
    "depth": 0,
    "children": [
      {
        "kind": "InstanceSymbol",
        "depth": 1,
        "name": "cpu_top",
        "path": "cpu_top",
        "definition": "cpu_top",
        "definition_kind": "module",
        "children": [ ... ]
      }
    ]
  }
}
```

Each node may contain: `kind`, `depth`, `name`, `path`, `definition`, `definition_kind`, `direction`, `type`, `value`, `location`, `children`, `truncated`.

### ast Output: jsonl

Flattened — one node per line:

```jsonl
{"kind": "RootSymbol", "path": "", "depth": 0}
{"kind": "InstanceSymbol", "depth": 1, "name": "cpu_top", "path": "cpu_top", "definition": "cpu_top", "definition_kind": "module"}
{"kind": "PortSymbol", "depth": 2, "name": "clk", "path": "cpu_top.clk", "direction": "In", "type": "logic"}
```

---

## filter — Instance Query

Searches the design hierarchy for module instances matching a glob pattern.

```bash
svlinter --filelist design.f filter --module "*fifo*" --ports
```

### filter Options

| Option | Default | Description |
|--------|---------|-------------|
| `--module <pattern>` | (required) | Glob pattern to match module names (repeatable) |
| `--ports` | off | Include port information in output |
| `--format <fmt>` | `text` | Output format: `text`, `json`, `jsonl` |
| `--output <path>` | stdout | Output file path |
| `--show-loc` | off | Show source locations |

### filter Output: text (default)

```
Found 3 instances matching "*":

  cpu_top
    module:   cpu_top

  cpu_top.u_alu
    module:   alu
    ports:
      a    In  logic[15:0]
      b    In  logic[15:0]
      op   In  logic[2:0]
      out  Out logic[15:0]

  cpu_top.u_regfile
    module:   regfile
```

### filter Output: jsonl

One instance record per line:

```jsonl
{"path": "cpu_top", "instance_name": "cpu_top", "module": "cpu_top"}
{"path": "cpu_top.u_alu", "instance_name": "u_alu", "module": "alu", "ports": [{"name": "a", "direction": "In", "type": "logic[15:0]"}, {"name": "b", "direction": "In", "type": "logic[15:0]"}]}
```

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Hierarchical instance path (e.g. `cpu_top.u_alu`) |
| `instance_name` | string | Instance name (e.g. `u_alu`) |
| `module` | string | Definition (module) name (e.g. `alu`) |
| `ports` | array | Port list (only with `--ports`) |
| `location` | object | Source location (only with `--show-loc`) |

Each port object: `{"name": "clk", "direction": "In", "type": "logic"}`

### filter Output: json

```json
{
  "version": "0.2.0",
  "command": "filter",
  "pattern": "*alu*",
  "total": 2,
  "instances": [
    {"path": "cpu_top.u_alu", "instance_name": "u_alu", "module": "alu"},
    {"path": "cpu_top.u_alu2", "instance_name": "u_alu2", "module": "alu"}
  ]
}
```

---

## Multi-Subcommand Usage

A powerful feature: run multiple analyses in one shot. The source files are parsed only once.

```bash
export DESIGN_ROOT=/path/to/design
svlinter --filelist design.f \
    check --output work/report.jsonl \
    ast --depth 3 --format json --output work/ast.json \
    filter --module "*" --ports --output work/instances.json
```

You can even repeat the same subcommand with different parameters:

```bash
svlinter --filelist design.f \
    filter --module "*fifo*" --ports --output work/fifos.jsonl \
    filter --module "alu" --format text
```

## Backward Compatibility

If no subcommand is given but `--output` is specified at global level, svlinter defaults to `check`:

```bash
# These two are equivalent:
svlinter --filelist design.f --output work/
svlinter --filelist design.f check --output work/
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (no errors, or `--no-fail-on-error` used) |
| 1 | Lint errors found (check subcommand) |
| 2 | Usage error (missing filelist, bad arguments, etc.) |

## Typical Workflow

1. **Prepare filelist**: Create a `.f` file listing all SV source files
2. **Set environment**: `export DESIGN_ROOT=/path/to/design`
3. **Run lint**: `svlinter --filelist design.f --top my_top check --output work/`
4. **Review report**: Open `work/report.jsonl` and examine diagnostics
5. **Fix issues**: Edit the SV source files based on the diagnostics
6. **Re-lint**: Repeat steps 3-5 until clean

## Examples

### Example 1: Simple lint check

```bash
export DESIGN_ROOT=/home/user/projects/my_cpu
svlinter --filelist my_cpu.f --top cpu_top check --output lint_results/
cat lint_results/report.jsonl | head
```

### Example 2: Explore design hierarchy

```bash
export DESIGN_ROOT=/home/user/projects/my_soc
svlinter --filelist soc.f --top soc_top filter --module "*" --ports --format json --output hierarchy.json
```

### Example 3: Full analysis pipeline

```bash
export DESIGN_ROOT=/home/user/projects/my_design

svlinter --filelist design.f --top top_module \
    check --output work/report.jsonl --severity warning \
    ast --depth 4 --format json --output work/ast.json \
    filter --module "*mem*" --ports --output work/memories.jsonl
```
