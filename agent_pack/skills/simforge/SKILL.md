---
name: simforge
description: Manage chip verification regression runs using the simforge CLI tool. Use this skill whenever the user wants to submit, monitor, cancel, or analyze regression runs, wants to run simulation testcases in parallel, needs to merge coverage data from multiple simulation runs, asks about testplan YAML, tag-based case filtering, regression status, or failed case analysis — even if they don't explicitly say "simforge".
---

# simforge — Chip Verification Regression Framework

A lightweight CLI tool for managing simulation regressions asynchronously.
Each project directory runs a background daemon that schedules and tracks
simulation cases. Invoke it via shell commands — no SDK, no Python import.

## Workflow

```
submit → status → results → merge-cov → close
```

1. **`simforge submit`** — filter testplan by tags, dispatch all cases async
2. **`simforge status`** — poll progress (pending / running / passed / failed)
3. **`simforge results`** — get per-case detailed results
4. **`simforge merge-cov`** — merge coverage databases after run completes
5. **`simforge close`** — shutdown the daemon when done

The daemon auto-launches on first `submit`. It auto-shuts down after 3600s idle.

---

## Where to Run simforge

simforge operates relative to a **project directory** — the root of a DV project.
By default it uses the **current working directory (CWD)** as the project dir.
Always `cd` into the project root before running commands, or pass `--project-dir <path>` explicitly.

```bash
cd /proj/dv/my_ip          # project root
simforge submit --tags smoke
```

Or from anywhere:
```bash
simforge submit --project-dir /proj/dv/my_ip --tags smoke
```

The daemon is **per-project-dir**: each unique directory gets its own daemon process.
Multiple engineers can run separate daemons for different projects on the same machine.

---

## Required Directory Structure

```
<project_root>/                   ← run simforge from here (or --project-dir)
├── cases/
│   └── testplan.yaml             ← REQUIRED: defines all simulation cases
├── regress.cfg.yaml              ← optional: parallel count, backend, run_dir
└── runs/                         ← auto-created by simforge on first submit
    └── 20240101_001/             ← one dir per run_id
        ├── config_snapshot.json
        ├── final_status.json     ← written when run ends (completed/cancelled/error)
        ├── tc_smoke_1/
        │   ├── run.sh
        │   └── sim.log
        └── tc_smoke_2/
            ├── run.sh
            └── sim.log
```

### Minimum Required Files

| File | Required | Notes |
|------|----------|-------|
| `cases/testplan.yaml` | **Yes** | Must exist before `submit`. Use `--testplan` to point to a different path |
| `regress.cfg.yaml` | No | Place in project root; overrides defaults for backend/parallelism |

### testplan.yaml path resolution

- Default: `<project_root>/cases/testplan.yaml`
- Override: `simforge submit --testplan path/to/other.yaml`  (relative to project root)
- Check what's in the testplan without submitting: `simforge list`

### Run output

- Default run output dir: `<project_root>/runs/` (controlled by `run_dir` in `regress.cfg.yaml`)
- Each run gets a sub-directory named by `run_id` (`YYYYMMDD_NNN`)
- Each case gets its own sub-directory inside the run dir: `<run_dir>/<run_id>/<case_name>/`
- Simulation log is at `<run_dir>/<run_id>/<case_name>/sim.log`
- Coverage database (if produced) at `<run_dir>/<run_id>/<case_name>/coverage.vdb`
- Merged coverage after `merge-cov`: `<run_dir>/<run_id>/merged_cov/`

### Daemon state

simforge stores daemon registry and auth tokens in `~/.simforge/`:

```
~/.simforge/
├── registry.json      ← tracks all running daemons (host, port, pid)
├── remote/
│   ├── s-<user>-<id>.token   ← per-daemon auth token (chmod 600)
│   └── s-<user>-<id>.ready   ← port/pid info written at startup
└── logs/
    └── s-<user>-<id>.log     ← daemon log
```

This directory is managed automatically — no manual setup needed.

---

## Commands

### submit

Submit all matching cases from the testplan for async execution.

```
simforge submit [options]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--testplan <path>` | `cases/testplan.yaml` | Testplan file path (relative to project dir) |
| `--tags <t1,t2>` | all | Include only cases with ALL listed tags |
| `--exclude-tags <t1,t2>` | none | Exclude cases with ANY listed tag |
| `-j <n>` | 4 | Max parallel simulation jobs |
| `--backend <local\|lsf>` | `local` | Job scheduler backend |
| `--seed <n\|random>` | `random` | Global simulation seed |
| `--timeout <sec>` | from testplan | Override per-case timeout |
| `--project-dir <dir>` | CWD | Project root directory |
| `--session <id>` | auto | Isolate daemons for parallel workflows |
| `--json` | off | JSON output |

**Returns:** `run_id`, total case count, list of case names, run directory path.

**Example:**
```bash
simforge submit --tags smoke -j 8
simforge submit --tags regress --exclude-tags slow -j 16 --seed 42
```

---

### status

Poll the progress of a regression run.

```
simforge status [--run-id <id>] [--project-dir <dir>] [--json]
```

**Returns:** run status (`running`/`completed`/`cancelled`), counts of total/passed/failed/running/pending cases, elapsed time, list of currently running and failed case names.

**Example:**
```bash
simforge status
simforge status --run-id 20240101_002
simforge status --json
```

---

### cancel

Cancel a running regression.

```
simforge cancel [--run-id <id>] [--project-dir <dir>] [--json]
```

**Returns:** run status, number of killed running jobs, number of cancelled pending jobs.

---

### results

Get per-case detailed results.

```
simforge results [--run-id <id>] [--filter all|failed|passed] [--project-dir <dir>] [--json]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--filter` | `all` | Show all / only failed / only passed cases |

**Returns:** summary counts + per-case table with: name, status, seed, elapsed_sec, log_file path, error snippet.

**Example:**
```bash
simforge results --filter failed
simforge results --json
```

---

### merge-cov

Merge per-case coverage databases into a single merged report.

```
simforge merge-cov [--run-id <id>] [--tool urg|imc|vcover] [--project-dir <dir>] [--json]
```

**Returns:** path to merged coverage directory, merger tool used, number of databases merged.

**Auto-detects tool from simulator**: VCS → `urg`, Xrun → `imc`, QuestaSim → `vcover`.

---

### list

List testplan cases without starting a daemon. Useful for previewing tag filters.

```
simforge list [--testplan <path>] [--tags <t1,t2>] [--exclude-tags <t1,t2>]
              [--project-dir <dir>] [--json]
```

**Returns:** total count + list of case names and their tags.

**Example:**
```bash
simforge list --tags smoke
simforge list --json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['total'])"
```

---

### list-runs

List all runs: includes active (in-memory) runs from the current daemon **and** completed runs persisted to disk from past sessions.

```
simforge list-runs [--project-dir <dir>] [--session <id>] [--json]
```

Each entry shows: `run_id`, `status`, `total`/`passed`/`failed`, `elapsed_sec`, `finished_at` (disk runs), and `source` (`live` or `disk`).

Use this to see the history of all past regressions in a project, even after daemon restarts.

---

### ps

Global view of all running daemons across sessions.

```
simforge ps [--clean] [--json]
```

| Parameter | Description |
|-----------|-------------|
| `--clean` | Remove stale (dead process) registry entries |

**Returns:** list of all active daemons with their run summaries, plus stale entries.

---

### close

Shutdown the daemon for this project.

```
simforge close [--all] [--project-dir <dir>] [--session <id>] [--json]
```

| Parameter | Description |
|-----------|-------------|
| `--all` | Close all daemons in this session |

---

## Testplan YAML Format

The testplan file (`cases/testplan.yaml` by default) defines all simulation cases:

```yaml
global:
  simulator: vcs          # vcs | xrun | questa
  top_module: tb_top
  compile_opts: "-f rtl/rtl.f"
  sim_opts: "+UVM_VERBOSITY=UVM_LOW"
  timeout: 3600           # seconds
  plusargs: []

cases:
  - name: tc_basic_write
    tags: [smoke, regress]
    sim_opts: "+TESTNAME=basic_write"

  - name: tc_burst_read
    tags: [regress]
    timeout: 7200
    sim_opts: "+TESTNAME=burst_read"

  - name: tc_error_inject
    tags: [regress, slow]
    plusargs: ["+inject_mode=1"]
```

### Tag Filtering Rules
- `--tags t1,t2` — includes cases that have **ALL** listed tags (intersection)
- `--exclude-tags t1,t2` — removes cases that have **ANY** listed tag (union)
- Tags are combined: first apply include filter, then apply exclude filter

---

## Config File (regress.cfg.yaml)

Optional project-level config in the project root:

```yaml
backend: local          # local | lsf
run_dir: runs           # directory for run outputs

local:
  max_parallel: 8

lsf:
  queue: normal
  memory: 4G
  extra_opts: "-R 'rusage[mem=4096]'"
```

---

## Key JSON Fields

### submit response
```json
{
  "status": "ok",
  "run_id": "20240101_001",
  "total_cases": 42,
  "cases": ["tc_smoke_1", "tc_smoke_2", ...],
  "run_dir": "/proj/dv/runs/20240101_001",
  "backend": "local",
  "max_parallel": 8
}
```

### status response
```json
{
  "status": "ok",
  "run_id": "20240101_001",
  "run_status": "running",
  "total": 42,
  "passed": 30,
  "failed": 2,
  "running": 4,
  "pending": 6,
  "elapsed_sec": 147.3,
  "failed_cases": [
    {"name": "tc_burst", "seed": 1234567, "elapsed_sec": 32.1, "error_msg": "UVM_FATAL: ..."}
  ]
}
```

### results response (per case)
```json
{
  "name": "tc_burst",
  "status": "failed",
  "seed": 1234567,
  "elapsed_sec": 32.1,
  "log_file": "/proj/dv/runs/20240101_001/tc_burst/sim.log",
  "coverage_dir": "/proj/dv/runs/20240101_001/tc_burst/coverage.vdb",
  "error_msg": "UVM_FATAL @ 1500ns: DUT timeout"
}
```

### final_status.json (on-disk persistence)

Written to `<run_dir>/<run_id>/final_status.json` when a run ends (completed, cancelled, or error). Enables querying past runs across daemon restarts.

```json
{
  "run_id": "20240101_001",
  "status": "completed",
  "project_dir": "/proj/dv",
  "run_dir": "/proj/dv/runs/20240101_001",
  "testplan": "cases/testplan.yaml",
  "tags": ["smoke"],
  "backend": "local",
  "created_at": "2024-01-01T10:00:00",
  "finished_at": "2024-01-01T10:05:00",
  "total": 10,
  "passed": 9,
  "failed": 1,
  "cancelled": 0,
  "elapsed_sec": 300.0,
  "cases": [
    {
      "name": "tc_smoke_1",
      "status": "passed",
      "seed": 42,
      "elapsed_sec": 25.3,
      "exit_code": 0,
      "log_file": "/proj/dv/runs/20240101_001/tc_smoke_1/sim.log",
      "error_msg": null,
      "coverage_dir": null
    }
  ]
}
```

---

## Common Patterns

### Quick smoke regression
```bash
cd /proj/dv
simforge submit --tags smoke -j 4
simforge status --json   # poll until run_status == "completed"
simforge results --filter failed
```

### Full regression with coverage
```bash
simforge submit --tags regress -j 32 --backend lsf
# ... wait for completion ...
simforge status
simforge merge-cov         # auto-detects tool
simforge results --json
```

### Debug a failed test
```bash
# Find what failed
simforge results --filter failed --json | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d['results']:
    print(r['name'], r['seed'], r['error_msg'])
"

# Rerun just one case (use its seed for reproducibility)
simforge submit --tags smoke --testplan cases/testplan.yaml --seed 1234567
```

### Global status check
```bash
simforge ps               # show all active daemons
simforge ps --clean       # remove stale entries
simforge close --all      # shutdown all daemons in session
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| `NO_CASES_MATCHED` | Tag filter matched zero cases — check testplan and tag names |
| `RUN_NOT_FOUND` | run_id doesn't exist in current daemon memory **and** no `final_status.json` on disk |
| `INVALID_TESTPLAN` | testplan.yaml parse error |
| `LAUNCH_FAILED` | Daemon failed to start (binary not found or permission error) |
| `NO_DAEMON` | No daemon running for this project (use `submit` first) |

---

## Practical Notes

- **run_id format**: `YYYYMMDD_NNN` (e.g., `20240101_001`). Omit `--run-id` to use the latest run.
- **Logs**: Each case writes to `<run_dir>/<case_name>/sim.log`. 
- **Seeds**: When a case fails, record the seed from `results` output to reproduce exactly.
- **Daemon persistence**: Daemon survives CLI exit. Run `simforge ps` to see all active daemons.
- **Run persistence**: When a run finishes, a `final_status.json` file is written to `<run_dir>/<run_id>/`. Commands `status`, `results`, and `list-runs` automatically fall back to this file when the run is no longer in daemon memory (e.g., after daemon restart). Use `list-runs` to see all past runs across sessions.
- **Multiple projects**: Each project dir gets its own daemon. Use `--session` to further isolate.
