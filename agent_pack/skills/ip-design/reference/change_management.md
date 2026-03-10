# Design Change Management

## Core Rule

**All specification documents MUST be updated together.**

The specification is a **collection** of interconnected documents, not a single file:

1. **Text**: `docs/spec.md`, `README.md`, `status.md`
2. **Graphics**: `docs/*.drawio` (source), `docs/*.png` (exported for embedding)
3. **Structure**: Module lists, filelist, deliverables

**"Specification = Text + Graphics + Structure"** — not spec.md alone.

## Change Workflow (4 Steps)

When ANY architecture changes (module structure, interface, storage, etc.):

1. **Identify scope**: Which documents reference this? (spec.md, diagram, README, status.md, deliverables)
2. **Update atomically**: All affected documents together, or none
3. **Verify consistency**: Module names in text = module names in diagram = module names in deliverables
4. **Document change**: Record in status.md what changed and which docs updated

## Failure Patterns

❌ Update spec.md but forget diagram
❌ Remove module from diagram but leave in deliverables
❌ Change module name in text but not in diagram

✅ **Correct example**: Change "dual-port RAM module" to "register array"
   - spec.md: "uses register array"
   - diagram: remove mem module box
   - module list: remove mem.v
   - deliverables: 4 files not 5
   - status.md: record change

## Change Propagation Rules

- Any spec change → re-confirm with user → update RTL, filelist, testbench, testcases, and SDC as required
- Any RTL change → update filelist, TB, testcases, and constraints if needed
- Any testbench architecture change → may need to re-run all testcases
