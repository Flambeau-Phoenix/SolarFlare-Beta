package solarflare.preview;

import imgui.ImGui;
import solarflare.castbar.CastBarRenderer;
import solarflare.castbar.CastSnap;
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
	static var ALL_IDS = ["target", "castbar", "dash", "health", "attack", "rage", "mana", "prayers", "combo", "chaincast", "conduit"];
	var dashSample=new solarflare.resourcetracker.DashState();
	var dashPreviewSource:PreviewState;
	var hp = new VitalSnap();
	var rage = new VitalSnap();
	var mana = new VitalSnap();
	var targetRenderer = new solarflare.target.TargetOverlay();
	var targetSample = new solarflare.target.TargetSnap();
	var castSample = new CastSnap();
	var chainSkill = new solarflare.chaincast.ChaincastSkillState();
	public var chainSkillPreview:Int = 0;
	public static final CHAIN_SKILL_PREVIEWS = ["Cooldown (3.7s)", "Off cooldown", "No data", "No skill linked"];

	public function new() {
		hp.kind = VitalSnap.HP;
		rage.kind = VitalSnap.RAGE;
		mana.kind = VitalSnap.MANA;
		castSample.active = true;
		castSample.skillId = "Mage_RayOfSpark";
		castSample.label = "Ray Of Spark";
		castSample.duration = 3.5;
		castSample.elapsed = 2.15;
		castSample.remaining = 1.35;
		castSample.progress = castSample.elapsed / castSample.duration;
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
		if(id=="dash" && cfg!=null) return Math.max(cfg.dash.minHeight(),cfg.dash.height.get());
		if (id == "chaincast" && cfg != null && cfg.chaincast != null)
			return ChaincastRenderer.headHeight(cfg.chaincast.style.get(), cfg.chaincast.width.get());
		if (id == "target") return cfg != null && cfg.target != null ? Math.max(solarflare.target.TargetConfig.MIN_H, Math.min(solarflare.target.TargetConfig.MAX_H, cfg.target.height.get())) : 72;
		if (id == "castbar" && cfg != null && cfg.castBar != null)
			return Math.max(solarflare.castbar.CastBarConfig.MIN_H,
				Math.min(solarflare.castbar.CastBarConfig.MAX_H, cfg.castBar.height.get()));
		if (cfg == null || cfg.vitals == null) return 30;
		var v = cfg.vitals;
		return switch (id) {
			case "health": VitalsConfig.compactRow(v.hpStyle.get(), v.hpVertical.get()) ? 30 : Math.max(30, v.hpHeight.get()-8);
			case "rage": VitalsConfig.compactRow(v.rageStyle.get(), v.rageVertical.get()) ? 30 : Math.max(30, v.rageHeight.get()-8);
			case "mana": VitalsConfig.compactRow(v.manaStyle.get(), v.manaVertical.get()) ? 30 : Math.max(30, v.manaHeight.get()-8);
			case "prayers": solarflare.resourcetracker.PrayerRenderer.rowHeight(v.prayersLook, false);
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
		if(id=="dash") width=Math.min(width,Math.max(cfg.dash.minWidth(),cfg.dash.width.get()));
		if(id=="target" && cfg.target!=null) width=Math.min(width,Math.max(solarflare.target.TargetConfig.MIN_W,Math.min(solarflare.target.TargetConfig.MAX_W,cfg.target.width.get())));
		var left = ImGui.getCursorPosX();
		ImGui.setCursorPosX(left + Math.max(0, (ImGui.getContentRegionAvail().x - width) * 0.5));
		var art=cfg.resourceArtwork.get(id);
		var face=ImGui.getCursorScreenPos();
		var artProgress:Float=s.hpRatio();
		switch(id) {
			case "rage": artProgress=s.rageMax>0 ? s.rage/s.rageMax : 0;
			case "mana": artProgress=s.sparkValid ? (s.sparkMax>0 ? s.spark/s.sparkMax : 0) : s.manaMax>0 ? s.mana/s.manaMax : 0;
			case "prayers": artProgress=s.prayersCharged/3;
			case "combo": artProgress=s.comboMax>0 ? s.comboCurrent/s.comboMax : 0;
			case "attack": artProgress=s.attackLength>0 ? s.attackStep/s.attackLength : 0;
			case "chaincast": artProgress=s.chainReady ? 1 : s.chainMax>0 ? s.chainCurrent/s.chainMax : 0;
			case "conduit": artProgress=s.conduitSlotCount>0 ? s.conduitFilled/s.conduitSlotCount : 0;
			case "castbar": artProgress=castSample.progress;
			case "dash": artProgress=s.comboCurrent==0 ? 0.8 : s.comboCurrent>=s.comboMax ? 1 : 0.45;
			default:
		}
		if(art!=null) art.paint(face.x,face.y,width,height,artProgress,false);
		ImGui.setCursorScreenPos(face);
		if(art==null || art.keepContent.get() || !art.ready()) switch (id) {
			case "dash":
				if(dashPreviewSource!=s) { dashPreviewSource=s; dashSample.update("Dash_Base",s.comboCurrent==0 ? 0 : s.comboCurrent>=s.comboMax ? 2 : 1,2,s.comboCurrent>=s.comboMax ? 0 : artProgress*8,8); }
				solarflare.resourcetracker.DashTracker.render(cfg.dash,dashSample,width,height);
			case "health":
				syncHp(s);
				VitalsRenderer.draw(hp, cfg.vitals.hpStyle.get(), width, height, cfg.vitals.hpVertical.get(), false, cfg.vitals.hpLook);
			case "rage":
				syncRage(s);
				VitalsRenderer.draw(rage, cfg.vitals.rageStyle.get(), width, height, cfg.vitals.rageVertical.get(), false, cfg.vitals.rageLook);
			case "mana":
				syncMana(s);
				VitalsRenderer.draw(mana, cfg.vitals.manaStyle.get(), width, height, cfg.vitals.manaVertical.get(), false, cfg.vitals.manaLook);
			case "prayers":
				solarflare.resourcetracker.PrayerRenderer.draw(cfg.vitals.prayersLook, art, s.prayersCharged >= 1, s.prayersCharged >= 2,
					s.prayersCharged >= 3, width, false);
			case "combo":
				var points = cfg.combo.points();
				var filled = s.comboCurrent >= s.comboMax ? points : Std.int(Math.min(points, s.comboCurrent));
				PipShapes.drawCount(width, height, points, filled, cfg.combo.vertical.get(), cfg.combo.shape.get(),
					s.comboAlert ? "MAX" : Std.string(filled), null, cfg.combo.look, art, 0, solarflare.combo.Combo.ComboConfig.EMPTY_SLOT);
			case "attack":
				AttackComboRenderer.draw(s.attackStep, s.attackLength, s.attackFlashFinal, s.attackWithinCombo, cfg.attackCombo, width, height,
					AttackComboRenderer.RESOURCE_PREVIEW);
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
				targetRenderer.drawPreview(cfg.target, targetSample, width, height, castSample);
			case "castbar":
				var p = ImGui.getCursorScreenPos();
				ImGui.dummy(ImGui.vec2(width, height));
				CastBarRenderer.drawPlayer(castSample, cfg.castBar.skin.get(), cfg.castBar.showIcon.get(),
					cfg.castBar.showName.get(), cfg.castBar.showTime.get(), p.x, p.y, width, height);
			case "chaincast":
				var showBadge = cfg.chaincast == null || cfg.chaincast.showStackBadge == null
					|| cfg.chaincast.showStackBadge.get();
				chainSkill.update(chainSkillPreview != 3, chainSkillPreview != 2, chainSkillPreview != 2,
					chainSkillPreview == 1, 3.7, 10);
				ChaincastRenderer.drawHead(width, height, s.chainShownCount(), s.chainReady, showBadge, s.chainPulse,
					cfg.chaincast != null ? cfg.chaincast.style.get() : 0, chainSkill);
			case "conduit":
				drawConduitPreview(s, cfg, width, height);
			default:
				ImGui.textDisabled("Select a resource to preview.");
		}
		else ImGui.dummy(ImGui.vec2(width,height));
		if(art!=null) { var end=ImGui.getCursorScreenPos(); art.paint(face.x,face.y,width,height,artProgress,true); ImGui.setCursorScreenPos(end); }
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
		var powers = new Array<Bool>();
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
			powers.push(power);
			if (power && stacks > 0)
				stackLabels.push(Std.string(stacks));
			else
				stackLabels.push("");
			i++;
		}
		ConduitOverlay.drawSlotRow(width, height, n, amounts, iconIds, stackLabels, cfg.conduit.vertical.get(),
			cfg.conduit.shape.get(), s.conduitLabel(), cfg.conduit.look, cfg.resourceArtwork.get("conduit"), powers);
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
			case "dash": "Dash / Recharge";
			case "health": "Health";
			case "rage": "Rage";
			case "mana": "Mana / Spark";
			case "prayers": "Prayers";
			case "combo": "Combo Points";
			case "attack": "Attack Combo";
			case "target": "Current Target";
			case "castbar": "Player Cast Bar";
			case "chaincast": "Chaincast";
			case "conduit": "Conduits";
			default: id;
		};
	}
}
