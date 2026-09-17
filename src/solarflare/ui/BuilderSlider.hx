package solarflare.ui;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/** Fraction / multiplier controls use whole percentages; model keeps native units. */
class BuilderSlider {
	static var percent = new IntRef(0);
	public static function draw(label:String, value:FloatRef, min:Single, max:Single, format:String):Bool {
		if (max <= 3 && format.indexOf("%.0f") < 0) {
			percent.set(Math.round(value.get() * 100));
			if (!ImGui.sliderInt(label, percent, Math.round(min * 100), Math.round(max * 100), "%d%%")) return false;
			value.set(percent.get() / 100.0);
			return true;
		}
		return ImGui.sliderFloat(label, value, min, max, format);
	}
}
