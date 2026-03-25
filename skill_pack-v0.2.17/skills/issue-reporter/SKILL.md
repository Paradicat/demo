---
name: issue-reporter
description: Guide for reporting reproducible issues as self-contained compressed archives, and for triaging received issue packages. Use this skill when the user asks to report a bug, file an issue, create a repro case, package a problem for handoff, or whenever you encounter a tool/environment failure that should be escalated. Also use when the user provides a .tar.gz issue package and asks you to investigate, reproduce, or fix it.
---

# Issue Reporter & Handler

This skill covers **both sides** of issue lifecycle:

- **Part A — Creating** an issue package (reporter workflow)
- **Part B — Receiving** and triaging an issue package (handler workflow)

---

# Part A: Creating an Issue Package

Generate a **self-contained, compressed issue package** that anyone can download, extract, and reproduce the problem — no prior context required.

## When to Use

- User explicitly asks to "report an issue", "file a bug", "create a repro"
- You hit a tool/environment failure that cannot be resolved and should be escalated
- A bug needs to be handed off to another team or upstream maintainer

## Output Package Structure

```
issue_<slug>_<YYYYMMDD>/
├── README.md            # Structured issue description (see template below)
├── repro/               # Minimal reproduction files
│   ├── ...              # Only essential source files
│   └── run_repro.sh     # One-command reproduction script
└── logs/                # (Optional) relevant log snippets
    └── ...
```

The final deliverable is a compressed archive: `issue_<slug>_<YYYYMMDD>.tar.gz`

- `<slug>`: short kebab-case identifier, e.g. `vcs-lto-mismatch`, `fifo-overflow`
- `<YYYYMMDD>`: date of issue creation

---

## Step-by-Step Workflow

### Step 1: Identify and Name the Issue

Choose a short, descriptive slug for the issue. This becomes the directory and archive name.

### Step 2: Create the Package Directory

```bash
ISSUE_DIR="issue_<slug>_$(date +%Y%m%d)"
mkdir -p "$ISSUE_DIR"/{repro,logs}
```

### Step 3: Write README.md

Create `$ISSUE_DIR/README.md` following the template below. **Fill every section** — do not leave placeholders.

```markdown
# Issue: <concise title>

## Environment

| Item       | Value |
|------------|-------|
| OS         | ... |
| Tool       | ... (name + version) |
| Date       | YYYY-MM-DD |

## Scenario

Describe what you were doing when the problem occurred.
Provide enough context so the reader understands the workflow.

## Problem

Describe the observed behavior clearly:
- What happened (error message, incorrect output, crash, etc.)
- What was expected instead
- Paste key error snippets inline (use code blocks)

## Analysis

Explain your investigation:
- Root cause hypothesis
- What you checked / ruled out
- Relevant references (docs, source code, known issues)

## Fix (if available)

If a fix or workaround was found, describe it here with exact steps.
If no fix is known, write "No fix identified yet."

## Reproduction

### Prerequisites

List required tools, versions, environment variables, etc.

### Steps

1. `cd repro/`
2. `bash run_repro.sh`
3. Observe: <what to look for>

### Expected vs. Actual

| | Description |
|--|-------------|
| **Expected** | ... |
| **Actual**   | ... |
```

### Step 4: Collect Reproduction Files

**Size rule**: Estimate the total size of reproduction files.

- **≤ 50 MB** → Copy the necessary original source files into `repro/`.
  Only copy files that are **essential** for reproduction — strip test data, unrelated modules, build artifacts, etc.
- **> 50 MB or problem is unambiguous** → Construct a **minimal self-contained case** that demonstrates the same failure. Writing a 20-line repro is better than bundling 200 files.

**Checklist for copying source files:**

- [ ] Only files needed to trigger the issue
- [ ] No build artifacts (`*.o`, `*.d`, `__pycache__`, etc.)
- [ ] No large binary blobs unless absolutely required
- [ ] Relative paths preserved where possible
- [ ] Any hard-coded absolute paths patched to be relative

### Step 5: Write the Reproduction Script

Create `repro/run_repro.sh`:

```bash
#!/bin/bash
# run_repro.sh — one-command reproduction for <issue slug>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# === Prerequisites check ===
# e.g.: command -v vcs >/dev/null || { echo "ERROR: vcs not found"; exit 1; }

# === Reproduction steps ===
# <actual commands that trigger the issue>

# === Verdict ===
# Check the exit code / output to confirm reproduction
echo "✅ Issue reproduced successfully — see output above."
```

Requirements for `run_repro.sh`:
- Must be runnable with `bash run_repro.sh` from inside `repro/`
- Must check prerequisites (tools, env vars) and fail fast with clear errors
- Must use only relative paths (portable)
- Must end with a clear verdict message

### Step 6: Verify Reproduction

**Run the script yourself before packaging:**

```bash
cd "$ISSUE_DIR/repro" && bash run_repro.sh
```

- If it reproduces the issue → proceed to packaging
- If it does NOT reproduce → fix the repro files/script, repeat
- **Never ship an untested repro**

### Step 7: Package and Compress

```bash
tar czf "${ISSUE_DIR}.tar.gz" "$ISSUE_DIR"
echo "📦 Package ready: ${ISSUE_DIR}.tar.gz"
ls -lh "${ISSUE_DIR}.tar.gz"
```

Report the final archive path and size to the user.

---

## Part A Rules

1. **README.md is mandatory.** Every package must have a complete description — the archive is useless without context.
2. **Test before you ship.** The `run_repro.sh` must actually reproduce the issue on your machine. If it doesn't, fix it.
3. **Minimize aggressively.** The goal is the smallest possible package that still reproduces the problem. Remove everything non-essential.
4. **No secrets.** Strip credentials, tokens, internal hostnames, and proprietary data before packaging. If the issue requires proprietary files, note it in README.md and provide a synthetic equivalent.
5. **Self-contained.** The recipient should need nothing beyond standard tools and the archive contents. Document any non-obvious prerequisites.
6. **One issue per package.** Don't bundle multiple unrelated issues.

---

# Part B: Handling a Received Issue Package

When you receive a `.tar.gz` issue package (from a user, another agent, or an upstream report), follow this workflow to understand, reproduce, and act on it.

## When to Use

- User provides a `.tar.gz` / `.tgz` file and asks you to "look at this issue", "investigate", "reproduce", "fix this"
- You receive an issue handoff from another team or agent
- A CI/CD pipeline drops an issue package for triage

## Step-by-Step Workflow

### Step 1: Extract and Inventory

```bash
tar xzf <archive>.tar.gz
ls -R <extracted_dir>/
```

Verify the package has the expected structure:
- `README.md` exists → proceed
- `README.md` missing → the package is incomplete; notify the user and ask for context, or try to infer the issue from available files

### Step 2: Read README.md Thoroughly

Read the full `README.md`. Extract and internalize:

| Section | What to look for |
|---------|------------------|
| **Environment** | OS, tool versions — do they match your environment? Note any mismatches. |
| **Scenario** | Understand the workflow context — what were they trying to do? |
| **Problem** | The exact symptom: error message, wrong output, crash. Copy key error strings for searching. |
| **Analysis** | The reporter's hypothesis — do you agree? Are there gaps in their reasoning? |
| **Fix** | If a fix is provided, verify it before applying. If not, this is your job. |
| **Reproduction** | Steps and expected vs. actual — this is your test plan. |

### Step 3: Check Environment Compatibility

Before running anything, verify your environment matches the prerequisites:

```bash
# Example checks — adapt to the issue's requirements
cat /etc/os-release
<tool> --version
echo $RELEVANT_ENV_VAR
```

| Situation | Action |
|-----------|--------|
| Environment matches | Proceed to reproduction |
| Minor mismatch (e.g., patch version differs) | Note it, try reproducing anyway |
| Major mismatch (e.g., tool not installed) | Stop, report to user what's missing |

### Step 4: Run the Reproduction

```bash
cd <extracted_dir>/repro
bash run_repro.sh
```

Record the outcome:

| Result | Meaning | Next step |
|--------|---------|-----------|
| Issue reproduces ✅ | Package is valid, issue is real | Proceed to analysis (Step 5) |
| Script fails with unrelated error | Environment issue, not the reported bug | Fix environment, re-run |
| Issue does NOT reproduce | May be environment-specific or already fixed | Report to user with your environment details |

### Step 5: Analyze the Issue

Now that you can reproduce it, dig deeper:

1. **Verify the reporter's analysis** — Do you agree with the root cause hypothesis in README.md? Test it.
2. **Read the source files** in `repro/` — understand what they do, not just what fails.
3. **Isolate the trigger** — Can you narrow it down further? Comment out lines, change parameters, simplify the case.
4. **Search for known issues** — Check relevant skills (e.g., `eda-toolchain-debug`), documentation, error message strings.
5. **Form your own hypothesis** — Even if the reporter's analysis is correct, verify independently.

### Step 6: Attempt a Fix

If a fix is suggested in README.md:
1. Apply it to the repro files
2. Re-run `run_repro.sh` — does the issue go away?
3. Verify no regressions — does the underlying functionality still work?

If no fix is suggested:
1. Based on your analysis, develop a fix or workaround
2. Test it against the repro case
3. If the fix works, document what you changed and why

### Step 7: Report Back

Provide a clear triage summary to the user:

```markdown
## Issue Triage Report

### Package: <archive name>

### Reproduction: ✅ Reproduced / ❌ Could not reproduce

### Environment Match
| Item | Package says | My environment | Match? |
|------|-------------|----------------|--------|
| OS   | ...         | ...            | ✅/❌  |
| Tool | ...         | ...            | ✅/❌  |

### Analysis
- Reporter's hypothesis: <agree/disagree/partially agree>
- My findings: <your analysis>
- Root cause: <confirmed or revised root cause>

### Resolution
- **Status**: Fixed / Workaround found / Needs escalation / Cannot reproduce
- **Fix applied**: <describe what was changed>
- **Verification**: <confirm the fix resolves the issue and causes no regressions>

### Recommendations
- <next steps, upstream patches to apply, configuration changes, etc.>
```

---

## Part B Rules

1. **Always read README.md first.** Don't jump into running scripts without understanding the issue.
2. **Check environment before running.** Blind execution in a mismatched environment wastes time and produces misleading results.
3. **Reproduce before analyzing.** If you can't trigger the bug, your analysis is speculation.
4. **Verify fixes against the repro.** A fix isn't confirmed until `run_repro.sh` passes (issue gone) and the underlying operation succeeds.
5. **Report clearly.** The person who sent the package needs to know: did it reproduce? what did you find? is it fixed?
6. **Don't modify the original package.** Work on copies. Keep the original archive intact for reference.
