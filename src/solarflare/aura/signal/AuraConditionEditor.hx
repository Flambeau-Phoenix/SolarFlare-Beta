package solarflare.aura.signal;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiInputTextFlags;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraEngine;
import solarflare.aura.signal.AuraSignalDescriptor;
import solarflare.aura.signal.AuraValueKind;
import solarflare.ui.ByteUtil;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.WindowEffects;

/**
 * Conversational condition cards: "Show when [signal] is [op] [value]".
 * Restores natural single-sentence flow while preserving robust layout math.
 */
class AuraConditionEditor {
	public static function draw(a:AuraDef, prominent:Bool = false, onBatchSnapshot:Void->Void = null, bossFocusId:String = ""):Void {
		if (a == null) return;
		if (a.rule == null) a.rule = new AuraRuleDef();
		a.ruleEditor.id = a.id;
		a.ruleEditor.rule = a.rule;
		a.ruleEditor.snapshot = onBatchSnapshot;
		drawContext(a.ruleEditor, prominent, bossFocusId);
	}

	public static function drawContext(a:AuraRuleEditorContext, prominent:Bool = false, bossFocusId:String = ""):Void {
		if (a == null || a.rule == null) return;
		var r = a.rule;
		var onBatchSnapshot = a.snapshot;
		UiChrome.subHeader("Require");
		var allMode = r.mode == "all";
		if (ImGui.radioButton("ALL conditions (AND)##rule_all_" + a.id, allMode)) {
			if (a.snapshot != null) a.snapshot();
			r.mode = "all";
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.radioButton("ANY condition (OR)##rule_any_" + a.id, !allMode)) {
			if (a.snapshot != null) a.snapshot();
			r.mode = "any";
			SettingsStore.markDirty();
		}

		// Sentence summary
		ImGui.spacing();
		var count = r.conditions != null ? r.conditions.length : 0;
		if (count == 0) {
			ImGui.textDisabled("No conditions yet â€” add one below.");
		} else {
			ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_INFO),
				allMode ? "Show when ALL of these are true:" : "Show when ANY of these is true:");
			var i = 0;
			for (c in r.conditions) {
				var join = i == 0 ? "" : (allMode ? "  and " : "  or ");
				ImGui.textWrapped(join + humanConditionSummary(c)
					+ (a.presentation && r.presentationSource == i && count > 1 ? "  (main trigger)" : ""));
				i++;
			}
		}
		ImGui.separator();

		var ci = 0;
		while (ci < r.conditions.length) {
			var c = r.conditions[ci];
			var removed = false;
			var border = ThemePalette.status(c.negate ? ThemePalette.STATUS_DANGER : ThemePalette.STATUS_SUCCESS);

			ImGui.pushStyleColor(ImGuiCol.Border, border);
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, prominent ? 2.0 : 1.5);
			ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(10, 8));

			ImGui.beginChild("##condition_card_" + c.uiKey, ImGui.vec2(0, 0),
				ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding, 0);
			try {
				removed = drawConditionCard(a, r, c, ci, bossFocusId);
			} catch (e:Dynamic) {
				UiScope.reportOnce("condition card", a.id + "_" + c.uiKey, e);
			}
			ImGui.endChild();

			ImGui.popStyleVar(2);
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
			if (UiChrome.ghostButton("+ Add Condition##add_cond_" + a.id, ImGui.vec2(-1, 32))) {
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
		if(c.signal=="custom.script") {
			var excerpt=StringTools.trim(c.subject).split("\n").join(" ");
			if(excerpt.length>64) excerpt=excerpt.substr(0,61)+"...";
			return (c.negate ? "not " : "")+"Haxe expression: "+(excerpt=="" ? "(empty)" : excerpt)+" "+friendlyOp(c.op)+" "+(c.boolValue ? "true" : "false");
		}
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
		if (AuraConditionValidator.isStatusPresence(c.signal)) return "";
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
		var tint = ThemePalette.status(allMode ? ThemePalette.STATUS_SUCCESS : ThemePalette.STATUS_WARN);
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

	static function drawConditionCard(a:AuraRuleEditorContext, r:AuraRuleDef, c:AuraConditionDef, index:Int, bossFocusId:String):Bool {
		solarflare.aura.StatusTypeDemand.requestEditor(c.signal,c.subject);
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
			if (a.snapshot != null) a.snapshot();
			var p = r.conditions[index - 1];
			r.conditions[index - 1] = c;
			r.conditions[index] = p;
			adjustPresentation(r, index, index - 1);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (index + 1 < r.conditions.length && ImGui.smallButton("v##cond_dn_" + tag)) {
			if (a.snapshot != null) a.snapshot();
			var n = r.conditions[index + 1];
			r.conditions[index + 1] = c;
			r.conditions[index] = n;
			adjustPresentation(r, index, index + 1);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();

		// Destructive action stays outlined; its rim and caption communicate danger.
		var theme = ThemePalette.current();
		ImGui.pushStyleColor(ImGuiCol.Button, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, theme.windowBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, theme.windowBg);
		var danger = ThemePalette.status(ThemePalette.STATUS_DANGER);
		ImGui.pushStyleColor(ImGuiCol.Border, danger);
		ImGui.pushStyleColor(ImGuiCol.Text, danger);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.5);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 4.0);
		var remove = ImGui.smallButton("Remove##cond_rm_" + tag);
		ImGui.popStyleVar(2);
		ImGui.popStyleColor(5);

		ImGui.sameLine();
		if (ImGui.checkbox("Invert##cond_neg_" + tag, ui.negateRef)) {
			if (a.snapshot != null) a.snapshot();
			ui.pull(c);
			ui.flashContext();
			SettingsStore.markDirty();
		}
		if (a.presentation && r.conditions.length > 1) {
			if (ImGui.getContentRegionAvail().x > 230) ImGui.sameLine();
			var isMain = r.presentationSource == index;
			if (ImGui.smallButton(isMain ? "Main Trigger##cond_main_" + tag : "Use as Main Trigger##cond_main_" + tag)) {
				if (a.snapshot != null) a.snapshot();
				r.presentationSource = index;
				SettingsStore.markDirty();
			}
		}

		ImGui.dummy(ImGui.vec2(0, 2));

		// Natural language row: Show when [signal] is [op] [value]
		ImGui.alignTextToFramePadding();
		ImGui.text("Show when");
		ImGui.sameLine();

		var compact = ImGui.getContentRegionAvail().x < 700;
		var d = AuraSignalCatalog.find(c.signal);
		var preview = d != null ? d.label : (c.signal.length > 0 ? c.signal : "Select signalâ€¦");
		ImGui.setNextItemWidth(210);
		if (ImGui.beginCombo("##cond_sig_" + tag, preview)) {
			var currentGroup = "";
			for (item in AuraSignalCatalog.all()) {
				if (item.group != currentGroup) {
					currentGroup = item.group;
					ImGui.separatorText(item.group);
				}
				if (ImGui.selectable(item.label + "##sig_" + tag + item.id, c.signal == item.id)) {
					if (a.snapshot != null) a.snapshot();
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
		if (d != null && d.subjectKind.length > 0 && d.subjectKind!="script") {
			if (!compact) ImGui.sameLine();
			drawSubjectInline(a, c, ui, d.subjectKind, tag, bossFocusId);
		}

		if (d != null) {
			if (!compact) ImGui.sameLine();
			drawOperatorInline(c, ui, d, tag, a.snapshot);
		}

		if (d != null && !AuraConditionValidator.isStatusPresence(d.id)) {
			ImGui.sameLine();
			switch (d.kind) {
				case Boolean:
					if (ImGui.checkbox("active##cond_bool_" + tag, ui.boolRef)) {
						if (a.snapshot != null) a.snapshot();
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Percent:
					ImGui.setNextItemWidth(100);
					if (solarflare.ui.NumberField.draw("##cond_pct_" + tag, ui.percentRef, 0, 100, "%.0f%%", a.snapshot)) {
						ui.pullPercent(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Count:
					ImGui.setNextItemWidth(90);
					if (solarflare.ui.NumberField.draw("##cond_cnt_" + tag, ui.numberRef, 0, 9999, "%.0f", a.snapshot)) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				case Duration:
					ImGui.setNextItemWidth(100);
					if (solarflare.ui.NumberField.draw("##cond_dur_" + tag, ui.numberRef, 0, 3600, "%.1fs", a.snapshot)) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
				default:
					ImGui.setNextItemWidth(90);
					if (solarflare.ui.NumberField.draw("##cond_num_" + tag, ui.numberRef, 0, 1e12, "%.1f", a.snapshot)) {
						ui.pull(c);
						ui.flashContext();
						SettingsStore.markDirty();
					}
			}
		}

		// Help tips when relevant
		if(c.signal=="custom.script") drawScriptEditor(a,c,ui,tag,bossFocusId);
		if (d != null) {
			if (d.subjectKind=="statusType")
				ImGui.textWrapped("General status category from any source. Present/absent only; skill IDs, stacks and durations are separate conditions.");
			else if (StringTools.startsWith(d.id,"target.status."))
				ImGui.textWrapped("Tracks the first live matching application on your current enemy, from any player. No target or incomplete observation is unknown.");
			else if (d.id == "status.count" || d.id == "status.overflow")
				ImGui.textDisabled("Count is full character status container length. Overflow means > " + AuraSignalFrame.MAX_STATUSES + " entries.");
			else if (d.id == "skill.instantReady")
				ImGui.textDisabled("Skill script shouldPlayInstantly (e.g. Staff_Craft_S1). For buffs, prefer Statuses.");
			else if (d.id == "equipment.weaponEquipped")
				ImGui.textWrapped("Matches either equipped weapon slot or the active offhand, including the inactive weapon. Items only in your bag do not match.");
			else if (d.id == "event.cast.recent" || d.id == "event.playerCast.recent")
				ImGui.textDisabled("Seconds since cast. Use 'within' operator for windows (e.g. within 5s).");
			else if (AuraConditionValidator.isCombatEvent(d.id))
				ImGui.textWrapped("Use 'within' to choose how long the combat trigger stays active (e.g. 3s). For a countdown, choose a fixed timer duration.");
			else if(StringTools.startsWith(d.id,"event.status."))
				ImGui.textWrapped("Observed changes on your character. Refresh means a timed effect restarted or its instance changed; short transitions between samples may be missed. Untimed effects cannot report refreshes.");
			else if(d.group=="Movement")
				ImGui.textWrapped("Follows your equipped dash. Available means a charge is ready; temporary movement restrictions may still prevent dashing. Recharge is time until the next charge.");
			else if(AuraConditionValidator.isElapsedEvent(d.id))
				ImGui.textWrapped("Seconds since the observed event. Use within to choose the alert window; loading or observation gaps establish a new baseline.");
		}

		ImGui.dummy(ImGui.vec2(0, 2));
		ImGui.textColored(theme.accent, "Active: " + humanConditionSummary(c));
		return remove;
	}

	static function drawOperatorInline(c:AuraConditionDef, ui:AuraConditionUiState, d:AuraSignalDescriptor, tag:String, beforeEdit:Void->Void):Void {
		var ops:Array<String>;
		// status.present is Boolean-kinded but AuraConditionValidator.isValidOperator
		// accepts only present/absent for it. Without this case the generic Boolean
		// list offers is/isNot, so opening the combo silently writes an operator the
		// validator rejects and compareValue routes to boolValue instead of present.
		if (d != null && AuraConditionValidator.isStatusPresence(d.id))
			ops = ["present", "absent"];
		else if (d != null && AuraConditionValidator.isElapsedEvent(d.id))
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
					if (beforeEdit != null) beforeEdit();
					c.op = op;
					ui.flashContext();
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
	}

	static function drawScriptEditor(a:AuraRuleEditorContext,c:AuraConditionDef,ui:AuraConditionUiState,tag:String,bossFocusId:String):Void {
		ui.syncScript(c);
		ImGui.spacing();
		ImGui.textDisabled("Haxe expression / small block - return true or false");
		if(ImGui.inputTextMultiline("##cond_script_"+tag,ui.scriptBuf,AuraConditionUiState.SCRIPT_BUF,
			ImGui.vec2(-1,150),ImGuiInputTextFlags.AllowTabInput)) {
			if(!ui.scriptEditing && a.snapshot!=null) a.snapshot();
			c.subject=ByteUtil.readString(ui.scriptBuf,AuraConditionUiState.SCRIPT_BUF,false); c.subjectLabel="";
			ui.scriptSource=c.subject; ui.scriptBytes=haxe.io.Bytes.ofString(c.subject).length;
			ui.scriptEditing=true;
			ui.scriptSession.request(c.subject,haxe.Timer.stamp()); SettingsStore.markDirty();
		}
		if(!ImGui.isItemActive()) ui.scriptEditing=false;
		ImGui.textDisabled(ui.scriptBytes+" / 4096 UTF-8 bytes");
		if(ImGui.smallButton("Check##script_check_"+tag)) ui.scriptSession.request(c.subject,0,true,false);
		ImGui.sameLine();
		if(ImGui.smallButton("Test##script_test_"+tag)) ui.scriptSession.request(c.subject,0,true,true);
		ImGui.setNextItemWidth(-1);
		if(ImGui.beginCombo("##script_example_"+tag,"Insert example...")) {
			try {
			if(ImGui.selectable("Low health, no dash##script_ex_dash_"+tag)) setScript(a,c,ui,'hp < 35 && !signal("dash.available")');
			if(ImGui.selectable("Missing buff in combat##script_ex_status_"+tag)) setScript(a,c,ui,
				'signal("combat.inCombat") && !hasStatus("Staff_SummonDemon_Skill1_Status")');
			if(ImGui.selectable("Local variables and if/else##script_ex_block_"+tag)) setScript(a,c,ui,
				'{\n  var low = hp < 35;\n  if (low) return signal("dash.available");\n  return false;\n}');
			} catch(e:Dynamic) { ImGui.endCombo(); throw e; }
			ImGui.endCombo();
		}
		var session=ui.scriptSession;
		ImGui.textColored(ThemePalette.status(session.state=="Error" ? ThemePalette.STATUS_DANGER :
			session.state=="True" || session.state=="Valid" ? ThemePalette.STATUS_SUCCESS : ThemePalette.STATUS_INFO),session.state);
		if(session.message!="") ImGui.textWrapped(session.message);
		if(UiChrome.groupHeader("Insert signal##script_insert_"+tag,false)) {
			var insert=ui.scriptInsert; var insertUi=ui.scriptInsertUi;
			ImGui.setNextItemWidth(-1);
			if(ImGui.beginCombo("##script_signal_"+tag,AuraSignalCatalog.find(insert.signal).label)) {
				try {
				for(d in AuraSignalCatalog.all()) if(d.id!="custom.script" && ImGui.selectable(d.label+"##script_sig_"+tag+d.id,insert.signal==d.id)) {
					insert.signal=d.id; insert.subject=insert.subjectLabel=""; insertUi.sync(insert);
				}
				} catch(e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			}
			var descriptor=AuraSignalCatalog.find(insert.signal);
			if(descriptor.subjectKind!="") drawSubjectInline(a,insert,insertUi,descriptor.subjectKind,"script_"+tag,bossFocusId);
			ImGui.textDisabled("Inserts at the end. Combine the value with a comparison, && or ||.");
			ImGui.textDisabled(descriptor.kind==Percent ? "Percent: 0..1 (legacy hp/mana/rage/spark variables use 0..100)." :
				descriptor.kind==Duration ? "Seconds. Event signals are elapsed age; recharge/status signals are remaining time." :
				insert.signal=="target.distance" ? "Horizontal distance in game units." : "Boolean, count, or current amount as named above.");
			if(ImGui.smallButton("Insert signal##script_add_"+tag)) {
				if(descriptor.subjectKind=="" || insert.subject!="") {
					var subject=StringTools.replace(StringTools.replace(insert.subject,"\\","\\\\"),'"','\\"');
					var expression='signal("'+insert.signal+'"'+(subject=="" ? "" : ', "'+subject+'"')+')';
					setScript(a,c,ui,c.subject+(StringTools.trim(c.subject)=="" ? "" : "\n")+expression);
				}
			}
		}
		if(UiChrome.groupHeader("Expression reference##script_ref_"+tag,false)) {
			ImGui.textWrapped("Use &&, ||, !, comparisons, arithmetic, local var, return, and if/else. Loops and functions are unavailable. Each evaluation starts fresh.");
			ImGui.textWrapped('signal("id", "subject") reads an Aura signal; known("id", "subject") checks availability. IDs must be quoted literals. Missing data waits instead of becoming zero.');
			ImGui.textWrapped("hp, shield, mana, rage, spark: 0..100; hpRatio: 0..1; hpCur: amount. combo/comboMax, prayers, prayerLife/Shield/Smite, chaincast/Ready, conduit/Power, step, comboWithin/Final, inRift, damageTaken.");
			ImGui.textWrapped("Helpers: hasSkill, skillCd, skillReady, hasStatus, statusStacks, statusDuration (one quoted ID). Math: min/max, abs, floor/ceil/round, sqrt/pow, sin/cos/tan, asin/acos/atan/atan2, exp/log, isFinite/isNaN, Math.PI. Times are seconds. Numeric results > 0 remain true for compatibility.");
		}
	}
	static function setScript(a:AuraRuleEditorContext,c:AuraConditionDef,ui:AuraConditionUiState,source:String):Void {
		if(a.snapshot!=null) a.snapshot(); c.subject=source; c.subjectLabel=""; ui.syncScript(c); SettingsStore.markDirty();
	}

	/** Other auras a condition may watch (group mates first); installed by the Aura Builder. */
	public static var auraChoices:Void->Array<{id:String, name:String}> = null;

	static function auraName(id:String):String {
		if (auraChoices != null) for (r in auraChoices()) if (r.id == id) return r.name;
		return null;
	}

	static function subjectName(c:AuraConditionDef):String {
		if (c.signal == "aura.active") { var n = auraName(c.subject); if (n != null) return n; }
		// subjectLabel is the stable user-facing identity selected in the catalog.
		// `subject` may intentionally be rewritten to an engine status id.
		if (solarflare.cdb.AuraCatalog.validName(c.subjectLabel)) return c.subjectLabel;
		var name = solarflare.cdb.AuraCatalog.label(c.subject);
		if (solarflare.cdb.AuraCatalog.validName(name)) return name;
		return c.subject;
	}

	static function drawSubjectInline(a:AuraRuleEditorContext, c:AuraConditionDef, ui:AuraConditionUiState, kind:String, tag:String, bossFocusId:String):Void {
		var name = subjectName(c);
		if (name.length > 0) c.subjectLabel = name;

		// Same beginCombo pattern as AuraBuilder.drawWizardCatalogPicker / signal combo.
		// ghostButton+popup inside AutoResizeY condition cards eats clicks and sticks.
		var previewText = name.length > 0 ? name : "Select " + kind + "â€¦";
		ImGui.setNextItemWidth(210);
		ImGui.setNextWindowSize(ImGui.vec2(480, 420), ImGuiCond.Always);
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
			if (kind == "weapon" && ui.search.length > 0 && ImGui.smallButton("Use typed weapon ID##cond_weapon_id_" + tag)) {
				if (a.snapshot != null) a.snapshot();
				c.subject = solarflare.cdb.WeaponCatalog.canonicalId(ByteUtil.readString(ui.searchBuf, AuraConditionUiState.SEARCH_BUF, true));
				c.subjectLabel = solarflare.cdb.AuraCatalog.label(c.subject);
				ui.sync(c); ui.flashContext(); SettingsStore.markDirty(); ImGui.closeCurrentPopup();
			}
			ImGui.separator();

			// Child begin always pairs with end (AGENTS.md); content only when open.
			var childOpen = ImGui.beginChild("##cond_subj_list_" + tag, ImGui.vec2(0, 0), ImGuiChildFlags.Borders);
			try {
				if (childOpen)
					drawSubjectList(c, ui, kind, tag, bossFocusId, a.snapshot);
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

	static function drawSubjectList(c:AuraConditionDef, ui:AuraConditionUiState, kind:String, tag:String, bossFocusId:String, beforeEdit:Void->Void):Void {
		if (kind == "aura") {
			var shown = 0;
			for (r in (auraChoices != null ? auraChoices() : [])) {
				if (ui.search.length > 0 && r.name.toLowerCase().indexOf(ui.search) < 0) continue;
				if (ImGui.selectable(r.name + "##aura_pick_" + r.id, c.subject == r.id)) {
					if (beforeEdit != null) beforeEdit();
					c.subject = r.id; c.subjectLabel = r.name;
					ui.sync(c); ui.flashContext(); SettingsStore.markDirty(); ImGui.closeCurrentPopup();
				}
				shown++;
			}
			if (shown == 0) ImGui.textDisabled("No other auras match.");
			return;
		}
		if(kind=="statusType") {
			ImGui.separatorText("General status types");
			var shown=0;
			for(entry in solarflare.cdb.StatusTypeCatalog.entries) if(solarflare.cdb.StatusTypeCatalog.matches(entry.id,entry.name,ui.search)) {
				drawSubjectRow(c,ui,entry.id,entry.name,"statustype",tag,kind,beforeEdit); shown++;
			}
			ImGui.textDisabled(shown+" matching"); return;
		}
		var statusSkills:Array<{id:String, name:String, kind:String}> = [];
		var otherSkills:Array<{id:String, name:String, kind:String}> = [];
		var categories:Array<{id:String, name:String, kind:String}> = [];
		var units:Array<{id:String, name:String, kind:String}> = [];

		if (kind == "consumable") {
			for (entry in solarflare.cdb.ConsumableCatalog.entries)
				if (solarflare.cdb.AuraCatalog.matchesSearch(entry.id, entry.name, ui.search))
					otherSkills.push({id:entry.id, name:entry.name, kind:"consumable"});
		}
		if (kind == "weapon") {
			for (entry in solarflare.cdb.WeaponCatalog.entries)
				if (solarflare.cdb.AuraCatalog.matchesSearch(entry.id, entry.name, ui.search))
					otherSkills.push({id:entry.id, name:entry.name, kind:"weapon"});
		}
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
			var enemy=StringTools.startsWith(c.signal,"target.status.");
			var statuses=frame==null ? null : enemy ? frame.targetStatuses : frame.statuses;
			var count=frame==null ? 0 : enemy ? frame.targetStatusCount : frame.statusCount;
			if (frame != null) for (i in 0...count) {
				var status = statuses[i];
				if (!status.known || !status.present) continue;
				var label = solarflare.cdb.AuraCatalog.label(status.rawId);
				if (solarflare.cdb.AuraCatalog.matchesSearch(status.rawId, label, ui.search))
					observed.push({id: status.rawId, name: label, kind: "active status"});
			}
			shown += drawSubjectSection(c, ui, tag + "_live", enemy ? "Currently on your enemy target" : "Currently on your character", observed, kind, beforeEdit);
			shown += drawSubjectSection(c, ui, tag, "Status / Proc IDs", statusSkills, kind, beforeEdit);
			shown += drawSubjectSection(c, ui, tag, "Other skills", otherSkills, kind, beforeEdit);
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
			shown += drawSubjectSection(c, ui, tag + "_recent", "Recent targets", recent, kind, beforeEdit);
			shown += drawSubjectSection(c, ui, tag, "Units", units, kind, beforeEdit);
		} else {
			shown += drawSubjectSection(c, ui, tag, kind == "weapon" ? "Weapons / offhands" : kind == "consumable" ? "Consumables / usable items" : "Skills", otherSkills, kind, beforeEdit);
		}
		ImGui.textDisabled(shown + " matching");
	}

	static function drawSubjectSection(c:AuraConditionDef, ui:AuraConditionUiState, tag:String, title:String,
			rows:Array<{id:String, name:String, kind:String}>, subjectKind:String, beforeEdit:Void->Void):Int {
		if (rows == null || rows.length == 0) return 0;
		ImGui.separatorText(title + " (" + rows.length + ")");
		var n = 0;
		for (entry in rows) {
			drawSubjectRow(c, ui, entry.id, entry.name, entry.kind, tag, subjectKind, beforeEdit);
			n++;
		}
		return n;
	}

	/**
	 * Status pickers can list either the real stacking status (Status / Proc IDs, Currently
	 * on your character) or the ability that grants it (Other skills). Picking the ability by
	 * mistake used to leave `status.stacks`/`status.present` pointed at an id the engine never
	 * stacks â€” the granted status underneath it does. Redirect to the granted status id here so
	 * every entry point (wizard, Home templates, manual edit) lands on the trackable id.
	 */
	static function drawSubjectRow(c:AuraConditionDef, ui:AuraConditionUiState, id:String, name:String, entryKind:String, tag:String,
			subjectKind:String = "", beforeEdit:Void->Void = null):Void {
		if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, 28))) {
			ImGui.dummy(ImGui.vec2(1, 28));
			return;
		}
		drawSubjectIcon(id, 28, 28);
		ImGui.sameLine();
		var resolvedId = subjectKind == "status" ? solarflare.cdb.CdbAuraTable.statusSubjectId(id) : id;
		var kindTag = entryKind == "statustype" ? "category" : entryKind;
		if (ImGui.selectable(name + " [" + id + "] Â· " + kindTag + "##subject_" + tag + id, c.subject == resolvedId)) {
			if (beforeEdit != null) beforeEdit();
			c.subject = resolvedId;
			// Keep the catalog identity stable; the tooltip shows the resolved id.
			c.subjectLabel = name;
			ui.sync(c);
			ui.flashContext();
			SettingsStore.markDirty();
			ImGui.closeCurrentPopup();
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip(name + " [" + resolvedId + "]");
	}

	static function adjustPresentation(r:AuraRuleDef, fromIdx:Int, toIdx:Int):Void {
		if (r.presentationSource == fromIdx) r.presentationSource = toIdx;
		else if (r.presentationSource == toIdx) r.presentationSource = fromIdx;
	}

	static function drawSubjectIcon(id:String, w:Single, h:Single):Void {
		var itemKey = solarflare.cdb.ConsumableCatalog.iconKey(id);
		if (itemKey.length > 0 && solarflare.ui.GameIcons.imageKey(itemKey, w, h)) return;
		if (solarflare.ui.GameIcons.imageKey(id, w, h)) return;

		var stem = solarflare.cdb.CdbAuraTable.iconStem(id);
		if (stem.length > 0 && stem != id && solarflare.ui.GameIcons.imageKey(stem, w, h)) return;

		var stripped = id;
		for (suffix in ["_Status", "_status", "_Proc", "_proc", "Status", "Proc"]) {
			if (StringTools.endsWith(stripped, suffix) && stripped.length > suffix.length) {
				stripped = stripped.substr(0, stripped.length - suffix.length);
				break;
			}
		}
		if (stripped != id && solarflare.ui.GameIcons.imageKey(stripped, w, h)) return;
		if (stripped != id) {
			var strippedStem = solarflare.cdb.CdbAuraTable.iconStem(stripped);
			if (strippedStem.length > 0 && strippedStem != stripped && solarflare.ui.GameIcons.imageKey(strippedStem, w, h)) return;
		}

		var grant = solarflare.cdb.CdbAuraTable.grantedStatusId(id);
		if (grant.length > 0 && grant != id && solarflare.ui.GameIcons.imageKey(grant, w, h)) return;

		drawIconPlaceholder(id, w, h);
	}

	static function drawIconPlaceholder(id:String, w:Single, h:Single):Void {
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.13, 0.16, 0.21, 1)), 4);
		ImGui.ImDrawList_AddRect(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.36, 0.45, 0.58, 1)), 4, 1);
		var mark = id != null && id.length > 0 ? id.substr(0, 1).toUpperCase() : "?";
		var ts = ImGui.calcTextSize(mark);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + (w - ts.x) * 0.5, p.y + (h - ts.y) * 0.5), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.72, 0.8, 0.92, 1)), mark);
	}
}
