package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiPopupFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraEffect;
import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraConditionValidator;
import solarflare.aura.signal.AuraRuleDef;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraValueKind;
import solarflare.cdb.AuraQuickStartCatalog;
import solarflare.cdb.CdbAuraTable;
import solarflare.ui.GameIcons;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.VectorGlow;

/**
 * Creation-home encounter gallery: CDB quickstart bosses, neon connectors,
 * left-click focus, right-click starters, skill chips. No long dropdowns.
 *
 * Layout is absolute X offsets — never SameLine after GameIcons.drawKey
 * (that helper parks a tiny Dummy on the next line and breaks horizontal rows).
 */
class AuraBossPortraitStrip {
	// Showcase (creation splash) — full intentional gallery
	static inline var PORTRAIT:Single = 72;
	static inline var LABEL_H:Single = 24;
	static inline var CELL_W:Single = 94;
	static inline var ARROW_W:Single = 22;
	static inline var STEP:Single = 116;

	public static function draw(
		focusBossId:String,
		a:AuraDef,
		onFocus:String->Void,
		onSnapshot:Void->Void,
		onCreateAura:AuraDef->Void,
		showcase:Bool = true
	):Void {
		AuraQuickStartCatalog.keep();
		var bosses = AuraQuickStartCatalog.bosses;
		if (bosses == null || bosses.length == 0) {
			ImGui.textDisabled("Boss catalog empty — check assets/cdb/aura-quickstart.json.");
			return;
		}

		var padY:Single = showcase ? 4 : 2;
		var stripH:Single = PORTRAIT + LABEL_H + padY * 2 + 10;
		var contentW:Single = bosses.length * STEP;
		if (contentW < STEP) contentW = STEP;

		var pushedVars = 0;
		var failed = false;
		var failure:Dynamic = null;
		try {
			ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(showcase ? 8 : 4, showcase ? 6 : 2));
			pushedVars++;
			ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(6, 6));
			pushedVars++;
			UiScope.child("##ab_boss_portrait_strip", ImGui.vec2(0, stripH), function() {
				var origin = ImGui.getCursorScreenPos();
				var dl = ImGui.getWindowDrawList();
				var i = 0;
				while (i < bosses.length) {
					var boss = bosses[i];
					if (boss == null) { i++; continue; }
					var x = origin.x + i * STEP;
					var selected = focusBossId == boss.id;
					ImGui.setCursorScreenPos(ImGui.vec2(x, origin.y + padY));
					drawPortrait(boss, selected, a, onFocus, onSnapshot, onCreateAura);
					if (i + 1 < bosses.length)
						drawArrowAt(dl, x + CELL_W, origin.y + padY + PORTRAIT * 0.5);
					i++;
				}
				ImGui.setCursorScreenPos(origin);
				ImGui.dummy(ImGui.vec2(contentW, stripH));
			}, ImGuiChildFlags.Borders, ImGuiWindowFlags.HorizontalScrollbar);
			if (ImGui.isItemHovered())
				ImGui.setTooltip("Left-click focus · Right-click starters · Skill chips add cast conditions");
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		if (pushedVars > 0) ImGui.popStyleVar(pushedVars);
		if (failed) throw failure;

		if (focusBossId == null || focusBossId.length == 0)
			return;
		var focused = AuraQuickStartCatalog.boss(focusBossId);
		if (focused == null) return;

		ImGui.spacing();
		drawRelatedSkillChips(focused, a, onSnapshot, onCreateAura, showcase);
	}

	static function drawPortrait(
		boss:{id:String, name:String, skills:Array<{id:String, name:String}>},
		selected:Bool,
		a:AuraDef,
		onFocus:String->Void,
		onSnapshot:Void->Void,
		onCreateAura:AuraDef->Void
	):Void {
		ImGui.pushID_Str("boss_port_" + boss.id);
		var p = ImGui.getCursorScreenPos();
		var size = PORTRAIT;
		ImGui.invisibleButton("##hit", ImGui.vec2(size, size + LABEL_H));
		var hovered = ImGui.isItemHovered();
		var left = ImGui.isItemClicked(ImGuiMouseButton.Left);
		// Capture clicks BEFORE GameIcons — drawKey replaces last-item identity.
		if (left && onFocus != null)
			onFocus(boss.id);
		if (ImGui.beginPopupContextItem("##ctx", ImGuiPopupFlags.MouseButtonRight)) {
			if (onFocus != null) onFocus(boss.id);
			drawContextMenuBody(boss, a, onSnapshot, onCreateAura);
			ImGui.endPopup();
		}

		var dl = ImGui.getWindowDrawList();
		var bg = selected
			? ImGui.vec4(0.18, 0.22, 0.38, 0.98)
			: (hovered ? ImGui.vec4(0.14, 0.16, 0.22, 0.95) : ImGui.vec4(0.10, 0.11, 0.14, 0.92));
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + size, p.y + size),
			ImGui.colorConvertFloat4ToU32(bg), 8);
		if (selected)
			VectorGlow.skillAlertBloom(dl, p.x, p.y, size, size, 0xFFC040FF, 14, 8, 10, 2.0);
		else
			ImGui.ImDrawList_AddRect(dl, p, ImGui.vec2(p.x + size, p.y + size),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.35, 0.40, 0.50, 0.9)), 8, 1.5);

		var pad:Single = 6;
		var icon = size - pad * 2;
		var iconOk = GameIcons.drawKey(dl, boss.id, p.x + pad, p.y + pad, icon, icon);
		if (!iconOk) {
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + 10, p.y + size * 0.4),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.85, 0.88, 0.95, 1)),
				boss.name.length > 0 ? boss.name.substr(0, 1) : "?");
		}

		var label = boss.name;
		if (label.length > 10) label = label.substr(0, 9) + "…";
		var ts = ImGui.calcTextSize(label);
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(p.x + (size - ts.x) * 0.5, p.y + size + 3),
			ImGui.colorConvertFloat4ToU32(selected
				? ImGui.vec4(0.95, 0.85, 0.45, 1)
				: ImGui.vec4(0.75, 0.78, 0.85, 1)),
			label);

		if (hovered)
			ImGui.setTooltip(boss.name + "\n" + boss.id + "\nRight-click for starters");

		ImGui.popID();
	}

	static function drawArrowAt(dl:Dynamic, x0:Single, cy:Single):Void {
		var x1 = x0 + ARROW_W;
		VectorGlow.radial(dl, (x0 + x1) * 0.5, cy, 10, 0xAA8844FF, 0.55, 5);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, cy), ImGui.vec2(x1 - 4, cy), 0xFF40C0FF, 3.0);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0 + 1, cy), ImGui.vec2(x1 - 5, cy), 0xFF101018, 1.6);
		ImGui.ImDrawList_AddTriangleFilled(dl,
			ImGui.vec2(x1, cy),
			ImGui.vec2(x1 - 8, cy - 5),
			ImGui.vec2(x1 - 8, cy + 5),
			0xFFFFC040);
		ImGui.ImDrawList_AddTriangleFilled(dl,
			ImGui.vec2(x1 - 1, cy),
			ImGui.vec2(x1 - 7, cy - 3.5),
			ImGui.vec2(x1 - 7, cy + 3.5),
			0xFF1A1210);
	}

	static function drawContextMenuBody(
		boss:{id:String, name:String, skills:Array<{id:String, name:String}>},
		a:AuraDef,
		onSnapshot:Void->Void,
		onCreateAura:AuraDef->Void
	):Void {
		ImGui.textDisabled(boss.name);
		ImGui.separator();
		if (a != null && ImGui.menuItem("Add: Kill of this unit")) {
			if (onSnapshot != null) onSnapshot();
			pushCondition(a, "combat.killKindMatches", boss.id, boss.name);
		}
		if (a != null && ImGui.menuItem("Add: Target kind matches")) {
			if (onSnapshot != null) onSnapshot();
			pushCondition(a, "target.kindMatches", boss.id, boss.name);
		}
		if (a != null && ImGui.menuItem("Add: Target is boss")) {
			if (onSnapshot != null) onSnapshot();
			pushCondition(a, "target.isBoss", "", "");
		}
		if (a != null && boss.skills != null && boss.skills.length > 0 && ImGui.beginMenu("Add: Cast alert…")) {
			for (skill in boss.skills) {
				if (skill == null) continue;
				var label = skill.name.length > 0 ? skill.name : skill.id;
				if (ImGui.menuItem(label + "##cast_" + skill.id)) {
					if (onSnapshot != null) onSnapshot();
					pushCondition(a, "event.cast.active", skill.id, label);
					a.skillId = skill.id;
					a.syncSkillBuf();
					a.iconId = resolveSkillIcon(skill.id, boss.id);
					a.syncIconBuf();
				}
			}
			ImGui.endMenu();
		}
		ImGui.separator();
		if (onCreateAura != null && ImGui.menuItem("Create Kill Counter aura")) {
			if (onSnapshot != null) onSnapshot();
			onCreateAura(makeKillCounter(boss));
		}
		if (onCreateAura != null && boss.skills != null && boss.skills.length > 0
				&& ImGui.beginMenu("Create Cast Alert aura…")) {
			for (skill in boss.skills) {
				if (skill == null) continue;
				var label = skill.name.length > 0 ? skill.name : skill.id;
				if (ImGui.menuItem(label + "##newcast_" + skill.id)) {
					if (onSnapshot != null) onSnapshot();
					onCreateAura(makeCastAlert(boss, skill));
				}
			}
			ImGui.endMenu();
		}
	}

	/** Boss name + skill chips; null aura creates a cast-alert starter instead. */
	static function drawRelatedSkillChips(
		boss:{id:String, name:String, skills:Array<{id:String, name:String}>},
		a:AuraDef,
		onSnapshot:Void->Void,
		onCreateAura:AuraDef->Void,
		showcase:Bool = true
	):Void {
		if (boss.skills == null || boss.skills.length == 0)
			return;

		var btnH:Single = ImGui.getFontSize() + 10;
		if (btnH < 28) btnH = 28;
		var rowH:Single = btnH + (showcase ? 14 : 10);
		UiScope.child("##ab_boss_skill_chips_" + boss.id, ImGui.vec2(0, rowH), function() {
			ImGui.alignTextToFramePadding();
			ImGui.textColored(ImGui.vec4(0.95, 0.85, 0.45, 1), boss.name);
			ImGui.sameLine(0, 6);
			ImGui.textDisabled("·");
			for (skill in boss.skills) {
				if (skill == null) continue;
				ImGui.sameLine(0, 4);
				var full = skill.name.length > 0 ? skill.name : skill.id;
				var maxTextW:Single = CELL_W - 16;
				var label = full;
				if (ImGui.calcTextSize(label).x > maxTextW) {
					var trimmed = full;
					while (trimmed.length > 1 && ImGui.calcTextSize(trimmed + "…").x > maxTextW)
						trimmed = trimmed.substr(0, trimmed.length - 1);
					label = trimmed + "…";
				}
				var already = a != null && hasSubjectCondition(a, skill.id);
				var textW:Single = ImGui.calcTextSize(label).x + 16;
				if (textW < 48) textW = 48;
				if (textW > CELL_W) textW = CELL_W;
				ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 4.0);
				var chipClicked = UiChrome.navButton(label + "##chip_" + boss.id + "_" + skill.id, already, ImGui.vec2(textW, btnH));
				ImGui.popStyleVar(1);
				if (chipClicked) {
					if (a == null) {
						if (onCreateAura != null) {
							if (onSnapshot != null) onSnapshot();
							onCreateAura(makeCastAlert(boss, skill));
						}
					} else if (already) {
						solarflare.ui.ToastManager.info("Already tracking " + full);
					} else {
						if (onSnapshot != null) onSnapshot();
						pushCondition(a, "event.cast.active", skill.id, full);
						a.skillId = skill.id;
						a.syncSkillBuf();
						a.iconId = resolveSkillIcon(skill.id, boss.id);
						a.syncIconBuf();
						solarflare.ui.ToastManager.success("Added cast: " + full);
					}
				}
				if (ImGui.isItemHovered()) {
					if (a == null)
						ImGui.setTooltip("Create cast alert aura\n" + full + "\n" + skill.id);
					else
						ImGui.setTooltip((already ? "Already in WHEN\n" : "Add cast/channel to WHEN\n") + full + "\n" + skill.id);
				}
			}
		}, 0, ImGuiWindowFlags.HorizontalScrollbar);
	}

	static function hasSubjectCondition(a:AuraDef, subjectId:String):Bool {
		if (a == null || a.rule == null || a.rule.conditions == null || subjectId == null) return false;
		for (c in a.rule.conditions)
			if (c != null && c.subject == subjectId) return true;
		return false;
	}

	/** Prefer encounter scope when focusing a known boss (Shared stays until user picks). */
	public static function suggestedFight(bossId:String):String {
		if (bossId == null) return "";
		return switch (bossId) {
			case "DemonSuperElite": "maat";
			case "DemonSuperElite_Fairy": "nightqueen";
			default: "";
		};
	}

	public static function pushCondition(a:AuraDef, signal:String, subject:String, subjectLabel:String):Bool {
		if (a == null) return false;
		if (a.rule == null) a.rule = new AuraRuleDef();
		if (a.rule.conditions == null) a.rule.conditions = [];
		if (a.rule.conditions.length >= AuraRuleDef.MAX_CONDITIONS) {
			solarflare.ui.ToastManager.warn("Condition limit reached");
			return false;
		}
		if (subject != null && subject.length > 0 && hasSubjectCondition(a, subject))
			return false;
		var c = new AuraConditionDef();
		c.signal = signal;
		c.subject = subject != null ? subject : "";
		c.subjectLabel = subjectLabel != null ? subjectLabel : "";
		var desc = AuraSignalCatalog.find(signal);
		if (desc != null) {
			c.op = AuraConditionValidator.defaultOperator(desc);
			c.numberValue = desc.kind == AuraValueKind.Percent ? 0.35 : 1;
			c.boolValue = true;
		} else {
			c.op = "is";
			c.boolValue = true;
		}
		a.rule.conditions.push(c);
		SettingsStore.markDirty();
		return true;
	}

	/**
	 * Only pin an icon the atlas can actually draw. Most boss skills have no frame of
	 * their own, and writing the raw skill id into iconId leaves the starter showing
	 * "?" until the user retypes it. Empty instead lets preferredIconId fall through
	 * to the encounter portrait.
	 */
	static function resolveIconStem(id:String):String {
		if (id == null || id.length == 0)
			return "";
		var stem = CdbAuraTable.iconStem(id);
		if (stem.length > 0 && GameIcons.hasKey(stem))
			return stem;
		return GameIcons.hasKey(id) ? id : "";
	}

	/**
	 * Skill art when the atlas has it, else the encounter portrait. A cast aura's
	 * whole candidate chain — iconId, condition subject, skillId — is the skill, so
	 * without this the boss face never becomes reachable and the aura renders "?".
	 */
	static function resolveSkillIcon(skillId:String, bossId:String):String {
		var art = resolveIconStem(skillId);
		return art.length > 0 ? art : resolveIconStem(bossId);
	}

	static function makeKillCounter(boss:{id:String, name:String}):AuraDef {
		var a = new AuraDef("kill_" + boss.id, boss.name + " Kills");
		a.announce = boss.name + " Kills";
		a.syncAnnounceBuf();
		a.isCounter.set(true);
		a.alwaysOn.set(true);
		a.region = "text";
		a.showIcon.set(true);
		a.stackCounter.set(true);
		a.iconId = resolveIconStem(boss.id);
		a.syncIconBuf();
		a.rule = new AuraRuleDef();
		pushCondition(a, "combat.killKindMatches", boss.id, boss.name);
		a.effects = [new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_ON_RISE_HOLD)];
		a.effects[0].hold = 5.0;
		a.effects[0].holdRef.set(5.0);
		a.enabled.set(false);
		return a;
	}

	static function makeCastAlert(boss:{id:String, name:String}, skill:{id:String, name:String}):AuraDef {
		var label = skill.name.length > 0 ? skill.name : skill.id;
		var a = new AuraDef("cast_" + skill.id, boss.name + " · " + label);
		a.announce = label + "!";
		a.syncAnnounceBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.skillId = skill.id;
		a.syncSkillBuf();
		a.iconId = resolveSkillIcon(skill.id, boss.id);
		a.syncIconBuf();
		a.rule = new AuraRuleDef();
		pushCondition(a, "event.cast.active", skill.id, label);
		a.effects = [new AuraEffect("win", AuraEffect.KIND_ALERT, AuraEffect.WHEN_WHILE_TRUE)];
		a.enabled.set(false);
		return a;
	}
}
