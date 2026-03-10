# status.md Template

Use this template when creating `status.md` in a new project's root directory.

```markdown
# Project Status

**Project Name**: <project_name>
**Created**: <date>
**Last Updated**: <date>

## Current Phase

Step 1: Project Structure - ✅ COMPLETED

## Progress Checklist

- [x] Step 0: Context & Scope Check
- [x] Step 1: Project Structure Created
- [ ] Step 2: spec.md Written
- [ ] Step 3: Spec Doc Review
- [ ] ⛔ GATE: User Confirmation — NOT YET
- [ ] Step 4: RTL Implementation
- [ ] Step 5: RTL Code Review
- [ ] Step 6: TB + Smoke Test — MUST ACTUALLY COMPILE & RUN
- [ ] Step 7: All Testcases — MUST ACTUALLY EXECUTE EACH ONE
- [ ] Step 8: SDC Constraints
- [ ] Step 9: Makefile + Regression

## Key Decisions

- **Design approach**: <brief summary>
- **Critical parameters**: <list confirmed parameters>

## Review Records

### Step 3: Spec Review
- Reviewer: <sub-agent / self-review (fallback)>
- Verdict: <READY / NEEDS IMPROVEMENT / MAJOR GAPS>
- Issues found: <count>
- Issues fixed: <count>

### Step 5: RTL Review
- Reviewer: <sub-agent / self-review (fallback)>
- Verdict: <CLEAN / ISSUES / CRITICAL BUGS>
- 🔴 Bugs found: <count>
- 🔴 Bugs fixed: <count>

## Compilation & Simulation Evidence

### Step 6: Smoke Test
- Simulator: <VCS / iverilog / BLOCKED (no tool)>
- Compile result: <0 errors, N warnings / FAILED>
- Sim result: <PASSED / FAILED (reason)>

### Step 7: Testcase Results
| Testcase | Compiled | Executed | Result |
|----------|----------|----------|--------|
| tc001_*  | ☐        | ☐        | —      |
| tc002_*  | ☐        | ☐        | —      |

## Next Action

Write spec.md and wait for user confirmation.

## Notes

<Any important context or decisions>
```

## Update Rules

1. **Update immediately** after completing each step
2. **Never mark a step ✅** unless its DONE CRITERIA is actually met
3. **Step 6/7**: Must include compilation/simulation evidence (tool used, error count, PASSED/FAILED)
4. **If a step is blocked**: Mark as `⏸️ BLOCKED (reason)`, not ✅
5. **Gate status**: Must explicitly show AWAITING / PASSED with date
