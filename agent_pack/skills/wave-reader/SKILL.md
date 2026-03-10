---
name: wave-reader
description: Read and analyze chip simulation waveform files (VCD/FST/FSDB/GHW) using the wave_reader CLI tool. Use this skill whenever the user mentions waveform files, signal values, simulation debugging, VCD/FST/FSDB/GHW files, timing diagrams, clock analysis, chip verification, or wants to inspect simulation results. Also trigger when you see .vcd, .fst, .fsdb, or .ghw file extensions in the workspace, when the user mentions signal names like clk/reset/valid/ready/data, or when debugging chip-level failures involving timing or signal transitions — even if they don't explicitly say "wave_reader".
---

# wave_reader — Waveform File Reader

A standalone CLI tool for reading chip simulation waveform files. Invoke it via shell commands — no SDK, no Python import, no REST API.

Each waveform file is served by a background daemon process that starts automatically on `open`. Subsequent commands talk to the daemon over TCP. This is fully transparent — just run CLI commands sequentially.

## Workflow

Follow this order — it reflects how the daemon lifecycle works:

1. **`wave_reader open <file>`** — load the file, start a daemon, learn the time unit
2. **`wave_reader navigate`** / **`search`** — explore hierarchy, find signal paths
3. **`wave_reader query`** — read signal values (this is the core operation, ~65% of calls)
4. **`wave_reader info`** — re-check file metadata anytime (time range, unit, counts)
5. **`wave_reader close`** — release resources when done

The `open` → work → `close` structure matters because the daemon holds file handles and memory. Skipping `open` causes `NO_FILE_OPEN` errors; skipping `close` wastes resources (though daemons auto-exit after 30 min idle).

## Time Unit — Read It, Don't Assume It

The time unit (`ns`, `ps`, `fs`, etc.) is declared inside each waveform file. Different simulations use different units. After `open`, read `time_range.unit` from the output — all integer timestamps in `query --time` must use this unit.

If you lose track of the unit during a long session, call `wave_reader info --json` to retrieve it again. Never assume `ns`.

---

## Commands

### open

Load a waveform file and start its daemon.

```
wave_reader open <file> [--json] [--session <id>] [--idle-timeout <sec>]
                        [--bsub] [--queue <name>] [--memory <size>]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `file` | yes | — | Path to `.vcd` / `.fst` / `.ghw` / `.fsdb` file |
| `--json` | no | off | Structured JSON output |
| `--session <id>` | no | auto | Isolate daemons across parallel analyses |
| `--idle-timeout <sec>` | no | 1800 | Auto-shutdown after N seconds idle |
| `--bsub` | no | off | Launch daemon on HPC compute node |
| `--queue <name>` | no | normal | bsub queue (only with `--bsub`) |
| `--memory <size>` | no | 4G | bsub memory limit (only with `--bsub`) |

**Returns:** file format, size, simulation time range (start, end, **unit**), signal count, scope count, top-level scope names.

### navigate

Browse the design hierarchy — like `ls` for a chip's module tree.

```
wave_reader navigate [path] [--file <path>] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `path` | no | top level | Dot-separated scope path (e.g. `system.i_cpu`) |
| `--file` | no | auto | Target file (needed when multiple files are open) |
| `--json` | no | off | Structured JSON output |

**Returns:** child scopes (name, path, signal/scope counts) and signals (name, path, width, type).

Start with no path to see top-level scopes, then drill down into interesting modules.

### search

Find signals by name pattern when you don't know the exact path.

```
wave_reader search <pattern> [--regex] [--scope <path>] [--max <n>]
                              [--file <path>] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `pattern` | yes | — | Glob pattern (e.g. `'*clk*'`). Use `--regex` for regex. **Shell-quote it** to prevent glob expansion |
| `--regex` | no | off | Interpret pattern as Python regex |
| `--scope <path>` | no | global | Restrict search to this scope subtree |
| `--max <n>` | no | 50 | Max results returned |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Returns:** matching signals with full hierarchical path, width, type. Case-insensitive.

### query ⭐

Read signal values — this is the command you'll use most. It reads values at a specific time point or across a time range.

```
wave_reader query <signals> --time <spec> [--format <fmt>] [--max-rows <n>]
                            [--file <path>] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `signals` | yes | — | Comma-separated full signal paths. **Max 20 per call** (daemon rejects more to keep responses parseable) |
| `--time <spec>` | yes | — | Integer timestamps in the file's time unit. Point: `--time 500`. Range: `--time 0:1000` |
| `--format <fmt>` | no | auto | `hex` / `bin` / `dec` / `auto`. Auto: 1-bit→char, ≤8-bit→dec, ≤64-bit→hex, x/z→bin |
| `--max-rows <n>` | no | 200 | Max rows. Hard cap 2000 (exists to prevent context window overflow in agent conversations) |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Understanding the output:**
- Table columns: `time`, then one column per signal
- **Dot compression:** `"."` means "same value as the row above" — not a missing value. This saves ~60% tokens, which matters because agent context windows are finite
- Point query → exactly 1 row
- Range query → one row per value-change transition in [start, end]
- If `truncated` is true, narrow the time range and retry

**JSON output** includes `meta.time_unit`, `meta.time_range`, `meta.signal_info`, `rows`, `total_transitions`, and `truncated`.

### info

Re-fetch file metadata from the running daemon. Returns the same data as `open` output. Call this when you need to recall the time range, time unit, signal count, or top scopes — especially after many queries when the `open` output has scrolled out of context.

```
wave_reader info [--file <path>] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

### stats

Display statistics for a single signal — useful for understanding clocks and periodic signals.

```
wave_reader stats <signal> [--file <path>] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `signal` | yes | — | Full hierarchical signal path |
| `--file` | no | auto | Target file |
| `--json` | no | off | Structured JSON output |

**Returns:** signal width, type, total transitions, period, frequency, duty cycle, clock-like flag.

### close

Stop the daemon and free resources.

```
wave_reader close [--file <path>] [--all] [--session <id>] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--file` | no | — | Close daemon for this specific file |
| `--all` | no | off | Close ALL daemons in current session |
| `--json` | no | off | Structured JSON output |

With one file open, bare `wave_reader close` suffices. With multiple files, use `--file` or `--all`.

### list

Show all active daemons — useful when managing multiple open files.

```
wave_reader list [--session <id>] [--json]
```

**Returns:** daemon ID, file name, host, port, launch mode, session, idle time.

---

## Constraints and Why They Exist

| Constraint | Why |
|-----------|-----|
| `open` before everything else | The daemon must be running to serve queries. Other commands have no file handle without it |
| Signal paths are dot-separated full paths (e.g. `system.i_cpu.PC`) | Waveform files use hierarchical namespaces. Short names are ambiguous across modules |
| Time values are integers in the file's native unit | Each simulator chooses its own timescale. Using wrong units gives wrong results silently |
| Max 20 signals per `query` | Keeps response size bounded so agents can parse it without context overflow |
| Max 200 rows default, 2000 hard cap | Same reason — protects agent context windows from massive data dumps |
| `"."` = unchanged (dot compression) | Saves ~60% tokens. First row always has full values; subsequent rows only show changes |
| Shell-quote glob patterns (`'*clk*'`) | Without quotes, the shell expands globs against local files before wave_reader sees them |
| `--file` needed with multiple open files | The daemon registry can't guess which file you mean. Explicit is better than ambiguous |

## Error Reference

| Code | Meaning | Fix |
|------|---------|-----|
| `FILE_NOT_FOUND` | Path doesn't exist | Verify the file path |
| `FORMAT_UNSUPPORTED` | Not a supported format | Use .vcd / .fst / .ghw / .fsdb |
| `NO_FILE_OPEN` | No daemon running | Run `wave_reader open <file>` first |
| `SIGNAL_NOT_FOUND` | Bad signal path | Use `search` to find the correct path |
| `TIME_OUT_OF_RANGE` | Timestamp outside sim range | Check range via `info --json` |
| `TOO_MANY_SIGNALS` | >20 signals in one query | Split into multiple queries |
| `AMBIGUOUS_TARGET` | Multiple files, no `--file` | Add `--file <path>` |

## Debug Strategy

When investigating a chip simulation failure:

1. Extract signal names and timestamps from the error log
2. `wave_reader open <file>` — note the time unit
3. `wave_reader search '*keyword*'` — find signals related to the failure (e.g. `'*timeout*'`, `'*valid*'`, `'*err*'`)
4. `wave_reader query <signals> --time <t-100>:<t+100>` — inspect values around the failure time
5. `wave_reader navigate <scope>` — find related signals in the same module
6. Iterate: narrow/widen time ranges, trace upstream/downstream signals, compare expected vs actual
7. `wave_reader close --all` — clean up when done
