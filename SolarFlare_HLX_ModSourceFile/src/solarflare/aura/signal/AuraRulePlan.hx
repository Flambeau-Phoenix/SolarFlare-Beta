package solarflare.aura.signal;

/** Prepared bounded traversal. Created on configuration changes, reused during observation. */
class AuraRulePlan {
	public var entries:Array<AuraRulePlanEntry> = [];
	public var error:String = "";
	public var groupCount:Int = 0;
	var count:Int;
	var importError:String;
	var seen:Array<Bool> = [];
	var conditionPresence:Array<Bool> = [];
	public function new(rule:AuraRuleDef) {
		count = rule.conditions == null ? -1 : rule.conditions.length;
		if (rule.conditions != null) for (i in 0...Std.int(Math.min(count, AuraRuleDef.MAX_CONDITIONS))) conditionPresence.push(rule.conditions[i] != null);
		importError = rule.structureError;
		if (importError != "") error = importError;
		if (count < 0 || count > AuraRuleDef.MAX_CONDITIONS) fail("Rule exceeds 32 conditions or has no condition list.");
		var root = new AuraRulePlanEntry(null, -1, rule.mode, rule.negate, rule.nodes);
		entries.push(root); groupCount = 1;
		if (rule.mode != "all" && rule.mode != "any") fail("Unsupported root mode.");
		walk(root, 0, 1);
		if (count >= 0 && count <= AuraRuleDef.MAX_CONDITIONS) for (i in 0...count) {
			if (rule.conditions[i] == null) fail("Null condition.");
			if (i >= seen.length || !seen[i]) fail("Every condition must appear exactly once in the tree.");
		}
		if (error == "") for (e in entries) if (e.conditionIndex >= 0) {
			var p = e.parent;
			while (p >= 0) {
				var g = entries[p];
				if (g.negate) break;
				if (g.mode == "all") required(p, e.casts);
				p = g.parent;
			}
		}
	}
	function fail(message:String):Void { if (error == "") error = message; }
	function walk(parent:AuraRulePlanEntry, parentIndex:Int, depth:Int):Void {
		if (parent.source == null) { fail("Group nodes must be an array."); return; }
		if (parentIndex != 0 && parent.source.length == 0) fail("Empty group: add a condition or remove this group.");
		for (node in parent.source) {
			if (entries.length >= AuraRuleDef.MAX_NODES) { fail("Rule exceeds 64 nodes."); return; }
			if (node == null) { fail("Null rule node."); continue; }
			var e = new AuraRulePlanEntry(node, parentIndex, node.mode, node.negate, node.nodes);
			var index = entries.length; parent.children.push(index); entries.push(e);
			if (node.kind == "condition") {
				e.conditionIndex = node.conditionIndex;
				if (node.conditionIndex < 0 || node.conditionIndex >= count || node.conditionIndex >= AuraRuleDef.MAX_CONDITIONS)
					fail("Invalid condition reference.");
				else if (node.conditionIndex < seen.length && seen[node.conditionIndex]) fail("Duplicate condition reference.");
				else seen[node.conditionIndex] = true;
			} else if (node.kind == "group") {
				groupCount++;
				if (groupCount > AuraRuleDef.MAX_GROUPS) fail("Rule exceeds 32 groups.");
				if (depth >= AuraRuleDef.MAX_GROUP_DEPTH) { fail("Rule exceeds four group levels."); continue; }
				if (node.mode != "all" && node.mode != "any") fail("Unsupported group mode.");
				walk(e, index, depth + 1);
			} else fail("Unsupported rule node kind.");
		}
	}
	function required(index:Int, out:Array<Int>):Void {
		var e = entries[index];
		if (e.conditionIndex >= 0) { if (out.indexOf(e.conditionIndex) < 0) out.push(e.conditionIndex); return; }
		if (e.negate || e.mode != "all") return;
		for (child in e.children) required(child, out);
	}
	/** Exact shape comparison also catches callers that edited arrays without using helpers. */
	public function matches(rule:AuraRuleDef):Bool {
		if (count != (rule.conditions == null ? -1 : rule.conditions.length) || importError != rule.structureError) return false;
		for (i in 0...conditionPresence.length) if ((rule.conditions[i] != null) != conditionPresence[i]) return false;
		var root = entries[0];
		if (root.mode != rule.mode || root.negate != rule.negate || root.source != rule.nodes) return false;
		for (e in entries) {
			if (e.node != null && (e.node.kind != e.kind || e.node.conditionIndex != e.savedIndex || e.node.mode != e.mode
				|| e.node.negate != e.negate || e.node.nodes != e.source)) return false;
			if (e.source != null && e.kind == "group") {
				if (e.source.length != e.sourceCount) return false;
				for (i in 0...e.sourceCount) if (e.source[i] != e.savedNodes[i]) return false;
			}
		}
		return true;
	}
}

class AuraRulePlanEntry {
	public var node:AuraRuleNodeDef;
	public var parent:Int;
	public var kind:String;
	public var mode:String;
	public var negate:Bool;
	public var conditionIndex:Int = -1;
	public var savedIndex:Int;
	public var source:Array<AuraRuleNodeDef>;
	public var sourceCount:Int;
	public var savedNodes:Array<AuraRuleNodeDef>;
	public var children:Array<Int> = [];
	public var casts:Array<Int> = [];
	public function new(node:AuraRuleNodeDef, parent:Int, mode:String, negate:Bool, source:Array<AuraRuleNodeDef>) {
		this.node = node; this.parent = parent; this.mode = mode; this.negate = negate; this.source = source;
		kind = node == null ? "group" : node.kind; savedIndex = node == null ? -1 : node.conditionIndex;
		sourceCount = source == null ? -1 : source.length;
		savedNodes = source == null ? null : source.copy();
	}
}
