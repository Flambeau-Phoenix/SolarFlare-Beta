package solarflare.ui;

import imgui.ImGui;
import imgui.ref.IntRef;
import imgui.Structs.ImVec4;

/**
 * Discrete pip / bubble drawing for combo, vitals segments, and conduits.
 */
class PipShapes {
	public static inline var BOX:Int = 0;
	public static inline var DIAMOND:Int = 1;
	public static inline var CIRCLE:Int = 2;
	public static inline var RING:Int = 3;
	public static inline var HEX:Int = 4;

	public static inline var SLOTS:Int = 6;
	public static inline var GAP:Single = 3;
	public static inline var LABEL_W:Single = 28;
	public static inline var LABEL_H:Single = 18;

	public static function normalize(shape:Int):Int {
		if (shape == BOX || shape == DIAMOND || shape == CIRCLE || shape == RING || shape == HEX)
			return shape;
		return DIAMOND;
	}

	public static function name(shape:Int):String {
		return switch (normalize(shape)) {
			case BOX: "Box";
			case CIRCLE: "Circle";
			case RING: "Ring";
			case HEX: "Hexagon";
			default: "Diamond";
		};
	}

	public static function drawShapeCombo(label:String, shape:IntRef):Void {
		if (shape == null)
			return;
		var cur = normalize(shape.get());
		if (cur != shape.get())
			shape.set(cur);
		if (ImGui.beginCombo(label, name(cur))) {
			if (ImGui.selectable("Diamond##pip", cur == DIAMOND)) {
				shape.set(DIAMOND);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Circle##pip", cur == CIRCLE)) {
				shape.set(CIRCLE);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Ring##pip", cur == RING)) {
				shape.set(RING);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Hexagon##pip", cur == HEX)) {
				shape.set(HEX);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Box##pip", cur == BOX)) {
				shape.set(BOX);
				SettingsStore.markDirty();
			}
			ImGui.endCombo();
		}
	}

	/** Integer-filled slots (combo / conduits). Optional skill PNG per pip. */
	public static function drawCount(rowW:Single, rowH:Single, n:Int, filled:Int, vertical:Bool, shape:Int,
			label:String, iconId:String = null):Void {
		if (n < 1)
			n = SLOTS;
		var f = filled;
		if (f < 0)
			f = 0;
		if (f > n)
			f = n;
		var amounts = new Array<Float>();
		for (i in 0...n)
			amounts.push(i < f ? 1 : 0);
		drawInternal(rowW, rowH, n, amounts, vertical, shape, label, iconId, defaultLit(), defaultDim(),
			defaultLitBorder(), defaultDimBorder());
	}

	/** Value split across equal box segments (for example 2×10 or 2×50). */
	public static function drawValueSegments(rowW:Single, rowH:Single, segs:Int, value:Float, perSeg:Float,
			vertical:Bool, label:String, lit:ImVec4, dim:ImVec4):Void {
		if (segs < 1)
			segs = 2;
		if (perSeg < 1)
			perSeg = 1;
		var amounts = new Array<Float>();
		var i = 0;
		while (i < segs) {
			var a = (value - i * perSeg) / perSeg;
			if (a < 0)
				a = 0;
			if (a > 1)
				a = 1;
			amounts.push(a);
			i++;
		}
		var borderLit = ImGui.vec4(lit.x * 0.7 + 0.3, lit.y * 0.7 + 0.3, lit.z * 0.7 + 0.3, 0.7);
		var borderDim = ImGui.vec4(0.22, 0.26, 0.23, 1);
		drawInternal(rowW, rowH, segs, amounts, vertical, BOX, label, null, lit, dim, borderLit, borderDim);
	}
	public static function drawRatio(rowW:Single, rowH:Single, n:Int, ratio:Float, vertical:Bool, shape:Int,
			label:String, lit:ImVec4, dim:ImVec4):Void {
		if (n < 1)
			n = SLOTS;
		var r = ratio;
		if (r < 0)
			r = 0;
		if (r > 1)
			r = 1;
		var amounts = new Array<Float>();
		var remain = r * n;
		for (i in 0...n) {
			var a = remain;
			if (a < 0)
				a = 0;
			if (a > 1)
				a = 1;
			amounts.push(a);
			remain -= 1;
		}
		var borderLit = ImGui.vec4(lit.x * 0.7 + 0.3, lit.y * 0.7 + 0.3, lit.z * 0.7 + 0.3, 0.7);
		var borderDim = ImGui.vec4(0.22, 0.26, 0.23, 1);
		drawInternal(rowW, rowH, n, amounts, vertical, shape, label, null, lit, dim, borderLit, borderDim);
	}

	static function defaultLit():ImVec4 {
		return ImGui.vec4(0.32, 0.78, 0.42, 1);
	}

	static function defaultDim():ImVec4 {
		return ImGui.vec4(0.12, 0.14, 0.13, 0.95);
	}

	static function defaultLitBorder():ImVec4 {
		return ImGui.vec4(0.55, 0.95, 0.62, 0.55);
	}

	static function defaultDimBorder():ImVec4 {
		return ImGui.vec4(0.22, 0.26, 0.23, 1);
	}

	static function drawInternal(rowW:Single, rowH:Single, n:Int, amounts:Array<Float>, vertical:Bool, shape:Int,
			label:String, iconId:String, lit:ImVec4, dim:ImVec4, litBorder:ImVec4, dimBorder:ImVec4):Void {
		shape = normalize(shape);
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var gap:Single = GAP;
		var text = label != null ? label : "";
		var ts = text.length > 0 ? ImGui.calcTextSize(text) : ImGui.vec2(0, 0);
		var labelW:Single = text.length > 0 ? Math.max(LABEL_W, ts.x + 6) : 0;
		var labelH:Single = text.length > 0 ? Math.max(LABEL_H, ts.y + 2) : 0;

		var pipW:Single = rowW;
		var pipH:Single = rowH;
		var labelX:Single = origin.x;
		var labelY:Single = origin.y;
		if (vertical) {
			pipH = rowH - labelH;
			if (pipH < 8)
				pipH = 8;
			labelX = origin.x + Math.max(0, (rowW - ts.x) * 0.5);
			labelY = origin.y + pipH + 1;
		} else {
			pipW = rowW - labelW;
			if (pipW < 8)
				pipW = 8;
			labelX = origin.x + pipW + 4;
			labelY = origin.y + Math.max(0, (rowH - ts.y) * 0.5);
		}

		var tex:hl.I64 = 0;
		if (iconId != null && iconId.length > 0)
			tex = GameIcons.get(iconId);
		var hasTex = tex != (0 : hl.I64);

		if (vertical) {
			var blockH:Single = (pipH - gap * (n - 1)) / n;
			if (blockH < 4)
				blockH = 4;
			var blockW:Single = pipW;
			if (blockW < 8)
				blockW = 8;
			for (i in 0...n) {
				var idx = n - 1 - i;
				var y:Single = origin.y + (blockH + gap) * i;
				var amt = idx < amounts.length ? amounts[idx] : 0;
				drawOne(dl, origin.x, y, blockW, blockH, shape, amt, lit, dim, litBorder, dimBorder, tex, hasTex);
			}
		} else {
			var blockW:Single = (pipW - gap * (n - 1)) / n;
			if (blockW < 4)
				blockW = 4;
			var blockH:Single = pipH;
			if (blockH < 8)
				blockH = 8;
			for (i in 0...n) {
				var x:Single = origin.x + (blockW + gap) * i;
				var amt = i < amounts.length ? amounts[i] : 0;
				drawOne(dl, x, origin.y, blockW, blockH, shape, amt, lit, dim, litBorder, dimBorder, tex, hasTex);
			}
		}

		if (text.length > 0) {
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(labelX, labelY),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92)), text);
		}
		ImGui.dummy(ImGui.vec2(rowW, rowH));
	}

	static function drawOne(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, shape:Int, amount:Float, lit:ImVec4,
			dim:ImVec4, litBorder:ImVec4, dimBorder:ImVec4, tex:hl.I64, hasTex:Bool):Void {
		var a = amount;
		if (a < 0)
			a = 0;
		if (a > 1)
			a = 1;
		var fill = mix(dim, lit, a);
		var border = mix(dimBorder, litBorder, a > 0.01 ? Math.max(a, 0.35) : 0);
		var cx:Single = x + w * 0.5;
		var cy:Single = y + h * 0.5;
		var rad:Single = Math.min(w, h) * 0.42;
		if (rad < 3)
			rad = 3;
		var fillU = ImGui.colorConvertFloat4ToU32(fill);
		var borderU = ImGui.colorConvertFloat4ToU32(border);

		if (hasTex) {
			var side:Single = Math.min(w, h) * 0.92;
			if (side < 6)
				side = 6;
			var tint = a > 0.5 ? GameIcons.tintReady(true) : GameIcons.tintReady(false);
			if (a > 0.01 && a < 0.99)
				tint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.38 + 0.62 * a));
			GameIcons.draw(dl, tex, cx - side * 0.5, cy - side * 0.5, side, tint);
			return;
		}

		switch (shape) {
			case CIRCLE:
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 24);
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), rad, borderU, 24, 1.25);
			case RING:
				var thick:Single = Math.max(1.5, rad * 0.22);
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), rad, borderU, 24, thick);
				if (a > 0.02)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), rad * (0.35 + 0.55 * a), fillU, 24);
			case HEX:
				ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 6);
				ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), rad, borderU, 6, 1.25);
			case DIAMOND:
				ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 4);
				ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), rad, borderU, 4, 1.25);
			default:
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), fillU, 3);
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), borderU, 3, 1);
		}
	}

	static function mix(a:ImVec4, b:ImVec4, t:Float):ImVec4 {
		if (t <= 0)
			return a;
		if (t >= 1)
			return b;
		return ImGui.vec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t);
	}
}
