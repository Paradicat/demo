---
name: terminal-manager
description: Manage persistent terminal sessions (tmux) using the terminal_manager CLI tool. Use this skill whenever the user needs long-running terminal sessions, EDA tool shells, background processes, or persistent command environments. Trigger when the user mentions terminal management, persistent sessions, tmux, background processes, EDA tool sessions (DC shell, VCS, Innovus), or wants to run commands that need session state persistence — even if they don't explicitly say "terminal_manager".
---

# terminal_manager — Persistent Terminal Session Manager

A standalone CLI tool for managing persistent tmux terminal sessions. Invoke it via shell commands — no SDK, no Python import, no REST API.

All sessions are managed by a shared background daemon that starts automatically. Terminal state persists across CLI invocations.

## Workflow

1. **`terminal_manager create --name <name>`** — create a terminal session
2. **`terminal_manager execute <id> '<command>'`** — run a command and get output
3. **`terminal_manager read <id>`** — read current terminal output
4. **`terminal_manager write <id> '<text>'`** — send keystrokes
5. **`terminal_manager list`** — see all terminals
6. **`terminal_manager close <id>`** — destroy when done

The daemon starts automatically on the first command. No explicit `start` needed.

## When to Use Terminal Manager

**Use TM when:**
- Running EDA tools (DC shell, VCS, Innovus) that take over the terminal
- Long-running processes (builds, simulations) you need to check later
- Operations requiring session state persistence
- Multi-step workflows in the same shell environment
- Any task requiring "come back later" capability

**Don't use TM when:**
- Running simple one-shot commands (`ls`, `cat`, `grep`)
- Quick queries that don't need context

---

## Commands

### create

Create a new terminal session.

```
terminal_manager create [--name NAME] [--shell SHELL] [--cwd DIR] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--name` | no | auto | Display name for the terminal |
| `--shell` | no | bash | Shell to use |
| `--cwd` | no | current dir | Working directory |
| `--json` | no | off | JSON output |

**Returns:** terminal ID, name, shell, cwd, status.

### execute

Run a command and wait for completion. Returns output and exit code.

```
terminal_manager execute <id> <command> [--timeout SEC] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `id` | yes | — | Terminal ID |
| `command` | yes | — | Command string |
| `--timeout` | no | 30 | Timeout in seconds |
| `--json` | no | off | JSON output |

**Returns:** command output, exit code, timeout flag.

### read

Read current visible output from a terminal.

```
terminal_manager read <id> [--lines N] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `id` | yes | — | Terminal ID |
| `--lines` | no | 50 | Lines to capture |
| `--json` | no | off | JSON output |

### write

Send text (keystrokes) to a terminal.

```
terminal_manager write <id> <input> [--no-enter] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `id` | yes | — | Terminal ID |
| `input` | yes | — | Text to send |
| `--no-enter` | no | off | Don't press Enter |
| `--json` | no | off | JSON output |

### wait-for

Wait for a pattern to appear in terminal output.

```
terminal_manager wait-for <id> <pattern> [--timeout SEC] [--json]
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `id` | yes | — | Terminal ID |
| `pattern` | yes | — | Text to wait for |
| `--timeout` | no | 30 | Timeout in seconds |
| `--json` | no | off | JSON output |

### status

Show terminal status and metadata.

```
terminal_manager status <id> [--json]
```

### list

List all terminal sessions.

```
terminal_manager list [--json]
```

### close

Close (destroy) a terminal session.

```
terminal_manager close <id> [--json]
```

### update

Update terminal metadata (name, description).

```
terminal_manager update <id> [--name NAME] [--description DESC] [--json]
```

### start / stop

Explicitly start or stop the daemon (usually not needed — auto-starts).

```
terminal_manager start [--json]
terminal_manager stop [--json]
```

### commands / help-cmd

Discover available daemon commands and their parameters.

```
terminal_manager commands [--json]
terminal_manager help-cmd <command-name> [--json]
```

---

## Best Practices

| Practice | Why |
|----------|-----|
| **Check `list` before creating** | Avoid duplicate terminals for the same task |
| **Give terminals descriptive names** | `--name dc_shell` is better than default names |
| **Use `execute` for commands with exit codes** | `write` + `read` doesn't capture exit status |
| **Use `wait-for` for async patterns** | More reliable than polling with `read` |
| **Close terminals when done** | Frees tmux sessions and system resources |
| **Use `--json` for programmatic access** | Structured output is easier to parse |

## Error Reference

| Code | Meaning | Fix |
|------|---------|-----|
| `NO_TMUX` | tmux not installed | Install tmux |
| `NOT_FOUND` | Terminal ID not found | Check `list` for valid IDs |
| `SESSION_DEAD` | tmux session died | Create a new terminal |
| `MISSING_PARAM` | Required parameter missing | Check `help-cmd` for usage |
| `DAEMON_ERROR` | Cannot reach daemon | Run `terminal_manager start` |

## Terminal Session Naming Convention

Give each terminal a descriptive name:
- `dc_shell` — Design Compiler sessions
- `build_server` — Long-running builds
- `python_repl` — Interactive Python
- `vcs_sim` — VCS simulation runs
- `innovus_pnr` — Place & route sessions
