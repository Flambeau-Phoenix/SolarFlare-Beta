package solarflare.aura;

import solarflare.ui.ByteUtil;

import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Declarative presentation / lifecycle reaction for an aura.
 * Trigger answers "is it true?"; effects answer "what shows and for how long?".
 */
class AuraEffect {
	public static inline var KIND_WINDOW:String = "window";
	public static inline var KIND_ALERT:String = "alert";
	public static inline var KIND_ICON:String = "icon";
	public static inline var KIND_AUDIO:String = "audio";

	public static inline var WHEN_WHILE_TRUE:String = "whileTrue";
	public static inline var WHEN_WHILE_FALSE:String = "whileFalse";
	public static inline var WHEN_ON_RISE:String = "onRise";
	public static inline var WHEN_ON_FALL:String = "onFall";
	public static inline var WHEN_ON_RISE_HOLD:String = "onRiseHold";
	public static inline var WHEN_ON_FALL_HOLD:String = "onFallHold";
	public static inline var WHEN_STICKY:String = "sticky";

	public static final KINDS:Array<String> = [KIND_WINDOW, KIND_ALERT, KIND_ICON, KIND_AUDIO];
	public static final WHENS:Array<String> = [
		WHEN_WHILE_TRUE, WHEN_WHILE_FALSE, WHEN_ON_RISE, WHEN_ON_FALL, WHEN_ON_RISE_HOLD, WHEN_ON_FALL_HOLD, WHEN_STICKY
	];

	public var id:String;
	public var kind:String;
	public var when:String;
	public var enabled:BoolRef;
	public var hold:Float;
	public var fadeIn:Float;
	public var fadeOut:Float;
	public var text:String;
	public var cue:String;
	public var glow:BoolRef;
	public var alpha:FloatRef;
	public var holdRef:FloatRef;
	public var textBuf:hl.Bytes;
	public var cueBuf:hl.Bytes;
	public static inline var TEXT_BUF:Int = 120;
	public static inline var CUE_BUF:Int = 48;

	/** Runtime edge / hold memory (not persisted). */
	public var until:Float;
	public var stickyArmed:Bool;

	public function new(id:String, kind:String = KIND_WINDOW, when:String = WHEN_WHILE_TRUE) {
		this.id = id != null && id.length > 0 ? id : "fx";
		this.kind = kind != null && kind.length > 0 ? kind : KIND_WINDOW;
		this.when = when != null && when.length > 0 ? when : WHEN_WHILE_TRUE;
		enabled = new BoolRef(true);
		hold = 1.5;
		fadeIn = 0;
		fadeOut = 0;
		text = "";
		cue = "";
		glow = new BoolRef(false);
		alpha = new FloatRef(1);
		holdRef = new FloatRef(1.5);
		textBuf = new hl.Bytes(TEXT_BUF);
		cueBuf = new hl.Bytes(CUE_BUF);
		until = 0;
		stickyArmed = false;
		syncTextBuf();
		syncCueBuf();
	}

	public function syncTextBuf():Void {
		fillBuf(textBuf, TEXT_BUF, text);
	}

	public function syncCueBuf():Void {
		fillBuf(cueBuf, CUE_BUF, cue);
	}

	public function toObj():Dynamic {
		try {
			return {
				id: id,
				kind: kind,
				when: when,
				enabled: safeBool(enabled, true),
				hold: hold,
				fadeIn: fadeIn,
				fadeOut: fadeOut,
				text: text != null ? text : "",
				cue: cue != null ? cue : "",
				glow: safeBool(glow, false),
				alpha: safeFloat(alpha, 1)
			};
		} catch (_:Dynamic) {
			return {id: id != null ? id : "fx", kind: KIND_WINDOW, when: WHEN_WHILE_TRUE, enabled: true};
		}
	}

	static function safeBool(r:Null<BoolRef>, fallback:Bool):Bool {
		if (r == null) return fallback;
		try return r.get() catch (_:Dynamic) return fallback;
	}

	static function safeFloat(r:Null<FloatRef>, fallback:Float):Float {
		if (r == null) return fallback;
		try return r.get() catch (_:Dynamic) return fallback;
	}

	public static function fromDyn(d:Dynamic):AuraEffect {
		var id = d != null && d.id != null ? Std.string(d.id) : "fx";
		var kind = d != null && d.kind != null ? Std.string(d.kind) : KIND_WINDOW;
		var when = d != null && d.when != null ? Std.string(d.when) : WHEN_WHILE_TRUE;
		var e = new AuraEffect(id, kind, when);
		if (d == null)
			return e;
		if (d.enabled == false)
			e.enabled.set(false);
		if (d.hold != null)
			e.hold = d.hold;
		if (d.fadeIn != null)
			e.fadeIn = d.fadeIn;
		if (d.fadeOut != null)
			e.fadeOut = d.fadeOut;
		if (d.text != null)
			e.text = Std.string(d.text);
		if (d.cue != null)
			e.cue = Std.string(d.cue);
		if (d.glow == true)
			e.glow.set(true);
		if (d.alpha != null)
			e.alpha.set(d.alpha);
		e.holdRef.set(e.hold);
		e.syncTextBuf();
		e.syncCueBuf();
		return e;
	}

	/** Continuous window (legacy dormant off). */
	public static function defaultWindow():AuraEffect {
		return new AuraEffect("win", KIND_WINDOW, WHEN_WHILE_TRUE);
	}

	/** DRM-style rising-edge hold (legacy dormant on). */
	public static function dormantWindow(holdSec:Float):AuraEffect {
		var e = new AuraEffect("win", KIND_WINDOW, WHEN_ON_RISE_HOLD);
		e.hold = holdSec > 0 ? holdSec : 3;
		e.holdRef.set(e.hold);
		return e;
	}

	/** Berserk / CD-ready pack: window while ready + rise alert. */
	public static function presetCdReady(alertText:String):Array<AuraEffect> {
		var win = defaultWindow();
		var al = new AuraEffect("al", KIND_ALERT, WHEN_ON_RISE);
		al.hold = 1.5;
		al.holdRef.set(1.5);
		al.text = alertText != null ? alertText : "READY";
		al.syncTextBuf();
		return [win, al];
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, s:String):Void ByteUtil.fillBuf(buf, cap, s);
}
