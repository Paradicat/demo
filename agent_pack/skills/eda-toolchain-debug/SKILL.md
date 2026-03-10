---
name: eda-toolchain-debug
description: EDA toolchain configuration and debugging knowledge base. Records configuration, compilation, linking, and version-compatibility issues encountered with VCS, Xrun, Design Compiler, and other EDA tools at the IT infrastructure level (not IC design knowledge). This skill serves as a continuously growing case library — new toolchain issues should always be added here.
---

# EDA Toolchain Debugging Knowledge Base

## ⚠️ When to Use This Skill

**Trigger signals — consult this skill immediately when you see:**

- VCS/Xrun error messages containing: `lto-wrapper`, `PIE`, `ld:`, `gcc:`, `g++:`, `_sigintr`
- Errors occurring at the **linking stage** (parsing and elaboration already passed)
- Error messages involving: `.so`, `.a`, `undefined reference`, `relocation R_X86_64_32S`
- **Same command passes in terminal but fails in scripts/Makefile/CI** (TTY detection issues)
- License errors: `license checkout failed`, `FLEXlm error`
- Tool launch failures: `command not found`, `library not found`
- Waveform tool integration issues: `fsdb`, `Verdi`, `DVE`

**Do not try to figure it out from scratch** — search this skill first for existing solutions!

## Scope and Boundaries

This skill records EDA toolchain issues at the **IT infrastructure level**, including but not limited to:

- Compiler / linker version incompatibilities
- OS library conflicts
- License configuration issues
- Inter-tool integration conflicts (e.g., VCS + Verdi)
- Environment variable configuration
- Makefile / build script tool adaptation

**Out of scope**: RTL syntax errors, simulation logic bugs, timing analysis methodology, and other IC design knowledge. Those belong to `ip-design` and other skills.

---

## Directory Structure

```
eda_toolchain_debug/
├── SKILL.md                    # This file: overview + usage guide + contribution rules
└── issues/                     # Case library, organized by tool subdirectories
    ├── vcs/
    │   ├── 001_verdi_pli_lto_mismatch.md
    │   └── 002_vcs_nontty_linking.md
    ├── xrun/                   # (Reserved) Cadence Xrun issues
    ├── dc/                     # (Reserved) Synopsys Design Compiler
    ├── vivado/                 # (Reserved) Xilinx Vivado
    ├── quartus/                # (Reserved) Intel Quartus
    ├── verilator/              # (Reserved) Verilator
    └── common/                 # Cross-tool generic issues (shell env, GCC version, OS libs, etc.)
        └── 001_bash_alias_noninteractive.md
```

---

## Usage

### When encountering EDA tool errors

1. Search `issues/<tool_name>/` in this skill for similar cases first
2. If a matching case is found, follow its solution directly
3. If not found, after resolving the issue you **must add** a new case record

### Search tips

- Search using keywords from the error message (e.g., `lto-wrapper`, `PIE`, `license`)
- Search by tool name + error type (e.g., `vcs linker`)

---

## Contribution Rules

### When to add a new case

A new record **must** be added when:

1. An EDA tool reports a non-RTL-syntax error (compiler, linker, environment)
2. The resolution involves modifying compile options, environment variables, installing dependencies, or other IT operations
3. The issue is reproducible (not a one-off fluke)

### How to add

1. Create a new file under `issues/<tool_name>/`
2. File naming: `<number>_<short_description>.md`, where number is the next sequential ID in that tool's directory
3. Fill in using the template below

### Case template

Each case **must** contain these fields:

```markdown
# <Short title>

## Basic Info

| Field | Value |
|-------|-------|
| Tool | <Tool name and version, e.g., VCS L-2016.06> |
| OS | <e.g., Ubuntu 22.04, CentOS 7> |
| Date Found | <YYYY-MM-DD> |
| Severity | Blocking / Workaround available / Warning only |

## Symptom

<Full error message, paste key parts verbatim>

## Root Cause Analysis

<Brief explanation of the root cause>

## Solution

<Specific resolution steps, including commands, option changes, etc.>

## Notes

<Additional info: known limitations, side effects, alternatives, etc.>
```

### Numbering rules

- Each tool directory uses independent numbering, starting from 001
- Numbers are zero-padded to 3 digits for sorting: `001`, `002`, ..., `099`, `100`

---

## Tool Coverage

| Tool | Vendor | Directory | Purpose |
|------|--------|-----------|----------|
| VCS | Synopsys | `issues/vcs/` | RTL simulation |
| Verdi | Synopsys | `issues/vcs/` | Waveform debugging (tightly integrated with VCS, shared directory) |
| Xrun | Cadence | `issues/xrun/` | RTL simulation |
| Design Compiler (DC) | Synopsys | `issues/dc/` | Logic synthesis |
| Vivado | AMD/Xilinx | `issues/vivado/` | FPGA synthesis and implementation |
| Quartus | Intel/Altera | `issues/quartus/` | FPGA synthesis and implementation |
| Verilator | Open source | `issues/verilator/` | Open-source RTL simulation |
| Common | — | `issues/common/` | GCC, OS libs, license, and other cross-tool issues |

> If you encounter a tool not listed above, simply create a new subdirectory under `issues/`.

---

## Known Issues Index

> This index should be kept up to date as cases accumulate.

### VCS

| ID | Title | Severity |
|----|-------|----------|
| [001](issues/vcs/001_verdi_pli_lto_mismatch.md) | Verdi PLI library LTO version mismatch causes linker failure | Blocking |
| [002](issues/vcs/002_vcs_nontty_linking.md) | VCS linking failure due to inconsistent linker options in non-TTY environments | Blocking |
| [003](issues/vcs/003_vcs_cm_linker_version.md) | VCS coverage (-cm) linker failure on older versions (e.g. L-2016.06) | Blocking |
| [004](issues/vcs/004_urg_ncurses_missing.md) | urg fails with missing libncursesw.so.5 on Ubuntu 22.04+ | Workaround available |

### Xrun

(No records yet)

### DC

(No records yet)

### Common

| ID | Title | Severity |
|----|-------|----------|
| [001](issues/common/001_bash_alias_noninteractive.md) | Bash aliases do not expand in non-interactive shells | Blocking |
| [002](issues/common/002_drawio_export_vscode.md) | Draw.io diagram export in VS Code environment | Blocking |

