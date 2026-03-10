---
name: sw-install-self-test
description: "Use this skill when the user asks to verify that custom tools are installed correctly, run a self-test, check tool availability, or diagnose missing binaries. Triggers include: 'self test', 'self-test', 'check tools', 'verify installation', 'are my tools installed', 'test installation', 'which tools are available', 'tool health check', or any request to confirm that svlinter, terminal_manager, fast_elab, wave_reader, cov_reader, or simforge can be found and executed."
---

# Software Installation Self-Test

Verify that all custom-built tools are correctly installed and accessible from the command line.

## Tool Registry

The following tools should all be available in `$PATH` (typically via `skill_pack/tool/` or `~/.local/bin/`):

| Tool | Binary Name | Quick Check | Expected Output |
|------|-------------|-------------|-----------------|
| SVLinter | `svlinter` | `svlinter --version` | `svlinter <version>` |
| Fast Elaborator | `fast_elab` | `fast_elab --version` | `fast_elab <version>` |
| Wave Reader | `wave_reader` | `wave_reader --help` | usage line starting with `usage: wave_reader` |
| Coverage Reader | `cov_reader` | `cov_reader --help` | usage line starting with `usage: cov_reader` |
| Terminal Manager | `terminal_manager` | `terminal_manager --help` | usage line starting with `usage: terminal_manager` |
| SimForge | `simforge` | `simforge --help` | usage line starting with `usage: simforge` |

## How to Run the Self-Test

Run the following **single command** in a terminal and report the results to the user:

```bash
echo "===== Software Installation Self-Test =====" && \
echo "" && \
PASS=0 FAIL=0 && \
for spec in \
  "svlinter:svlinter --version" \
  "fast_elab:fast_elab --version" \
  "wave_reader:wave_reader --help" \
  "cov_reader:cov_reader --help" \
  "terminal_manager:terminal_manager --help" \
  "simforge:simforge --help" \
; do \
  name="${spec%%:*}" && \
  cmd="${spec#*:}" && \
  if output=$($cmd 2>&1 | head -1); then \
    printf "  ✅  %-20s  %s\n" "$name" "$output" && \
    PASS=$((PASS+1)); \
  else \
    printf "  ❌  %-20s  NOT FOUND or ERROR\n" "$name" && \
    FAIL=$((FAIL+1)); \
  fi; \
done && \
echo "" && \
echo "Result: $PASS passed, $FAIL failed out of 6 tools."
```

## Interpreting Results

- **All ✅**: All tools are installed and working. Report success to the user.
- **Any ❌**: For each failing tool:
  1. Check if the binary exists: `which <binary_name>` or `ls skill_pack/tool/<binary_name>`
  2. If not found, the tool may not have been downloaded — run `tool_integration.sh` from `skill_pack/`.
  3. If found but not executable, fix permissions: `chmod +x <path>`
  4. If found but errors on execution, it may be a glibc/architecture mismatch — check with `file <binary>` and `ldd <binary>`.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `command not found` | Binary not in PATH | Ensure `skill_pack/tool/` is in PATH, or run `deploy.sh` |
| Segfault or glibc error | Binary built for different OS/arch | Rebuild via `make build` in the tool's repo |
| Permission denied | Missing execute bit | `chmod +x skill_pack/tool/<name>` |
