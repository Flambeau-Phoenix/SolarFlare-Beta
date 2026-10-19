package solarflare.aura;

import solarflare.aura.signal.AuraRuleCodec;
import solarflare.aura.signal.AuraRuleDef;
import solarflare.aura.signal.AuraRuleResult;

/**
 * A named look for an aura. States are checked in order; the first whose rule matches is the active one,
 * otherwise the aura uses its Default look (state id ""). Canvas elements choose which states show them and
 * may override position, size, colour, opacity and rotation per state.
 */
class AuraStateDef {
	public static inline var MAX_STATES:Int = 24;
	public static inline var MAX_NAME:Int = 32;

	public var id:String;
	public var name:String;
	public var rule:AuraRuleDef = new AuraRuleDef();
	/** Runtime only; sized by the evaluator. */
	public var result(default, null):AuraRuleResult = new AuraRuleResult();

	public function new(id:String, name:String) {
		this.id = id;
		this.name = name;
	}

	public function toObj():Dynamic {
		return {id: id, name: name, rule: AuraRuleCodec.toObj(rule)};
	}

	/** Null when the record has no usable id. */
	public static function fromDyn(d:Dynamic):AuraStateDef {
		if (d == null || d.id == null) return null;
		var id = cleanId(Std.string(d.id));
		if (id.length == 0) return null;
		var name = d.name != null ? StringTools.trim(Std.string(d.name)) : "";
		if (name.length > MAX_NAME) name = name.substr(0, MAX_NAME);
		var s = new AuraStateDef(id, name.length > 0 ? name : id);
		if (d.rule != null) {
			var r = AuraRuleCodec.fromDyn(d.rule);
			if (r != null) s.rule = r;
		}
		return s;
	}

	/** Ids are short, lower-case and safe to use as JSON keys. */
	public static function cleanId(raw:String):String {
		var b = new StringBuf();
		for (i in 0...raw.length) {
			var c = raw.charCodeAt(i);
			var ok = (c >= "a".code && c <= "z".code) || (c >= "0".code && c <= "9".code) || c == "_".code || c == "-".code;
			if (c >= "A".code && c <= "Z".code) { b.addChar(c + 32); continue; }
			if (ok) b.addChar(c);
		}
		var out = b.toString();
		return out.length > 24 ? out.substr(0, 24) : out;
	}

	public static function uniqueId(states:Array<AuraStateDef>):String {
		var n = 1;
		while (true) {
			var id = "s" + n;
			var taken = false;
			for (s in states) if (s.id == id) { taken = true; break; }
			if (!taken) return id;
			n++;
		}
	}

	/** "Name copy", then "Name copy 2"... whichever no look is using, kept within MAX_NAME. */
	public static function copyName(states:Array<AuraStateDef>, base:String):String {
		var root = base.length > MAX_NAME - 7 ? base.substr(0, MAX_NAME - 7) : base;
		var n = 1;
		while (true) {
			var candidate = root + " copy" + (n > 1 ? " " + n : "");
			var taken = false;
			for (s in states) if (s.name == candidate) { taken = true; break; }
			if (!taken) return candidate;
			n++;
		}
	}

	/**
	 * Copies a look: its trigger rule, plus every layer's membership and per-look overrides. The copy goes right
	 * after the original (looks are checked in order) and shares nothing with it. Null at the look limit or when
	 * `sourceId` is unknown.
	 */
	public static function duplicate(states:Array<AuraStateDef>, elements:Array<AuraCanvasElement>, sourceId:String):AuraStateDef {
		var src = find(states, sourceId);
		if (src == null || states.length >= MAX_STATES) return null;
		var copy = new AuraStateDef(uniqueId(states), copyName(states, src.name));
		var rule = AuraRuleCodec.fromDyn(AuraRuleCodec.toObj(src.rule));
		if (rule != null) copy.rule = rule;
		states.insert(states.indexOf(src) + 1, copy);
		if (elements != null) for (el in elements) {
			if (el == null) continue;
			if (el.inStates != null && el.inStates.indexOf(sourceId) >= 0 && el.inStates.indexOf(copy.id) < 0) el.inStates.push(copy.id);
			var o = el.ov(sourceId);
			if (o != null && !o.isEmpty()) {
				if (el.overrides == null) el.overrides = new Map();
				el.overrides.set(copy.id, o.clone());
			}
		}
		return copy;
	}

	public static function find(states:Array<AuraStateDef>, id:String):AuraStateDef {
		if (states != null) for (s in states) if (s.id == id) return s;
		return null;
	}
}
