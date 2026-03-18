# Draw.io Diagram Export in VS Code Environment

## Basic Info

| Field | Value |
|-------|-------|
| Tool | hediet.vscode-drawio (VS Code extension, v1.9.0+) |
| OS | All (Windows, Linux, WSL) |
| Date Found | 2026-02-24 |
| Severity | Blocking (if PNG is a required deliverable) |

## Symptom

Agent creates a `.drawio` diagram file but cannot export it to PNG. Searches for `drawio` CLI, `@drawio/cli`, desktop app, etc. all fail. Agent may silently skip PNG generation or produce a degraded deliverable.

Common search attempts that fail:
```bash
which drawio                    # not found
npm list -g | grep drawio       # finds @drawio/mcp but it has NO export
find / -name "draw.io.exe"     # not found (no desktop app)
```

## Root Cause

1. **`@drawio/mcp`** (npm MCP server) only opens diagrams in browser — it has NO export/PNG capability
2. **draw.io desktop app** is often not installed (especially on servers/WSL)
3. **The actual export tool is the VS Code extension `hediet.vscode-drawio`**, which provides:
   - `hediet.vscode-drawio.export` — "Export To..." (PNG/SVG)
   - `hediet.vscode-drawio.convert` — "Convert To..." (between `.drawio` / `.drawio.png` / `.drawio.svg`)
   - Native `*.drawio.png` format — PNG image with embedded drawio XML metadata

## Solution

### Step 1: Verify extension is installed

Search installed VS Code extensions for `hediet.vscode-drawio`. In WSL environments, the extension files are on the Windows side (e.g., `/mnt/c/Users/<user>/.vscode/extensions/hediet.vscode-drawio-*/`).

### Step 2: Use VS Code command to export

**Option A — Convert to `.drawio.png` format (recommended)**:
- Use VS Code command `hediet.vscode-drawio.convert` to convert `.drawio` to `.drawio.png`
- The resulting file is both a valid PNG and an editable drawio diagram

**Option B — Export command**:
- Open the `.drawio` file in VS Code
- Execute `hediet.vscode-drawio.export` command
- Select PNG format

### Step 3: If extension is NOT installed

Do NOT silently degrade. Report to the user:
- What: PNG export is blocked because no drawio export tool is available
- Action needed: Install `hediet.vscode-drawio` extension, or manually export the `.drawio` file

## Notes

- The `@drawio/mcp` npm package is a red herring — it only opens diagrams in browser, not export
- In WSL environments, VS Code extensions are installed on the Windows side but accessible from WSL via VS Code's remote architecture
- The `.drawio.png` format is the most convenient: single file serves as both editable source and viewable image
