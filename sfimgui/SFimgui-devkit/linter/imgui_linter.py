"""SolarFlare ImGui layout linter and CDB-driven dense layout boilerplater.

Make sure to replace "~/cdbTool" and <data_cdb_file> with your actual source material
 
Injects playbook validation (type / enum / density / table sizing) and
<data_cdb_file>-backed Haxe layout scaffolding into the Farever FastMCP server via
``register_imgui_tools(mcp)``.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Optional native CDB primitive (same path wiring as farever_api_skill.py)
# ---------------------------------------------------------------------------

_CDB_TOOL_DIR = Path("~/cdbTool")
_DEFAULT_CDB_PATH = _CDB_TOOL_DIR / "<data_cdb_file>"

if _CDB_TOOL_DIR.is_dir() and str(_CDB_TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(_CDB_TOOL_DIR))

try:
    import cdb_agent  # type: ignore
except ImportError:  # pragma: no cover - runtime environment without .cdbtool
    cdb_agent = None  # type: ignore


# ---------------------------------------------------------------------------
# Result models
# ---------------------------------------------------------------------------


class ImGuiLintResult(BaseModel):
    is_valid: bool = Field(
        ...,
        description="True if code complies with the IMGUI_DESIGN_PLAYBOOK standards.",
    )
    errors: List[str] = Field(
        ...,
        description="List of visual density or binding type violations found.",
    )
    suggestions: List[str] = Field(
        ...,
        description="Actionable code refactoring advice based on the playbook.",
    )


class CdbDenseLayoutResult(BaseModel):
    skill_id: str = Field(..., description="Resolved entity / skill id.")
    display_name: str = Field(..., description="Title-cased display label.")
    sheet: Optional[str] = Field(
        None, description="CastleDB sheet the entity was resolved from."
    )
    layout_type: str = Field(..., description="'grid' or 'inline'.")
    haxe_code: str = Field(
        ...,
        description="Playbook-compliant Haxe layout snippet ready to paste.",
    )
    notes: List[str] = Field(
        default_factory=list,
        description="Resolver notes (fallbacks, missing rows, etc.).",
    )


# ---------------------------------------------------------------------------
# Regex intellect — tuned to avoid false positives on valid Structs.ImVec2
# ---------------------------------------------------------------------------

# Explicit concrete import that authorizes bare ImVec2 annotations.
_CONCRETE_IMVEC2_IMPORT = re.compile(
    r"(?m)^\s*import\s+imgui\.Structs\.ImVec2\s*;"
)

# Forbidden standalone Vec2 module path (must NOT match imgui.Structs.ImVec2).
_BAD_VEC2_PATH = re.compile(r"(?<![\w.])imgui\.Vec2(?!\w)")

# Bare ImVec2 identifier — `imgui.Structs.ImVec2` is excluded by (?<![\w.]).
_RAW_IMVEC2 = re.compile(r"(?<![\w.])ImVec2\b")

# C++ macro-style style vars.
_CPP_STYLE_VAR = re.compile(r"\bImGuiStyleVar_([A-Za-z0-9_]+)\b")

_KNOWN_STYLE_VAR_MAP = {
    "CellPadding": "ImGuiStyleVar.CellPadding",
    "ItemSpacing": "ImGuiStyleVar.ItemSpacing",
}

_BUILDER_SLIDER = re.compile(r"\bBuilderSlider\.draw\b")
_CHECKBOX = re.compile(r"\bImGui\.checkbox\b")

_PROPERTY_GRID = re.compile(r"\bUiLayout\.propertyGrid\b")
_INLINE_PAIR = re.compile(r"\bUiLayout\.inlinePair\b")
_INLINE_SPLIT = re.compile(r"\bUiLayout\.inlineSplit\b")

_SIZING_FIXED_FIT = re.compile(r"\bSizingFixedFit\b")
_PERCENT_WEIGHT = re.compile(
    r"(?<![\w.])(?:0\.35|0\.65|LABEL_WEIGHT|CONTROL_WEIGHT)(?![\w.])"
)
_DENSE_STYLE_PUSH = re.compile(
    r"\bImGui\.pushStyleVar\s*\(\s*ImGuiStyleVar\.(?:CellPadding|ItemSpacing)\b"
)


def _uniq(items: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


# ---------------------------------------------------------------------------
# Check A–D
# ---------------------------------------------------------------------------


def _check_type_guard(code: str, errors: List[str], suggestions: List[str]) -> None:
    """Check A — reject imgui.Vec2 and unimported raw ImVec2."""
    has_concrete_import = _CONCRETE_IMVEC2_IMPORT.search(code) is not None
    bad_path = _BAD_VEC2_PATH.search(code) is not None
    raw_unimported = (not has_concrete_import) and (
        _RAW_IMVEC2.search(code) is not None
    )

    if bad_path or raw_unimported:
        errors.append(
            "CRITICAL TYPE MISMATCH: Standalone 'imgui.Vec2' or raw "
            "'ImVec2' without its concrete import detected."
        )
        suggestions.append(
            "Use the concrete binding type: 'import imgui.Structs.ImVec2;' "
            "and allocate with ImGui.vec2(...)."
        )


def _check_enum_protection(
    code: str, errors: List[str], suggestions: List[str]
) -> None:
    """Check B — flag C++ ImGuiStyleVar_* macro leaks."""
    hits = _CPP_STYLE_VAR.findall(code)
    if not hits:
        return

    unique = sorted(set(hits))
    mapped = [
        _KNOWN_STYLE_VAR_MAP.get(name, f"ImGuiStyleVar.{name}") for name in unique
    ]

    errors.append(
        "NATIVE NAMING VIOLATION: Direct C++ style parameter names detected "
        f"({', '.join('ImGuiStyleVar_' + h for h in unique)})."
    )
    suggestions.append(
        "Map to verified Haxe enums: "
        + " / ".join(mapped)
        + ". Prefer ImGuiStyleVar.CellPadding and ImGuiStyleVar.ItemSpacing."
    )


def _check_density_audit(
    code: str, errors: List[str], suggestions: List[str]
) -> None:
    """Check C — loose vertical stacks of sliders/checkboxes.

    Safe when enclosed in UiLayout.propertyGrid or horizontal inline helpers
    (inlinePair / inlineSplit).
    """
    unstructured = _without_layout_helpers(code)
    slider_count = len(_BUILDER_SLIDER.findall(unstructured))
    checkbox_count = len(_CHECKBOX.findall(unstructured))

    if slider_count > 1 or checkbox_count > 2:
        errors.append(
            "SPATIAL DENSITY VIOLATION: Found stacked loose controls "
            f"({slider_count} sliders, {checkbox_count} checkboxes)."
        )
        suggestions.append(
            "Wrap sequential configuration metrics in a "
            "'UiLayout.propertyGrid' closure and use propertyRow / "
            "inlinePair / inlineSplit helpers where appropriate."
        )


def _without_layout_helpers(code: str) -> str:
    """Blank helper closures without letting one grid hide an entire file.

    The original linter treated a single ``propertyGrid`` occurrence as proof
    that every slider and checkbox in the submitted source was structured. It
    therefore missed loose control stacks before or after an otherwise-valid
    grid. This small brace matcher intentionally only recognizes the Haxe
    callback form used by the design playbook.
    """
    chars = list(code)
    for helper in (_PROPERTY_GRID, _INLINE_PAIR, _INLINE_SPLIT):
        for match in helper.finditer(code):
            open_brace = code.find("{", match.end())
            if open_brace < 0:
                continue
            depth = 0
            for index in range(open_brace, len(code)):
                if code[index] == "{":
                    depth += 1
                elif code[index] == "}":
                    depth -= 1
                    if depth == 0:
                        for masked in range(match.start(), index + 1):
                            chars[masked] = " "
                        break
    return "".join(chars)


def _check_grid_style_ownership(code: str, errors: List[str], suggestions: List[str]) -> None:
    """The shared grid owns its CellPadding and ItemSpacing styles."""
    if _DENSE_STYLE_PUSH.search(code) is None:
        return
    errors.append(
        "GRID STYLE OWNERSHIP VIOLATION: CellPadding or ItemSpacing is pushed directly."
    )
    suggestions.append(
        "Use UiLayout.propertyGrid for dense property groups; it owns and restores "
        "CellPadding and ItemSpacing on every control-flow path."
    )


def _check_table_layout(
    code: str, errors: List[str], suggestions: List[str]
) -> None:
    """Check D — percentage weights must not use SizingFixedFit."""
    if _SIZING_FIXED_FIT.search(code) is None:
        return
    if _PERCENT_WEIGHT.search(code) is None:
        return

    errors.append(
        "LAYOUT CLIPPING RISK: Percentage weights are being fed into a "
        "SizingFixedFit table."
    )
    suggestions.append(
        "Convert to 'ImGuiTableFlags.SizingStretchProp' so weights "
        "(0.35 / 0.65 / LABEL_WEIGHT) are treated as proportions rather "
        "than pixel widths."
    )


def run_imgui_layout_lint(code: str) -> ImGuiLintResult:
    """Validate Haxe ImGui code against the workspace layout playbook."""
    if code is None:
        code = ""

    errors: List[str] = []
    suggestions: List[str] = []

    _check_type_guard(code, errors, suggestions)
    _check_enum_protection(code, errors, suggestions)
    _check_density_audit(code, errors, suggestions)
    _check_table_layout(code, errors, suggestions)
    _check_grid_style_ownership(code, errors, suggestions)

    errors = _uniq(errors)
    suggestions = _uniq(suggestions)

    return ImGuiLintResult(
        is_valid=not errors,
        errors=errors,
        suggestions=suggestions,
    )


# ---------------------------------------------------------------------------
# CDB layout boilerplater
# ---------------------------------------------------------------------------


def _resolve_cdb_path(explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    env = os.environ.get("FAREVER_CDB_PATH")
    if env:
        return Path(env).resolve()
    return _DEFAULT_CDB_PATH.resolve()


_CDB_CACHE: Dict[str, Any] = {}


def _get_cdb(cdb_path: Optional[str] = None) -> Any:
    if cdb_agent is None:
        raise RuntimeError(
            "cdb_agent module could not be imported; ensure "
            f"{_CDB_TOOL_DIR} is present on the host."
        )
    path = _resolve_cdb_path(cdb_path)
    key = str(path)
    if key not in _CDB_CACHE:
        if not path.is_file():
            raise FileNotFoundError(f"<data_cdb_file> not found at {path}")
        _CDB_CACHE[key] = cdb_agent.CDB(path)
    return _CDB_CACHE[key]


def _title_case_label(raw: str) -> str:
    """Cleanses id/name tokens into a readable Title Case label."""
    if not raw:
        return "Entity"
    cleaned = re.sub(r"[_\-.]+", " ", str(raw))
    cleaned = re.sub(r"(?<!^)(?=[A-Z])", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    if not cleaned:
        return "Entity"
    return " ".join(part[:1].upper() + part[1:] for part in cleaned.split(" "))


def _safe_id_token(raw: str) -> str:
    token = re.sub(r"[^A-Za-z0-9]+", "_", str(raw)).strip("_").lower()
    return token or "entity"


def _pascal(token: str) -> str:
    return "".join(
        part[:1].upper() + part[1:] for part in token.split("_") if part
    )


def _lookup_entity(
    db: Any, skill_id: str
) -> Tuple[Optional[str], Optional[dict], List[str]]:
    """Resolve a skill/entity row. Prefers ``skill`` sheet, then free search."""
    notes: List[str] = []
    sid = (skill_id or "").strip()
    if not sid:
        notes.append("Empty skill_id; using generic Entity template.")
        return None, None, notes

    preferred_sheets = (
        "skill",
        "unit",
        "item",
        "status",
        "fxset",
        "element",
    )

    for sheet_name in preferred_sheets:
        if sheet_name not in db.sheets:
            continue
        found = db.find_row(sheet_name, sid)
        if found is not None:
            _idx, row = found
            notes.append(f"Resolved via sheet '{sheet_name}' exact id.")
            return sheet_name, row, notes

    for sheet in db.populated_sheets():
        for row in sheet.rows:
            rid = cdb_agent.row_id(row)
            if rid == sid:
                notes.append(
                    f"Resolved via sheet '{sheet.name}' exact id scan."
                )
                return sheet.name, row, notes
            matched, _path, _preview = cdb_agent.free_search_match(
                row, sid, None, False, False
            )
            if matched and rid and sid.lower() in str(rid).lower():
                notes.append(
                    f"Resolved via free search on sheet '{sheet.name}' ({rid})."
                )
                return sheet.name, row, notes

    notes.append(
        f"No CDB row found for '{sid}'; generating layout from id token alone."
    )
    return None, None, notes


def _generate_grid_layout(label: str, token: str) -> str:
    fn = f"draw{_pascal(token)}Properties"
    return "\n".join(
        [
            "import imgui.ImGui;",
            "import imgui.Structs.ImVec2;",
            "import imgui.ref.BoolRef;",
            "import imgui.ref.FloatRef;",
            "import solarflare.ui.SettingsStore;",
            "import solarflare.ui.UiLayout;",
            "",
            f"/** Auto-generated dense property layout for {label} ({token}). */",
            f"function {fn}(",
            "\tvisible:BoolRef,",
            "\tlocked:BoolRef,",
            "\twidth:FloatRef,",
            "\theight:FloatRef",
            "):Void {",
            f'\tUiLayout.propertyGrid("##{token}_properties", function() {{',
            '\t\tUiLayout.propertyRow("Visible", function() {',
            f'\t\t\tif (ImGui.checkbox("##{token}_visible", visible))',
            "\t\t\t\tSettingsStore.markDirty();",
            "\t\t});",
            "",
            '\t\tUiLayout.propertyRow("Window", function() {',
            "\t\t\tUiLayout.inlinePair(",
            f'\t\t\t\t"##{token}_window_toggles",',
            "\t\t\t\tfunction(_:Single) {",
            f'\t\t\t\t\tif (ImGui.checkbox("Lock##{token}_lock", locked))',
            "\t\t\t\t\t\tSettingsStore.markDirty();",
            "\t\t\t\t},",
            "\t\t\t\tfunction(_:Single) {",
            f'\t\t\t\t\tImGui.textDisabled("{label}");',
            "\t\t\t\t}",
            "\t\t\t);",
            "\t\t});",
            "",
            '\t\tUiLayout.propertyRow("Size", function() {',
            "\t\t\tUiLayout.inlinePair(",
            f'\t\t\t\t"##{token}_size",',
            "\t\t\t\tfunction(_:Single) {",
            f'\t\t\t\t\tif (ImGui.sliderFloat("Width##{token}_width", width, 80, 1200, "%.0f px"))',
            "\t\t\t\t\t\tSettingsStore.markDirty();",
            "\t\t\t\t},",
            "\t\t\t\tfunction(_:Single) {",
            f'\t\t\t\t\tif (ImGui.sliderFloat("Height##{token}_height", height, 28, 720, "%.0f px"))',
            "\t\t\t\t\t\tSettingsStore.markDirty();",
            "\t\t\t\t}",
            "\t\t\t);",
            "\t\t});",
            "\t});",
            "}",
            "",
        ]
    )


def _generate_inline_layout(label: str, token: str) -> str:
    fn = f"draw{_pascal(token)}PresetRow"
    return "\n".join(
        [
            "import imgui.ImGui;",
            "import imgui.Structs.ImVec2;",
            "import solarflare.ui.SettingsStore;",
            "import solarflare.ui.UiLayout;",
            "",
            f"/** Auto-generated inlineSplit matrix for {label} ({token}). */",
            f"function {fn}():Void {{",
            '\tvar presets = ["Compact", "Standard", "Wide", "Tall"];',
            "\tUiLayout.inlineSplit(",
            f'\t\t"##{token}_presets",',
            "\t\tpresets.length,",
            "\t\tfunction(index:Int, width:Single) {",
            "\t\t\tvar btnLabel = presets[index];",
            "\t\t\tif (ImGui.button(",
            f'\t\t\t\tbtnLabel + "##{token}_preset_" + index,',
            "\t\t\t\tImGui.vec2(width, 28)",
            "\t\t\t)) {",
            "\t\t\t\tSettingsStore.markDirty();",
            "\t\t\t\t// applyPreset(btnLabel);",
            "\t\t\t}",
            "\t\t},",
            "\t\t4",
            "\t);",
            "}",
            "",
        ]
    )


def build_cdb_dense_layout(
    skill_id: str,
    layout_type: str = "grid",
    cdb_path: Optional[str] = None,
) -> CdbDenseLayoutResult:
    """Build a playbook-compliant Haxe layout snippet from a CDB entity id."""
    layout = (layout_type or "grid").strip().lower()
    if layout not in ("grid", "inline"):
        layout = "grid"

    notes: List[str] = []
    sheet: Optional[str] = None
    row: Optional[dict] = None
    display = _title_case_label(skill_id)
    token = _safe_id_token(skill_id)

    try:
        db = _get_cdb(cdb_path)
        sheet, row, lookup_notes = _lookup_entity(db, skill_id)
        notes.extend(lookup_notes)
        if row is not None:
            name = cdb_agent.display_name(row) or cdb_agent.row_id(row) or skill_id
            display = _title_case_label(str(name))
            rid = cdb_agent.row_id(row) or skill_id
            token = _safe_id_token(str(rid))
    except Exception as exc:  # noqa: BLE001 — still emit a usable template
        notes.append(f"CDB lookup unavailable: {exc}")

    if layout == "inline":
        haxe = _generate_inline_layout(display, token)
    else:
        haxe = _generate_grid_layout(display, token)

    return CdbDenseLayoutResult(
        skill_id=skill_id,
        display_name=display,
        sheet=sheet,
        layout_type=layout,
        haxe_code=haxe,
        notes=notes,
    )


# Public alias matching the tool name for direct Python / CLI imports.
generate_cdb_dense_layout = build_cdb_dense_layout


# ---------------------------------------------------------------------------
# FastMCP factory injection
# ---------------------------------------------------------------------------


def register_imgui_tools(mcp: Any) -> None:
    """Register SolarFlare ImGui tools on an existing FastMCP instance."""

    @mcp.tool()
    def lint_imgui_layout(code: str) -> ImGuiLintResult:
        """
        Validate a Haxe ImGui code block against SolarFlare's strict spatial
        density, table sizing, enum naming, and concrete binding-type rules.
        """
        return run_imgui_layout_lint(code)

    @mcp.tool()
    def generate_cdb_dense_layout(  # noqa: F811 — FastMCP tool surface
        skill_id: str,
        layout_type: str = "grid",
    ) -> CdbDenseLayoutResult:
        """
        Resolve a CastleDB skill/entity id from <data_cdb_file> and emit a
        playbook-compliant dense Haxe layout snippet.

        layout_type:
          - "grid": UiLayout.propertyGrid + inlinePair size/toggles
          - "inline": UiLayout.inlineSplit button matrix with unique ## IDs
        """
        return build_cdb_dense_layout(skill_id, layout_type)
