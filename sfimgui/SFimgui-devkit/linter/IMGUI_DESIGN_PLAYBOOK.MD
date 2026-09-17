# SolarFlare ImGui Design Playbook

This file is the workspace standard for new SolarFlare configuration UI.
Use the shared layout and scope helpers instead of recreating layout arithmetic
or manually splitting Begin/End ownership.

## 1. The Visual Paradigm

SolarFlare configuration windows must use their available screen space
deliberately.

- Do not build loose vertical chains of label, control, label, control.
- Related properties belong in `UiLayout.propertyGrid` rows.
- Related scalar pairs and short option groups belong in `inlinePair` or
  `inlineSplit`.
- Property grids use the required 35/65 label/control split.
- Property grids enforce 4×2 px `CellPadding` and 4×2 px `ItemSpacing` through
  the shared wrapper.
- Labels and controls remain on the same row unless the compact width makes the
  control unusable.
- Large catalogs, prose, previews, diagnostics, and multiline editors are not
  property grids. Give those surfaces the space their content requires.
- Use readable labels. Density is achieved through structure and spacing, not
  cryptic abbreviations.
- Use stable double-hash IDs derived from the owning suite and item identity.
- Use `ToolWindow.drawWindow`, `ToolWindow.drawMenuWindow`, `UiScope.child`,
  and `UiScope.table` so the function opening a scope also owns its close.

Direct suite calls to the internal ToolWindow Begin/End methods are forbidden.
Every Push must have a matching Pop on every reachable control-flow path.

## 2. Property Grid Compactness

Use one `propertyGrid` per related configuration group and one `propertyRow`
per setting. The row provides the visible label, so the control should normally
use a hidden ImGui label.

```haxe
import imgui.ImGui;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;

function drawWindowProperties():Void {
	UiLayout.propertyGrid("##example_window_properties", function() {
		UiLayout.propertyRow("Visible", function() {
			if (ImGui.checkbox("##example_visible", cfg.visible))
				SettingsStore.markDirty();
		});

		UiLayout.propertyRow("Opacity", function() {
			if (ImGui.sliderFloat(
				"##example_opacity",
				cfg.opacity,
				0,
				1,
				"%.0f%%"
			)) {
				SettingsStore.markDirty();
			}
		});

		UiLayout.propertyRow(
			"Scale",
			function() {
				if (ImGui.sliderFloat(
					"##example_scale",
					cfg.scale,
					0.5,
					2,
					"%.2fx"
				)) {
					SettingsStore.markDirty();
				}
			},
			"Changes the rendered HUD size."
		);
	});
}
```

Do not manually push table padding around this code. `propertyGrid` owns its
density styles and restores them when the table is drawn, clipped, or fails.

## 3. Horizontal Scalar Clusters

Use `inlinePair` for two related controls. The callback receives the available
cell width; ordinary scalar widgets inherit it from the helper.

```haxe
UiLayout.propertyGrid("##example_dimensions", function() {
	UiLayout.propertyRow("Size", function() {
		UiLayout.inlinePair(
			"##example_width_height",
			function(width:Single) {
				if (ImGui.sliderFloat(
					"Width##example_width",
					cfg.width,
					100,
					800,
					"%.0f px"
				)) {
					SettingsStore.markDirty();
				}
			},
			function(width:Single) {
				if (ImGui.sliderFloat(
					"Height##example_height",
					cfg.height,
					40,
					600,
					"%.0f px"
				)) {
					SettingsStore.markDirty();
				}
			}
		);
	});

	UiLayout.propertyRow("Grid", function() {
		UiLayout.inlinePair(
			"##example_rows_columns",
			function(width:Single) {
				if (ImGui.sliderInt(
					"Rows##example_rows",
					cfg.rows,
					1,
					8
				)) {
					SettingsStore.markDirty();
				}
			},
			function(width:Single) {
				if (ImGui.sliderInt(
					"Columns##example_columns",
					cfg.columns,
					1,
					12
				)) {
					SettingsStore.markDirty();
				}
			}
		);
	});
});
```

Use `inlineSplit` for three or more equivalent controls, such as presets. Pass
the supplied width explicitly to buttons because `pushItemWidth` does not size
buttons.

```haxe
var presets = ["1x4", "1x6", "2x4"];

UiLayout.inlineSplit(
	"##example_presets",
	presets.length,
	function(index:Int, width:Single) {
		var label = presets[index];
		if (ImGui.button(
			label + "##example_preset_" + index,
			ImGui.vec2(width, 28)
		)) {
			applyPreset(label);
		}
	},
	4
);
```

For responsive multi-row navigation or card groups, calculate the active column
count first:

```haxe
var available = ImGui.getContentRegionAvail().x;
var columns = UiLayout.columnCount(available, 120, 4, 8);
```

Do not send unbounded catalogs through `inlineSplit`. Use a searchable and
clipped list for large collections.

## 4. Binding Warnings

The concrete layout-vector type in this Haxe binding is:

```haxe
import imgui.Structs.ImVec2;
```

Use `imgui.Structs.ImVec2` in shared APIs and explicit type annotations.
Do not import `imgui.Vec2`; that standalone type import does not exist in the
current generated hl-imgui binding and will fail compilation.

Create values with the verified constructor:

```haxe
var size:ImVec2 = ImGui.vec2(320, 180);
```

The verified style enum names are:

```haxe
ImGuiStyleVar.CellPadding
ImGuiStyleVar.ItemSpacing
```

Do not translate C++ names such as `ImGuiStyleVar_CellPadding` directly into
Haxe.

## Required Verification

Before handing off UI work:

1. Run `haxe compile.hxml`.
2. Test normal and minimum window sizes.
3. Test every theme, especially High Contrast and Custom.
4. Repeatedly open, close, resize, and switch the affected windows.
5. Check ImGui Metrics and Debug Log for stack, table, or ID errors.
6. Confirm every Begin/End and Push/Pop pair by control-flow path, not by raw
   text counts.

