# SVG Diagram Template Reference

When generating the floorplan SVG diagram, follow this structure and style guide.

## SVG Skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1000" width="900" height="1000">
  <defs>
    <!-- Styles -->
    <style>
      text { font-family: 'Helvetica Neue', Arial, sans-serif; }
      .title { font-size: 18px; font-weight: bold; fill: #1a1a2e; }
      .subtitle { font-size: 11px; fill: #555; }
      .module-label { font-size: 12px; font-weight: bold; fill: #fff; text-anchor: middle; }
      .module-detail { font-size: 9px; fill: rgba(255,255,255,0.85); text-anchor: middle; }
      .zone-label { font-size: 10px; font-weight: bold; fill: #333; }
      .arrow-critical { stroke: #e63946; stroke-width: 2.5; fill: none; marker-end: url(#arrowhead-red); }
      .arrow-data { stroke: #457b9d; stroke-width: 1.5; fill: none; marker-end: url(#arrowhead-blue); }
      .bus-line { stroke: #6c757d; stroke-width: 1.2; fill: none; stroke-dasharray: 4,3; }
      .note { font-size: 9px; fill: #e63946; font-style: italic; }
    </style>

    <!-- Arrow Markers -->
    <marker id="arrowhead" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#444"/>
    </marker>
    <marker id="arrowhead-red" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#e63946"/>
    </marker>
    <marker id="arrowhead-blue" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#457b9d"/>
    </marker>

    <!-- Gradient Templates (customize per design) -->
    <linearGradient id="sram-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#2d6a4f" />
      <stop offset="100%" style="stop-color:#1b4332" />
    </linearGradient>
    <linearGradient id="pipeline-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#457b9d" />
      <stop offset="100%" style="stop-color:#1d3557" />
    </linearGradient>
    <linearGradient id="regfile-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#e63946" />
      <stop offset="100%" style="stop-color:#a8201a" />
    </linearGradient>
    <linearGradient id="exec-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#264653" />
      <stop offset="100%" style="stop-color:#1a323d" />
    </linearGradient>
    <linearGradient id="float-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#7b2cbf" />
      <stop offset="100%" style="stop-color:#5a189a" />
    </linearGradient>
    <linearGradient id="alu-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#f4a261" />
      <stop offset="100%" style="stop-color:#e07a30" />
    </linearGradient>
    <linearGradient id="bus-grad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#6c757d" />
      <stop offset="100%" style="stop-color:#495057" />
    </linearGradient>
    <linearGradient id="ext-grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#219ebc" />
      <stop offset="100%" style="stop-color:#126782" />
    </linearGradient>

    <!-- Shadow filter -->
    <filter id="shadow">
      <feDropShadow dx="2" dy="2" stdDeviation="3" flood-color="#00000033"/>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="900" height="1000" fill="#f8f9fa" rx="8"/>

  <!-- Title -->
  <text x="450" y="32" class="title" text-anchor="middle">DESIGN_NAME Floorplan Diagram</text>
  <text x="450" y="48" class="subtitle" text-anchor="middle">ARCH_DESCRIPTION</text>

  <!-- Die outline -->
  <rect x="50" y="65" width="800" height="870" fill="#fff" stroke="#1a1a2e" stroke-width="2.5" rx="6" filter="url(#shadow)"/>

  <!-- CONTENT GOES HERE: modules, arrows, labels -->

  <!-- Legend (always at bottom) -->
  <rect x="60" y="900" width="780" height="55" fill="#f0f0f0" rx="4" stroke="#ddd"/>
  <!-- Legend items -->

</svg>
```

## Color Assignments by Module Type

| Module Type | Gradient ID | Primary Color | Use For |
|-------------|-------------|---------------|---------|
| SRAM / Memory macros | `sram-grad` | Green (#2d6a4f) | ITCM, DTCM, caches, tag RAM |
| Pipeline stages | `pipeline-grad` | Blue (#457b9d) | Fetch, Decode, general pipeline |
| Regfile (critical) | `regfile-grad` | Red (#e63946) | Register files, scoreboard |
| Execution units | `exec-grad` | Dark teal (#264653) | LSU, MEXT, CSR |
| FP / Large compute | `float-grad` | Purple (#7b2cbf) | Float unit, DSP blocks |
| ALU / Branch | `alu-grad` | Orange (#f4a261) | ALU (use dark text on orange) |
| Bus / Interconnect | `bus-grad` | Gray (#6c757d) | Bus network, NoC |
| External / Periph | `ext-grad` | Cyan (#219ebc) | UART, GPIO, external slave |

## Arrow Types

| Arrow Type | Class | Use For |
|------------|-------|---------|
| Critical timing path | `arrow-critical` | P0 paths, red, thick (2.5px) |
| Normal data flow | `arrow-data` | Pipeline data flow, blue |
| Bus/memory connect | `bus-line` | Bus routes, gray dashed |
| Writeback | custom dashed | Exec→Regfile writeback, semi-transparent red dashed |

## Layout Grid Guidelines

```
+------------------------------------------------------------------+
|  SRAM-NW          Bus/Interconnect          SRAM-NE              |  ← Zone A: Memory
|                                                                  |
|  Fetch ──→ Decode ──→ ALU(Branch)                                |  ← Zone B: Pipeline
|                  ↓                                                |
|  ★ Regfile-INT  ★ Regfile-FP   (center!)                        |  ← Core Center
|      ↓       ↓       ↓       ↓                                   |
|  LSU    MEXT    CSR    Float(large)                              |  ← Zone C: Execute
|                                                                  |
|  Bus (LSU path)                                                  |
|  EXT Slave / Peripherals                                         |  ← Zone D: External
+------------------------------------------------------------------+
```

## Sizing Guidelines

- Module block size should be **roughly proportional** to estimated area percentage
- Minimum block: 100×60px (for ~3% modules)
- SRAM macros: 180-220px wide (they're physically large)
- Regfile: extra border stroke (2px) + star ★ marker to emphasize criticality
- Float unit: largest block if it has many DW IPs
- Leave 15-20px gaps between blocks for arrow routing

## Text in Blocks

Each module block should have:
1. **Hier path** (bold, 11px) — the exact RTL instance path (e.g., `u_core/u_alu`)
2. **Module type + key info** (9px) — e.g., `toy_alu | ALU+Branch`
3. **Area percentage** (9px) — at bottom of block
4. **Critical note** (9px, red italic) — if this module is on a P0 path

## Wire Count Annotations

Every connection line/arrow between module blocks MUST include a wire count label:

```xml
<!-- Wire count annotation example -->
<line x1="300" y1="200" x2="300" y2="300" class="arrow-data" />
<text x="310" y="250" class="wire-count">~217</text>
```

Add this CSS class to the style section:
```css
.wire-count { font-size: 9px; fill: #333; font-weight: bold; }
.wire-count-critical { font-size: 9px; fill: #e63946; font-weight: bold; }
```

Placement rules for wire count labels:
- Place near the midpoint of the connection line
- Use `wire-count-critical` class for P0 path connections
- For bidirectional connections, show total (e.g., `~217` = 173 out + 44 back)
- Prefix with `~` to indicate approximate count
- If the diagram gets cluttered, omit wire counts < 30 and focus on the top 5-8 heaviest connections
