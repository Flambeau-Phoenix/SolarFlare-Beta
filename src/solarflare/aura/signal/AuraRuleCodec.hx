package solarflare.aura.signal;

class AuraRuleCodec {
	public static function toObj(rule:AuraRuleDef):Dynamic {
		if (rule == null) return null;
		if (rule.invalidSource != null) return haxe.Json.parse(haxe.Json.stringify(rule.invalidSource));
		var cs:Array<Dynamic> = [];
		if (rule.conditions != null) for (c in rule.conditions) {
			if (c == null) { if (rule.version == 2) cs.push(null); continue; }
			cs.push({
			signal: c.signal,
			subject: c.signal=="custom.script" ? c.subject : solarflare.EngineText.cleanId(c.subject),
			subjectLabel: solarflare.EngineText.cleanId(c.subjectLabel),
			op: c.op,
			numberValue: c.numberValue, boolValue: c.boolValue, stringValue: c.stringValue, negate: c.negate
			});
		}
		var out:Dynamic = {version: rule.version, mode: rule.mode, presentationSource: rule.presentationSource, conditions: cs};
		if (rule.version == 2) { out.negate = rule.negate; out.nodes = encodeNodes(rule.nodes); }
		return out;
	}
	static function encodeNodes(nodes:Array<AuraRuleNodeDef>):Array<Dynamic> {
		if (nodes == null) return null;
		return [for (n in nodes) n == null ? null : n.kind == "condition"
			? {kind: "condition", conditionIndex: n.conditionIndex}
			: cast {kind: n.kind, mode: n.mode, negate: n.negate, nodes: encodeNodes(n.nodes)}];
	}
	static function decodeNodes(nodes:Array<Dynamic>):Array<AuraRuleNodeDef> {
		return [for (d in nodes) {
			var n = new AuraRuleNodeDef(d.kind);
			if (n.kind == "condition") n.conditionIndex = d.conditionIndex;
			else { n.mode = d.mode; n.negate = d.negate == true; n.nodes = decodeNodes(d.nodes); }
			n;
		}];
	}
	public static function fromDyn(d:Dynamic):AuraRuleDef {
		if (d == null) return null;
		var r = new AuraRuleDef();
		try if (d.version != null) r.version = Std.int(d.version) catch (_:Dynamic) {}
		try if (d.mode != null) r.mode = Std.string(d.mode) catch (_:Dynamic) {}
		try if (d.presentationSource != null) r.presentationSource = Std.int(d.presentationSource) catch (_:Dynamic) {}
		if (r.version != 1) {
			// Empty editor drafts remain repairable after settings reload; package imports are stricter.
			r.structureError = AuraRuleStructure.validateObject(d, true);
			if (r.structureError != "") r.invalidSource = haxe.Json.parse(haxe.Json.stringify(d));
			else { r.negate = d.negate == true; r.nodes = decodeNodes(d.nodes); }
		}
		r.conditions = [];
		try {
			var arr:Array<Dynamic> = cast d.conditions;
			if (arr != null) for (item in arr) {
				if (r.conditions.length >= AuraRuleDef.MAX_CONDITIONS) break;
				if (item == null) continue;
				var c = new AuraConditionDef();
				if (item.signal != null) c.signal = Std.string(item.signal);
				if (item.subject != null) c.subject = c.signal=="custom.script" ? Std.string(item.subject) : solarflare.EngineText.cleanId(item.subject);
				if (item.subjectLabel != null) c.subjectLabel = solarflare.EngineText.cleanId(item.subjectLabel);
				if (item.op != null) c.op = Std.string(item.op);
				if (item.numberValue != null) c.numberValue = item.numberValue;
				if (item.boolValue == true) c.boolValue = true;
				if (item.stringValue != null) c.stringValue = Std.string(item.stringValue);
				if (item.negate == true) c.negate = true;
				if (StringTools.startsWith(c.signal, "status.") || StringTools.startsWith(c.signal, "target.status.") || StringTools.startsWith(c.signal,"event.status."))
					c.subject = solarflare.cdb.CdbAuraTable.statusSubjectId(c.subject);
				r.conditions.push(c);
			}
		} catch (_:Dynamic) {}
		AuraConditionValidator.validateRule(r);
		return r;
	}
}
