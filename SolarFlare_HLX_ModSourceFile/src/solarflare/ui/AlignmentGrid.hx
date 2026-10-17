package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * Optional screen grid that helps line HUD pieces up by eye. Presentation only: no snapping, nothing
 * written to any overlay. Lines are anchored on the screen center so the middle vertical and horizontal
 * lines always exist; those two are drawn thicker in the theme accent, every other line is thin and faint.
 *
 * Drawn on the background draw list: every overlay and editor sits above it and it takes no input.
 * The line geometry is rebuilt only when the spacing or the client extent changes (an edge), so a frame
 * costs one AddLine per line and no allocation.
 */
class AlignmentGrid {
	public static inline var MIN_SPACING:Int = 10;
	public static inline var MAX_SPACING:Int = 200;
	static inline var CENTER_THICKNESS:Float = 2.5;

	/** Off at every launch is not enforced: the choice is remembered like the other presentation prefs. */
	public static var enabled = new BoolRef(false);
	public static var spacing = new IntRef(50);
	public static var opacity = new FloatRef(0.22);

	static var lineA:Array<ImVec2> = [];
	static var lineB:Array<ImVec2> = [];
	static var midV0:ImVec2;
	static var midV1:ImVec2;
	static var midH0:ImVec2;
	static var midH1:ImVec2;
	static var builtCx:Float = -1;
	static var builtCy:Float = -1;
	static var builtW:Float = -1;
	static var builtH:Float = -1;
	static var builtStep:Int = -1;
	static var minorColor:Int = 0;
	static var builtOpacity:Float = -1;

	/** Background layer, called once per frame before the overlays. Cheap no-op while the grid is off. */
	public static function draw():Void {
		if (!enabled.get())
			return;
		var vp = ImGui.getMainViewport();
		if (vp == null)
			return;
		var center = ImGui.ImGuiViewport_GetCenter(vp);
		if (center == null)
			return;
		var step = spacing.get();
		if (step < MIN_SPACING)
			step = MIN_SPACING;
		else if (step > MAX_SPACING)
			step = MAX_SPACING;
		var w = HudChrome.viewportWidth;
		var h = HudChrome.viewportHeight;
		if (center.x != builtCx || center.y != builtCy || w != builtW || h != builtH || step != builtStep)
			rebuild(center.x, center.y, w, h, step);
		var dl = ImGui.getBackgroundDrawList();
		if (dl == null)
			return;
		var a = opacity.get();
		if (a != builtOpacity) {
			builtOpacity = a;
			minorColor = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, a));
		}
		for (i in 0...lineA.length)
			ImGui.ImDrawList_AddLine(dl, lineA[i], lineB[i], minorColor, 1);
		var accent = ThemePalette.current().accent;
		var centerColor = ImGui.colorConvertFloat4ToU32(accent);
		ImGui.ImDrawList_AddLine(dl, midV0, midV1, centerColor, CENTER_THICKNESS);
		ImGui.ImDrawList_AddLine(dl, midH0, midH1, centerColor, CENTER_THICKNESS);
	}

	static function rebuild(cx:Float, cy:Float, w:Float, h:Float, step:Int):Void {
		builtCx = cx;
		builtCy = cy;
		builtW = w;
		builtH = h;
		builtStep = step;
		lineA.resize(0);
		lineB.resize(0);
		var left = cx - w * 0.5;
		var right = cx + w * 0.5;
		var top = cy - h * 0.5;
		var bottom = cy + h * 0.5;
		// Outward from the center, so the grid is symmetric and line 0 is the emphasized center line.
		var k = 1;
		while (k * step <= w * 0.5) {
			var dx = k * step;
			lineA.push(ImGui.vec2(cx - dx, top));
			lineB.push(ImGui.vec2(cx - dx, bottom));
			lineA.push(ImGui.vec2(cx + dx, top));
			lineB.push(ImGui.vec2(cx + dx, bottom));
			k++;
		}
		k = 1;
		while (k * step <= h * 0.5) {
			var dy = k * step;
			lineA.push(ImGui.vec2(left, cy - dy));
			lineB.push(ImGui.vec2(right, cy - dy));
			lineA.push(ImGui.vec2(left, cy + dy));
			lineB.push(ImGui.vec2(right, cy + dy));
			k++;
		}
		midV0 = ImGui.vec2(cx, top);
		midV1 = ImGui.vec2(cx, bottom);
		midH0 = ImGui.vec2(left, cy);
		midH1 = ImGui.vec2(right, cy);
	}

	/** Controls for the Utilities page. `id` keeps the ImGui IDs unique per host. */
	public static function drawSettings(id:String):Void {
		UiLayout.propertyGrid("##grid_props_" + id, function() {
			UiLayout.propertyRow("Show grid", function() {
				if (ImGui.checkbox("Overlay an alignment grid##grid_show_" + id, enabled))
					SettingsStore.markDirty();
			}, "Lines every few pixels from the screen center. The middle lines are thicker. Nothing snaps to it.");
			ImGui.beginDisabled(!enabled.get());
			UiLayout.propertyRow("Spacing", function() {
				if (ImGui.sliderInt("##grid_spacing_" + id, spacing, MIN_SPACING, MAX_SPACING))
					SettingsStore.markDirty();
			}, "Distance between grid lines, in pixels.");
			UiLayout.propertyRow("Opacity", function() {
				if (ImGui.sliderFloat("##grid_opacity_" + id, opacity, 0.05, 0.8, "%.2f"))
					SettingsStore.markDirty();
			});
			ImGui.endDisabled();
		});
	}

	public static function dump():Dynamic {
		return {enabled: enabled.get(), spacing: spacing.get(), opacity: opacity.get()};
	}

	public static function apply(data:Dynamic):Void {
		if (data == null)
			return;
		var on:Dynamic = Reflect.field(data, "enabled");
		if (Std.isOfType(on, Bool))
			enabled.set(on);
		var s:Dynamic = Reflect.field(data, "spacing");
		if (Std.isOfType(s, Int))
			spacing.set(Std.int(Math.max(MIN_SPACING, Math.min(MAX_SPACING, s))));
		var o:Dynamic = Reflect.field(data, "opacity");
		if (Std.isOfType(o, Float))
			opacity.set(Math.max(0.05, Math.min(0.8, o)));
	}
}
