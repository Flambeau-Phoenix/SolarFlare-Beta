package solarflare.preview;

import imgui.ImGui;
import solarflare.attackcombo.AttackComboRenderer;
import solarflare.chaincast.ChaincastRenderer;
import solarflare.conduit.Conduit;
import solarflare.preview.VitalsRenderer;
import solarflare.ui.ConfigPanel;
import solarflare.ui.EnhancedText;
import solarflare.ui.PipShapes;
import solarflare.ui.UiCol;
import solarflare.ui.VitalsConfig;

/**
 * Embedded ResourceTracker presentation. It consumes only a frozen PreviewState
 * and the user's presentation settings; it never reads caches or writes live
 * window geometry. Vitals and pip resources use the same low-level renderers as
 * their live overlays.
 */
class ResourcePreviewRenderer {
	static var ALL_IDS = ["target", "health", "attack", "rage", "mana", "prayers", "combo", "chaincast", "conduit"];
	var hp = new VitalSnap();
	var rage = new VitalSnap();
	var mana = new VitalSnap();
	var targetRenderer = new solarflare.target.TargetOverlay();
	var targetSample = new solarflare.target.TargetSnap();

	public function new() {
		hp.kind = VitalSnap.HP;
		rage.kind = VitalSnap.RAGE;
		mana.kind = VitalSnap.MANA;
	}

	public function drawSelected(id:String, state:PreviewState, cfg:ConfigPanel, width:Single):Void {
		if (id == null || id.length == 0)
			id = "health";
		drawElement(id, state, cfg, width, elementHeight(id, cfg));
	}

	public function drawAll(state:PreviewState, cfg:ConfigPanel, width:Single):Void {
		for (id in ALL_IDS) {
			solarflare.ui.UiChrome.heading(labelOf(id), 1);
			drawElement(id, state, cfg, width, elementHeight(id, cfg));
		}
	}

	public function elementHeight(id:String, cfg:ConfigPanel):Single {
		if (id == "target") return 64;
		if (cfg == null || cfg.vitals == null) return 30;
		var v = cfg.vitals;
		return switch (id) {
			case "health": VitalsConfig.compactRow(v.hpStyle.get(), v.hpVertical.get()) ? 30 : Math.max(30, v.hpHeight.get()-8);
			case "rage": VitalsConfig.compactRow(v.rageStyle.get(), v.rageVertical.get()) ? 30 : Math.max(30, v.rageHeight.get()-8);
			case "mana": VitalsConfig.compactRow(v.manaStyle.get(), v.manaVertical.get()) ? 30 : Math.max(30, v.manaHeight.get()-8);
			case "attack": Math.max(30, cfg.attackCombo.height.get()-8);
			case "combo": Math.max(30, cfg.combo.height.get()-8);
			case "conduit": Math.max(30, cfg.conduit.height.get()-8);
			default: 30;
		};
	}
	public function measureAll(cfg:ConfigPanel):Single {
		var height:Single = 0;
		for (id in ALL_IDS) height += elementHeight(id, cfg) + ImGui.getTextLineHeightWithSpacing() * 1.5 + 8;
		return height;
	}

	function drawElement(id:String, s:PreviewState, cfg:ConfigPanel, width:Single, height:Single):Void {
		if (s == null || cfg == null)
			return;
		if (width < 40)
			width = 40;
		var left = ImGui.getCursorPosX();
		ImGui.setCursorPosX(left + Math.max(0, (ImGui.getContentRegionAvail().x - width) * 0.5));
		switch (id) {
			case "health":
				syncHp(s);
				VitalsRenderer.draw(hp, cfg.vitals.hpStyle.get(), width, height, cfg.vitals.hpVertical.get());
			case "rage":
				syncRage(s);
				VitalsRenderer.draw(rage, cfg.vitals.rageStyle.get(), width, height, cfg.vitals.rageVertical.get());
			case "mana":
				syncMana(s);
				VitalsRenderer.draw(mana, cfg.vitals.manaStyle.get(), width, height, cfg.vitals.manaVertical.get());
			case "prayers":
				PipShapes.drawCount(width, height, 3, s.prayersCharged, false, PipShapes.RING,
					Std.string(s.prayersCharged), null);
			case "combo":
				PipShapes.drawCount(width, height, s.comboMax, s.comboCurrent, cfg.combo.vertical.get(), cfg.combo.shape.get(),
					s.comboAlert ? "MAX" : Std.string(s.comboCurrent), null);
			case "attack":
				AttackComboRenderer.draw(s.attackStep, s.attackLength, s.attackFlashFinal, s.attackWithinCombo, cfg.attackCombo, width, height);
			case "target":
				targetSample.valid = true;
				targetSample.name = "Nightspawn";
				targetSample.healthValid = s.hpValid;
				targetSample.health = s.hpCurrent;
				targetSample.maxHealth = s.hpMax;
				targetSample.ratio = s.hpRatio();
				targetSample.targetLevelValid = true; targetSample.playerLevelValid = true;
				targetSample.targetLevel = 12; targetSample.playerLevel = 10;
				targetSample.isElite = true;
				targetRenderer.drawPreview(cfg.target, targetSample, width, Math.max(64, height));
			case "chaincast":
				var showBadge = cfg.chaincast == null || cfg.chaincast.showStackBadge == null
					|| cfg.chaincast.showStackBadge.get();
				ChaincastRenderer.drawHead(width, height, s.chainShownCount(), s.chainReady, showBadge, s.chainPulse);
			case "conduit":
				drawConduitPreview(s, cfg, width, height);
			default:
				ImGui.textDisabled("Select a resource to preview.");
		}
		ImGui.setCursorPosX(left);
		// Register the restored cursor (including trailing item spacing) before EndChild.
		ImGui.pushStyleVar(imgui.Enums.ImGuiStyleVar.ItemSpacing, ImGui.vec2(0, 0));
		ImGui.dummy(ImGui.vec2(0, 0));
		ImGui.popStyleVar();
	}


	static function drawConduitPreview(s:PreviewState, cfg:ConfigPanel, width:Single, height:Single):Void {
		var n = s.conduitSlotCount;
		if (n < 1)
			n = 3;
		var amounts = new Array<Float>();
		var iconIds = new Array<String>();
		var stackLabels = new Array<String>();
		var i = 0;
		while (i < n) {
			var slot = s.conduitSlots != null && i < s.conduitSlots.length ? s.conduitSlots[i] : null;
			var id = slot != null && slot.id != null ? slot.id : "";
			var stacks = slot != null ? slot.stacks : 0;
			var power = slot != null && slot.power;
			var filled = slot != null && (slot.filled || id.length > 0);
			var amt:Float = filled ? 1 : 0;
			amounts.push(amt);
			iconIds.push(id);
			if (power && stacks > 0)
				stackLabels.push(Std.string(stacks));
			else
				stackLabels.push("");
			i++;
		}
		ConduitOverlay.drawSlotRow(width, height, n, amounts, iconIds, stackLabels, cfg.conduit.vertical.get(),
			cfg.conduit.shape.get(), s.conduitLabel());
	}

	function syncHp(s:PreviewState):Void {
		hp.valid = s.hpValid;
		hp.current = s.hpCurrent;
		hp.max = s.hpMax;
		hp.ratio = s.hpRatio();
		hp.shield = s.hpShield;
	}

	function syncRage(s:PreviewState):Void {
		rage.valid = s.rageValid;
		rage.current = s.rage;
		rage.max = s.rageMax;
		rage.ratio = s.rageRatio();
	}

	function syncMana(s:PreviewState):Void {
		mana.valid = s.resourceValid();
		mana.current = s.resourceCurrent();
		mana.max = s.resourceMax();
		mana.ratio = s.resourceRatio();
		mana.sparkValid = s.sparkValid;
	}

	static function labelOf(id:String):String {
		return switch (id) {
			case "health": "Health";
			case "rage": "Rage";
			case "mana": "Mana / Spark";
			case "prayers": "Prayers";
			case "combo": "Combo Points";
			case "attack": "Attack Combo";
			case "target": "Current Target";
			case "chaincast": "Chaincast";
			case "conduit": "Conduits";
			default: id;
		};
	}
}
