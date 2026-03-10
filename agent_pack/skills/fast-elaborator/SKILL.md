---
name: fast-elaborator
description: Fast RTL PPA analysis using Yosys + OpenSTA. Use this skill whenever the user mentions quick synthesis, gate count estimation, logic depth analysis, flip-flop count, combinational cell count, design hierarchy exploration after synthesis, or fast PPA (Power/Performance/Area) estimation. Also trigger when the user has Verilog/SystemVerilog RTL files and wants a quick area or timing estimate without running a full EDA flow, when they mention "fast_elab" or "fast elaboration", or when they want to check logic depth, critical path, or cell statistics of an RTL design.
---

# fast_elab — Fast RTL PPA Analysis

A standalone CLI tool for quick RTL synthesis and timing analysis using Yosys + OpenSTA. Invoke via shell commands — no SDK, no Python import, no REST API.

Each design is served by a background daemon that runs Yosys synthesis on load, then serves queries over TCP. This is fully transparent — just run CLI commands sequentially.

## Workflow

Follow this order — it reflects the daemon lifecycle:

1. **`fast_elab load <file> --top <module>`** — synthesise the design, start a daemon
2. **`fast_elab stat [path]`** — view gate-level statistics (cell counts, FF counts)
3. **`fast_elab timing`** — run timing analysis (logic depth, critical paths)
4. **`fast_elab navigate [path]`** — browse design hierarchy
5. **`fast_elab search <pattern>`** — find instances or ports by name
6. **`fast_elab close`** — release resources when done

The `load` → work → `close` structure matters because the daemon holds synthesis results in memory. Calling `load` triggers Yosys synthesis which may take 5-60 seconds depending on design size.

## What It Provides

- **Cell counts**: total gates, flip-flops, combinational cells — per module and hierarchical
- **Logic depth**: number of gate levels on critical paths (via OpenSTA)
- **Hierarchy tree**: navigate module instances, view per-instance stats
- **No SDC needed**: auto-detects clock ports from the netlist

This is NOT a replacement for a full synthesis flow. It uses a generic liberty library where every gate has 1ns delay — so timing results show **logic depth in gate levels**, not real nanoseconds.

---

## Commands

### load

Synthesise a design and start the daemon.

```
fast_elab load <filelist> --top <module> [--json] [--session <id>] [--idle-timeout <sec>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `filelist` | yes | — | Path to `.v` file or `.f` filelist |
| `--top` | yes | — | Top-level module name |
| `--json` | no | off | Structured JSON output |
| `--session <id>` | no | auto | Isolate daemons across parallel analyses |
| `--idle-timeout` | no | 1800 | Auto-shutdown after N seconds idle |

**Returns:** top module, file count, synthesis time, total cells, FFs, combinational count, module count.

**Filelist format** (`.f` files): supports `+incdir+`, `+define+`, `-y`, `-v`, `-f` (nested), comments (`//`, `#`).

### stat

Show gate-level statistics for a module or sub-instance.

```
fast_elab stat [path] [--json] [--session <id>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `path` | no | top module | Hierarchy path (e.g. `soc_top.u_cpu`) |
| `--json` | no | off | Structured JSON output |

**Returns:** total cells, FFs, combinational, wires, wire bits, sub-instance list with their stats.

### timing

Run timing analysis to find logic depth and critical paths.

```
fast_elab timing [--from <point>] [--to <point>] [--max-paths <n>]
                 [--path-type max|min] [--json] [--session <id>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--from` | no | all | Startpoint filter (port or instance name) |
| `--to` | no | all | Endpoint filter |
| `--max-paths` | no | 5 | Max paths to report (cap: 20) |
| `--path-type` | no | max | `max` (setup) or `min` (hold) |
| `--json` | no | off | Structured JSON output |

**Returns:** for each path: from/to points, logic depth, gate-by-gate stages with delay.

**Note:** all gate delays are 1.0ns in the dummy liberty, so:
- `logic_depth = 5` means 5 gate levels on the path
- Compare paths by depth, not absolute timing

### navigate

Browse the design hierarchy — like `ls` for the synthesised module tree.

```
fast_elab navigate [path] [--json] [--session <id>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `path` | no | top module | Hierarchy path |
| `--json` | no | off | Structured JSON output |

**Returns:** child instances (name, module type, cell count, FF count), ports (name, direction, width).

Start with no path to see top-level children, then drill down.

### search

Find instances or ports by glob pattern.

```
fast_elab search <pattern> [--type all|cell|ff|port] [--scope <path>]
                           [--max-results <n>] [--json] [--session <id>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `pattern` | yes | — | Glob pattern (e.g. `*alu*`, `u_cpu.*`) |
| `--type` | no | all | Filter: `all`, `cell`, `ff`, `port` |
| `--scope` | no | global | Restrict search to subtree |
| `--max-results` | no | 50 | Max results (cap: 200) |
| `--json` | no | off | Structured JSON output |

**Returns:** matching instances/ports with full hierarchy path and type.

### list

Show all active daemons.

```
fast_elab list [--json] [--session <id>]
```

**Returns:** daemon ID, top module, port, status, idle time.

### close

Stop the daemon and free resources.

```
fast_elab close [--all] [--json] [--session <id>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--all` | no | off | Close ALL daemons for current user |
| `--json` | no | off | Structured JSON output |

---

## Constraints and Why They Exist

| Constraint | Why |
|-----------|-----|
| `load` before everything else | Yosys synthesis must complete before any queries |
| `--top` is required on `load` | Yosys needs to know the top module for hierarchy analysis |
| Gate delays are all 1.0ns | This is a logic-depth estimation tool, not real timing analysis |
| No SDC support (auto-clock only) | SDC reading is a TODO — clocks are auto-detected from DFF connections |
| Synthesis may take 5-60+ seconds | Yosys processes the full design; larger designs take longer |
| `--json` recommended for parsing | Human-formatted output is for display; JSON is stable for programmatic use |

## Error Reference

| Error | Meaning | Fix |
|-------|---------|-----|
| `Yosys not found` | Binary not on PATH | Set `FAST_ELAB_YOSYS=/path/to/yosys` |
| `OpenSTA not found` | Binary not on PATH | Set `FAST_ELAB_STA=/path/to/sta` |
| `Yosys exited with code N` | Synthesis failed | Check the design for syntax errors; see `~/.fast-elab/logs/` |
| `No active daemon found` | No `load` was run | Run `fast_elab load <file> --top <module>` first |
| `Path not found` | Bad hierarchy path | Use `navigate` to find valid paths |
| `Daemon failed to start` | Synthesis timed out | Check logs; design may be too large |

## Analysis Strategy

When estimating PPA for an RTL design:

1. `fast_elab load design.f --top chip_top --json` — synthesise and see overall stats
2. `fast_elab stat --json` — get top-level cell/FF breakdown
3. `fast_elab stat chip_top.u_cpu --json` — drill into specific blocks
4. `fast_elab timing --json` — find worst-case logic depth
5. `fast_elab timing --from data_in --to u_reg --json` — analyse specific paths
6. `fast_elab navigate chip_top --json` — explore hierarchy for area hotspots
7. `fast_elab search '*fifo*' --json` — find specific components
8. `fast_elab close` — clean up when done
