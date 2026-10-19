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
	public static inline var MAX_STATES:Int = 8;
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

	public static function find(states:Array<AuraStateDef>, id:String):AuraStateDef {
		if (states != null) for (s in states) if (s.id == id) return s;
		return null;
	}
}
