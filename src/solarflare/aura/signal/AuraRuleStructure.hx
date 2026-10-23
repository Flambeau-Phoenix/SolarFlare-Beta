package solarflare.aura.signal;

/** Strict wire-shape validation before decoding, shared by settings and package imports. */
class AuraRuleStructure {
	var seen:Array<Bool> = [];
	var groups:Int = 1;
	var total:Int = 1;
	var count:Int;
	var allowEmptyGroups:Bool;
	function new(count:Int, allowEmptyGroups:Bool) { this.count = count; this.allowEmptyGroups = allowEmptyGroups; }
	public static function validateObject(d:Dynamic, allowEmptyGroups:Bool = false):String {
		try {
			if (d == null || d.version != 2) return "Unsupported nested rule version.";
			if (d.mode != "all" && d.mode != "any") return "Unsupported root mode.";
			if (d.negate != null && !Std.isOfType(d.negate, Bool)) return "Invalid root NOT value.";
			if (!Std.isOfType(d.conditions, Array)) return "Conditions must be an array.";
			var cs:Array<Dynamic> = cast d.conditions;
			if (cs.length > AuraRuleDef.MAX_CONDITIONS) return "Rule exceeds 32 conditions.";
			for (c in cs) if (c == null) return "Null condition.";
			if (cs.length > 0 && (!Std.isOfType(d.presentationSource, Int) || d.presentationSource < 0 || d.presentationSource >= cs.length))
				return "Invalid presentation source.";
			var check = new AuraRuleStructure(cs.length, allowEmptyGroups);
			var error = check.walk(d.nodes, 1, true);
			if (error != "") return error;
			for (i in 0...cs.length) if (i >= check.seen.length || !check.seen[i]) return "Every condition must appear exactly once in the tree.";
			return "";
		} catch (_:Dynamic) { return "Malformed nested rule."; }
	}
	function walk(value:Dynamic, depth:Int, root:Bool):String {
		if (!Std.isOfType(value, Array)) return "Group nodes must be an array.";
		var nodes:Array<Dynamic> = cast value;
		if (!root && nodes.length == 0 && !allowEmptyGroups) return "Empty group: add a condition or remove this group.";
		for (n in nodes) {
			if (++total > AuraRuleDef.MAX_NODES) return "Rule exceeds 64 nodes.";
			if (n == null) return "Null rule node.";
			if (n.kind == "condition") {
				if (!Std.isOfType(n.conditionIndex, Int) || n.conditionIndex < 0 || n.conditionIndex >= count) return "Invalid condition reference.";
				var index:Int = n.conditionIndex;
				if (index < seen.length && seen[index]) return "Duplicate condition reference.";
				if (n.nodes != null || n.mode != null || n.negate != null) return "Condition nodes cannot contain group fields.";
				seen[index] = true;
			} else if (n.kind == "group") {
				if (++groups > AuraRuleDef.MAX_GROUPS) return "Rule exceeds 32 groups.";
				if (depth >= AuraRuleDef.MAX_GROUP_DEPTH) return "Rule exceeds four group levels.";
				if (n.mode != "all" && n.mode != "any") return "Unsupported group mode.";
				if (n.conditionIndex != null) return "Group nodes cannot reference a condition.";
				if (n.negate != null && !Std.isOfType(n.negate, Bool)) return "Invalid group NOT value.";
				var error = walk(n.nodes, depth + 1, false); if (error != "") return error;
			} else return "Unsupported rule node kind.";
		}
		return "";
	}
}
