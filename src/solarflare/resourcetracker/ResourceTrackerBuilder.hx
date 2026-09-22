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
import solarflare.ui.HideAllBind;
import solarflare.ui.HudChrome;
import solarflare.ui.HudSuppress;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import solarflare.ui.EditorWindow;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.UiLayout;
import solarflare.ui.VitalsConfig;

/** Unified F6 editor for every independently movable resource window. */
class ResourceTrackerBuilder {
	/** Nav row height; the selectable and its Showing tile share it so they align. */
	static inline var ROW_H:Single = 26;

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
		EditorWindow.drawMenuWindow("Resource Tracker Builder###SolarFlare.ResourceTracker", open, 1240, 860, function() {
			drawMenuBar();
			ImGui.textWrapped("Pick a resource on the left to edit it on the right. The Showing toggle takes effect on the live HUD straight away.");
			ImGui.separator();
			HudChrome.safeChild("##rt_builder_left", ImGui.vec2(320, 0), 0, drawNavigation, imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
			ImGui.sameLine(0, 24);
			HudChrome.safeChild("##rt_builder_right", ImGui.vec2(0, 0), 0, function() {
				drawPreview();
				section("Settings — " + selectedLabel());
				drawSelectedSettings();
				ImGui.separator();
				ImGui.textDisabled("Saved with the active Resources profile.");
			}, imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
		}, false, true);
	}

	function drawMenuBar():Void {
		if (!ImGui.beginMenuBar())
			return;
		if (ImGui.beginMenu("Open")) {
			if (ImGui.menuItem("SolarFlare Hub", "F6") && host != null)
				host.open.set(true);
			if (ImGui.menuItem("Aura Builder") && host != null && host.auraBuilder != null)
				host.auraBuilder.open.set(true);
			if (ImGui.menuItem("Geaux Builder") && host != null && host.geauxBuilder != null)
				host.geauxBuilder.open.set(true);
			if (ImGui.menuItem("Notebook") && host != null && host.notebook != null)
				host.notebook.open.set(true);
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("File")) {
			if (ImGui.menuItem("Save", "Ctrl+S"))
				solarflare.ui.UiActionQueue.save();
			if (ImGui.menuItem("Reset Dock Layout"))
				solarflare.ui.UiActionQueue.enqueue(solarflare.ui.UiActionQueue.UiActionKind.ResetDockLayout);
			ImGui.endMenu();
		}
		ImGui.endMenuBar();
	}

	function drawNavigation():Void {
		solarflare.ui.FeatureProfiles.drawToolbar(host, "resources", "resource_builder");
		ImGui.separator();
		section("Common Resources");
		var v = host.vitals;
		if (host.target != null) navRow("target", "Current Target", host.target.hidden);
		if (host.castBar != null) navRow("castbar", "Player Cast Bar", host.castBar.hidden);
		if (v != null) navRow("health", "Health", v.hpHidden);
		if (host.attackCombo != null) navRow("attack", "Combo Tracker", host.attackCombo.hidden);
		section("Class Resources");
		if (v != null) {
			navRow("rage", "Rage", v.rageHidden);
			navRow("mana", "Mana/Spark", v.manaHidden);
			navRow("prayers", "Prayers", v.prayersHidden);
		}
		if (host.combo != null) navRow("combo", "Combo Points", host.combo.hidden);
		if (host.chaincast != null) navRow("chaincast", "Chaincast", host.chaincast.hidden);
		if (host.conduit != null) navRow("conduit", "Conduits", host.conduit.hidden);
		drawHideAll();
	}

	/** Blanks every HUD draw on a keypress; saved window state is untouched. */
	function drawHideAll():Void {
		section("Hide All");
		UiLayout.propertyGrid("##rt_hide_all", function() {
			UiLayout.propertyRow("Hidden", function() {
				if (ImGui.checkbox("##rt_ha_state", HudSuppress.hideAll))
					SettingsStore.markDirty();
			}, "Blanks every SolarFlare window so the game underneath is clickable.");
			UiLayout.propertyRow("Hotkey", function() {
				if (ImGui.combo("##rt_ha_key", HideAllBind.choice, HideAllBind.ITEMS))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Middle mouse", function() {
				if (ImGui.checkbox("##rt_ha_mmb", HideAllBind.middleMouse))
					SettingsStore.markDirty();
			}, "Also toggle on middle click, but only while the cursor is free.");
		});
		if (HudSuppress.active())
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "Hidden now — press the hotkey to bring the HUD back.");
		else
			ImGui.textDisabled("Never saved as hidden; every launch starts visible.");
	}

	static function section(label:String):Void {
		ImGui.spacing();
		solarflare.ui.UiChrome.heading(label);
		ImGui.separator();
		ImGui.spacing();
	}

	/**
	 * One line per resource: name selects, Showing toggles.
	 *
	 * Lock and Transparent deliberately live only in the right-hand Window section.
	 * Carrying all three here cost two lines and a separator per resource, pushed the
	 * list past the fold, and repeated controls the settings pane already owned.
	 */
	function navRow(id:String, label:String, hidden:BoolRef):Void {
		var tileW:Single = 96;
		var nameW:Single = Math.max(90, ImGui.getContentRegionAvail().x - tileW - 10);
		if (ImGui.selectable(label + "##rt_nav_" + id, selected == id, 0, ImGui.vec2(nameW, ROW_H)))
			selected = id;
		if (hidden != null) {
			ImGui.sameLine(0, 10);
			if (solarflare.ui.UiChrome.showingTile("##rt_nav_show_" + id, "Showing", hidden, tileW, ROW_H))
				SettingsStore.markDirty();
		}
	}

	function drawPreview():Void {
		section("Preview");
		// Property rows instead of centred headings with manual cursor maths: the two
		// controls are ordinary settings and read better as labelled rows.
		UiLayout.propertyGrid("##rt_preview_controls", function() {
			UiLayout.propertyRow("Mode", function() {
				if (ImGui.beginCombo("##rt_preview_scope", previewScope.get() == 1 ? "All elements" : "Selected element")) {
					if (ImGui.selectable("Selected element##rt_scope_selected", previewScope.get() == 0)) previewScope.set(0);
					if (ImGui.selectable("All elements##rt_scope_all", previewScope.get() == 1)) previewScope.set(1);
					ImGui.endCombo();
				}
			}, "Preview just the selected resource, or the whole HUD together.");
			UiLayout.propertyRow("State", function() {
				if (ImGui.beginCombo("##rt_preview_state", scenarioLabel(previewScenario.get()))) {
					for (i in 0...4) if (ImGui.selectable(scenarioLabel(i) + "##rt_scenario_" + i, previewScenario.get() == i)) {
						previewScenario.set(i);
						previewState = PreviewState.forScenario(scenarioOf(i));
					}
					ImGui.endCombo();
				}
			});
		});
		ImGui.spacing();
		var previewH:Single = previewScope.get() == 1 ? previewRenderer.measureAll(host) : previewRenderer.elementHeight(selected, host) + 8;
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
				ImGui.textWrapped("Color: " + solarflare.ui.HealthColorPolicy.source(solarflare.HealthCache.deadKnown && solarflare.HealthCache.dead, false, solarflare.HealthCache.valid)
					+ (solarflare.HealthCache.valid ? " | health valid" : " | health unavailable: empty fill"));
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
				if (solarflare.ui.UiChrome.toggleTileRef("##rt_combo_vertical", "Vertical", host.combo.vertical, 108, 28)) SettingsStore.markDirty();
				PipShapes.drawShapeCombo("Pip shape##rt_combo_shape", host.combo.shape);
				drawBehaviorText("Shows Rogue combo points from 0 through 6.");
			case "attack":
				drawWindow(host.attackCombo.hidden, host.attackCombo.chrome, host.attackCombo.width, host.attackCombo.height, "attack");
				section("Appearance"); host.attackCombo.drawAppearanceSettings();
				section("Behavior"); host.attackCombo.drawBehaviorSettings();
			case "target":
				if (host.target != null)
					host.target.drawSettings("rt_tgt");
			case "castbar":
				if (host.castBar != null)
					host.castBar.drawSettings("rt_castbar");
			case "chaincast":
				drawWindow(host.chaincast.hidden, host.chaincast.chrome, host.chaincast.width, host.chaincast.height, "chaincast");
				section("Appearance"); ImGui.textDisabled("Chaincast uses its fixed rail and ready-gem presentation.");
				section("Behavior"); host.chaincast.drawSettings();
			case "conduit":
				drawWindow(host.conduit.hidden, host.conduit.chrome, host.conduit.width, host.conduit.height, "conduit");
				section("Appearance");
				if (solarflare.ui.UiChrome.toggleTileRef("##rt_conduit_vertical", "Vertical", host.conduit.vertical, 108, 28)) SettingsStore.markDirty();
				PipShapes.drawShapeCombo("Pip shape##rt_conduit_shape", host.conduit.shape);
				drawBehaviorText("Shows Sparkmaster conduit slots and Power stacks from 0 through 20.");
			default: ImGui.textDisabled("Select a resource from the left pane.");
		}
	}

	function drawWindow(hidden:BoolRef, chrome:HudChrome, width:FloatRef, height:FloatRef, id:String):Void {
		section("Window");
		if (chrome != null) chrome.drawWindowSettings(hidden, "rt_" + id);
		UiLayout.propertyGrid("##rt_" + id + "_window_props", function() {
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair(
					"##rt_" + id + "_size",
					function(_:Single) {
						if (ImGui.sliderFloat("Width##rt_" + id + "_w", width, minWidth(id), maxWidth(id), "%.0f px")) {
							markSizeDirty(id);
							SettingsStore.markDirty();
						}
					},
					function(_:Single) {
						var autoHeight = switch (id) {
							case "health": VitalsConfig.compactRow(host.vitals.hpStyle.get(), host.vitals.hpVertical.get());
							case "rage": VitalsConfig.compactRow(host.vitals.rageStyle.get(), host.vitals.rageVertical.get());
							case "mana": VitalsConfig.compactRow(host.vitals.manaStyle.get(), host.vitals.manaVertical.get());
							case "prayers", "chaincast": true;
							default: false;
						};
						if (autoHeight) ImGui.textDisabled("Content fit");
						else if (ImGui.sliderFloat("Height##rt_" + id + "_h", height, minHeight(id), maxHeight(id), "%.0f px")) {
							markSizeDirty(id);
							SettingsStore.markDirty();
						}
					}
				);
			});
		});
	}

	function drawVitalAppearance(label:String, style:IntRef, vertical:BoolRef, allowPips:Bool, id:String):Void {
		section("Appearance");
		UiLayout.propertyGrid("##rt_" + id + "_appearance", function() {
			UiLayout.propertyRow("Style", function() {
				VitalsConfig.drawStyleCombo(label + " style##rt_" + id + "_style", style, true, allowPips);
			});
			UiLayout.propertyRow("Layout", function() {
				if (solarflare.ui.UiChrome.toggleTileRef("##rt_" + id + "_vertical", "Vertical", vertical, 108, 28))
					SettingsStore.markDirty();
			});
		});
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
		case "castbar": host.castBar.sizeDirty = true;
		case "chaincast": host.chaincast.sizeDirty = true;
		case "conduit": host.conduit.sizeDirty = true;
	}

	static function minWidth(id:String):Single return switch (id) {
		case "combo": ComboConfig.MIN_W; case "attack": AttackComboConfig.MIN_W; case "target": TargetConfig.MIN_W;
		case "castbar": solarflare.castbar.CastBarConfig.MIN_W;
		case "chaincast": ChaincastConfig.MIN_W;
		case "conduit": ConduitConfig.MIN_W; default: VitalsConfig.HP_MIN_W;
	};
	static function maxWidth(id:String):Single return switch (id) {
		case "combo": ComboConfig.MAX_W; case "attack": AttackComboConfig.MAX_W; case "target": TargetConfig.MAX_W;
		case "castbar": solarflare.castbar.CastBarConfig.MAX_W;
		case "chaincast": ChaincastConfig.MAX_W;
		case "conduit": ConduitConfig.MAX_W; default: VitalsConfig.HP_MAX_W;
	};
	static function minHeight(id:String):Single return switch (id) {
		case "combo": ComboConfig.MIN_H; case "attack": AttackComboConfig.MIN_H; case "target": TargetConfig.MIN_H;
		case "castbar": solarflare.castbar.CastBarConfig.MIN_H;
		case "chaincast": ChaincastConfig.MIN_H;
		case "conduit": ConduitConfig.MIN_H; default: 28;
	};
	static function maxHeight(id:String):Single return switch (id) {
		case "combo": ComboConfig.MAX_H; case "attack": AttackComboConfig.MAX_H; case "target": TargetConfig.MAX_H;
		case "castbar": solarflare.castbar.CastBarConfig.MAX_H;
		case "chaincast": ChaincastConfig.MAX_H;
		case "conduit": ConduitConfig.MAX_H; default: VitalsConfig.HP_MAX_H;
	};

	static function scenarioOf(i:Int):PreviewScenario return switch (i) { case 0: Empty; case 2: Full; case 3: FinalAlert; default: Partial; };
	static function scenarioLabel(i:Int):String return PreviewState.scenarioLabel(scenarioOf(i));

	function selectedLabel():String return switch (selected) {
		case "health": "Health"; case "rage": "Rage"; case "mana": "Mana/Spark"; case "prayers": "Prayers";
		case "combo": "Combo Points"; case "attack": "Combo Tracker"; case "target": "Current Target";
		case "castbar": "Player Cast Bar";
		case "chaincast": "Chaincast";
		case "conduit": "Conduits"; default: "Resource";
	};

	static function isResourceId(id:String):Bool return id == "health" || id == "rage" || id == "mana" || id == "prayers"
		|| id == "combo" || id == "attack" || id == "target" || id == "castbar" || id == "chaincast" || id == "conduit";
}
