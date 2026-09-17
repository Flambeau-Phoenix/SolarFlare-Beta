package solarflare.aura.signal;

import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

class AuraConditionUiState {
	public static inline var SEARCH_BUF:Int = 160;
	public var numberRef:FloatRef;
	/** Display-only 0–100 percentage; the model stores its threshold as 0–1. */
	public var percentRef:FloatRef;
	public var boolRef:BoolRef;
	public var negateRef:BoolRef;
	public var searchBuf:hl.Bytes;
	public var search:String = "";
	/** Short-lived builder-only context cue; never persisted with Aura rule data. */
	public var focusUntil:Float = 0;
	var bound:AuraConditionDef;
	public function new() {
		numberRef = new FloatRef(0); percentRef = new FloatRef(0); boolRef = new BoolRef(false); negateRef = new BoolRef(false); searchBuf = new hl.Bytes(SEARCH_BUF); solarflare.ui.ByteUtil.clearBytes(searchBuf, SEARCH_BUF);
	}
	public function bind(c:AuraConditionDef):Void { if (bound != c) { bound = c; sync(c); } }
	public function sync(c:AuraConditionDef):Void { if (c == null) return; numberRef.set(c.numberValue); percentRef.set(c.numberValue * 100); boolRef.set(c.boolValue); negateRef.set(c.negate); }
	public function pull(c:AuraConditionDef):Void { if (c == null) return; c.numberValue = numberRef.get(); c.boolValue = boolRef.get(); c.negate = negateRef.get(); }
	public function pullPercent(c:AuraConditionDef):Void { if (c == null) return; c.numberValue = percentRef.get() * 0.01; numberRef.set(c.numberValue); }
	public function flashContext():Void focusUntil = haxe.Timer.stamp() + 1.25;
}
