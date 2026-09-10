package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.attackcombo.AttackComboConfig;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.preview.PreviewScenario;
import solarflare.preview.PreviewState;
import solarflare.preview.ResourcePreviewRenderer;
import solarflare.target.TargetConfig;
import solarflare.ui.ConfigPanel;
import solarflare.ui.HudChrome;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import solarflare.ui.ToolWindow;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.VitalsConfig;

/** Unified F6 editor for every independently movable resource window. */
class ResourceTrackerBuilder {
	public var open = new BoolRef(false);
	public var selected:String = "target";

	var previewScope = new IntRef(0);
	var previewScenario = new IntRef(1);
	var previewState:PreviewState;
	var previewRenderer:ResourcePreviewRenderer;
	var host:ConfigPanel;

	public function new(host:ConfigPanel) {
		this.host = host;
		previewState = PreviewState.partial();
		previewRenderer = new ResourcePreviewRenderer();
	}

	public function openFor(id:String):Void {
		if (isResourceId(id)) selected = id;
		open.set(true);
		SettingsStore.markDirty();
	}

	public function draw():Void {
		if (!open.get() || host == null) return;
		if (!CursorCaptureFix.cursorFree) return;
		var vis = ToolWindow.begin("Resource Tracker Builder###SolarFlare.ResourceTracker", open, 1240, 860);
		if (vis) {
			ImGui.textWrapped("Choose a resource using its settings cog, then preview and adjust its appearance.");
			ImGui.separator();
			HudChrome.safeChild("##rt_builder_left", ImGui.vec2(400, 0), 0, drawNavigation, imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
			ImGui.sameLine(0, 24);
			HudChrome.safeChild("##rt_builder_right", ImGui.vec2(0, 0), 0, function() {
				drawPreview();
				section("Settings — " + selectedLabel());
				drawSelectedSettings();
				ImGui.separator();
				ImGui.textDisabled("Saved with the active Resources profile.");
			}, imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
		}
		ToolWindow.end();
	}

	function drawNavigation():Void {
		solarflare.ui.FeatureProfiles.drawToolbar(host, "resources", "resource_builder");
		ImGui.separator();
		section("Common Resources");
		var v = host.vitals;
		if (host.target != null) navRow("target", "Current Target", host.target.hidden, host.target.chrome);
		if (v != null) navRow("health", "Health", v.hpHidden, v.chrome);
		if (host.attackCombo != null) navRow("attack", "Combo Tracker", host.attackCombo.hidden, host.attackCombo.chrome);
		section("Class Resources");
		if (v != null) {
			navRow("rage", "Rage", v.rageHidden, v.rageChrome);
			navRow("mana", "Mana/Spark", v.manaHidden, v.manaChrome);
			navRow("prayers", "Prayers", v.prayersHidden, v.prayersChrome);
		}
		if (host.combo != null) navRow("combo", "Combo Points", host.combo.hidden, host.combo.chrome);
		if (host.chaincast != null) navRow("chaincast", "Chaincast", host.chaincast.hidden, host.chaincast.chrome);
		if (host.conduit != null) navRow("conduit", "Conduits", host.conduit.hidden, host.conduit.chrome);
	}

	static function section(label:String):Void {
		ImGui.spacing();
		solarflare.ui.UiChrome.heading(label);
		ImGui.separator();
		ImGui.spacing();
	}

	function navRow(id:String, label:String, hidden:BoolRef, chrome:HudChrome):Void {
		ImGui.spacing();
		if (selected == id)
			ImGui.textColored(solarflare.ui.ThemePalette.current().accent, label);
		else
			ImGui.text(label);
		if (hidden != null && ImGui.checkbox("Hide##rt_nav_hide_" + id, hidden)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (chrome != null && ImGui.checkbox("Lock##rt_nav_lock_" + id, chrome.locked)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (chrome != null && ImGui.checkbox("Transparent##rt_nav_trans_" + id, chrome.transparent)) SettingsStore.markDirty();
		ImGui.sameLine();
		ImGui.setCursorPosX(ImGui.getCursorPosX() + Math.max(0, ImGui.getContentRegionAvail().x - 28));
		if (gearButton(id, selected == id)) selected = id;
		ImGui.separator();
	}

	/** Small settings CTA; draw gear directly so no font glyph dependency. */
	static function gearButton(id:String, active:Bool):Bool {
		var clicked = active
			? solarflare.ui.UiChrome.accentButton("##rt_settings_" + id, ImGui.vec2(28, 28))
			: ImGui.button("##rt_settings_" + id, ImGui.vec2(28, 28));
		var p = ImGui.getItemRectMin();
		var dl = ImGui.getWindowDrawList();
		if (active || clicked)
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(p.x + 1, p.y + 1), ImGui.vec2(p.x + 27, p.y + 27),
				0xFFFFFFFF, 5, 2);
		var col = active ? 0xFF181818 : ImGui.colorConvertFloat4ToU32(solarflare.ui.ThemePalette.current().text);
		for (i in 0...32) {
			var a = i * Math.PI / 16;
			var b = (i + 1) * Math.PI / 16;
			var r = i % 4 < 2 ? 9 : 6.5;
			var next = (i + 1) % 4 < 2 ? 9 : 6.5;
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p.x + 14 + Math.cos(a) * r, p.y + 14 + Math.sin(a) * r),
				ImGui.vec2(p.x + 14 + Math.cos(b) * next, p.y + 14 + Math.sin(b) * next), col, 1.5);
		}
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(p.x + 14, p.y + 14), 3, col, 16, 1.5);
		return clicked;
	}

	function drawPreview():Void {
		section("Preview");
		var left = ImGui.getCursorPosX();
		var availW = ImGui.getContentRegionAvail().x;
		var controlW:Single = Math.min(500, availW);
		solarflare.ui.UiChrome.heading("Mode", 1);
		ImGui.setCursorPosX(left + (availW - controlW) * 0.5);
		ImGui.setNextItemWidth(controlW);
		if (ImGui.beginCombo("##rt_preview_scope", previewScope.get() == 1 ? "All elements" : "Selected element")) {
			if (ImGui.selectable("Selected element##rt_scope_selected", previewScope.get() == 0)) previewScope.set(0);
			if (ImGui.selectable("All elements##rt_scope_all", previewScope.get() == 1)) previewScope.set(1);
			ImGui.endCombo();
		}
		ImGui.setCursorPosX(left);
		solarflare.ui.UiChrome.heading("State", 1);
		ImGui.setCursorPosX(left + (availW - controlW) * 0.5);
		ImGui.setNextItemWidth(controlW);
		if (ImGui.beginCombo("##rt_preview_state", scenarioLabel(previewScenario.get()))) {
			for (i in 0...4) if (ImGui.selectable(scenarioLabel(i) + "##rt_scenario_" + i, previewScenario.get() == i)) {
				previewScenario.set(i);
				previewState = PreviewState.forScenario(scenarioOf(i));
			}
			ImGui.endCombo();
		}
		ImGui.setCursorPosX(left);
		ImGui.spacing();
		var previewH:Single = previewScope.get() == 1 ? 360 : 100;
		HudChrome.safeChild("##rt_preview_canvas", ImGui.vec2(0, previewH), HudChrome.CHILD_NO_SCROLL, function() {
			var avail = ImGui.getContentRegionAvail();
			var width:Single = Math.max(40, Math.min(620, avail.x));
			if (previewScope.get() == 1) previewRenderer.drawAll(previewState, host, width);
			else previewRenderer.drawSelected(selected, previewState, host, width);
		});
	}

	function drawSelectedSettings():Void {
		var v = host.vitals;
		switch (selected) {
			case "health":
				drawWindow(v.hpHidden, v.chrome, v.hpWidth, v.hpHeight, "health");
				drawVitalAppearance("Health", v.hpStyle, v.hpVertical, true, "health");
				drawBehaviorText("Health shows current/max health and shield using the selected presentation.");
			case "rage":
				drawWindow(v.rageHidden, v.rageChrome, v.rageWidth, v.rageHeight, "rage");
				drawVitalAppearance("Rage", v.rageStyle, v.rageVertical, false, "rage");
				drawBehaviorText("Rage uses the authoritative rage snapshot and maximum-resource alert.");
			case "mana":
				drawWindow(v.manaHidden, v.manaChrome, v.manaWidth, v.manaHeight, "mana");
				drawVitalAppearance("Mana/Spark", v.manaStyle, v.manaVertical, true, "mana");
				drawBehaviorText("This window presents Spark when Spark is authoritative; otherwise it presents Mana.");
			case "prayers":
				drawWindow(v.prayersHidden, v.prayersChrome, v.prayersWidth, v.prayersHeight, "prayers");
				section("Appearance"); ImGui.textDisabled("Prayer readiness uses the three semantic prayer colors.");
				drawBehaviorText("Smite, Life, and Shield readiness are observed independently.");
			case "combo":
				drawWindow(host.combo.hidden, host.combo.chrome, host.combo.width, host.combo.height, "combo");
				section("Appearance");
				if (ImGui.checkbox("Vertical##rt_combo_vertical", host.combo.vertical)) SettingsStore.markDirty();
				PipShapes.drawShapeCombo("Pip shape##rt_combo_shape", host.combo.shape);
				drawBehaviorText("Shows Rogue combo points from 0 through 6.");
			case "attack":
				drawWindow(host.attackCombo.hidden, host.attackCombo.chrome, host.attackCombo.width, host.attackCombo.height, "attack");
				section("Appearance"); host.attackCombo.drawAppearanceSettings();
				section("Behavior"); host.attackCombo.drawBehaviorSettings();
			case "target":
				if (host.target != null)
					host.target.drawSettings("rt_tgt");
			case "chaincast":
				drawWindow(host.chaincast.hidden, host.chaincast.chrome, host.chaincast.width, host.chaincast.height, "chaincast");
				section("Appearance"); ImGui.textDisabled("Chaincast uses its fixed rail and ready-gem presentation.");
				section("Behavior"); host.chaincast.drawSettings();
			case "conduit":
				drawWindow(host.conduit.hidden, host.conduit.chrome, host.conduit.width, host.conduit.height, "conduit");
				section("Appearance");
				if (ImGui.checkbox("Vertical##rt_conduit_vertical", host.conduit.vertical)) SettingsStore.markDirty();
				PipShapes.drawShapeCombo("Pip shape##rt_conduit_shape", host.conduit.shape);
				drawBehaviorText("Shows Sparkmaster conduit slots and Power stacks from 0 through 20.");
			default: ImGui.textDisabled("Select a resource from the left pane.");
		}
	}

	function drawWindow(hidden:BoolRef, chrome:HudChrome, width:FloatRef, height:FloatRef, id:String):Void {
		section("Window");
		if (chrome != null) chrome.drawWindowSettings(hidden, "rt_" + id);
		if (ImGui.sliderFloat("Width##rt_" + id + "_w", width, minWidth(id), maxWidth(id), "%.0f px")) { markSizeDirty(id); SettingsStore.markDirty(); }
		if (ImGui.sliderFloat("Height##rt_" + id + "_h", height, minHeight(id), maxHeight(id), "%.0f px")) { markSizeDirty(id); SettingsStore.markDirty(); }
	}

	function drawVitalAppearance(label:String, style:IntRef, vertical:BoolRef, allowPips:Bool, id:String):Void {
		section("Appearance");
		VitalsConfig.drawStyleCombo(label + " style##rt_" + id + "_style", style, true, allowPips);
		if (ImGui.checkbox("Vertical##rt_" + id + "_vertical", vertical)) SettingsStore.markDirty();
	}

	function drawBehaviorText(text:String):Void { section("Behavior"); ImGui.textWrapped(text); }

	function markSizeDirty(id:String):Void switch (id) {
		case "health": host.vitals.hpSizeDirty = true;
		case "rage": host.vitals.rageSizeDirty = true;
		case "mana": host.vitals.manaSizeDirty = true;
		case "prayers": host.vitals.prayersSizeDirty = true;
		case "combo": host.combo.sizeDirty = true;
		case "attack": host.attackCombo.sizeDirty = true;
		case "target": host.target.sizeDirty = true;
		case "chaincast": host.chaincast.sizeDirty = true;
		case "conduit": host.conduit.sizeDirty = true;
	}

	static function minWidth(id:String):Single return switch (id) {
		case "combo": ComboConfig.MIN_W; case "attack": AttackComboConfig.MIN_W; case "target": TargetConfig.MIN_W;
		case "chaincast": ChaincastConfig.MIN_W;
		case "conduit": ConduitConfig.MIN_W; default: VitalsConfig.HP_MIN_W;
	};
	static function maxWidth(id:String):Single return switch (id) {
		case "combo": ComboConfig.MAX_W; case "attack": AttackComboConfig.MAX_W; case "target": TargetConfig.MAX_W;
		case "chaincast": ChaincastConfig.MAX_W;
		case "conduit": ConduitConfig.MAX_W; default: VitalsConfig.HP_MAX_W;
	};
	static function minHeight(id:String):Single return switch (id) {
		case "combo": ComboConfig.MIN_H; case "attack": AttackComboConfig.MIN_H; case "target": TargetConfig.MIN_H;
		case "chaincast": ChaincastConfig.MIN_H;
		case "conduit": ConduitConfig.MIN_H; default: 28;
	};
	static function maxHeight(id:String):Single return switch (id) {
		case "combo": ComboConfig.MAX_H; case "attack": AttackComboConfig.MAX_H; case "target": TargetConfig.MAX_H;
		case "chaincast": ChaincastConfig.MAX_H;
		case "conduit": ConduitConfig.MAX_H; default: VitalsConfig.HP_MAX_H;
	};

	static function scenarioOf(i:Int):PreviewScenario return switch (i) { case 0: Empty; case 2: Full; case 3: FinalAlert; default: Partial; };
	static function scenarioLabel(i:Int):String return PreviewState.scenarioLabel(scenarioOf(i));

	function selectedLabel():String return switch (selected) {
		case "health": "Health"; case "rage": "Rage"; case "mana": "Mana/Spark"; case "prayers": "Prayers";
		case "combo": "Combo Points"; case "attack": "Combo Tracker"; case "target": "Current Target";
		case "chaincast": "Chaincast";
		case "conduit": "Conduits"; default: "Resource";
	};

	static function isResourceId(id:String):Bool return id == "health" || id == "rage" || id == "mana" || id == "prayers"
		|| id == "combo" || id == "attack" || id == "target" || id == "chaincast" || id == "conduit";
}
