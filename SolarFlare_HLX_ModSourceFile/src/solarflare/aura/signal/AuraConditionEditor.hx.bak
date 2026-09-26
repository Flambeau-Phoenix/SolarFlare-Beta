package solarflare.aura.signal;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiStyleVar;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraEngine;
import solarflare.aura.signal.AuraSignalDescriptor;
import solarflare.aura.signal.AuraValueKind;
import solarflare.ui.ByteUtil;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
import solarflare.ui.WindowEffects;

/**
 * Conversational condition cards: "Show when [signal] is [op] [value]".
 * Restores natural single-sentence flow while preserving robust layout math.
 */
class AuraConditionEditor {
	public static function draw(a:AuraDef, prominent:Bool = false, onBatchSnapshot:Void->Void = null, bossFocusId:String = ""):Void {
		if (a == null) return;
		if (a.rule == null) a.rule = new AuraRuleDef();
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
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, prominent ? 2.0 : 1.5);
			ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(10, 8));
			ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(6, 4));

			ImGui.beginChild("##condition_card_" + c.uiKey, ImGui.vec2(0, 0),
				ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding, 0);
			try {
				removed = drawConditionCard(a, r, c, ci, bossFocusId);
			} catch (_:Dynamic) {}
			ImGui.endChild();

			ImGui.popStyleVar(3);
			ImGui.popStyleColor();

			var cardUi = ci < a.conditionUi.length ? a.conditionUi[ci] : null;
			if (cardUi != null && cardUi.focusUntil > haxe.Timer.stamp()) {
				var cardMin = ImGui.getItemRectMin();
				var cardSize = ImGui.getItemRectSize();
				WindowEffects.glowBorder(ImGui.getWindowDrawList(), cardMin.x, cardMin.y,
					cardMin.x + cardSize.x, cardMin.y + cardSize.y, 0xCC66C7FF, 0.28, 1.25, 5.0);
			}

			if (removed) {
				if (onBatchSnapshot != null) onBatchSnapshot();
				r.conditions.splice(ci, 1);
				if (r.presentationSource >= r.conditions.length)
					r.presentationSource = r.conditions.length > 0 ? r.conditions.length - 1 : 0;
				SettingsStore.markDirty();
				continue;
			}
			ImGui.spacing();
			ci++;
			if (ci < r.conditions.length)
				drawJoinChevron(allMode);
		}

		if (r.conditions.length < AuraRuleDef.MAX_CONDITIONS) {
			if (UiChrome.accentButton("+ Add Condition##add_cond_" + a.id, ImGui.vec2(-1, 32))) {
				if (onBatchSnapshot != null) onBatchSnapshot();
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
		if (c == null) return "Empty condition";
		var d = AuraSignalCatalog.find(c.signal);
		var sigLabel = d != null ? d.label : (c.signal.length > 0 ? c.signal : "Signal");
		var subLabel = subjectName(c);
		var subjectPart = subLabel.length > 0 ? ' ($subLabel)' : "";
		var opStr = friendlyOp(c.op);
		var valStr = formatValue(c, d);
		var stmt = sigLabel + subjectPart + " " + opStr + " " + valStr;
		if (c.negate) stmt = "not (" + stmt + ")";
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
			case "is": "is";
			case "isNot": "is not";
			case "within": "within";
			case "present": "present";
			case "absent": "absent";
			default: op;
		};
	}

	static function formatValue(c:AuraConditionDef, d:AuraSignalDescriptor):String {
		if (d == null) return c.boolValue ? "true" : Std.string(c.numberValue);
		return switch (d.kind) {
			case Boolean: c.boolValue ? "active" : "inactive";
			case Percent: Std.string(Math.round(c.numberValue * 100)) + "%";
			case Count: Std.string(Math.round(c.numberValue));
			case Duration: Std.string(Math.round(c.numberValue * 10) / 10) + "s";
			default: Std.string(c.numberValue);
		};
	}

	/**
	 * AND / OR joiner drawn between condition cards. The join used to exist only as the
	 * words "and" / "or" inside the summary sentence, at body-text size and weight, so
	 * the structure of a multi-condition rule was invisible while building it.
	 */
	static function drawJoinChevron(allMode:Bool):Void {
		var label = allMode ? "AND" : "OR";
		var tint = allMode
			? ImGui.vec4(0.33, 0.80, 0.44, 1.0)
			: ImGui.vec4(0.97, 0.72, 0.30, 1.0);
		var line = ImGui.colorConvertFloat4ToU32(tint);
		var fill = ImGui.colorConvertFloat4ToU32(ImGui.vec4(tint.x, tint.y, tint.z, 0.18));

		var h:Single = 26;
		var p = ImGui.getCursorScreenPos();
		var avail = ImGui.getContentRegionAvail().x;
		// Reserve the band first: the arrow is draw-list only and would otherwise sit
		// outside the layout box and trip ImGui's bounds assert.
		ImGui.dummy(ImGui.vec2(avail, h));

		var dl = ImGui.getWindowDrawList();
		var cx = p.x + 22;
		var cy = p.y + h * 0.5;
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx, p.y + 2), ImGui.vec2(cx, p.y + h - 9), line, 2.5);
		ImGui.ImDrawList_AddTriangleFilled(dl,
			ImGui.vec2(cx, p.y + h - 2),
			ImGui.vec2(cx - 6, p.y + h - 10),
			ImGui.vec2(cx + 6, p.y + h - 10), line);

		var ts = ImGui.calcTextSize(label);
		var px = cx + 14;
		var y0 = cy - ts.y * 0.5 - 3;
		var y1 = cy + ts.y * 0.5 + 3;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(px, y0), ImGui.vec2(px + ts.x + 16, y1), fill, 5);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(px, y0), ImGui.vec2(px + ts.x + 16, y1), line, 5, 1.5);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(px + 8, cy - ts.y * 0.5), line, label);
	}

	static function drawConditionCard(a:AuraDef, r:AuraRuleDef, c:AuraConditionDef, index:Int, bossFocusId:String):Bool {
		var tag = a.id + "_" + c.uiKey;
		while (a.conditionUi.length <= index)
			a.conditionUi.push(new AuraConditionUiState());
		var ui = a.conditionUi[index];
		if (ui == null) {
			ui = new AuraConditionUiState();
			a.conditionUi[index] = ui;
		}
		ui.bind(c);

		// Header row
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

		// Danger-fill Remove button
		var theme = ThemePalette.current();
		var dangerFill = ImGui.vec4(theme.cellBg.x * 0.55 + 0.45, theme.cellBg.y * 0.55, theme.cellBg.z * 0.55, 1.0);
		var dangerHover = ImGui.vec4(theme.cellBg.x * 0.35 + 0.55, theme.cellBg.y * 0.35, theme.cellBg.z * 0.35, 1.0);
		ImGui.pushStyleColor(ImGuiCol.Button, dangerFill);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, dangerHover);
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, theme.windowBg);
		ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.90, 0.35, 0.35, 1.0));
		ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.95, 0.50, 0.50, 1.0));
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.5);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 4.0);
		var remove = ImGui.smallButton("Remove##cond_rm_" + tag);
		ImGui.popStyleVar(2);
		ImGui.popStyleColor(5);

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

		ImGui.dummy(ImGui.vec2(0, 2));

		// Natural language row: Show when [signal] is [op] [value]
		ImGui.alignTextToFramePadding();
		ImGui.text("Show when");
		ImGui.sameLine();

		var d = AuraSignalCatalog.find(c.signal);
		var preview = d != null ? d.label : (c.signal.length > 0 ? c.signal : "Select signal…");
		ImGui.setNextItemWidth(210);
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
			ImGui.sameLine();
			drawSubjectInline(a, c, ui, d.subjectKind, tag, bossFocusId);
		}

		if (d != null) {
			ImGui.sameLine();
			drawOperatorInline(c, ui, d, tag);
		}

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

		// Help tips when relevant
		if (d != null) {
			if (d.id == "status.count" || d.id == "status.overflow")
				ImGui.textDisabled("Count is full character status container length. Overflow means > " + AuraSignalFrame.MAX_STATUSES + " entries.");
			else if (d.id == "skill.instantReady")
				ImGui.textDisabled("Skill script shouldPlayInstantly (e.g. Staff_Craft_S1). For buffs, prefer Statuses.");
			else if (d.id == "event.cast.recent")
				ImGui.textDisabled("Seconds since cast. Use 'within' operator for windows (e.g. within 5s).");
		}

		ImGui.dummy(ImGui.vec2(0, 2));
		ImGui.textColored(theme.accent, "Active: " + humanConditionSummary(c));
		return remove;
	}

	static function drawOperatorInline(c:AuraConditionDef, ui:AuraConditionUiState, d:AuraSignalDescriptor, tag:String):Void {
		var ops:Array<String>;
		// status.present is Boolean-kinded but AuraConditionValidator.isValidOperator
		// accepts only present/absent for it. Without this case the generic Boolean
		// list offers is/isNot, so opening the combo silently writes an operator the
		// validator rejects and compareValue routes to boolValue instead of present.
		if (d != null && d.id == "status.present")
			ops = ["present", "absent"];
		else if (d != null && d.id == "event.cast.recent")
			ops = ["within", "lt", "lte", "eq", "gte", "gt"];
		else
			ops = switch (d.kind) {
				case Boolean: ["is", "isNot"];
				case Percent, Count, Duration: ["lt", "lte", "eq", "gte", "gt"];
				default: ["eq", "neq", "lt", "lte", "gt", "gte"];
			};

		var label = friendlyOp(c.op);
		if (label.length == 0) label = c.op;
		ImGui.setNextItemWidth(104);
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
		// subjectLabel is the stable user-facing identity selected in the catalog.
		// `subject` may intentionally be rewritten to an engine status id.
		if (solarflare.cdb.AuraCatalog.validName(c.subjectLabel)) return c.subjectLabel;
		var name = solarflare.cdb.AuraCatalog.label(c.subject);
		if (solarflare.cdb.AuraCatalog.validName(name)) return name;
		return c.subject;
	}

	static function drawSubjectInline(a:AuraDef, c:AuraConditionDef, ui:AuraConditionUiState, kind:String, tag:String, bossFocusId:String):Void {
		var name = subjectName(c);
		if (name.length > 0) c.subjectLabel = name;

		// Same beginCombo pattern as AuraBuilder.drawWizardCatalogPicker / signal combo.
		// ghostButton+popup inside AutoResizeY condition cards eats clicks and sticks.
		var previewText = name.length > 0 ? name : "Select " + kind + "…";
		ImGui.setNextItemWidth(210);
		if (!ImGui.beginCombo("##cond_subj_" + tag, previewText)) {
			if (ImGui.isItemHovered() && c.subject != null && c.subject.length > 0)
				ImGui.setTooltip(c.subjectLabel + " [" + c.subject + "]");
			return;
		}
		try {
			if (ImGui.isItemHovered() && c.subject != null && c.subject.length > 0)
				ImGui.setTooltip(c.subjectLabel + " [" + c.subject + "]");

			ImGui.text("Search " + kind + " catalog");
			if (ImGui.inputText("##cond_subj_search_" + tag, ui.searchBuf, AuraConditionUiState.SEARCH_BUF))
				ui.search = ByteUtil.readString(ui.searchBuf, AuraConditionUiState.SEARCH_BUF, true).toLowerCase();
			ImGui.separator();

			// Child begin always pairs with end (AGENTS.md); content only when open.
			var childOpen = ImGui.beginChild("##cond_subj_list_" + tag, ImGui.vec2(440, 280), ImGuiChildFlags.Borders);
			try {
				if (childOpen)
					drawSubjectList(c, ui, kind, tag, bossFocusId);
			} catch (e:Dynamic) {
				ImGui.endChild();
				throw e;
			}
			ImGui.endChild();
		} catch (e:Dynamic) {
			ImGui.endCombo();
			throw e;
		}
		ImGui.endCombo();
	}

	static function drawSubjectList(c:AuraConditionDef, ui:AuraConditionUiState, kind:String, tag:String, bossFocusId:String):Void {
		var statusSkills:Array<{id:String, name:String, kind:String}> = [];
		var otherSkills:Array<{id:String, name:String, kind:String}> = [];
		var categories:Array<{id:String, name:String, kind:String}> = [];
		var units:Array<{id:String, name:String, kind:String}> = [];

		for (entry in solarflare.cdb.AuraCatalog.entries) {
			if (!solarflare.cdb.AuraCatalog.matchesSubject(entry.kind, kind)) continue;
			if (!solarflare.cdb.AuraCatalog.entryMatchesSearch(entry, ui.search)) continue;
			if (kind == "status") {
				var rank = solarflare.cdb.AuraCatalog.statusPickRank(entry.id, entry.kind);
				if (rank == 0) statusSkills.push(entry);
				else if (rank == 2) otherSkills.push(entry);
				else categories.push(entry);
			} else if (entry.kind == "unit") {
				units.push(entry);
			} else {
				otherSkills.push(entry);
			}
		}

		var shown = 0;
		if (kind == "status") {
			var observed:Array<{id:String, name:String, kind:String}> = [];
			var frame = AuraEngine.signalFrame();
			if (frame != null) for (i in 0...frame.statusCount) {
				var status = frame.statuses[i];
				if (!status.known || !status.present) continue;
				var label = solarflare.cdb.AuraCatalog.label(status.rawId);
				if (solarflare.cdb.AuraCatalog.matchesSearch(status.rawId, label, ui.search))
					observed.push({id: status.rawId, name: label, kind: "active status"});
			}
			shown += drawSubjectSection(c, ui, tag + "_live", "Currently on your character", observed, kind);
			shown += drawSubjectSection(c, ui, tag, "Status / Proc IDs", statusSkills, kind);
			shown += drawSubjectSection(c, ui, tag, "Other skills", otherSkills, kind);
		} else if (kind == "unit") {
			var recent:Array<{id:String, name:String, kind:String}> = [];
			var rids = solarflare.target.RecentTargetCache.ids();
			var rlabs = solarflare.target.RecentTargetCache.labels();
			var ri = 0;
			while (ri < rids.length) {
				var rid = rids[ri];
				var rlab = ri < rlabs.length ? rlabs[ri] : rid;
				if (solarflare.cdb.AuraCatalog.matchesSearch(rid, rlab, ui.search))
					recent.push({id: rid, name: rlab, kind: "recent target"});
				ri++;
			}
			shown += drawSubjectSection(c, ui, tag + "_recent", "Recent targets", recent, kind);
			shown += drawSubjectSection(c, ui, tag, "Units", units, kind);
		} else {
			shown += drawSubjectSection(c, ui, tag, "Skills", otherSkills, kind);
		}
		ImGui.textDisabled(shown + " matching");
	}

	static function drawSubjectSection(c:AuraConditionDef, ui:AuraConditionUiState, tag:String, title:String,
			rows:Array<{id:String, name:String, kind:String}>, subjectKind:String):Int {
		if (rows == null || rows.length == 0) return 0;
		ImGui.separatorText(title + " (" + rows.length + ")");
		var n = 0;
		for (entry in rows) {
			drawSubjectRow(c, ui, entry.id, entry.name, entry.kind, tag, subjectKind);
			n++;
		}
		return n;
	}

	/**
	 * Status pickers can list either the real stacking status (Status / Proc IDs, Currently
	 * on your character) or the ability that grants it (Other skills). Picking the ability by
	 * mistake used to leave `status.stacks`/`status.present` pointed at an id the engine never
	 * stacks — the granted status underneath it does. Redirect to the granted status id here so
	 * every entry point (wizard, Home templates, manual edit) lands on the trackable id.
	 */
	static function drawSubjectRow(c:AuraConditionDef, ui:AuraConditionUiState, id:String, name:String, entryKind:String, tag:String,
			subjectKind:String = ""):Void {
		if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, 28))) {
			ImGui.dummy(ImGui.vec2(1, 28));
			return;
		}
		if (!solarflare.ui.GameIcons.imageKey(id, 28, 28)) ImGui.dummy(ImGui.vec2(28, 28));
		ImGui.sameLine();
		var resolvedId = id;
		if (subjectKind == "status") {
			var grant = solarflare.cdb.CdbAuraTable.grantedStatusId(id);
			if (grant.length > 0 && grant != id)
				resolvedId = grant;
		}
		var kindTag = entryKind == "statustype" ? "category" : entryKind;
		if (ImGui.selectable(name + " [" + id + "] · " + kindTag + "##subject_" + tag + id, c.subject == resolvedId)) {
			c.subject = resolvedId;
			// Keep the catalog identity stable; the tooltip shows the resolved id.
			c.subjectLabel = name;
			ui.sync(c);
			ui.flashContext();
			SettingsStore.markDirty();
			ImGui.closeCurrentPopup();
		}
	}

	static function adjustPresentation(r:AuraRuleDef, fromIdx:Int, toIdx:Int):Void {
		if (r.presentationSource == fromIdx) r.presentationSource = toIdx;
		else if (r.presentationSource == toIdx) r.presentationSource = fromIdx;
	}
}
