# Skill Index

> **Auto-generated** by `skill_index.sh` — do not edit manually.
> Last updated: 2026-02-26 11:04
>
> This file lists all available skills. When a user's request matches a skill's
> description, load the full skill content from the path shown and follow its
> instructions precisely.

**20 skill(s) available.**

---

## Quick Reference

| Skill | Description |
|-------|-------------|
| `algorithmic-art` | Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users r… |
| `brand-guidelines` | Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic'… |
| `canvas-design` | Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user … |
| `doc-coauthoring` | Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, pr… |
| `docx` | "Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files). Triggers incl… |
| `eda-toolchain-debug` | EDA toolchain configuration and debugging knowledge base. Records configuration, compilation, linking, and version-compa… |
| `frontend-design` | Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to … |
| `internal-comms` | A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use… |
| `ip-design` | Guide for RTL/IP design — new designs from scratch, existing-RTL documentation, or existing-doc implementation. Covers s… |
| `mcp-builder` | Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services… |
| `pdf` | Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables fr… |
| `pptx` | "Use this skill any time a .pptx file is involved in any way — as input, output, or both. This includes: creating slide … |
| `skill-creator` | Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a sk… |
| `skill-improvement-suggestor` | Retrospective analysis of skill effectiveness after completing a task. Use when user requests skill improvement analysis… |
| `slack-gif-creator` | Knowledge and utilities for creating animated GIFs optimized for Slack. Provides constraints, validation tools, and anim… |
| `theme-factory` | Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. Th… |
| `wave-reader` | Read and analyze chip simulation waveform files (VCD/FST/FSDB/GHW) using the wave_reader CLI tool. Use this skill whenev… |
| `webapp-testing` | Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functional… |
| `web-artifacts-builder` | Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (… |
| `xlsx` | "Use this skill any time a spreadsheet file is the primary input or output. This means any task where the user wants to:… |

---

## Full Skill Descriptions

### `algorithmic-art`

**When to use:** Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. Create original algorithmic art rather than copying existing artists' work to avoid copyright violations.

**Full instructions:** [`../skills/algorithmic-art/SKILL.md`](../skills/algorithmic-art/SKILL.md)

---
### `brand-guidelines`

**When to use:** Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand colors or style guidelines, visual formatting, or company design standards apply.

**Full instructions:** [`../skills/brand-guidelines/SKILL.md`](../skills/brand-guidelines/SKILL.md)

---
### `canvas-design`

**When to use:** Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user asks to create a poster, piece of art, design, or other static piece. Create original visual designs, never copying existing artists' work to avoid copyright violations.

**Full instructions:** [`../skills/canvas-design/SKILL.md`](../skills/canvas-design/SKILL.md)

---
### `doc-coauthoring`

**When to use:** Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.

**Full instructions:** [`../skills/doc-coauthoring/SKILL.md`](../skills/doc-coauthoring/SKILL.md)

---
### `docx`

**When to use:** "Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files). Triggers include: any mention of 'Word doc', 'word document', '.docx', or requests to produce professional documents with formatting like tables of contents, headings, page numbers, or letterheads. Also use when extracting or reorganizing content from .docx files, inserting or replacing images in documents, performing find-and-replace in Word files, working with tracked changes or comments, or converting content into a polished Word document. If the user asks for a 'report', 'memo', 'letter', 'template', or similar deliverable as a Word or .docx file, use this skill. Do NOT use for PDFs, spreadsheets, Google Docs, or general coding tasks unrelated to document generation."

**Full instructions:** [`../skills/docx/SKILL.md`](../skills/docx/SKILL.md)

---
### `eda-toolchain-debug`

**When to use:** EDA toolchain configuration and debugging knowledge base. Records configuration, compilation, linking, and version-compatibility issues encountered with VCS, Xrun, Design Compiler, and other EDA tools at the IT infrastructure level (not IC design knowledge). This skill serves as a continuously growing case library — new toolchain issues should always be added here.

**Full instructions:** [`../skills/eda-toolchain-debug/SKILL.md`](../skills/eda-toolchain-debug/SKILL.md)

---
### `frontend-design`

**When to use:** Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.

**Full instructions:** [`../skills/frontend-design/SKILL.md`](../skills/frontend-design/SKILL.md)

---
### `internal-comms`

**When to use:** A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever asked to write some sort of internal communications (status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, project updates, etc.).

**Full instructions:** [`../skills/internal-comms/SKILL.md`](../skills/internal-comms/SKILL.md)

---
### `ip-design`

**When to use:** Guide for RTL/IP design — new designs from scratch, existing-RTL documentation, or existing-doc implementation. Covers spec-first workflow, user confirmation gates, project structure, RTL/filelist/testbench/testcase/SDC synchronization. Use when user asks to design new IP, write docs for existing RTL, implement RTL from existing docs, add testbenches, or any combination of RTL design deliverables.

**Full instructions:** [`../skills/ip-design/SKILL.md`](../skills/ip-design/SKILL.md)

---
### `mcp-builder`

**When to use:** Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).

**Full instructions:** [`../skills/mcp-builder/SKILL.md`](../skills/mcp-builder/SKILL.md)

---
### `pdf`

**When to use:** Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill.

**Full instructions:** [`../skills/pdf/SKILL.md`](../skills/pdf/SKILL.md)

---
### `pptx`

**When to use:** "Use this skill any time a .pptx file is involved in any way — as input, output, or both. This includes: creating slide decks, pitch decks, or presentations; reading, parsing, or extracting text from any .pptx file (even if the extracted content will be used elsewhere, like in an email or summary); editing, modifying, or updating existing presentations; combining or splitting slide files; working with templates, layouts, speaker notes, or comments. Trigger whenever the user mentions \"deck,\" \"slides,\" \"presentation,\" or references a .pptx filename, regardless of what they plan to do with the content afterward. If a .pptx file needs to be opened, created, or touched, use this skill."

**Full instructions:** [`../skills/pptx/SKILL.md`](../skills/pptx/SKILL.md)

---
### `skill-creator`

**When to use:** Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, update or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.

**Full instructions:** [`../skills/skill-creator/SKILL.md`](../skills/skill-creator/SKILL.md)

---
### `skill-improvement-suggestor`

**When to use:** Retrospective analysis of skill effectiveness after completing a task. Use when user requests skill improvement analysis (e.g., "做skill改善分析", "skill improvement analysis", "analyze skill gaps"). Analyzes the conversation to identify where goals were missed or required excessive iteration, then produces generalized, actionable improvement proposals saved to a structured report.

**Full instructions:** [`../skills/skill-improvement-suggestor/SKILL.md`](../skills/skill-improvement-suggestor/SKILL.md)

---
### `slack-gif-creator`

**When to use:** Knowledge and utilities for creating animated GIFs optimized for Slack. Provides constraints, validation tools, and animation concepts. Use when users request animated GIFs for Slack like "make me a GIF of X doing Y for Slack."

**Full instructions:** [`../skills/slack-gif-creator/SKILL.md`](../skills/slack-gif-creator/SKILL.md)

---
### `theme-factory`

**When to use:** Toolkit for styling artifacts with a theme. These artifacts can be slides, docs, reportings, HTML landing pages, etc. There are 10 pre-set themes with colors/fonts that you can apply to any artifact that has been creating, or can generate a new theme on-the-fly.

**Full instructions:** [`../skills/theme-factory/SKILL.md`](../skills/theme-factory/SKILL.md)

---
### `wave-reader`

**When to use:** Read and analyze chip simulation waveform files (VCD/FST/FSDB/GHW) using the wave_reader CLI tool. Use this skill whenever the user mentions waveform files, signal values, simulation debugging, VCD/FST/FSDB/GHW files, timing diagrams, clock analysis, chip verification, or wants to inspect simulation results. Also trigger when you see .vcd, .fst, .fsdb, or .ghw file extensions in the workspace, when the user mentions signal names like clk/reset/valid/ready/data, or when debugging chip-level failures involving timing or signal transitions — even if they don't explicitly say "wave_reader".

**Full instructions:** [`../skills/wave-reader/SKILL.md`](../skills/wave-reader/SKILL.md)

---
### `webapp-testing`

**When to use:** Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.

**Full instructions:** [`../skills/webapp-testing/SKILL.md`](../skills/webapp-testing/SKILL.md)

---
### `web-artifacts-builder`

**When to use:** Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.

**Full instructions:** [`../skills/web-artifacts-builder/SKILL.md`](../skills/web-artifacts-builder/SKILL.md)

---
### `xlsx`

**When to use:** "Use this skill any time a spreadsheet file is the primary input or output. This means any task where the user wants to: open, read, edit, or fix an existing .xlsx, .xlsm, .csv, or .tsv file (e.g., adding columns, computing formulas, formatting, charting, cleaning messy data); create a new spreadsheet from scratch or from other data sources; or convert between tabular file formats. Trigger especially when the user references a spreadsheet file by name or path — even casually (like \"the xlsx in my downloads\") — and wants something done to it or produced from it. Also trigger for cleaning or restructuring messy tabular data files (malformed rows, misplaced headers, junk data) into proper spreadsheets. The deliverable must be a spreadsheet file. Do NOT trigger when the primary deliverable is a Word document, HTML report, standalone Python script, database pipeline, or Google Sheets API integration, even if tabular data is involved."

**Full instructions:** [`../skills/xlsx/SKILL.md`](../skills/xlsx/SKILL.md)

---
