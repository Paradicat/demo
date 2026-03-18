---
name: skill-improvement-suggestor
description: Retrospective analysis of skill effectiveness after completing a task. Use when user requests skill improvement analysis (e.g., "做skill改善分析", "skill improvement analysis", "analyze skill gaps"). Analyzes the conversation to identify where goals were missed or required excessive iteration, then produces generalized, actionable improvement proposals saved to a structured report.
---

# Skill Improvement Suggestor

Analyze the current conversation to identify skill gaps, inefficiencies, and improvement opportunities. Produce a structured report with actionable proposals.

## When to Use

User explicitly requests skill improvement analysis. Typical triggers:
- "做skill改善分析" / "skill improvement analysis"
- "分析一下skill的问题" / "analyze skill gaps"
- "我们来回顾一下" / "let's do a retrospective"

## Workflow

```
Step 1: Gather context
Step 2: Analyze conversation
Step 3: Survey existing skills
Step 4: Draft proposals
Step 5: Write report
```

### Step 1: Gather Context

Collect:
- **Scenario**: What was the user trying to accomplish? (1-2 sentence summary)
- **Available skills**: List all skills in `skills/skills/` (read directory)
- **Used skills**: Which skills were actually consulted or triggered during the conversation?
- **Tools/env**: What external tools, MCPs, or CLI utilities were involved?

### Step 2: Analyze Conversation

**2a. Reconstruct timeline.** Walk through the conversation chronologically. For each task/sub-task, record:
- What was attempted
- Whether it succeeded, and how many iterations it took
- Whether the user intervened to correct direction

**2b. Classify outcomes.** For each task, assign one outcome:

| Outcome | Definition |
|---------|------------|
| ✅ Smooth | Goal achieved in ≤2 iterations, no user correction needed |
| ⚠️ Struggled | Goal achieved, but required 3+ iterations or user correction |
| ❌ Missed | Goal not achieved, or user had to do it themselves |

Focus analysis on ⚠️ and ❌ items only — smooth tasks don't need improvement.

**2c. Identify root causes.** For each ⚠️/❌ item, determine why using these signals:

| Signal | Indicates |
|--------|-----------|
| Multiple retry loops on same error | Missing knowledge base or inadequate error-handling guidance |
| Agent searched blindly without consulting existing skill | Cross-referencing gap — skill exists but wasn't discovered |
| User had to correct agent's approach | Workflow guidance insufficient or missing |
| Agent produced output user rejected | Quality criteria or constraints not captured in skill |
| Excessive back-and-forth on scope/format | Ambiguous skill instructions, missing templates |
| Manual steps that could be automated | Opportunity for scripts or MCP integration |

**2d. Record each finding:**
1. **What happened** (factual, 1-2 sentences)
2. **Outcome**: ⚠️ Struggled / ❌ Missed
3. **Iterations**: how many attempts before resolution (or "unresolved")
4. **Impact** (wasted tokens / time / wrong output)
5. **Category**: `missing-skill` | `skill-gap` | `cross-ref-gap` | `automation-opportunity` | `quality-criteria`

### Step 3: Survey Existing Skills

Before drafting any proposal:
1. **List all skills** in `skills/skills/` — read each SKILL.md's frontmatter `description` to understand scope
2. For each finding from Step 2, identify which existing skills are **potentially relevant** (even if they weren't used during the conversation)
3. Read the full SKILL.md of each potentially relevant skill to determine:
   - Does it already address this problem? → Finding is a cross-ref gap, not a skill gap
   - Does it partially address it? → Proposal should modify existing skill, not create new one
   - No coverage at all? → New skill may be justified
4. Check `skill-creator/SKILL.md` for design principles that new/modified skills must follow
5. Record which skills were checked and the conclusion for each — this goes into the proposal's `Overlaps checked` field

### Step 4: Draft Proposals

For each issue from Step 2, draft an improvement proposal following these principles:

#### P1: Generalize
- Abstract from the specific case to the **class of problems** it represents
- Ask: "What other scenarios would this same fix help with?"
- Never assume future environments/requirements match the current case exactly

#### P2: No Redundancy
- If an existing skill already covers >70% of the proposal → modify that skill, don't create a new one
- If two proposals overlap → merge them

#### P3: Consider Tooling
- Can the improvement be supported by MCP servers, CLI tools, or scripts?
- Prefer tool-assisted solutions over pure-text guidance when the task is repetitive or error-prone

#### P4: Architectural Extensibility
- New skills should have clear scope boundaries and extension points
- Use directory structures that accommodate growth (e.g., `issues/`, `reference/`, `templates/`)
- Separate stable guidelines from volatile case-specific knowledge

#### P5: Context Economy
- Every token in a skill competes with conversation context
- Proposals should specify: what to add, what to remove, estimated token delta
- Prefer `reference/` files (loaded on demand) over inline content for detailed knowledge

### Step 5: Write Report

Save to: `skill_improve_<YYYYMMDD>_<scenario_slug>.md` in the **workspace root**.

`scenario_slug` rules: lowercase, underscores, ≤30 chars, describes the task domain (e.g., `async_fifo_design`, `pdf_report_gen`, `frontend_dashboard`).

Use this exact structure:

```markdown
# Skill Improvement Report — <Scenario Name>

Date: <YYYY-MM-DD>
Scenario: <1-2 sentence description>

## Context

### Work Scenario
<What the user was trying to accomplish, what tools/environment were involved>

### Skill Inventory

| Skill | Used? | Relevance |
|-------|-------|-----------|
| <name> | ✅/❌ | <brief note on role or why unused> |
...

## Findings

### F1: <Short title>
- **What happened**: ...
- **Outcome**: ⚠️ Struggled / ❌ Missed
- **Iterations**: <N> (or "unresolved")
- **Impact**: ...
- **Category**: `<category>`

### F2: ...
(repeat for each finding)

## Proposals

### Proposal 1: <Action> — <Target Skill>
- **Type**: New Skill / Modify Existing / New Script / New MCP
- **Target**: `skills/skills/<name>/`
- **Addresses findings**: F1, F2, ... (link back to findings)
- **Problem class**: <What general category of problems this addresses>
- **Change summary**: <What to add/modify/remove, concisely>
- **Specific changes**:
  - File: `<path>` — Section: `<section>` — Action: add/modify/remove — Content sketch: `<brief>`
  - (repeat for each file/section affected)
- **Architecture notes**: <Extension points, growth path> (required for new skills)
- **Estimated context cost**: <+N / -N tokens in SKILL.md>
- **Overlaps checked**: <Which existing skills were verified, and conclusion for each>

### Proposal 2: ...
(repeat for each proposal)

## Priority

| # | Proposal | Impact | Effort | Priority |
|---|----------|--------|--------|----------|
| 1 | ... | High/Med/Low | High/Med/Low | P0/P1/P2 |
...
```

## Quality Checklist

Before finalizing the report, verify:

- [ ] Conversation timeline was reconstructed — no major task/sub-task omitted
- [ ] Each finding has an explicit outcome (⚠️ Struggled / ❌ Missed) and iteration count
- [ ] Every proposal is generalized beyond the current specific case
- [ ] Every proposal was checked against existing skills for redundancy
- [ ] No proposal embeds environment-specific assumptions (tool versions, OS, paths)
- [ ] New skill proposals include architectural extension points
- [ ] Each proposal lists specific files/sections to change, not just abstract descriptions
- [ ] Estimated context cost is provided for each proposal
- [ ] Findings are factual (cite conversation events), not speculative
