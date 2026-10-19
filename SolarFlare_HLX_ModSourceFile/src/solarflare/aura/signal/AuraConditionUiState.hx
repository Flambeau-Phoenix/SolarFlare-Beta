package solarflare.aura.signal;

import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

class AuraConditionUiState {
	public static inline var SEARCH_BUF:Int = 160;
	/** Larger than the supported source limit so oversized pasted input can be diagnosed. */
	public static inline var SCRIPT_BUF:Int = 65536;
	public var scriptBuf:hl.Bytes;
	public var scriptSource:String="";
	public var scriptBytes:Int=0;
	public var scriptEditing:Bool=false;
	public var scriptSession:solarflare.scripting.ScriptEditorSession;
	public var scriptInsert:AuraConditionDef;
	public var scriptInsertUi:AuraConditionUiState;
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
	public function bind(c:AuraConditionDef):Void { if (bound != c) { bound = c; scriptEditing=false; sync(c); } }
	public function sync(c:AuraConditionDef):Void { if (c == null) return; numberRef.set(c.numberValue); percentRef.set(c.numberValue * 100); boolRef.set(c.boolValue); negateRef.set(c.negate); if(c.signal=="custom.script") syncScript(c); }
	public function syncScript(c:AuraConditionDef):Void {
		if(scriptBuf==null) {
			scriptBuf=new hl.Bytes(SCRIPT_BUF); scriptSession=new solarflare.scripting.ScriptEditorSession();
			scriptInsert=new AuraConditionDef(); scriptInsert.signal="dash.available"; scriptInsertUi=new AuraConditionUiState();
		}
		scriptSession.touch(haxe.Timer.stamp());
		if(scriptSource!=c.subject || scriptSession.state=="Unchecked") {
			scriptSource=c.subject; scriptBytes=haxe.io.Bytes.ofString(scriptSource).length;
			solarflare.ui.ByteUtil.fillBuf(scriptBuf,SCRIPT_BUF,scriptSource);
			scriptSession.request(scriptSource,haxe.Timer.stamp());
		}
	}
	public function pull(c:AuraConditionDef):Void { if (c == null) return; c.numberValue = numberRef.get(); c.boolValue = boolRef.get(); c.negate = negateRef.get(); }
	public function pullPercent(c:AuraConditionDef):Void { if (c == null) return; c.numberValue = percentRef.get() * 0.01; numberRef.set(c.numberValue); }
	public function flashContext():Void focusUntil = haxe.Timer.stamp() + 1.25;
}
