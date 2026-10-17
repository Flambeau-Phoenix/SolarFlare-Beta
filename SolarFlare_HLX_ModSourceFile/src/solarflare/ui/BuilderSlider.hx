package solarflare.ui;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/** Fraction / multiplier controls use whole percentages; model keeps native units. */
class BuilderSlider {
	static var percent = new IntRef(0);
	static var edits = new Map<String, PreciseSliderEdit>();
	public static function clearPreciseState():Void edits = new Map<String, PreciseSliderEdit>();
	/** Visible number entry; retain its native edit buffer throughout a typing/drag gesture. */
	public static function precise(label:String,value:FloatRef,min:Single,max:Single,format:String,?beforeEdit:Void->Void):Bool {
		var e=edits.get(label);
		if(e==null) { e=new PreciseSliderEdit(label); edits.set(label,e); }
		var factor:Float=max<=3 && format.indexOf("%.0f")<0 ? 100 : 1;
		var shownFormat=factor==100 ? "%.0f%%" : format;
		var total=ImGui.getContentRegionAvail().x;
		var numberW:Single=Math.min(112,Math.max(68,total*0.40));
		var changed=false;
		ImGui.pushID_Str(label);
		if(total>=170) {
			e.slider.set(value.get()*factor);
			ImGui.setNextItemWidth(total-numberW-4);
			if(ImGui.sliderFloat("##slider",e.slider,min*factor,max*factor,shownFormat)) {
				var n=PreciseValuePolicy.convert(e.slider.get(),factor,min,max,value.get());
				if(n!=value.get()) { if(!e.snapshotted && beforeEdit!=null) beforeEdit(); e.snapshotted=true; value.set(n); changed=true; }
			}
			e.sliderActive=ImGui.isItemActive();
			ImGui.sameLine(0,4);
		} else e.sliderActive=false;
		if(!e.numberActive) e.number.set(value.get()*factor);
		ImGui.setNextItemWidth(total>=170 ? numberW : total);
		if(ImGui.inputFloat("##number",e.number,1,10,shownFormat)) {
			var n=PreciseValuePolicy.convert(e.number.get(),factor,min,max,value.get());
			if(n!=value.get()) { if(!e.snapshotted && beforeEdit!=null) beforeEdit(); e.snapshotted=true; value.set(n); changed=true; }
		}
		e.numberActive=ImGui.isItemActive();
		if(!e.numberActive && !e.sliderActive) e.snapshotted=false;
		ImGui.popID();
		return changed;
	}
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

private class PreciseSliderEdit {
	public var slider=new FloatRef(0);
	public var number=new FloatRef(0);
	public var numberActive=false;
	public var sliderActive=false;
	public var snapshotted=false;
	public function new(label:String) {}
}
