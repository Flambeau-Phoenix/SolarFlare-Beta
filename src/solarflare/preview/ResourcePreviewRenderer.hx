package solarflare.preview;

import imgui.ImGui;
import solarflare.attackcombo.AttackComboRenderer;
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

	public function new() {
		hp.kind = VitalSnap.HP;
		rage.kind = VitalSnap.RAGE;
		mana.kind = VitalSnap.MANA;
	}

	public function drawSelected(id:String, state:PreviewState, cfg:ConfigPanel, width:Single):Void {
		if (id == null || id.length == 0)
			id = "health";
		drawElement(id, state, cfg, width, 54);
	}

	public function drawAll(state:PreviewState, cfg:ConfigPanel, width:Single):Void {
		for (id in ALL_IDS) {
			solarflare.ui.UiChrome.heading(labelOf(id), 1);
			drawElement(id, state, cfg, width, 34);
		}
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
				drawTargetPreview(cfg, width, height);
			case "chaincast":
				PipShapes.drawCount(width, height, PreviewState.CHAIN_SLOTS, s.chainShownCount(), false, PipShapes.DIAMOND,
					s.chainReady ? "READY" : Std.string(s.chainShownCount()), null);
			case "conduit":
				PipShapes.drawCount(width, height, s.conduitSlotCount, s.conduitFilled, cfg.conduit.vertical.get(),
					cfg.conduit.shape.get(), s.conduitLabel(), null);
			default:
				ImGui.textDisabled("Select a resource to preview.");
		}
		ImGui.setCursorPosX(left);
		// Register the restored cursor (including trailing item spacing) before EndChild.
		ImGui.pushStyleVar(imgui.Enums.ImGuiStyleVar.ItemSpacing, ImGui.vec2(0, 0));
		ImGui.dummy(ImGui.vec2(0, 0));
		ImGui.popStyleVar();
	}

	static function drawTargetPreview(cfg:ConfigPanel, width:Single, height:Single):Void {
		if (height < 40)
			height = 40;
		var dl = ImGui.getWindowDrawList();
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, height));
		var port:Single = cfg != null && cfg.target != null && cfg.target.showPortrait.get()
			? Math.min(height - 4, 36) : 0;
		var x0:Single = p.x;
		if (port > 0) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, p.y + 2), ImGui.vec2(x0 + port, p.y + 2 + port), 0xCC1A1218, 3);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0, p.y + 2), ImGui.vec2(x0 + port, p.y + 2 + port), 0x88FFAA66, 3, 1.2);
			x0 += port + 6;
		}
		var barW:Single = Math.max(40, p.x + width - x0);
		EnhancedText.shadowed(dl, ImGui.vec2(x0 + 2, p.y + 2), "Nightspawn", 0xFFFFFFFF, 0x88000000, 1, 1);
		var barY:Single = p.y + 18;
		var barH:Single = Math.max(12, height - 22);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, barY), ImGui.vec2(x0 + barW, barY + barH), 0xCC12141A, 3);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, barY), ImGui.vec2(x0 + barW * 0.72, barY + barH), UiCol.rgb(0x44CC55), 3);
		var ts = ImGui.calcTextSize("72%");
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x0 + (barW - ts.x) * 0.5, barY + (barH - ts.y) * 0.5), 0xFFFFFFFF, "72%");
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
