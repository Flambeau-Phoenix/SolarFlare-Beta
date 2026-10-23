package solarflare.aura.signal;

/** Atomic model edits. Callers own their Undo snapshot and persistence notification. */
class AuraRuleMutations {
	public static function upgrade(r:AuraRuleDef):Void {
		if (r.version != 1) return;
		r.nodes = [for (i in 0...r.conditions.length) AuraRuleNodeDef.leaf(i)];
		r.version = 2; r.plan = null;
	}
	public static function addCondition(r:AuraRuleDef, c:AuraConditionDef, group:AuraRuleNodeDef = null):Bool {
		if (r == null || c == null || r.structureError != "" || (r.version != 1 && r.version != 2) || r.conditions.length >= AuraRuleDef.MAX_CONDITIONS) return false;
		if (group != null && (group.kind != "group" || parentOf(r, group) == null)) return false;
		if (group != null) upgrade(r);
		var index = r.conditions.length; r.conditions.push(c);
		if (r.version == 2) children(r, group).push(AuraRuleNodeDef.leaf(index));
		r.plan = null; return true;
	}
	public static function replaceConditions(r:AuraRuleDef, cs:Array<AuraConditionDef>):Void {
		r.conditions = cs; r.negate = false; r.nodes = r.version == 2 ? [for (i in 0...cs.length) AuraRuleNodeDef.leaf(i)] : [];
		r.structureError = ""; r.invalidSource = null; r.plan = null;
		if (r.presentationSource >= cs.length) r.presentationSource = 0;
	}
	public static function canAddGroup(r:AuraRuleDef, group:AuraRuleNodeDef = null):Bool {
		return r.structureError == "" && (r.version == 1 || r.version == 2)
			&& (r.version == 1 || r.prepared().groupCount < AuraRuleDef.MAX_GROUPS)
			&& depth(r, group) > 0 && depth(r, group) < AuraRuleDef.MAX_GROUP_DEPTH;
	}
	public static function addGroup(r:AuraRuleDef, group:AuraRuleNodeDef = null):AuraRuleNodeDef {
		if (!canAddGroup(r, group)) return null;
		upgrade(r); var n = new AuraRuleNodeDef(); children(r, group).push(n); r.plan = null; return n;
	}
	public static function children(r:AuraRuleDef, group:AuraRuleNodeDef):Array<AuraRuleNodeDef> return group == null ? r.nodes : group.nodes;
	public static function depth(r:AuraRuleDef, group:AuraRuleNodeDef):Int {
		if (group == null) return 1;
		if (r.version != 2 || group.kind != "group") return -1;
		var plan = r.prepared();
		for (e in plan.entries) if (e.node == group) {
			var d = 2; var p = e.parent;
			while (p > 0) { d++; p = plan.entries[p].parent; } return d;
		}
		return -1;
	}
	public static function parentOf(r:AuraRuleDef, node:AuraRuleNodeDef):Array<AuraRuleNodeDef> {
		if (r.version != 2 || node == null) return null;
		var p = r.prepared(); for (e in p.entries) if (e.node == node) return p.entries[e.parent].source;
		return null;
	}
	static function height(node:AuraRuleNodeDef):Int {
		if (node.kind != "group") return 0;
		var h = 1; for (n in node.nodes) h = Std.int(Math.max(h, 1 + height(n))); return h;
	}
	static function contains(node:AuraRuleNodeDef, target:AuraRuleNodeDef):Bool {
		if (node == target) return true;
		if (node.kind == "group") for (n in node.nodes) if (contains(n, target)) return true;
		return false;
	}
	public static function canMove(r:AuraRuleDef, node:AuraRuleNodeDef, target:AuraRuleNodeDef):Bool {
		if (r.structureError != "" || parentOf(r, node) == null || (target != null && (target.kind != "group" || parentOf(r, target) == null))) return false;
		return !contains(node, target) && depth(r, target) + height(node) <= AuraRuleDef.MAX_GROUP_DEPTH;
	}
	public static function move(r:AuraRuleDef, node:AuraRuleNodeDef, target:AuraRuleNodeDef, position:Int = -1):Bool {
		if (!canMove(r, node, target)) return false;
		var from = parentOf(r, node); var to = children(r, target);
		from.remove(node); if (position < 0 || position > to.length) position = to.length;
		to.insert(position, node); r.plan = null; return true;
	}
	public static function reorder(r:AuraRuleDef, node:AuraRuleNodeDef, offset:Int):Bool {
		var cs = parentOf(r, node); if (cs == null) return false;
		var index = cs.indexOf(node); var next = index + offset;
		if (next < 0 || next >= cs.length) return false;
		cs[index] = cs[next]; cs[next] = node; r.plan = null; return true;
	}
	public static function removeNode(r:AuraRuleDef, node:AuraRuleNodeDef):Bool {
		var from = parentOf(r, node); if (from == null) return false;
		var removed:Array<Int> = []; collect(node, removed); from.remove(node);
		removed.sort(function(a, b) return b - a);
		for (index in removed) removeCondition(r, index, false);
		r.plan = null; return true;
	}
	static function collect(n:AuraRuleNodeDef, out:Array<Int>):Void {
		if (n.kind == "condition") out.push(n.conditionIndex); else for (c in n.nodes) collect(c, out);
	}
	public static function removeCondition(r:AuraRuleDef, index:Int, removeReference:Bool = true):Void {
		if (index < 0 || index >= r.conditions.length) return;
		r.conditions.splice(index, 1);
		if (r.presentationSource > index) r.presentationSource--;
		else if (r.presentationSource == index) r.presentationSource = Std.int(Math.min(index, Math.max(0, r.conditions.length - 1)));
		if (r.version == 2) remap(r.nodes, index, removeReference);
		r.plan = null;
	}
	static function remap(nodes:Array<AuraRuleNodeDef>, removed:Int, removeReference:Bool):Void {
		var i = nodes.length;
		while (i-- > 0) {
			var n = nodes[i];
			if (n.kind == "group") remap(n.nodes, removed, removeReference);
			else if (n.conditionIndex == removed && removeReference) nodes.splice(i, 1);
			else if (n.conditionIndex > removed) n.conditionIndex--;
		}
	}
	public static function reorderFlat(r:AuraRuleDef, from:Int, to:Int):Void {
		if (r.version != 1 || from < 0 || to < 0 || from >= r.conditions.length || to >= r.conditions.length) return;
		var c = r.conditions[from]; r.conditions[from] = r.conditions[to]; r.conditions[to] = c;
		if (r.presentationSource == from) r.presentationSource = to; else if (r.presentationSource == to) r.presentationSource = from;
	}
}
