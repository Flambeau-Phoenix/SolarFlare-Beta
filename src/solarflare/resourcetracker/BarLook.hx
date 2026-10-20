package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.ui.NumberField;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiCol;
import solarflare.ui.UiLayout;

/**
 * Presentation options for a rectangular resource bar (Health, Rage, Mana/Spark): fill finish,
 * color, border, rounding, ticks and text. Pure presentation; holds no engine objects.
 * Persists as a small object inside the vitals dump and tolerates missing or malformed data.
 * Created in constructors only (native-backed refs and byte buffers).
 */
class BarLook {
	public static inline var FLAT:Int = 0;
	public static inline var GRADIENT:Int = 1;
	public static inline var GLASS:Int = 2;
	public static inline var SEGMENTED:Int = 3;
	public static inline var TEXT_AUTO:Int = 0;
	public static inline var TEXT_VALUE:Int = 1;
	public static inline var TEXT_PERCENT:Int = 2;
	public static inline var TEXT_BOTH:Int = 3;
	public static inline var TEXT_NONE:Int = 4;
	public static final FILL_NAMES = ["Flat", "Gradient", "Glass", "Segmented"];
	public static final TEXT_NAMES = ["Auto", "Value", "Percent", "Value + percent", "None"];
	static inline var DEFAULT_SEGMENTS:Int = 10;

	public var fillStyle:IntRef;
	public var useColor = new BoolRef(false);
	public var color:hl.Bytes;
	public var trackColor:hl.Bytes;
	public var borderThickness:FloatRef;
	public var autoBorder = new BoolRef(true);
	public var borderColor:hl.Bytes;
	public var rounding:FloatRef;
	public var edge:BoolRef;
	public var ticks = new IntRef(0);
	public var textMode = new IntRef(TEXT_AUTO);
	public var textShadow = new BoolRef(true);
	public var lowPulse:BoolRef;
	public var lowPercent = new FloatRef(25);

	public function new(defaultStyle:Int, defaultEdge:Bool, defaultBorder:Float, defaultPulse:Bool) {
		fillStyle = new IntRef(defaultStyle);
		edge = new BoolRef(defaultEdge);
		borderThickness = new FloatRef(defaultBorder);
		rounding = new FloatRef(4);
		lowPulse = new BoolRef(defaultPulse);
		color = ImGui.v4(0.28, 0.82, 0.42, 1);
		trackColor = ImGui.v4(0.10, 0.11, 0.12, 0.95);
		borderColor = ImGui.v4(1, 1, 1, 0.55);
	}

	// ---- Persistence --------------------------------------------------------------------------

	public function dump():Dynamic {
		return {
			fill: fillStyle.get(), useColor: useColor.get(), color: v4(color), track: v4(trackColor),
			border: borderThickness.get(), autoBorder: autoBorder.get(), borderColor: v4(borderColor),
			round: rounding.get(), edge: edge.get(), ticks: ticks.get(), text: textMode.get(),
			shadow: textShadow.get(), pulse: lowPulse.get(), low: lowPercent.get()
		};
	}

	/** Missing keys keep the current (constructor default) value, so old saves load unchanged. */
	public function apply(d:Dynamic):Void {
		if (d == null)
			return;
		fillStyle.set(Std.int(num(d, "fill", fillStyle.get(), 0, FILL_NAMES.length - 1)));
		useColor.set(bool(d, "useColor", useColor.get()));
		loadV4(color, Reflect.field(d, "color"));
		loadV4(trackColor, Reflect.field(d, "track"));
		borderThickness.set(num(d, "border", borderThickness.get(), 0, 4));
		autoBorder.set(bool(d, "autoBorder", autoBorder.get()));
		loadV4(borderColor, Reflect.field(d, "borderColor"));
		rounding.set(num(d, "round", rounding.get(), 0, 12));
		edge.set(bool(d, "edge", edge.get()));
		ticks.set(Std.int(num(d, "ticks", ticks.get(), 0, 20)));
		textMode.set(Std.int(num(d, "text", textMode.get(), 0, TEXT_NAMES.length - 1)));
		textShadow.set(bool(d, "shadow", textShadow.get()));
		lowPulse.set(bool(d, "pulse", lowPulse.get()));
		lowPercent.set(num(d, "low", lowPercent.get(), 5, 50));
	}

	static function num(d:Dynamic, k:String, fallback:Float, lo:Float, hi:Float):Float {
		var v:Dynamic = Reflect.field(d, k);
		return solarflare.ui.HudLayoutModel.finite(v) ? Math.max(lo, Math.min(hi, v)) : fallback;
	}

	static function bool(d:Dynamic, k:String, fallback:Bool):Bool {
		var v:Dynamic = Reflect.field(d, k);
		return Std.isOfType(v, Bool) ? v : fallback;
	}

	static function v4(b:hl.Bytes):Array<Float> return [b.getF32(0), b.getF32(4), b.getF32(8), b.getF32(12)];

	static function loadV4(b:hl.Bytes, data:Dynamic):Void {
		if (data == null)
			return;
		try {
			var arr:Array<Dynamic> = data;
			if (arr == null || arr.length < 4)
				return;
			for (i in 0...4)
				if (!solarflare.ui.HudLayoutModel.finite(arr[i]))
					return;
			for (i in 0...4)
				b.setF32(i * 4, Math.max(0, Math.min(1, arr[i])));
		} catch (_:Dynamic) {}
	}

	static inline function u32(b:hl.Bytes):Int
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(b.getF32(0), b.getF32(4), b.getF32(8), b.getF32(12)));

	/** The user's fill color as a vec4, or null while the automatic resource color applies. */
	public function userFill():Null<ImVec4> {
		return useColor.get() ? ImGui.vec4(color.getF32(0), color.getF32(4), color.getF32(8), color.getF32(12)) : null;
	}

	// ---- Drawing ------------------------------------------------------------------------------

	/**
	 * Paints the track, fill, ticks, border and label for one bar. `tint` is the resolved fill color
	 * (automatic or user, with dead/tapped gray already applied by the caller). `low` is true while
	 * the low-health pulse should show (the caller gates it to a living HP bar).
	 */
	public function paint(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Float, tint:ImVec4,
			vertical:Bool, label:String, shield:Float, low:Bool):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;
		var alpha:Float = tint.w;
		var base = ImGui.colorConvertFloat4ToU32(tint);
		var round:Single = Math.min(rounding.get(), Math.min(w, h) * 0.5);
		var style = fillStyle.get();
		var track = u32(trackColor);

		if (low) {
			var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * 3.2);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x - 2, y - 2), ImGui.vec2(x + w + 2, y + h + 2),
				UiCol.withAlpha(base, Std.int(0.22 * pulse * 255)), round + 2);
		}
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), UiCol.withAlpha(track, Std.int(((track >>> 24) & 0xFF) * alpha)), round);

		if (ratio > 0.001) {
			if (style == SEGMENTED)
				paintSegments(dl, x, y, w, h, ratio, base, vertical, round);
			else
				paintFill(dl, x, y, w, h, ratio, base, vertical, round, style);
		}
		if (style != SEGMENTED && ticks.get() > 0)
			paintTicks(dl, x, y, w, h, vertical);

		var bt:Single = borderThickness.get();
		if (bt > 0.01) {
			var border = low ? UiCol.rgb(0xFF5555) : autoBorder.get() ? UiCol.withAlpha(UiCol.lighten(base, 0.15), 0xD0) : u32(borderColor);
			var half:Single = bt * 0.5;
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x + half, y + half), ImGui.vec2(x + w - half, y + h - half), border, round, bt);
		}
		solarflare.ui.ShieldFill.bar(dl, x, y, w, h, shield, vertical);

		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			var pos = ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5);
			var col = UiCol.rgba(255, 255, 255, Std.int(0.92 * alpha * 255));
			if (textShadow.get())
				solarflare.ui.EnhancedText.shadowed(dl, pos, label, col, 0xAA000000, 1, 1);
			else
				ImGui.ImDrawList_AddText_Vec2(dl, pos, col, label);
		}
	}

	/** Fill rect clipped to the value, so the rounded track corners stay clean at any ratio. */
	function paintFill(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Float, base:Int, vertical:Bool,
			round:Single, style:Int):Void {
		var fx0:Single = x;
		var fy0:Single = vertical ? y + h * (1 - ratio) : y;
		var fx1:Single = vertical ? x + w : x + w * ratio;
		var fy1:Single = y + h;
		ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(fx0, fy0), ImGui.vec2(fx1, fy1), true);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), base, round);
		if (style != FLAT) {
			var inset:Single = Math.max(1, round * 0.5);
			var ix0:Single = x + inset;
			var ix1:Single = x + w - inset;
			// Light from the top, a touch of weight at the bottom: reads as a lit tube.
			var hi = UiCol.rgba(255, 255, 255, style == GLASS ? 0x30 : 0x2A);
			var clear = UiCol.rgba(255, 255, 255, 0);
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(ix0, y + 1), ImGui.vec2(ix1, y + h * 0.55), hi, hi, clear, clear);
			var shade = UiCol.rgba(0, 0, 0, 0x38);
			var none = UiCol.rgba(0, 0, 0, 0);
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(ix0, y + h * 0.5), ImGui.vec2(ix1, y + h - 1), none, none, shade, shade);
			if (style == GLASS)
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix0 + 1, y + 2), ImGui.vec2(ix1 - 1, y + Math.max(3, h * 0.36)),
					UiCol.rgba(255, 255, 255, 0x24), Math.max(0, round - 1));
		}
		ImGui.ImDrawList_PopClipRect(dl);
		if (edge.get() && ratio < 0.995) {
			var edgeCol = UiCol.rgba(255, 255, 255, 0xB0);
			if (vertical)
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x + 2, fy0), ImGui.vec2(x + w - 2, fy0), edgeCol, 2);
			else
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(fx1, y + 2), ImGui.vec2(fx1, y + h - 2), edgeCol, 2);
		}
	}

	function paintSegments(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Float, base:Int, vertical:Bool,
			round:Single):Void {
		var count = ticks.get() > 1 ? ticks.get() : DEFAULT_SEGMENTS;
		var gap:Single = 2;
		var span:Single = vertical ? h : w;
		var cell:Single = (span - gap * (count - 1)) / count;
		if (cell < 1)
			return;
		var segRound:Single = Math.min(round, Math.min(vertical ? w : h, cell) * 0.4);
		var lit = ratio * count;
		for (i in 0...count) {
			var amount = Math.max(0, Math.min(1, lit - i));
			if (amount <= 0)
				break;
			var s0:Single = i * (cell + gap);
			var x0:Single = vertical ? x : x + s0;
			var y0:Single = vertical ? y + h - s0 - cell : y;
			var sw:Single = vertical ? w : cell;
			var sh:Single = vertical ? cell : h;
			ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(x0, vertical ? y0 + sh * (1 - amount) : y0),
				ImGui.vec2(vertical ? x0 + sw : x0 + sw * amount, y0 + sh), true);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, y0), ImGui.vec2(x0 + sw, y0 + sh), base, segRound);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0 + 1, y0 + 1), ImGui.vec2(x0 + sw - 1, y0 + Math.max(2, sh * 0.4)),
				UiCol.rgba(255, 255, 255, 0x26), segRound);
			ImGui.ImDrawList_PopClipRect(dl);
		}
	}

	function paintTicks(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, vertical:Bool):Void {
		var n = ticks.get();
		var col = UiCol.rgba(0, 0, 0, 0x66);
		for (i in 1...n) {
			var f:Single = i / n;
			if (vertical) {
				var ty:Single = y + h * f;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x + 1, ty), ImGui.vec2(x + w - 1, ty), col, 1);
			} else {
				var tx:Single = x + w * f;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(tx, y + 1), ImGui.vec2(tx, y + h - 1), col, 1);
			}
		}
	}

	// ---- Editor -------------------------------------------------------------------------------

	/** Property rows for the look; `lowRows` adds the low-health pulse (Health only). */
	public function drawEditor(id:String, lowRows:Bool):Void {
		var colorFlags = imgui.Enums.ImGuiColorEditFlags.AlphaBar | imgui.Enums.ImGuiColorEditFlags.NoInputs;
		UiLayout.propertyGrid("##rt_" + id + "_look", function() {
			UiLayout.propertyRow("Finish", function() {
				if (ImGui.beginCombo("##rt_" + id + "_fill", FILL_NAMES[fillStyle.get()])) {
					for (i in 0...FILL_NAMES.length)
						if (ImGui.selectable(FILL_NAMES[i] + "##rt_" + id + "_fill_" + i, fillStyle.get() == i)) {
							fillStyle.set(i);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			}, "Flat is plain; Gradient and Glass add lighting; Segmented splits the bar into blocks.");
			UiLayout.propertyRow("Fill color", function() {
				UiLayout.inlinePair("##rt_" + id + "_fillcol",
					function(_:Single) {
						if (ImGui.checkbox("Custom##rt_" + id + "_usecol", useColor))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						ImGui.beginDisabled(!useColor.get());
						if (ImGui.colorEdit4("##rt_" + id + "_col", color, colorFlags))
							SettingsStore.markDirty();
						ImGui.endDisabled();
					});
			}, "Off uses the resource's own color. A confirmed dead or tapped target still shows gray.");
			UiLayout.propertyRow("Track", function() {
				if (ImGui.colorEdit4("##rt_" + id + "_track", trackColor, colorFlags))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Border", function() {
				UiLayout.inlinePair("##rt_" + id + "_border",
					function(_:Single) {
						if (NumberField.draw("##rt_" + id + "_bt", borderThickness, 0, 4, "%.1f px"))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						if (ImGui.checkbox("Auto color##rt_" + id + "_bauto", autoBorder))
							SettingsStore.markDirty();
					});
			});
			if (!autoBorder.get() && borderThickness.get() > 0.01)
				UiLayout.propertyRow("Border color", function() {
					if (ImGui.colorEdit4("##rt_" + id + "_bcol", borderColor, colorFlags))
						SettingsStore.markDirty();
				});
			UiLayout.propertyRow("Rounding", function() {
				if (NumberField.draw("##rt_" + id + "_round", rounding, 0, 12, "%.0f px"))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow(fillStyle.get() == SEGMENTED ? "Segments" : "Tick marks", function() {
				if (NumberField.drawInt("##rt_" + id + "_ticks", ticks, 0, 20, "%.0f"))
					SettingsStore.markDirty();
			}, fillStyle.get() == SEGMENTED ? "0 uses 10 segments." : "Divider lines across the bar; 0 for none.");
			UiLayout.propertyRow("Leading edge", function() {
				if (ImGui.checkbox("Bright edge at the fill tip##rt_" + id + "_edge", edge))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Text", function() {
				UiLayout.inlinePair("##rt_" + id + "_text",
					function(_:Single) {
						if (ImGui.beginCombo("##rt_" + id + "_textmode", TEXT_NAMES[textMode.get()])) {
							for (i in 0...TEXT_NAMES.length)
								if (ImGui.selectable(TEXT_NAMES[i] + "##rt_" + id + "_tm_" + i, textMode.get() == i)) {
									textMode.set(i);
									SettingsStore.markDirty();
								}
							ImGui.endCombo();
						}
					},
					function(_:Single) {
						if (ImGui.checkbox("Shadow##rt_" + id + "_tshadow", textShadow))
							SettingsStore.markDirty();
					});
			});
			if (lowRows)
				UiLayout.propertyRow("Low health", function() {
					UiLayout.inlinePair("##rt_" + id + "_low",
						function(_:Single) {
							if (ImGui.checkbox("Pulse below##rt_" + id + "_pulse", lowPulse))
								SettingsStore.markDirty();
						},
						function(_:Single) {
							ImGui.beginDisabled(!lowPulse.get());
							if (NumberField.draw("##rt_" + id + "_lowpct", lowPercent, 5, 50, "%.0f%%"))
								SettingsStore.markDirty();
							ImGui.endDisabled();
						});
				}, "Glow and a red border while health is below the threshold.");
		});
	}
}
