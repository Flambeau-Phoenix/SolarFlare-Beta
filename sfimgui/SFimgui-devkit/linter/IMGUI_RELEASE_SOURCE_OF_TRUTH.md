# SolarFlare ImGui Release Source of Truth

This document is the entry point for choosing and verifying ImGui features in
SolarFlare. It describes the exact `imgui64.hdll` installed for Farever, the
Haxe surface that can call it, and the higher-level interaction patterns already
proven by the demo. Every feature described by the cookbook is achievable in
this release, either through a direct binding or through composition.

Do not treat a Dear ImGui website, upstream C++ header, generated cimgui symbol,
or prose example as proof that a Haxe call exists. Check the layers below.

## 

The vendored header reports `1.93.0 WIP` and `IMGUI_VERSION_NUM 19294`. This is
expected: the pinned Dear ImGui commit is one fix commit after the v1.92.9 tag.
Use the commit and DLL hash as the durable identity, not the display string
alone.

Verified release coverage:

- 601 unique `imgui_*` exports in the DLL.
- 561 unique `@:hlNative("imgui", ...)` names in the active Haxe binding.
- Every Haxe native name exists in the DLL.
- 564 public Haxe declarations representing 549 unique ergonomic method names
  (overloads account for the difference).
- 85 enum types with 1,004 enum members.

Run `powershell -File tools/verify-imgui-release.ps1` from the repository root
to repeat the fingerprint, active-haxelib, and export-coverage checks.

## Authority order

When sources disagree, use this order:

1. The installed DLL hash proves which native release Farever will load.
2. `haxelib path hl-imgui`, then its `imgui/ImGui.hx`, `Enums.hx`, and
   `Structs.hx`, proves what the current build can call.
3. `docs/imgui/hl-imgui/src/imgui/` is the audited repository mirror of that
   active binding.
4. `docs/imgui/native/src/` explains implementation and ABI behavior.
5. Compiling and exercising `new_imgui_demo` proves composed interaction
   patterns.
6. `Full_Reference_New_ImGUI.MD` and the topic documents are a cookbook and
   idea catalog only. Verify every API spelling against `ImGui.hx` before use.

The generated C++ surface can be wider than the ergonomic Haxe surface. A DLL
export is not automatically a supported mod API. Conversely, a rich user-facing
feature may be composed from simpler callable primitives and still be fully
supported.

## Capability levels

Use these labels in plans and reviews:

- **Direct**: a public method exists in the active `imgui.ImGui` binding and
  its native dependency exists in the installed DLL.
- **Composed and proven**: no single native widget provides the whole behavior,
  but checked-in Haxe demo code builds and demonstrates it.
- **Native-only/internal**: the DLL exports a symbol, but the active public Haxe
  surface does not expose a supported ergonomic call.
- **Cookbook target**: the behavior is achievable, but the particular prose
  snippet is not proof of its implementation. Realize it with direct methods,
  a proven composition, custom draw-list interaction, or a deliberate binding
  extension, then lint, compile, and test it.

### Multi-select clarification

Multi-select is **composed and proven**. The working demo uses `selectable`,
retained `selected` state, `isKeyDown` for Ctrl/Shift behavior, stable IDs,
filtering, batch actions, and context menus. See
`new_imgui_demo/src/demo/DemoViews.hx`.

The upstream convenience workflow (`beginMultiSelect`, `endMultiSelect`, and
`ImGuiMultiSelectIO`) is not exposed by the active Haxe binding. Examples in the
large prose reference that call those methods directly therefore need to be
translated to the demo's proven composition (or supported by a deliberate
binding extension). This does not limit the multi-select feature itself.

## Linter role

The Farever MCP `lint_imgui_layout` linter is available and is mandatory for
changed Haxe ImGui functions or files before compilation. It checks SolarFlare
density rules, invalid vector types, C++-style enum spellings, loose repetitive
control stacks, and incorrect table sizing flags.

The linter complements this release audit. It does not inspect the installed
DLL, prove a native ABI, or turn a cookbook convenience call into a public Haxe
method. Use the complete verification chain:

1. Choose a direct or composed feature from this guide.
2. Verify exact public names in the active binding.
3. Run `lint_imgui_layout` on the complete changed function or file.
4. Compile the relevant Haxe target.
5. Exercise the interaction in Farever, including compact sizes and supported
   themes.

Submit at least a complete function so the linter can see its layout context.
For helper files containing several unrelated table-sizing strategies, lint the
complete affected functions separately; whole-file heuristic matching can
otherwise associate stretch weights with a different fixed-width table.

## Feature chooser

Start from the user interaction, not from the familiar widget. The following
options are all available in this release.

### Choosing one or many things

- Small mutually exclusive set: `radioButton` or a short row of styled
  `selectable`/navigation buttons.
- Compact single choice: `beginCombo` + `selectable`; show a summary outside
  the combo when the choice has consequences.
- Browsable single choice: `beginListBox`, `selectable`, search, and
  `ImGuiListClipper` for large collections.
- Multiple choice and batch work: the demo's composed multi-select pattern,
  including Ctrl/Shift selection, selection count, and batch actions.
- Hierarchical choice: `treeNode`, `treeNodeEx`, `collapsingHeader`, and stable
  IDs.
- Visual choice: `image`, `colorButton`, selectable cards, or an
  `invisibleButton` over custom draw-list content.

### Editing values

- Exact numeric entry: `inputInt`, `inputFloat`, `inputDouble`, and their
  multi-component variants.
- Relative adjustment: `dragInt`, `dragFloat`, vector drags, and
  `dragIntRange2`/`dragFloatRange2`.
- Bounded value with visible range: `sliderInt`, `sliderFloat`, `sliderAngle`,
  vector sliders, or `vSliderInt`/`vSliderFloat` where vertical form fits the
  visualization.
- Color: `colorEdit3/4`, `colorPicker3/4`, and `colorButton` swatches. Use flags
  to expose HSV, hue wheel, alpha bar, previews, and numeric formats where the
  workflow benefits.
- Text: `inputTextWithHint`, `inputTextMultiline`, or
  `inputTextWithCompletion`; keep buffers persistent across frames.
- Disabled/inapplicable values: `beginDisabled`/`endDisabled` plus nearby
  explanation instead of hiding the control without context.

### Organizing complex tools

- Stable categories or modes: `beginTabBar`/`beginTabItem`.
- Dense data and property comparisons: `beginTable`, row backgrounds,
  resizable/reorderable/hideable columns, frozen headers, sorting specs, and
  per-cell background color.
- Large collections: search + `ImGuiListClipper` + selectable rows/cards.
- Progressive disclosure: `collapsingHeader` or tree nodes.
- Commands: menu bars, nested `beginMenu`, `menuItem`, context popups, and
  modal popups.
- Independent work areas: `dockSpace` or `dockSpaceOverViewport`, then normal
  tool windows that can dock, tab, split, or float.
- Side-by-side editors/previews: child regions or tables with stretch sizing;
  use SolarFlare's `UiScope` and `UiLayout` wrappers where applicable.

### Feedback, inspection, and discoverability

- State or progress: `progressBar`, colored table cells, badges drawn through
  `ImDrawList`, and persistent summary text.
- Trends/distributions: `plotLines` and `plotHistogram`.
- Explanations: `setItemTooltip`, `beginItemTooltip`, rich `beginTooltip`
  content, and `textDisabled` hints.
- Item actions: `beginPopupContextItem` or the demo's explicit right-click +
  `openPopup` pattern.
- Confirmations and blocking workflows: `beginPopupModal`.
- Non-blocking events: the demo's composed toast queue.
- Power-user actions: `shortcut`, `setNextItemShortcut`,
  `isKeyChordPressed`, or explicit key/modifier checks.
- Diagnostics: `showMetricsWindow`, `showDebugLogWindow`,
  `showIDStackToolWindow`, and `debugStartItemPicker`.

### Custom presentation

The binding exposes a large `ImDrawList` surface: lines, rectangles, rounded
fills, circles, ellipses, triangles, quads, n-gons, polylines, convex/concave
fills, cubic/quadratic Beziers, path building, gradients, clipping, and channel
splitting. Combine these with `invisibleButton` and item-state queries for
purpose-built interactive widgets. Prefer existing SolarFlare helpers such as
`EnhancedBorders`, `WindowEffects`, `ProgressHelpers`, and `DrawListExt` before
adding another parallel primitive library.

## Proven rich examples

`new_imgui_demo` compiles against the active `hl-imgui` binding and demonstrates:

- Docking workspace and layout presets.
- Typed drag/drop sources and targets.
- Sortable, filterable tables with status styling and progress meters.
- Application-level multi-select with Ctrl/Shift behavior and batch actions.
- Line plots and histograms.
- Hinted and multiline inputs plus keyboard shortcuts.
- RGB/RGBA editing, hue wheel, alpha bar, and swatch palettes.
- Delayed/rich tooltips, nested context menus, modals, and toast notifications.
- Animated vector canvas content using draw-list primitives.

Use these implementations as behavior patterns, then adapt them to SolarFlare's
state ownership, theme, scope, density, Undo, profile, and preview rules. Do not
copy demo layout or styling blindly.

## Agent selection rule

Before implementing a non-trivial UI surface:

1. State the user task: choose, edit, organize, inspect, compare, preview, or
   act in bulk.
2. Consult the feature chooser and name the direct or composed capability that
   best fits it.
3. Check the exact method and enum spellings in the active binding.
4. Prefer an existing SolarFlare helper or proven demo composition when one
   already owns the behavior.
5. Use basic checkbox/slider/combo stacks only when they are genuinely the
   clearest interaction, not as a default vocabulary.
6. Verify scope balance, persistent refs/buffers, stable IDs, compact-width
   behavior, themes, and compilation.

Feature richness is not widget count. A searchable clipped table with a useful
preview and batch actions is richer than a panel containing many unrelated
controls.

## Known traps in the older reference

- C++ names and Haxe names differ. Use lower camel-case public dispatchers such
  as `beginTable`, not guessed C++ spellings.
- An enum existing does not prove the associated workflow methods are bound.
- Some cookbook snippets use upstream convenience calls that are not public
  Haxe methods in this release. Translate the behavior to verified direct
  methods or a proven composition; the feature remains achievable.
- Persistent edited values need `BoolRef`, `IntRef`, `FloatRef`, `DoubleRef`,
  or a persistent byte buffer. Plain temporary values revert on later frames.
- `ImVec2` lives at `imgui.Structs.ImVec2`; do not introduce `imgui.Vec2` in new
  shared APIs.
- Every `Begin`/`End` and `Push`/`Pop` must balance on every control-flow path.
