# SolarFlare ImGui DevKit (SFimgui-devkit)

A specialized developer kit and AI-agent tooling suite for building, linting, and maintaining dense, robust [Dear ImGui](https://github.com/ocornut/imgui) interfaces for Haxe / HashLink (`hl-imgui`) applications and mods.

---

## Overview

The **SolarFlare ImGui DevKit** provides everything needed to build production-grade, high-density configuration and tool UIs. It combines:
1. **Design & Layout Playbook**: Standards and patterns for clean, compact, and resilient UI layouts.
2. **Layout Linter & Boilerplate Generator**: Automated linting for visual density, type correctness, and scope hygiene, plus CastleDB-backed layout code generation.
3. **Deterministic CastleDB Query CLI (`cdbTool`)**: A stdlib-only agent tool for extracting exact data records from CastleDB (`data.cdb`) without context bloat.
4. **Comprehensive hl-imgui Reference Library**: In-depth API guides and cookbooks for tables, multi-selection, custom vector drawing, notifications, tooltips, and live previews.

---

## Directory Structure

```text
SFimgui-devkit/
├── README.MD                           # This documentation
├── linter/                             # UI linting, design standards, and reference library
│   ├── imgui_linter.py                 # Layout linter and Haxe boilerplate generator
│   ├── IMGUI_DESIGN_PLAYBOOK.MD        # The UI layout design standard
│   ├── IMGUI_RELEASE_SOURCE_OF_TRUTH.md # Native DLL & Haxe binding ABI authority
│   └── *.md                            # Topic cookbooks (Tables, Drag & Drop, Styling, etc.)
└── cdbTool/                            # CastleDB data query & agent integration
    ├── cdb_agent.py                    # Deterministic CastleDB CLI & library (Python stdlib)
    ├── cdb-agent.bat                   # Portable Windows runner script
    ├── AGENT_CONTRACT.md               # Tool contract for autonomous coding agents
    └── README.md                       # In-depth CLI commands and usage examples
```

---

## Core Components

### 1. SolarFlare ImGui Linter & Layout Scaffolding (`linter/`)

`imgui_linter.py` enforces the rules established in `IMGUI_DESIGN_PLAYBOOK.MD` and can be used as a CLI, a Python module, or registered into an MCP server:

- **Density & Layout Validation**: Enforces standard 35/65 property grid column ratios, compact padding (`CellPadding: 4x2`, `ItemSpacing: 4x2`), and disallows loose vertical widget chains.
- **Scope Safety**: Detects mismatched `Push`/`Pop` blocks, unclosed tables/child windows, and improper Begin/End scoping across control flows.
- **Type Safety**: Verifies `Structs.ImVec2` import correctness and flags forbidden standalone `imgui.Vec2` usage.
- **Scaffolding**: Generates playbook-compliant Haxe layout code directly from CastleDB entity schemas (grids or inline layouts).

#### Running the Linter
```powershell
# Check a Haxe file against the design playbook
python linter/imgui_linter.py lint path/to/MyToolWindow.hx

# Generate a dense property grid for a CastleDB entity
python linter/imgui_linter.py scaffold --sheet skill --id FireWall --layout grid
```

---

### 2. The Design Playbook & Source of Truth

- **`IMGUI_DESIGN_PLAYBOOK.MD`**: Defines the visual paradigm for SolarFlare configuration windows. Mandates the use of `UiLayout.propertyGrid`, `UiLayout.inlinePair`, and RAII-style scope helpers (`UiScope.child`, `UiScope.table`) so functions that open scopes also guarantee their closure.
- **`IMGUI_RELEASE_SOURCE_OF_TRUTH.md`**: Authoritative mapping of the installed `imgui64.hdll` (Dear ImGui 1.92.9+ commit) against the active `hl-imgui` Haxe surface. Establishes clear distinction between **Direct** bindings, **Composed** patterns, and **Native-only** symbols.

---

### 3. CastleDB Agent CLI (`cdbTool/`)

`cdb_agent.py` is a zero-dependency (Python 3.10+ stdlib only) utility engineered for developers and autonomous coding agents. It queries CastleDB (`data.cdb`) files with deterministic, machine-readable JSON outputs.

- **Fast & Lightweight**: Replaces dumping 5+ MB database files into agent context with laser-focused queries.
- **Deterministic**: Provides cryptographic SHA-256 fingerprinting and version-stamping to guarantee reproducible extractions.
- **Agent Contract**: Adheres to `AGENT_CONTRACT.md` with stable exit codes and JSON/JSONL streaming.

#### Common Commands
```powershell
# Inspect database summary and statistics
python cdbTool/cdb_agent.py --cdb path/to/data.cdb info --pretty

# Retrieve a specific row with projected fields
python cdbTool/cdb_agent.py --cdb path/to/data.cdb get unit DemonSuperElite_Fairy `
  --field id --field texts.name --field skills --pretty

# Search entities by regex
python cdbTool/cdb_agent.py --cdb path/to/data.cdb search "^SuperElite.*Fire" `
  --sheet skill --field id --regex --pretty
```

---

### 4. Reference Library & Topic Cookbooks

The `linter/` directory houses complete guides for advanced ImGui features in HashLink:
- **Tables & Multi-Select**: `MultiSelectnTablesNEWimgui.md`
- **Drag & Drop**: `Drag & Drop newimgui.md`
- **Styling & Color Palettes**: `stylingandcolorpicking_NEWimgui.md`
- **Vector Drawing & Canvas**: `vectordrawingimgui.md`
- **Notifications & Toasts**: `ToastNotifs_NewIMGUI.md`
- **Tooltips & Context Menus**: `Tooltips&ContextWindows_NEWimgui.md`
- **Widgets, Buttons & Inputs**: `newimguibuttons.md`, `newimguitextfields.md`, `widgetsandoptimization_newimgui.md`
- **Plots, Fonts & Shortcuts**: `PlotsFontsShortcutsNEWimgui.md`
- **Live Previewing & Windowing**: `LivePreviewNEwimgui.md`, `windowsandtitlebars.md`

---

## Requirements

- **Python**: 3.10 or newer (pure stdlib for `cdbTool`; `pydantic` optional for MCP server integration in `imgui_linter.py`).
- **Haxe / HashLink**: Haxe 4.x with `hl-imgui` native library installed.
- **Game Database**: A valid CastleDB `data.cdb` file (path can be provided via `--cdb` or the `FAREVER_CDB_PATH` environment variable).

---

## License & Distribution Notice

Before distributing or publishing this devkit:
- Ensure any distributed `data.cdb` database files contain only test/sample records or are excluded from public repositories.
- Verify environment variables (such as `FAREVER_CDB_PATH`) rather than relying on machine-specific local filepaths.
