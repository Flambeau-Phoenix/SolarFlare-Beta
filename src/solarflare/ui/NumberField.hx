package solarflare.ui;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * Typed numeric field that replaces builder sliders: type an exact value, or use the
 * -/+ buttons (Ctrl for the large step). Values clamp to [min, max] as they are applied.
 * Fraction / multiplier ranges (max <= 3, not "%.0f") edit as whole percentages like
 * BuilderSlider did; the model keeps native units.
 */
class NumberField {
	/** Below this item width the -/+ buttons would crowd out the digits. */
	static inline var STEP_BUTTONS_MIN_W:Single = 110;

	static var percent = new FloatRef(0);
	static var whole = new FloatRef(0);
	/** Label of the field whose current gesture already ran beforeEdit. */
	static var armed:String = null;

	/**
	 * `beforeEdit` runs once per gesture, just before the first change lands, so a typed value
	 * or a burst of -/+ clicks becomes one undo step.
	 */
	public static function draw(label:String, value:FloatRef, min:Single, max:Single, format:String,
			?beforeEdit:Void->Void):Bool {
		var buttons = ImGui.calcItemWidth() >= STEP_BUTTONS_MIN_W;
		var changed = false;
		if (max <= 3 && format.indexOf("%.0f") < 0) {
			percent.set(Math.round(value.get() * 100));
			if (ImGui.inputFloat(label, percent, buttons ? 1 : 0, buttons ? 10 : 0, "%.0f%%")) {
				var next = clamp(Math.round(percent.get()), Math.round(min * 100), Math.round(max * 100)) / 100.0;
				changed = apply(label, value, next, beforeEdit);
			}
		} else {
			var step = stepFor(format);
			var before = value.get();
			if (ImGui.inputFloat(label, value, buttons ? step : 0, buttons ? step * 10 : 0, format)) {
				var next = clamp(value.get(), min, max);
				value.set(before);
				changed = apply(label, value, next, beforeEdit);
			}
		}
		if (armed == label && !ImGui.isItemActive()) armed = null;
		return changed;
	}

	public static function drawInt(label:String, value:IntRef, min:Int, max:Int, format:String = "%.0f"):Bool {
		var buttons = ImGui.calcItemWidth() >= STEP_BUTTONS_MIN_W;
		whole.set(value.get());
		if (!ImGui.inputFloat(label, whole, buttons ? 1 : 0, buttons ? 10 : 0, format))
			return false;
		var next = Std.int(clamp(Math.round(whole.get()), min, max));
		if (next == value.get()) return false;
		value.set(next);
		return true;
	}

	static function apply(label:String, value:FloatRef, next:Float, beforeEdit:Void->Void):Bool {
		if (next == value.get()) return false;
		if (beforeEdit != null && armed != label) beforeEdit();
		armed = label;
		value.set(next);
		return true;
	}

	/** One unit of the format's last shown digit: "%.0f" -> 1, "%.1f" -> 0.1, "%.2f" -> 0.01. */
	static function stepFor(format:String):Single {
		var dot = format.indexOf("%.");
		if (dot < 0 || dot + 2 >= format.length) return 1;
		return switch (format.charAt(dot + 2)) {
			case "1": 0.1;
			case "2": 0.01;
			case "3": 0.001;
			default: 1;
		}
	}

	static inline function clamp(v:Float, min:Float, max:Float):Float {
		return !Math.isFinite(v) ? min : (v < min ? min : (v > max ? max : v));
	}
}
