---
name: fexpand
description: Preprocess and flatten hierarchical Verilog/SystemVerilog filelists using the fexpand CLI tool. Use this skill whenever the user mentions filelists, .f files, filelist expansion, -f includes, hierarchical filelists, or wants to preprocess EDA filelists into a flat list. Also trigger when you see .f file extensions, filelist-related commands like +incdir+, -y, -f, or when the user wants to resolve environment variables in filelists, deduplicate file paths, split VHDL files, or expand macros (`ifdef/`endif) in filelists — even if they don't explicitly say "fexpand".
---

# fexpand — Filelist Preprocessor

A standalone CLI tool that flattens hierarchical Verilog/SystemVerilog filelists into a single clean filelist. It resolves `-f` includes, expands environment variables, processes C99/Verilog macros, deduplicates paths, and converts relative paths to absolute paths.

Invoke it via shell commands — no Python import needed. The tool is a single self-contained binary.

## When to Use

- User has a hierarchical filelist with `-f` sub-includes and needs a flat version
- User wants to resolve `$ENV_VAR` references in filelists
- User needs to preprocess `ifdef/endif` guards in filelists with specific macro definitions
- User wants to deduplicate files across multiple sub-filelists
- User needs to split `.vhd`/`.vhdl` files into a separate output
- User wants to audit filelist issues (missing files, duplicate includes, filename conflicts)

## Quick Start

```bash
# Basic expansion — flatten a hierarchical filelist
fexpand -i top.f -o flat.f

# With macro definitions (like VCS -D flags)
fexpand -i top.f -o flat.f -D SYNTHESIS -D FPGA_TARGET

# Split VHDL files into separate output
fexpand -i mixed.f -o verilog.f -oh vhdl.f

# With macro values
fexpand -i top.f -o flat.f -D TARGET=fpga -D WIDTH=32
```

## CLI Reference

```
fexpand -i INPUT [-o OUTPUT] [-oh OUTPUT_VHDL] [-D macro[=val]] [-l LOG] [-s] [-j]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `-i INPUT` | **yes** | — | Input filelist path (the top-level `.f` file) |
| `-o OUTPUT` | no | `expanded_filelist.f` | Output flat filelist path |
| `-oh OUTPUT_VHDL` | no | — | Separate output for `.vhd`/`.vhdl` files only |
| `-D macro[=val]` | no | — | Define macro (repeatable). `-D FOO` sets `FOO=1`; `-D FOO=bar` sets `FOO=bar` |
| `-l LOG` | no | `fexpand.log` | Log file path |
| `-s` | no | off | Silent mode — suppress console output |
| `-j` | no | off | JSON output mode |

## Features

### 1. `-f` Include Expansion

Nested filelists referenced with `-f` are recursively expanded inline. The output contains no `-f` directives — just flat file paths.

```
# Input top.f:
/path/to/a.v
-f /path/to/sub.f        ← expanded inline
/path/to/b.v

# sub.f:
/path/to/c.v
/path/to/d.v

# Output:
/path/to/a.v
/path/to/c.v
/path/to/d.v
/path/to/b.v
```

### 2. Environment Variable Expansion

`$VAR` and `${VAR}` references are replaced with their values from the shell environment. Undefined variables are left in place.

```
# With PRJ_ROOT=/home/user/project
$PRJ_ROOT/rtl/top.v  →  /home/user/project/rtl/top.v
```

**Important:** Set the required environment variables in the shell before running fexpand — use `export VAR=value` or pass them inline.

### 3. Macro Preprocessing (`ifdef`/`endif`)

Both Verilog-style (`` `ifdef ``) and C99-style (`#ifdef`) macros are supported:

```
# In filelist:
`ifdef SYNTHESIS
/path/to/synth_wrapper.v
`endif

`ifndef DEBUG
/path/to/optimized.v
`endif

#define FEATURE_A
`ifdef FEATURE_A
/path/to/feature_a.v
`endif
```

Use `-D` flag to set macros from command line, matching how VCS/Xrun handle `-D`.

### 4. Path Deduplication

Duplicate file paths are automatically removed. The tool tracks:

- **Payload path duplicates (PPD)** — same file listed multiple times → only first occurrence kept
- **Include path duplicates (IPD)** — same `-f` file included multiple times → only first include processed
- **Filename conflicts (PFDC/PFSC)** — same filename in different directories with different/same content → reported as error/warning

### 5. EDA Directive Passthrough

EDA-specific directives pass through to the output:

- `+incdir+ /path/to/includes` — include directory
- `-y /path/to/library` — library directory

These are preserved as-is in the output filelist, with environment variables expanded.

### 6. VHDL File Splitting (`-oh`)

When `-oh` is specified, `.vhd` and `.vhdl` files are routed to a separate output file. Useful for mixed-language projects where Verilog and VHDL files need separate handling.

### 7. Path Normalization

All file paths in the output are converted to absolute paths. Non-existing files are left as-is but flagged with a warning.

## Diagnostics

fexpand reports issues with severity-coded diagnostics:

| Code | Severity | Meaning |
|------|----------|---------|
| `ICLD` | Info | Normal `-f` include processed |
| `IPD` | Info | Include path duplicate — skipped |
| `PPD` | Info | Payload path duplicate — skipped |
| `IPNE` | **Error** | Include path (`-f`) does not exist — skipped |
| `PPNE` | Warning | Payload file path does not exist |
| `PFDC` | **Error** | Filename conflict — different content in different dirs |
| `PFSC` | Warning | Filename conflict — same content (harmless duplicate) |

Use these diagnostics to audit filelist health and detect issues like missing files or conflicting source versions.

## Typical Agent Workflow

### Scenario: User asks to flatten a project's filelist

```bash
# 1. Set environment variables (read from project config or Makefile)
export PRJ_ROOT=/path/to/project
export IP_ROOT=/path/to/ips

# 2. Run fexpand with project-specific macros
fexpand -i $PRJ_ROOT/filelist/top.f -o /tmp/flat.f -D SYNTHESIS -D TARGET=asic

# 3. Check the output
cat /tmp/flat.f

# 4. If errors were reported, inspect the log
cat fexpand.log
```

### Scenario: User wants to know which files are needed for a design

```bash
# Expand the filelist to see all source files
fexpand -i design.f -o /tmp/all_files.f -D FPGA

# Count files
wc -l /tmp/all_files.f

# Check for issues (missing files, duplicates)
fexpand -i design.f -o /tmp/all_files.f -D FPGA 2>&1 | grep -E "Error|Warning"
```

### Scenario: User wants to separate VHDL from Verilog

```bash
fexpand -i mixed_project.f -o verilog_files.f -oh vhdl_files.f
```

## Constraints and Tips

| Constraint | Why |
|-----------|-----|
| `-i` is required | Tool needs an input filelist |
| Environment variables must be set before running | fexpand reads `os.environ` at runtime |
| `-f` paths in filelists must be valid | Missing includes are skipped with IPNE error |
| Comments use `//` (Verilog style) | C-style `/* */` may not be fully supported |
| Macros follow C99 and Verilog conventions | Both `#ifdef` and `` `ifdef `` work |
| Relative paths are resolved from the filelist's directory | Not from `cwd` |

## Error Handling

If fexpand reports errors:

1. **IPNE (Include Path Not Exist)** — The `-f` referenced file doesn't exist. Check the path and environment variables.
2. **PFDC (Filename Conflict, Different Content)** — Same filename in two directories with different content. This requires the user to decide which version to keep.
3. **PPNE (Payload Path Not Exist)** — A source file path doesn't exist. May be a typo or missing checkout.

Always check the fexpand output for warnings/errors and resolve them before using the flat filelist for compilation.
