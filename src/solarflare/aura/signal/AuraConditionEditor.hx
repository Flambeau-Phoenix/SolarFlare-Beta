package solarflare.aura.signal;

import solarflare.aura.AuraDef;
import solarflare.aura.AuraEngine;
import solarflare.aura.signal.AuraSignalDescriptor;
import solarflare.aura.signal.AuraValueKind;
import solarflare.cdb.CdbAuraTable;
import solarflare.cdb.CdbUnitNames;
import solarflare.geaux.GeauxCache;
import solarflare.target.RecentTargetCache;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiChrome;
import solarflare.ui.WindowEffects;
import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;

/**
 * Conversational condition cards: "Show when [signal] is [op] [value]".
 */
class AuraConditionEditor {

	public static function draw(a:AuraDef):Void {
		if (a == null)
			return;
		if (a.rule == null)
			a.rule = new AuraRuleDef();
		var r = a.rule;

		UiChrome.subHeader("Require");
		var allMode = r.mode == "all";
		if (ImGui.radioButton("ALL conditions (AND)##rule_all_" + a.id, allMode)) {
			r.mode = "all";
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.radioButton("ANY condition (OR)##rule_any_" + a.id, !allMode)) {
			r.mode = "any";
			SettingsStore.markDirty();
		}

		// Sentence summary
		ImGui.spacing();
		var count = r.conditions != null ? r.conditions.length : 0;
		if (count == 0) {
			ImGui.textDisabled("No conditions yet — add one below.");
		} else {
			ImGui.textColored(ImGui.vec4(0.55, 0.85, 1.0, 1.0),
				allMode ? "Show when ALL of these are true:" : "Show when ANY of these is true:");
			var i = 0;
			for (c in r.conditions) {
				var join = i == 0 ? "" : (allMode ? "  and " : "  or ");
				ImGui.textWrapped(join + humanConditionSummary(c)
					+ (r.presentationSource == i && count > 1 ? "  (main trigger)" : ""));
				i++;
			}
		}
		ImGui.separator();

		var ci = 0;
		while (ci < r.conditions.length) {
			var c = r.conditions[ci];
			var removed = false;
			var border = c.negate
				? ImGui.vec4(0.85, 0.35, 0.35, 0.9)
				: ImGui.vec4(0.35, 0.75, 0.45, 0.9);
			ImGui.pushStyleColor(ImGuiCol.Border, border);
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 2.0);
			ImGui.beginChild("##condition_card_" + c.uiKey, ImGui.vec2(0, 0),
				ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding, 0);
			try {
				removed = drawConditionCard(a, r, c, ci);
			} catch (_:Dynamic) {}
			ImGui.endChild();
			ImGui.popStyleVar();
			ImGui.popStyleColor();
			var cardUi = ci < a.conditionUi.length ? a.conditionUi[ci] : null;
			if (cardUi != null && cardUi.focusUntil > haxe.Timer.stamp()) {
				var cardMin = ImGui.getItemRectMin();
				var cardSize = ImGui.getItemRectSize();
				WindowEffects.glowBorder(ImGui.getWindowDrawList(), cardMin.x, cardMin.y,
					cardMin.x + cardSize.x, cardMin.y + cardSize.y, 0xCC66C7FF, 0.28, 1.25, 5.0);
			}
			if (removed) {
				r.conditions.splice(ci, 1);
				if (r.presentationSource >= r.conditions.length)
					r.presentationSource = r.conditions.length > 0 ? r.conditions.length - 1 : 0;
				SettingsStore.markDirty();
				continue;
			}
			ImGui.spacing();
			ci++;
		}

		if (r.conditions.length < AuraRuleDef.MAX_CONDITIONS) {
			if (ImGui.button("+ Add condition##add_cond_" + a.id, ImGui.vec2(-1, 30))) {
				var newCond = new AuraConditionDef();
				newCond.signal = "resource.health.ratio";
				newCond.op = "lte";
				newCond.numberValue = 0.35;
				r.conditions.push(newCond);
				SettingsStore.markDirty();
			}
		}
	}

	public static function humanConditionSummary(c:AuraConditionDef):String {
		if (c == null)
			return "Empty condition";
		var d = AuraSignalCatalog.find(c.signal);
		var sigLabel = d != null ? d.label : (c.signal.length > 0 ? c.signal : "Signal");
		var subLabel = subjectName(c);
		var subjectPart = subLabel.length > 0 ? " (" + subLabel + ")" : "";
		var opStr = friendlyOp(c.op);
		var valStr = formatValue(c, d);
		var stmt = sigLabel + subjectPart + " is " + opStr + " " + valStr;
		if (c.negate)
			stmt = "not (" + stmt + ")";
		return stmt;
	}

	static function friendlyOp(op:String):String {
		return switch (op) {
			case "lt": "below";
			case "lte": "at most";
			case "eq": "equal to";
			case "neq": "not equal to";
			case "gte": "at least";
			case "gt": "above";
			case "is": "";
			case "isNot": "not";
			default: op;
		};
	}

	static function formatValue(c:AuraConditionDef, d:AuraSignalDescriptor):String {
		if (d == null)
			return c.boolValue ? "true" : Std.string(c.numberValue);
		return switch (d.kind) {
			case Boolean: c.boolValue ? "active" : "inactive";
			case Percent: Std.string(Math.round(c.numberValue * 100)) + "%";
			case Count: Std.string(Math.round(c.numberValue));
			case Duration: Std.string(Math.round(c.numberValue * 10) / 10) + "s";
			default: Std.string(c.numberValue);
		};
	}

	static function drawConditionCard(a:AuraDef, r:AuraRuleDef, c:AuraConditionDef, index:Int):Bool {
		var tag = a.id + "_" + c.uiKey;
		while (a.conditionUi.length <= index)
			a.conditionUi.push(new AuraConditionUiState());
		var ui = a.conditionUi[index];
		if (ui == null) {
			ui = new AuraConditionUiState();
			a.conditionUi[index] = ui;
		}
		ui.bind(c);

		ImGui.textDisabled("Condition " + (index + 1));
		ImGui.sameLine();
		if (index > 0 && ImGui.smallButton("^##cond_up_" + tag)) {
			var p = r.conditions[index - 1];
			r.conditions[index - 1] = c;
			r.conditions[index] = p;
			adjustPresentation(r, index, index - 1);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (index + 1 < r.conditions.length && ImGui.smallButton("v##cond_dn_" + tag)) {
			var n = r.conditions[index + 1];
			r.conditions[index + 1] = c;
			r.conditions[index] = n;
			adjustPresentation(r, index, index + 1);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		var remove = ImGui.smallButton("Remove##cond_rm_" + tag);
		ImGui.sameLine();
		if (ImGui.checkbox("Invert##cond_neg_" + tag, ui.negateRef)) {
			ui.pull(c);
			ui.flashContext();
			SettingsStore.markDirty();
		}
		if (r.conditions.length > 1) {
			ImGui.sameLine();
			var isMain = r.presentationSource == index;
			if (ImGui.smallButton(isMain ? "Main Trigger##cond_main_" + tag : "Use as Main Trigger##cond_main_" + tag)) {
				r.presentationSource = index;
				SettingsStore.markDirty();
			}
		}

		// Natural language row: Show when [signal] is [op] [value]
		ImGui.alignTextToFramePadding();
		ImGui.text("Show when");
		ImGui.sameLine();

		var d = AuraSignalCatalog.find(c.signal);
		var preview = d != null ? d.label : (c.signal.length > 0 ? c.signal : "what…");
		ImGui.setNextItemWidth(180);
		if (ImGui.beginCombo("##cond_sig_" + tag, preview)) {
			var currentGroup = "";
			for (item in AuraSignalCatalog.all()) {
				if (item.group != currentGroup) {
					currentGroup = item.group;
					ImGui.separatorText(item.group);
				}
				if (ImGui.selectable(item.label + "##sig_" + tag + item.id, c.signal == item.id)) {
					c.signal = item.id;
					c.op = AuraConditionValidator.defaultOperator(item);
					c.subject = "";
					c.subjectLabel = "";
					c.numberValue = item.kind == Percent ? 0.35 : 1;
					c.boolValue = true;
					ui.sync(c);
					ui.flashContext();
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}

		d = AuraSignalCatalog.find(c.signal);
		if (d != null && d.subjectKind.length > 0) {
			drawSubjectInline(a, c, ui, d.subjectKind, tag);
		}

		ImGui.sameLine();
		ImGui.text("is");
		ImGui.sameLine();
		if (d != null)
			drawOperatorInline(c, ui, d, tag);

		if (d != null && d.id != "status.present") {
			ImGui.sameLine();
			switch (d.kind) {
				case Boolean:
					if (ImGui.checkbox("active##cond_bool_" + tag, ui.boolRef)) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Percent:
					ImGui.setNextItemWidth(100);
					if (solarflare.ui.BuilderSlider.draw("##cond_pct_" + tag, ui.percentRef, 0, 100, "%.0f%%")) {
						ui.pullPercent(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Count:
					ImGui.setNextItemWidth(90);
					if (solarflare.ui.BuilderSlider.draw("##cond_cnt_" + tag, ui.numberRef, 0, 100, "%.0f")) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Duration:
					ImGui.setNextItemWidth(100);
					if (solarflare.ui.BuilderSlider.draw("##cond_dur_" + tag, ui.numberRef, 0, 60, "%.1fs")) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				default:
					ImGui.setNextItemWidth(90);
					if (solarflare.ui.BuilderSlider.draw("##cond_num_" + tag, ui.numberRef, 0, 100, "%.1f")) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
			}
		}

		ImGui.textWrapped(humanConditionSummary(c));
		return remove;
	}

	static function drawOperatorInline(c:AuraConditionDef, ui:AuraConditionUiState, d:AuraSignalDescriptor, tag:String):Void {
		var ops = switch (d.kind) {
			case Boolean: ["is", "isNot"];
			case Percent, Count, Duration: ["lt", "lte", "eq", "gte", "gt"];
			default: ["eq", "neq", "lt", "lte", "gt", "gte"];
		};
		var label = friendlyOp(c.op);
		if (label.length == 0) label = c.op;
		ImGui.setNextItemWidth(110);
		if (ImGui.beginCombo("##cond_op_" + tag, label)) {
			for (op in ops) {
				if (ImGui.selectable(friendlyOp(op) + "##op_" + tag + op, c.op == op)) {
					c.op = op;
					ui.flashContext();
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
	}

	static function subjectName(c:AuraConditionDef):String {
		var name = solarflare.cdb.AuraCatalog.label(c.subject);
		if (solarflare.cdb.AuraCatalog.validName(name)) return name;
		return solarflare.cdb.AuraCatalog.validName(c.subjectLabel) ? c.subjectLabel : c.subject;
	}

	static function drawSubjectInline(a:AuraDef, c:AuraConditionDef, ui:AuraConditionUiState, kind:String, tag:String):Void {
		// Catalog names are owned strings, independent of live actors / skill-book objects.
		var name = subjectName(c);
		if (name.length > 0) c.subjectLabel = name;
		var pickerLabel = kind == "unit" ? "Select Unit" : (kind.indexOf("skill") >= 0 ? "Select Skill" : "Select Status");
		if (ImGui.button(pickerLabel + "##pick_" + tag))
			ImGui.openPopup("##subjects_" + tag);
		ImGui.textWrapped(name.length > 0 ? name + " [" + c.subject + "]" : "No selection");
		ImGui.setNextWindowSize(ImGui.vec2(620, 500), imgui.Enums.ImGuiCond.Appearing);
		if (!ImGui.beginPopup("##subjects_" + tag)) return;
		try {
		ImGui.text("Select " + kind + " by name or ID");
		if (ImGui.inputText("Search##subject_search_" + tag, ui.searchBuf, AuraConditionUiState.SEARCH_BUF))
			ui.search = ByteUtil.readString(ui.searchBuf, AuraConditionUiState.SEARCH_BUF, true).toLowerCase();
		ImGui.textDisabled("Saved IDs remain selected even when unit or skill is absent.");
		solarflare.ui.HudChrome.safeChild("##subject_list_" + tag, ImGui.vec2(0, 0), 0, function() {
		{
			for (entry in solarflare.cdb.AuraCatalog.entries)
				if (entry.kind == (kind == "unit" ? "unit" : (kind.indexOf("skill") >= 0 ? "skill" : "statustype")))
					drawSubjectRow(c, ui, entry.id, entry.name, tag);
		}
		}, ImGuiChildFlags.Borders);
		} catch (e:Dynamic) {
			ImGui.endPopup();
			throw e;
		}
		ImGui.endPopup();
	}

	static function drawSubjectRow(c:AuraConditionDef, ui:AuraConditionUiState, id:String, name:String, tag:String):Void {
		if (ui.search.length > 0 && (id + " " + name).toLowerCase().indexOf(ui.search) < 0) return;
		if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, 28))) {
			ImGui.dummy(ImGui.vec2(1, 28));
			return;
		}
		if (!solarflare.ui.GameIcons.imageKey(id, 28, 28)) ImGui.dummy(ImGui.vec2(28, 28));
		ImGui.sameLine();
		if (ImGui.selectable(name + " [" + id + "]##subject_" + tag + id, c.subject == id)) {
			c.subject = id;
			c.subjectLabel = name;
			ui.sync(c);
			ui.flashContext();
			SettingsStore.markDirty();
			ImGui.closeCurrentPopup();
		}
	}

	static function adjustPresentation(r:AuraRuleDef, fromIdx:Int, toIdx:Int):Void {
		if (r.presentationSource == fromIdx)
			r.presentationSource = toIdx;
		else if (r.presentationSource == toIdx)
			r.presentationSource = fromIdx;
	}
}
