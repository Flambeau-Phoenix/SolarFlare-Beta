package solarflare.aura.signal;

import imgui.ImGui;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;
import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraRuleDef;
import solarflare.ui.VectorGlow;
import solarflare.ui.ToastManager;
import solarflare.ui.UiChrome;
import solarflare.ui.SettingsStore;

class NodeConnection {
	public var from:Int;
	public var to:Int;
	public var color:Int;

	public function new(from:Int, to:Int, color:Int = 0xFF44CCFF) {
		this.from = from;
		this.to = to;
		this.color = color;
	}
}

class ConditionNode {
	public var id:Int;
	public var posX:Float;
	public var posY:Float;
	public var label:String;
	public var condition:AuraConditionDef;

	public function new(x:Float = 100, y:Float = 100, ?cond:AuraConditionDef) {
		this.id = Std.random(999999);
		this.posX = x;
		this.posY = y;
		this.condition = cond != null ? cond : new AuraConditionDef();
		this.label = condition.signal.length > 0 ? condition.signal : "New Condition";
	}

	public function clone():ConditionNode {
		var n = new ConditionNode(posX + 30, posY + 30, condition.clone());
		n.label = label + " (Copy)";
		return n;
	}
}

/**
 * Visual flowchart condition builder with zoom, node editing, and presets.
 */
class VisualConditionBuilder {
	public var nodes:Array<ConditionNode> = [];
	public var connections:Array<NodeConnection> = [];
	public var selectedNode:Int = -1;
	public var panX:Float = 0;
	public var panY:Float = 0;
	public var zoom:Float = 1.0;
	public var gridSize:Float = 24.0;
	var editBool = new imgui.ref.BoolRef(false);
	var editFloat = new imgui.ref.FloatRef(0);
	var editNegate = new imgui.ref.BoolRef(false);

	static inline var NODE_W:Single = 200;
	static inline var NODE_H:Single = 80;
	static inline var ZOOM_MIN:Float = 0.5;
	static inline var ZOOM_MAX:Float = 2.0;

	public function new() {}

	public function syncFromRule(rule:AuraRuleDef):Void {
		if (rule == null) return;
		nodes = [];
		connections = [];
		if (rule.conditions != null) {
			var x = 30.0;
			var y = 50.0;
			for (i in 0...rule.conditions.length) {
				var cond = rule.conditions[i];
				if (cond != null) {
					nodes.push(new ConditionNode(x, y, cond));
					x += 230.0;
					if (x > 700.0) {
						x = 30.0;
						y += 150.0;
					}
				}
			}
			for (i in 0...nodes.length - 1)
				connections.push(new NodeConnection(i, i + 1));
		}
	}

	public function draw(rule:AuraRuleDef):Bool {
		if (rule == null) return false;
		var changed = false;

		UiChrome.subHeader("Node Graph");
		if (ImGui.button("+ Node##flow_add")) {
			var newNode = new ConditionNode(40 + (nodes.length * 40) % 200, 60 + (nodes.length * 40) % 150);
			newNode.condition.signal = "resource.health.ratio";
			newNode.condition.op = "lte";
			newNode.condition.numberValue = 0.35;
			nodes.push(newNode);
			if (rule.conditions == null) rule.conditions = [];
			rule.conditions.push(newNode.condition);
			if (nodes.length > 1)
				connections.push(new NodeConnection(nodes.length - 2, nodes.length - 1));
			selectedNode = nodes.length - 1;
			changed = true;
			ToastManager.info("Condition node added.");
		}
		ImGui.sameLine();
		if (ImGui.button("Layout##flow_layout")) {
			autoLayout();
			changed = true;
		}
		ImGui.sameLine();
		if (ImGui.button("-##flow_zoom_out", ImGui.vec2(28, 0))) {
			zoom = Math.max(ZOOM_MIN, zoom - 0.15);
		}
		ImGui.sameLine();
		ImGui.text(Std.string(Math.round(zoom * 100)) + "%");
		ImGui.sameLine();
		if (ImGui.button("+##flow_zoom_in", ImGui.vec2(28, 0))) {
			zoom = Math.min(ZOOM_MAX, zoom + 0.15);
		}
		ImGui.sameLine();
		if (ImGui.button("Reset View##flow_reset")) {
			panX = 0;
			panY = 0;
			zoom = 1.0;
		}

		ImGui.sameLine();
		if (ImGui.beginCombo("##flow_presets", "Presets…")) {
			if (ImGui.selectable("Low Health Alert")) {
				applyPreset(rule, "resource.health.ratio", "lte", 0.35);
				changed = true;
			}
			if (ImGui.selectable("Low Mana + Low Health")) {
				applyDualPreset(rule, "resource.mana.ratio", "lte", 0.35, "resource.health.ratio", "lte", 0.35);
				changed = true;
			}
			if (ImGui.selectable("Skill Ready")) {
				applyPreset(rule, "skill.ready", "is", 1);
				changed = true;
			}
			if (ImGui.selectable("Rage Full")) {
				applyPreset(rule, "resource.rage.ratio", "gte", 0.95);
				changed = true;
			}
			ImGui.endCombo();
		}

		ImGui.separator();

		var avail = ImGui.getContentRegionAvail();
		var editW:Single = selectedNode >= 0 ? 260 : 0;
		var canvasW:Single = avail.x - editW - (editW > 0 ? 8 : 0);
		if (canvasW < 280) canvasW = 280;
		var canvasH:Single = avail.y > 220 ? avail.y : 260;

		ImGui.beginChild("##flow_canvas", ImGui.vec2(canvasW, canvasH), 0);
		var canvasPos = ImGui.getCursorScreenPos();
		var canvasSize = ImGui.getContentRegionAvail();
		var dl = ImGui.getWindowDrawList();

		var step = gridSize * zoom;
		var startX = canvasPos.x + (panX % step);
		var startY = canvasPos.y + (panY % step);
		var x = startX;
		while (x < canvasPos.x + canvasSize.x) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, canvasPos.y), ImGui.vec2(x, canvasPos.y + canvasSize.y), 0x18FFFFFF, 1.0);
			x += step;
		}
		var y = startY;
		while (y < canvasPos.y + canvasSize.y) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(canvasPos.x, y), ImGui.vec2(canvasPos.x + canvasSize.x, y), 0x18FFFFFF, 1.0);
			y += step;
		}

		if (ImGui.isWindowHovered() && ImGui.isMouseDragging(ImGuiMouseButton.Right)) {
			var delta = ImGui.getMouseDragDelta(ImGuiMouseButton.Right);
			panX += delta.x;
			panY += delta.y;
			ImGui.resetMouseDragDelta(ImGuiMouseButton.Right);
		}
		if (ImGui.isWindowHovered()) {
			// Zoom via toolbar buttons; wheel support depends on IO field availability.
		}

		var nw = NODE_W * zoom;
		var nh = NODE_H * zoom;

		for (conn in connections) {
			if (conn.from >= 0 && conn.from < nodes.length && conn.to >= 0 && conn.to < nodes.length) {
				var nA = nodes[conn.from];
				var nB = nodes[conn.to];
				var pA = ImGui.vec2(canvasPos.x + panX + nA.posX * zoom + nw, canvasPos.y + panY + nA.posY * zoom + nh * 0.5);
				var pB = ImGui.vec2(canvasPos.x + panX + nB.posX * zoom, canvasPos.y + panY + nB.posY * zoom + nh * 0.5);
				var cp1 = ImGui.vec2(pA.x + 40 * zoom, pA.y);
				var cp2 = ImGui.vec2(pB.x - 40 * zoom, pB.y);
				ImGui.ImDrawList_AddBezierCubic(dl, pA, cp1, cp2, pB, conn.color, 2.5, 24);
			}
		}

		for (i in 0...nodes.length) {
			var node = nodes[i];
			var nx = canvasPos.x + panX + node.posX * zoom;
			var ny = canvasPos.y + panY + node.posY * zoom;
			var isSel = selectedNode == i;
			var cardBg = isSel ? 0xEE1E293B : 0xDD0F172A;
			var borderCol = isSel ? 0xFFE8D5A3 : 0x5564748B;
			var headerCol = getNodeColor(node.condition.signal);

			if (isSel)
				VectorGlow.rect(dl, nx, ny, nw, nh, 0x44E8D5A3, 6.0, 2.0);

			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(nx, ny), ImGui.vec2(nx + nw, ny + nh), cardBg, 6.0);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(nx, ny), ImGui.vec2(nx + nw, ny + 22 * zoom), headerCol, 6.0);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(nx, ny), ImGui.vec2(nx + nw, ny + nh), borderCol, 6.0, isSel ? 2.5 : 1.5);

			var title = node.condition.signal.length > 0 ? node.condition.signal : 'Condition ${i + 1}';
			if (title.length > 22) title = title.substr(0, 20) + "…";
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(nx + 8, ny + 4), 0xFFFFFFFF, title);
			var op = node.condition.op.length > 0 ? node.condition.op : "==";
			var val = node.condition.stringValue.length > 0
				? node.condition.stringValue
				: (node.condition.numberValue != 0 ? Std.string(node.condition.numberValue) : Std.string(node.condition.boolValue));
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(nx + 8, ny + 28 * zoom), 0xCC94A3B8, '$op $val');
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(nx, ny + nh * 0.5), 4.5, 0xFF38BDF8, 12);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(nx + nw, ny + nh * 0.5), 4.5, 0xFF22C55E, 12);

			ImGui.setCursorScreenPos(ImGui.vec2(nx, ny));
			ImGui.invisibleButton("##node_btn_" + node.id, ImGui.vec2(nw, nh));
			if (ImGui.isItemClicked(ImGuiMouseButton.Left))
				selectedNode = i;
			if (ImGui.isItemActive() && ImGui.isMouseDragging(ImGuiMouseButton.Left)) {
				var delta = ImGui.getMouseDragDelta(ImGuiMouseButton.Left);
				node.posX += delta.x / zoom;
				node.posY += delta.y / zoom;
				ImGui.resetMouseDragDelta(ImGuiMouseButton.Left);
				changed = true;
			}
			if (ImGui.beginPopupContextItem("##node_ctx_" + node.id)) {
				if (ImGui.menuItem("Edit Node"))
					selectedNode = i;
				if (ImGui.menuItem("Duplicate")) {
					var copy = node.clone();
					nodes.push(copy);
					if (rule.conditions != null) rule.conditions.push(copy.condition);
					selectedNode = nodes.length - 1;
					changed = true;
				}
				if (ImGui.menuItem("Delete")) {
					nodes.splice(i, 1);
					if (rule.conditions != null && i < rule.conditions.length)
						rule.conditions.splice(i, 1);
					connections = connections.filter(c -> c.from != i && c.to != i);
					for (c in connections) {
						if (c.from > i) c.from--;
						if (c.to > i) c.to--;
					}
					selectedNode = -1;
					changed = true;
				}
				ImGui.endPopup();
			}
		}
		ImGui.endChild();

		if (selectedNode >= 0 && selectedNode < nodes.length) {
			ImGui.sameLine();
			ImGui.beginChild("##flow_edit", ImGui.vec2(0, canvasH), ImGuiChildFlags.Borders | ImGuiChildFlags.AlwaysUseWindowPadding);
			if (drawNodeEditor(nodes[selectedNode], rule))
				changed = true;
			ImGui.endChild();
		}

		return changed;
	}

	function drawNodeEditor(node:ConditionNode, rule:AuraRuleDef):Bool {
		var changed = false;
		UiChrome.subHeader("Edit Node");
		ImGui.textWrapped(AuraConditionEditor.humanConditionSummary(node.condition));
		ImGui.separator();

		var c = node.condition;
		var d = AuraSignalCatalog.find(c.signal);
		var preview = d != null ? d.label : (c.signal.length > 0 ? c.signal : "Signal…");
		if (ImGui.beginCombo("Signal##node_sig", preview)) {
			for (item in AuraSignalCatalog.all()) {
				if (ImGui.selectable(item.label + "##ns_" + item.id, c.signal == item.id)) {
					c.signal = item.id;
					c.op = AuraConditionValidator.defaultOperator(item);
					c.numberValue = item.kind == Percent ? 0.35 : 1;
					node.label = item.label;
					changed = true;
				}
			}
			ImGui.endCombo();
		}

		d = AuraSignalCatalog.find(c.signal);
		if (d != null) {
			var ops = switch (d.kind) {
				case Boolean: ["is", "isNot"];
				case Percent, Count, Duration: ["lt", "lte", "eq", "gte", "gt"];
				default: ["eq", "neq", "lt", "lte", "gt", "gte"];
			};
			if (ImGui.beginCombo("Operator##node_op", c.op)) {
				for (op in ops) {
					if (ImGui.selectable(op + "##nop_" + op, c.op == op)) {
						c.op = op;
						changed = true;
					}
				}
				ImGui.endCombo();
			}
			switch (d.kind) {
				case Boolean:
					editBool.set(c.boolValue);
					if (ImGui.checkbox("Active##node_bool", editBool)) {
						c.boolValue = editBool.get();
						changed = true;
					}
				case Percent:
					editFloat.set(c.numberValue * 100);
					if (solarflare.ui.BuilderSlider.draw("Threshold##node_pct", editFloat, 0, 100, "%.0f%%")) {
						c.numberValue = editFloat.get() * 0.01;
						changed = true;
					}
				default:
					editFloat.set(c.numberValue);
					if (solarflare.ui.BuilderSlider.draw("Value##node_num", editFloat, 0, 100, "%.1f")) {
						c.numberValue = editFloat.get();
						changed = true;
					}
			}
			editNegate.set(c.negate);
			if (ImGui.checkbox("Invert (NOT)##node_neg", editNegate)) {
				c.negate = editNegate.get();
				changed = true;
			}
		}

		if (changed)
			SettingsStore.markDirty();
		ImGui.textDisabled("Right-drag canvas to pan. Scroll to zoom.");
		return changed;
	}

	function applyPreset(rule:AuraRuleDef, signal:String, op:String, value:Float):Void {
		var cond = new AuraConditionDef();
		cond.signal = signal;
		cond.op = op;
		if (op == "is" || op == "isNot")
			cond.boolValue = true;
		else
			cond.numberValue = value;
		rule.conditions = [cond];
		rule.mode = "all";
		syncFromRule(rule);
		selectedNode = 0;
		ToastManager.success("Preset applied");
	}

	function applyDualPreset(rule:AuraRuleDef, s1:String, o1:String, v1:Float, s2:String, o2:String, v2:Float):Void {
		var c1 = new AuraConditionDef();
		c1.signal = s1; c1.op = o1; c1.numberValue = v1;
		var c2 = new AuraConditionDef();
		c2.signal = s2; c2.op = o2; c2.numberValue = v2;
		rule.conditions = [c1, c2];
		rule.mode = "all";
		syncFromRule(rule);
		selectedNode = 0;
		ToastManager.success("Dual preset applied");
	}

	function autoLayout():Void {
		var x = 30.0;
		var y = 50.0;
		for (node in nodes) {
			node.posX = x;
			node.posY = y;
			x += 230.0;
			if (x > 700.0) {
				x = 30.0;
				y += 150.0;
			}
		}
	}

	function getNodeColor(signal:String):Int {
		if (signal == null || signal.length == 0) return 0xFF475569;
		var s = signal.toLowerCase();
		if (s.indexOf("hp") >= 0 || s.indexOf("health") >= 0) return 0xFFDC2626;
		if (s.indexOf("rage") >= 0) return 0xFFEA580C;
		if (s.indexOf("mana") >= 0 || s.indexOf("shield") >= 0) return 0xFF2563EB;
		if (s.indexOf("combo") >= 0) return 0xFFD97706;
		if (s.indexOf("cd") >= 0 || s.indexOf("ready") >= 0) return 0xFF059669;
		if (s.indexOf("status") >= 0 || s.indexOf("buff") >= 0) return 0xFF7C3AED;
		return 0xFF0D9488;
	}
}
