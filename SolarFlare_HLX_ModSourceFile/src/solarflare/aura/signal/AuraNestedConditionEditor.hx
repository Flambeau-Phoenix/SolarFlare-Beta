package solarflare.aura.signal;

import imgui.ImGui;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;

/** Shared inline tree editor; no independent window or live game access. */
class AuraNestedConditionEditor {
	public static function draw(a:AuraRuleEditorContext, prominent:Bool, bossFocusId:String):Void {
		var r = a.rule;
		if (r.version != 2 || r.structureError != "") {
			ImGui.textWrapped(r.structureError != "" ? r.structureError : "Unsupported rule version."); return;
		}
		UiChrome.subHeader("Require");
		ImGui.textWrapped(a.summaryText());
		var error = r.prepared().error;
		if (error != "") ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_DANGER), error);
		ImGui.textDisabled(r.conditions.length + " / 32 conditions; four group levels maximum.");
		drawGroup(a, null, 1, bossFocusId);
	}
	static function snapshot(a:AuraRuleEditorContext):Void { if (a.snapshot != null) a.snapshot(); }
	static function changed(a:AuraRuleEditorContext):Bool { a.rule.plan = null; SettingsStore.markDirty(); return true; }
	static function status(a:AuraRuleEditorContext, node:AuraRuleNodeDef):String {
		var r = a.result; var p = a.rule.prepared();
		if (p.error != "") return "Error";
		if (r == null || r.plan != p) return "Waiting";
		for (i in 0...p.entries.length) if (p.entries[i].node == node) {
			if (hasError(r, p, i)) return "Error";
			return !r.nodeKnown[i] ? "Waiting" : r.nodeHit[i] ? "True" : "False";
		}
		return "Waiting";
	}
	static function hasError(r:AuraRuleResult, p:AuraRulePlan, index:Int):Bool {
		var e = p.entries[index];
		if (e.conditionIndex >= 0) {
			var code = r.conditions[e.conditionIndex].code;
			return code == UNKNOWN_SIGNAL || code == INVALID_OPERATOR || code == INVALID_RULE || code == NON_FINITE || code == MISSING_SUBJECT;
		}
		for (child in e.children) if (hasError(r, p, child)) return true;
		return false;
	}
	static function drawGroup(a:AuraRuleEditorContext, group:AuraRuleNodeDef, depth:Int, bossFocusId:String):Bool {
		var r = a.rule; var key = a.id + (group == null ? "_root" : "_group_" + group.uiKey);
		var mode = group == null ? r.mode : group.mode; var negate = group == null ? r.negate : group.negate;
		var open = UiChrome.groupHeader((negate ? "NOT " : "") + (mode == "all" ? "ALL" : "ANY") + "  -  " + status(a, group) + "###" + key, true);
		if (!open) return false;
		if (ImGui.radioButton("ALL##all_" + key, mode == "all")) {
			snapshot(a); if (group == null) r.mode = "all"; else group.mode = "all"; return changed(a);
		}
		ImGui.sameLine();
		if (ImGui.radioButton("ANY##any_" + key, mode == "any")) {
			snapshot(a); if (group == null) r.mode = "any"; else group.mode = "any"; return changed(a);
		}
		ImGui.sameLine();
		if (ImGui.smallButton((negate ? "NOT: on###not_" : "NOT: off###not_") + key)) {
			snapshot(a); if (group == null) r.negate = !r.negate; else group.negate = !group.negate; return changed(a);
		}
		if (group != null && toolbar(a, group)) return true;
		var nodes = AuraRuleMutations.children(r, group);
		if (nodes == null) { ImGui.textDisabled("Invalid group nodes."); return false; }
		if (nodes.length == 0) ImGui.textDisabled(group == null ? "No conditions yet." : "Add a condition or remove this empty group.");
		for (node in nodes) {
			if (node == null) continue;
			if (node.kind == "group") {
				if (depth >= AuraRuleDef.MAX_GROUP_DEPTH) { ImGui.textDisabled("Group exceeds the nesting limit."); continue; }
				ImGui.indent(12);
				var edited = false;
				try { edited = drawGroup(a, node, depth + 1, bossFocusId); }
				catch (e:Dynamic) { UiScope.reportOnce("nested group", key, e); }
				ImGui.unindent(12);
				if (edited) return true;
			} else if (node.kind == "condition" && node.conditionIndex >= 0 && node.conditionIndex < r.conditions.length) {
				var c = r.conditions[node.conditionIndex]; if (c == null) continue;
				if (toolbar(a, node)) return true;
				var remove = false;
				UiScope.child("##nested_card_" + a.id + "_" + c.uiKey, ImGui.vec2(0, 0), function() {
					remove = AuraConditionEditor.drawConditionCard(a, r, c, node.conditionIndex, bossFocusId, true);
				}, imgui.Enums.ImGuiChildFlags.AutoResizeY | imgui.Enums.ImGuiChildFlags.Borders);
				if (remove) { snapshot(a); AuraRuleMutations.removeNode(r, node); return changed(a); }
			}
		}
		ImGui.beginDisabled(r.conditions.length >= AuraRuleDef.MAX_CONDITIONS);
		var add = ImGui.smallButton("+ Condition##add_" + key);
		ImGui.endDisabled();
		if (add) {
			snapshot(a); var c = new AuraConditionDef(); c.signal = "resource.health.ratio"; c.op = "lte"; c.numberValue = 0.35;
			AuraRuleMutations.addCondition(r, c, group); return changed(a);
		}
		ImGui.sameLine();
		ImGui.beginDisabled(!AuraRuleMutations.canAddGroup(r, group));
		var addGroup = ImGui.smallButton("+ Group##add_group_" + key);
		ImGui.endDisabled();
		if (addGroup) { snapshot(a); AuraRuleMutations.addGroup(r, group); return changed(a); }
		return false;
	}
	static function toolbar(a:AuraRuleEditorContext, node:AuraRuleNodeDef):Bool {
		var r = a.rule; var p = r.prepared(); var parent = AuraRuleMutations.parentOf(r, node);
		if (parent == null) return false;
		var key = a.id + "_node_" + node.uiKey; var index = parent.indexOf(node);
		ImGui.beginDisabled(index == 0);
		var up = ImGui.smallButton("Up##up_" + key); ImGui.endDisabled(); ImGui.sameLine();
		ImGui.beginDisabled(index >= parent.length - 1);
		var down = ImGui.smallButton("Down##down_" + key); ImGui.endDisabled();
		if (up || down) { snapshot(a); AuraRuleMutations.reorder(r, node, up ? -1 : 1); return changed(a); }
		var parentNode:AuraRuleNodeDef = null; var grandparent:AuraRuleNodeDef = null;
		for (e in p.entries) if (e.node == node) {
			var pe = p.entries[e.parent]; parentNode = pe.node;
			if (pe.parent >= 0) grandparent = p.entries[pe.parent].node;
		}
		ImGui.sameLine();
		ImGui.beginDisabled(parentNode == null);
		var out = ImGui.smallButton("Move out##out_" + key); ImGui.endDisabled();
		if (out) {
			snapshot(a); var destination = AuraRuleMutations.children(r, grandparent);
			AuraRuleMutations.move(r, node, grandparent, destination.indexOf(parentNode) + 1); return changed(a);
		}
		ImGui.setNextItemWidth(150);
		if (ImGui.beginCombo("##into_" + key, "Move into group")) {
			var ordinal = 0;
			for (sibling in parent) if (sibling != null && sibling.kind == "group") {
				ordinal++; ImGui.beginDisabled(!AuraRuleMutations.canMove(r, node, sibling));
				var selected = ImGui.selectable("Group " + ordinal + " (" + (sibling.negate ? "NOT " : "") + sibling.mode.toUpperCase() + ")##into_" + key + sibling.uiKey);
				ImGui.endDisabled();
				if (selected) {
					snapshot(a); AuraRuleMutations.move(r, node, sibling); changed(a); ImGui.endCombo(); return true;
				}
			}
			ImGui.endCombo();
		}
		if (node.kind == "group" && ImGui.smallButton("Delete group##delete_" + key)) {
			snapshot(a); AuraRuleMutations.removeNode(r, node); return changed(a);
		}
		return false;
	}
}
