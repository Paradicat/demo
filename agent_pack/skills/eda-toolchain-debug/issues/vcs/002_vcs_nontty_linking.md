# VCS Linking Failure Due to Inconsistent Linker Options in Non-TTY Environments

## Basic Info

| Field | Value |
|-------|-------|
| Tool | VCS L-2016.06 |
| OS | Ubuntu 22.04+ (GCC 11+) |
| Date Found | 2026-02-16 |
| Severity | Blocking |

## Symptom

**The same VCS compile command** succeeds when run directly in a terminal but fails at the linking stage when invoked from scripts (e.g., Makefile `$(shell ...)`, subprocess, cron, CI pipeline):

```
/usr/bin/ld: /path/to/vcs/lib/vcs_save_restore_new.o: relocation R_X86_64_32S
against symbol '_sigintr' can not be used when making a PIE object;
recompile with -fPIC

/usr/bin/ld: /path/to/vcs/lib/libvcsnew.so: undefined reference to
'vcsRunUcliErrorScript'

collect2: error: ld returned 1 exit status
```

Key symptom: **parsing and elaboration both pass; only the linking stage fails**. Not reproducible in interactive terminal.

## Root Cause Analysis

### Root Cause 1: VCS TTY Detection Mechanism

1. **VCS TTY detection**: VCS L-2016 checks whether stdout is connected to a TTY at startup, and selects different internal compiler configurations accordingly:
   - **TTY mode** (interactive terminal): Uses VCS's bundled `g++-4.8` and automatically adds `-Wl,--no-as-needed -rdynamic` and other linker options
   - **Non-TTY mode** (script/pipe/redirect): Uses the system default `g++` (possibly 11+) and **does not add** those linker options

2. **System GCC too new**: Ubuntu 22.04's GCC 11+ enables PIE (Position Independent Executable) by default, but VCS 2016's pre-compiled object files (`.o`) were not compiled with `-fPIC`, causing `R_X86_64_32S` relocation errors

3. **Missing linker options**: Non-TTY mode lacks `-Wl,--no-as-needed`, causing VCS internal symbols (e.g., `vcsRunUcliErrorScript`) to not be linked correctly

4. **Hard to diagnose**: Since manual terminal execution works (TTY mode), developers mistakenly assume the command itself is fine and suspect other parts of the Makefile or script

### Root Cause 2: Shell aliases do not expand in non-interactive scripts

→ **This is a generic shell issue. See [`../common/001_bash_alias_noninteractive.md`](../common/001_bash_alias_noninteractive.md) for full details.**

In short: if the user has a `vcs` alias in `~/.bashrc` (e.g., `-cc gcc-4.8 -cpp g++-4.8 -LDFLAGS ...`), the alias does not expand in scripts, so VCS runs without critical flags. Symptoms are identical to Root Cause 1.

> ⚠️ **Check aliases first**: Running `grep alias ~/.bashrc | grep vcs` takes 1 second and directly identifies ~80% of these cases.

## Solutions

### Solution A: Explicitly specify full VCS options in Makefile/scripts (Recommended)

**Core idea**: Do not rely on aliases or automatic environment detection. Write all required VCS options directly in the Makefile or regression script:

```makefile
# Makefile example
VCS_FLAGS := -full64 -sverilog -timescale=1ns/1ps \
             -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed
```

```bash
# regression.sh example
VCS_FLAGS="-full64 -sverilog -timescale=1ns/1ps -cc gcc-4.8 -cpp g++-4.8 -LDFLAGS -Wl,--no-as-needed"
vcs ${VCS_FLAGS} -f rtl.f -f tb.f testcase/tc001.sv -top tb_top -top tc001 -o simv_tc001
```

> ⚠️ These options should match the user's vcs alias in `~/.bashrc`. Run `grep alias ~/.bashrc | grep vcs` to check.

If g++-4.8 is not installed:

```bash
sudo apt install g++-4.8    # Ubuntu 18.04/20.04
# Or install from PPA/source, depending on Ubuntu version
```

### Solution B: Use system GCC but add missing linker options

If you don't want to install an older GCC, just add the missing linker options:

```makefile
VCS_FLAGS += +vcs+novarun
VCS_FLAGS += -LDFLAGS "-Wl,--no-as-needed"
VCS_FLAGS += -LDFLAGS -no-pie
VCS_FLAGS += -LDFLAGS -rdynamic
```

> Note: A system GCC that is too new may cause other compatibility issues. Solution A is more robust.

### Solution C: Force TTY mode (debugging only)

Wrap the VCS call with `script` or `unbuffer` to trick it into thinking it's running in a TTY:

```bash
# Method 1: script
script -qc "vcs ... -o simv" /dev/null

# Method 2: unbuffer (requires expect package)
unbuffer vcs ... -o simv
```

> ⚠️ Not recommended for production — this workaround is fragile and affects log output formatting.

## Diagnostics

When this issue is suspected, **check in this order**:

```bash
# 0. Check for aliases first (most common root cause, see ../common/001_bash_alias_noninteractive.md)
grep -i "alias.*vcs" ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null

# 1. Compare compilers used in TTY vs non-TTY mode
vcs -full64 -sverilog ... -o simv 2>&1 | grep -i "g++"          # TTY
echo "" | vcs -full64 -sverilog ... -o simv 2>&1 | grep -i "g++" # non-TTY

# 2. Verify system GCC version
g++ --version
g++-4.8 --version 2>/dev/null || echo "g++-4.8 not installed"
```

## Notes

- The core issue is that VCS 2016's TTY detection changes its internal behavior — an **undocumented** behavioral difference
- Another equally common root cause is bash alias non-expansion → see [`../common/001_bash_alias_noninteractive.md`](../common/001_bash_alias_noninteractive.md)
- This issue does not occur on CentOS 7 (GCC 4.8) since the system GCC matches VCS's expected version
- Newer VCS versions (2017+) may not exhibit this issue, but this is unverified
- The issue is typically first exposed when migrating manual compilation flows to Makefile/CI
- Can co-occur with [001_verdi_pli_lto_mismatch.md](001_verdi_pli_lto_mismatch.md) — both must be resolved together
