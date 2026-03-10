# Bash Aliases Do Not Expand in Non-Interactive Shells

## Basic Info

| Field | Value |
|-------|-------|
| Tool | Generic (VCS, Xrun, DC, and all EDA tools wrapped via alias) |
| OS | All Linux distributions |
| Date Found | 2026-02-16 |
| Severity | Blocking |

## Symptom

Users define aliases for EDA tools in `~/.bashrc` (adding commonly used options). **Commands work normally in interactive terminals**, but aliases do not take effect in the following scenarios, causing different command behavior or outright failure:

- `bash script.sh` / `sh script.sh`
- Makefile `$(shell ...)` or recipes
- CI pipelines (Jenkins, GitHub Actions, etc.)
- `subprocess.run()` / `os.system()` and other programmatic invocations
- cron jobs

**Typical alias examples**:
```bash
# In ~/.bashrc
alias vcs='vcs -full64 -sverilog -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed'
alias xrun='xrun -64bit -sv -licqueue'
alias dc_shell='dc_shell -64bit -topographical_mode'
```

**Behavior**: Manual terminal execution succeeds; script execution fails. The specific error depends on which options are missing (linker errors, missing compile options, license issues, etc.).

## Root Cause

1. **Bash aliases only expand in interactive shells**. Bash decides whether to load aliases based on whether it's an interactive shell:
   - Interactive shell (typing commands directly in terminal): Loads `~/.bashrc`, expands aliases ✅
   - Non-interactive shell (`bash script.sh`, Makefile, CI): **Does not load `~/.bashrc`**, aliases don't exist ❌

2. **`which` cannot see aliases** — only `type` can:
   ```bash
   which vcs     # → /path/to/vcs  (no alias visible)
   type vcs      # → vcs is aliased to 'vcs -full64 -sverilog ...'  (alias visible)
   ```

3. **Highly deceptive**: Everything works when the user debugs in terminal; once written into a script or Makefile it fails, easily misdiagnosed as a problem with the script itself

## Diagnostics

```bash
# 1. Check for EDA tool aliases
grep -i "alias" ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null | grep -iE "vcs|xrun|dc_shell|icc|pt_shell|verdi"

# 2. Confirm with type (in interactive terminal)
type vcs        # If output shows "vcs is aliased to ..." then this is the issue
type xrun

# 3. Compare interactive vs non-interactive environments
echo "type vcs" | bash        # Non-interactive: should show "vcs is /path/to/vcs"
type vcs                       # Interactive: may show alias
```

## Solutions

### Solution A: Explicitly write full options in scripts/Makefiles (Recommended)

Do not rely on aliases — write all options explicitly:

```makefile
# Makefile example
VCS_FLAGS := -full64 -sverilog -timescale=1ns/1ps \
             -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed
```

```bash
# Shell script example
VCS_FLAGS="-full64 -sverilog -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed"
vcs ${VCS_FLAGS} -f rtl.f -o simv
```

> ⚠️ Run `grep alias ~/.bashrc | grep <tool_name>` first to extract the user's alias options, then copy them into the script verbatim.

### Solution B: Explicitly enable alias expansion in scripts (Not recommended)

```bash
#!/bin/bash
shopt -s expand_aliases
source ~/.bashrc
# Aliases now expand, but side effects are unpredictable
```

> ⚠️ Not recommended: `source ~/.bashrc` may introduce unexpected side effects (duplicate PATH entries, environment variable overwrites, etc.).

### Solution C: Convert alias to shell function (User-side change)

Suggest the user convert their alias to a function, which can be exported to non-interactive shells:

```bash
# In ~/.bashrc
vcs_run() {
    command vcs -full64 -sverilog -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed "$@"
}
export -f vcs_run
```

> Requires user cooperation to modify their environment configuration — may not always be feasible.

## Affected Tool Cases

| Tool | Common Alias Content | Typical Error When Missing in Scripts |
|------|---------------------|--------------------------------------|
| VCS | `-cc gcc-4.8 -cpp g++-4.8 -LDFLAGS ...` | `PIE`, `undefined reference`, linker failure → see `../vcs/002_vcs_nontty_linking.md` |
| Xrun | `-64bit -sv -licqueue` | 32/64-bit mismatch, license queue failure |
| DC Shell | `-64bit -topographical_mode` | Out of memory (32-bit mode), missing topo mode |

## Notes

- This is a **shell-level generic issue**, not a bug in any specific EDA tool
- Most commonly exposed when migrating manual compilation flows to Makefile/CI
- **Extremely low diagnostic cost** (a single `grep` command), but without knowing this mechanism, hours can be spent debugging
- Related case: `../vcs/002_vcs_nontty_linking.md` (VCS-specific TTY detection issue, can co-occur with this problem)
