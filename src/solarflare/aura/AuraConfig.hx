package solarflare.aura;

import solarflare.HealthCache;
import solarflare.cdb.CdbAuraTable;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiChrome;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import solarflare.aura.signal.AuraRuleCodec;
import solarflare.aura.signal.AuraConditionEditor;

class AuraConfig {
	public var open = new BoolRef(false);
	public var enabled = new BoolRef(true);
	public var unlockAll = new BoolRef(true);
	public var auras:Array<AuraDef> = [];
	public var importBuf:hl.Bytes;
	public var packIdBuf:hl.Bytes;
	public var packNameBuf:hl.Bytes;
	public var packFight:String = "shared";
	public var packId:String = "my_fight";
	public var packName:String = "My fight pack";
	public var regionOverride:String = "";
	var regionBytes:haxe.io.Bytes;
	var profileNameBytes:haxe.io.Bytes;
	static inline var IMP:Int = 8192;
	static inline var PACK_ID:Int = 48;
	static inline var PACK_NAME:Int = 80;
	static inline var REGION_BUF:Int = 64;
	static inline var NAME_BUF:Int = 48;

	public function new() {
		AuraEngine.initialize();
		importBuf = new hl.Bytes(IMP);
		packIdBuf = new hl.Bytes(PACK_ID);
		packNameBuf = new hl.Bytes(PACK_NAME);
		fillBuf(packIdBuf, PACK_ID, packId);
		fillBuf(packNameBuf, PACK_NAME, packName);
		seedDefaults();
		AuraEngine.loadAll(this);
	}

	public function find(id:String):AuraDef {
		for (a in auras)
			if (a.id == id)
				return a;
		return null;
	}

	public static function fromDyn(d:Dynamic):AuraDef {
		var a = new AuraDef(Std.string(d.id), d.name != null ? Std.string(d.name) : Std.string(d.id));
		if (d.enabled == false)
			a.enabled.set(false);
		if (d.trigger != null)
			a.trigger = Std.string(d.trigger);
		if (d.skillId != null)
			a.skillId = Std.string(d.skillId);
		if (d.resource != null)
			a.resource = Std.string(d.resource);
		if (d.op != null)
			a.op = Std.string(d.op);
		if (d.pct != null)
			a.pct = d.pct;
		if (d.duration != null)
			a.duration = d.duration;
		if (d.region != null)
			a.region = Std.string(d.region);
		if (d.iconId != null)
			a.iconId = Std.string(d.iconId);
		if (d.invert == true)
			a.invert.set(true);
		if (d.requireAfford == false)
			a.requireAfford.set(false);
		if (d.dormant == true)
			a.dormant.set(true);
		if (d.visual == false)
			a.visual.set(false);
		if (d.audio == true)
			a.audio.set(true);
		if (d.cue != null)
			a.cue = Std.string(d.cue);
		if (d.plate != null)
			a.plate = Std.string(d.plate);
		// `plate` is a legacy DRM alias. Normalize it into the one icon authority.
		if (a.iconId.length == 0 && a.plate.length > 0)
			a.iconId = a.plate;
		if (d.announce != null)
			a.announce = Std.string(d.announce);
		if (d.bannerText != null)
			a.bannerText = Std.string(d.bannerText);
		if (d.bannerScale != null)
			a.bannerScale.set(d.bannerScale);
		if (d.showBanner == true)
			a.showBanner.set(true);
		if (d.fight != null)
			a.fight = Std.string(d.fight);
		if (d.keyText != null)
			a.keyText = AuraDef.sanitizeKey(d.keyText);
		else if (d.key != null)
			a.keyText = AuraDef.sanitizeKey(d.key);
		if (d.showKey == false)
			a.showKey.set(false);
		if (d.volume != null)
			a.volume.set(d.volume);
		if (d.opacity != null) {
			var visualOpacity:Float = d.opacity;
			a.opacity.set(visualOpacity < 0 ? 0 : (visualOpacity > 1 ? 1 : visualOpacity));
		}
		if (d.scale != null)
			a.scale.set(d.scale);
		if (d.showIcon == false)
			a.showIcon.set(false);
		if (d.progressRing == false)
			a.progressRing.set(false);
		if (d.stackCounter == true)
			a.stackCounter.set(true);
		if (d.showLabel == false)
			a.showLabel.set(false);
		if (d.isCounter == true)
			a.isCounter.set(true);
		if (d.w != null)
			a.w.set(d.w);
		if (d.h != null)
			a.h.set(d.h);
		if (d.x != null)
			a.chrome.x.set(d.x);
		if (d.y != null)
			a.chrome.y.set(d.y);
		if (d.lock == true)
			a.chrome.locked.set(true);
		if (d.transparent == true)
			a.chrome.transparent.set(true);
		if (Reflect.hasField(d, "rule") && d.rule != null)
			a.rule = AuraRuleCodec.fromDyn(d.rule);
		a.effects = [];
		try {
			var rawFx:Dynamic = d.effects;
			if (rawFx != null) {
				var arr:Array<Dynamic> = cast rawFx;
				var fi = 0;
				while (fi < arr.length && a.effects.length < AuraEffects.MAX) {
					if (arr[fi] != null)
						a.effects.push(AuraEffect.fromDyn(arr[fi]));
					fi++;
				}
			}
		} catch (_:Dynamic) {}
		AuraEffects.ensure(a);
		AuraEffects.syncDormantFlag(a);
		a.pctRef.set(a.pct);
		a.durRef.set(a.duration);
		a.syncSkillBuf();
		a.syncNameBuf();
		a.syncIconBuf();
		a.syncCueBuf();
		a.syncPlateBuf();
		a.syncAnnounceBuf();
		a.syncBannerBuf();
		a.syncFightBuf();
		a.syncKeyBuf();
		a.sizeDirty = true;
		a.chrome.posDirty = true;
		return a;
	}

	/** Full configuration clone for builder duplication; runtime state is reset by fromDyn(). */
	public static function cloneAura(source:AuraDef, newId:String, newName:String):AuraDef {
		if (source == null)
			return null;
		var copy = fromDyn(AuraEngine.toObj(source));
		copy.id = newId;
		copy.name = newName;
		copy.counterValue = 0;
		copy.stacks = 1;
		copy.show = false;
		copy.alertShow = false;
		copy.condWas = false;
		copy.packSelect.set(false);
		copy.syncNameBuf();
		return copy;
	}

	/** Apply a profile layout blob `{on, unlock, list}` without touching profile keys. */
	public static function applyListDump(c:AuraConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		if (data.on != null)
			c.enabled.set(data.on == true || data.on == 1 || data.on == "true");
		if (data.unlock != null)
			c.unlockAll.set(data.unlock == true || data.unlock == 1 || data.unlock == "true");
		var raw:Dynamic = data.list;
		if (raw == null)
			return;
		var list:Array<Dynamic> = [];
		try
			list = cast raw
		catch (_:Dynamic)
			return;
		var next:Array<AuraDef> = [];
		var i = 0;
		while (i < list.length && next.length < AuraEngine.MAX) {
			var item = list[i];
			if (item != null && item.id != null)
				next.push(fromDyn(item));
			i++;
		}
		c.auras = next;
	}

	public function setRegionOverride(s:String):Void {
		regionOverride = s != null ? StringTools.trim(s) : "";
		ensureRegionBuf();
		writeRegionBuf(regionOverride);
	}

	function seedDefaults():Void {
		var low = new AuraDef("hp_low", "HP low");
		low.trigger = "resource";
		low.resource = "hp";
		low.op = "below";
		low.pct = 35;
		low.pctRef.set(35);
		low.region = "bar";
		low.chrome.x.set(220);
		low.chrome.y.set(160);
		auras.push(low);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(420, 160), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Auras##solarflare", open, "Auras")) {
			ImGui.textWrapped("Use the Aura Builder for the full library editor (multi-select, preview, conditions).");
			if (ImGui.button("Open Aura Builder##ae_legacy_open", ImGui.vec2(-1, 0)))
				open.set(false);
			ImGui.textDisabled("Legacy list editor retired — F6 → Auras → Open Aura Builder.");
		}
		HudChrome.endPanel();
	}

	/** Reusable field editor consumed by AuraBuilder; AuraDef remains authoritative. */
	public function drawBuilderFields(a:AuraDef):Void {
		if (a == null)
			return;
		ImGui.separatorText("Window");
		if (ImGui.checkbox("Enabled##aben" + a.id, a.enabled)) SettingsStore.markDirty();
		a.chrome.drawToggles("aura_builder_" + a.id);
		if (ImGui.sliderFloat("Width##abw" + a.id, a.w, 32, 720, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		if (ImGui.sliderFloat("Height##abh" + a.id, a.h, 24, 480, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		ImGui.separatorText("Identity");
		if (a.rule == null && ImGui.checkbox("Invert##abinv" + a.id, a.invert)) SettingsStore.markDirty();
		if (ImGui.inputText("Name##abnm" + a.id, a.nameBuf, AuraDef.NAME_BUF)) {
			a.name = bytesToString(a.nameBuf, AuraDef.NAME_BUF);
			SettingsStore.markDirty();
		}
		ImGui.separatorText("Condition");
		if (a.rule == null) drawTrigger(a);
		AuraConditionEditor.draw(a);
		ImGui.separatorText("Region");
		drawRegion(a);
		drawEffects(a);
		drawDrmStyle(a);
	}

	static var lastExport:String = "";
	static var lastDrmIni:String = "";

	function drawDrmStyle(a:AuraDef):Void {
		if (!ImGui.collapsingHeader("Alert style / DRM##drm" + a.id))
			return;
		AuraEffects.ensure(a);
		if (ImGui.checkbox("Dormant (rise+hold window)##dor" + a.id, a.dormant)) {
			if (a.dormant.get())
				AuraEffects.applyPresetDormant(a);
			else
				AuraEffects.applyPresetContinuous(a);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.checkbox("Visual##vis" + a.id, a.visual))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Audio (DRM)##aud" + a.id, a.audio))
			SettingsStore.markDirty();
		if (ImGui.sliderFloat("Hold (s, 0=CDB)##hold" + a.id, a.durRef, 0, 12, "%.1f")) {
			a.duration = a.durRef.get();
			SettingsStore.markDirty();
		}
		if (ImGui.sliderFloat("Scale##sc" + a.id, a.scale, 0.5, 2.5, "%.2f")) {
			a.sizeDirty = true;
			SettingsStore.markDirty();
		}
		if (ImGui.sliderFloat("Volume (DRM)##vol" + a.id, a.volume, 0, 1, "%.2f"))
			SettingsStore.markDirty();
		if (ImGui.inputText("Announce##ann" + a.id, a.announceBuf, AuraDef.ANN_BUF)) {
			a.announce = bytesToString(a.announceBuf, AuraDef.ANN_BUF);
			SettingsStore.markDirty();
		}
		if (ImGui.inputText("Icon ID##pl" + a.id, a.iconBuf, AuraDef.ICON_BUF)) {
			a.iconId = bytesToString(a.iconBuf, AuraDef.ICON_BUF);
			a.plate = "";
			SettingsStore.markDirty();
		}
		var cuePrev = a.cue.length > 0 ? a.cue : "(silent)";
		if (ImGui.beginCombo("Cue (DRM)##cue" + a.id, cuePrev)) {
			if (ImGui.selectable("(silent)##cuesil" + a.id, a.cue.length == 0)) {
				a.cue = "";
				a.syncCueBuf();
				SettingsStore.markDirty();
			}
			for (c in AuraPack.CUE_IDS) {
				if (ImGui.selectable(c + "##cue" + a.id + c, a.cue == c)) {
					a.cue = c;
					a.syncCueBuf();
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
		var fightPrev = a.fight.length > 0 ? a.fight : "(pack default)";
		if (ImGui.beginCombo("Fight##fg" + a.id, fightPrev)) {
			if (ImGui.selectable("(pack default)##fgdef" + a.id, a.fight.length == 0)) {
				a.fight = "";
				a.syncFightBuf();
				SettingsStore.markDirty();
			}
			for (f in AuraPack.FIGHTS) {
				if (ImGui.selectable(f + "##fg" + a.id + f, a.fight == f)) {
					a.fight = f;
					a.syncFightBuf();
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
	}

	public function drawEffects(a:AuraDef, withHeader:Bool = true):Void {
		if (withHeader && !ImGui.collapsingHeader("Advanced Effects##fx" + a.id))
			return;
		AuraEffects.ensure(a);
		ImGui.textWrapped("Layered reactions for when the aura matches. Use Visual FX below for Pulse / Expire / Ready overlays.");

		UiChrome.subHeader("Visual FX (live + preview)");
		if (ImGui.checkbox("Pulse FX while matching##fxpulse" + a.id, a.fxPulse))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Expire FX on fall##fxexp" + a.id, a.fxExpire))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Ready FX on rise##fxrdy" + a.id, a.fxReady))
			SettingsStore.markDirty();

		ImGui.separator();
		if (ImGui.button("Ready + Announcement##fxcd" + a.id)) {
			var label = a.announce.length > 0 ? a.announce : (a.name.length > 0 ? a.name : "READY");
			AuraEffects.applyPresetCdReady(a, label.toUpperCase());
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.button("While Matching##fxcont" + a.id)) {
			AuraEffects.applyPresetContinuous(a);
			SettingsStore.markDirty();
		}
		if (ImGui.button("Briefly When Matched##fxdor" + a.id)) {
			AuraEffects.applyPresetDormant(a);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.button("While Not Matching##fxocd" + a.id)) {
			AuraEffects.applyPresetOnCd(a);
			SettingsStore.markDirty();
		}
		var ei = 0;
		while (ei < a.effects.length) {
			var e = a.effects[ei];
			var tag = a.id + "_" + ei;
			if (e == null) {
				ei++;
				continue;
			}
			if (ImGui.treeNode("fxn" + tag, effectKindLabel(e.kind) + " · " + effectWhenLabel(e.when))) {
				if (ImGui.checkbox("On##fxen" + tag, e.enabled))
					SettingsStore.markDirty();
				if (ImGui.beginCombo("Reaction##fxk" + tag, effectKindLabel(e.kind))) {
					for (k in AuraEffect.KINDS) {
						if (ImGui.selectable(effectKindLabel(k) + "##fxks" + tag + k, e.kind == k)) {
							e.kind = k;
							SettingsStore.markDirty();
						}
					}
					ImGui.endCombo();
				}
				if (ImGui.beginCombo("Timing##fxw" + tag, effectWhenLabel(e.when))) {
					for (w in AuraEffect.WHENS) {
						if (ImGui.selectable(effectWhenLabel(w) + "##fxws" + tag + w, e.when == w)) {
							e.when = w;
							AuraEffects.syncDormantFlag(a);
							SettingsStore.markDirty();
						}
					}
					ImGui.endCombo();
				}
				if (ImGui.sliderFloat("Hold (s)##fxh" + tag, e.holdRef, 0.1, 12, "%.1f")) {
					e.hold = e.holdRef.get();
					SettingsStore.markDirty();
				}
				if (e.kind == AuraEffect.KIND_ALERT || e.kind == AuraEffect.KIND_AUDIO) {
					if (ImGui.inputText("Text##fxt" + tag, e.textBuf, AuraEffect.TEXT_BUF)) {
						e.text = bytesToString(e.textBuf, AuraEffect.TEXT_BUF);
						SettingsStore.markDirty();
					}
				}
				if (e.kind == AuraEffect.KIND_ICON) {
					if (ImGui.checkbox("Glow##fxg" + tag, e.glow))
						SettingsStore.markDirty();
					if (ImGui.sliderFloat("Alpha##fxa" + tag, e.alpha, 0.1, 1, "%.2f"))
						SettingsStore.markDirty();
				}
				if (ImGui.button("Remove effect##fxrm" + tag)) {
					ImGui.treePop();
					a.effects.splice(ei, 1);
					AuraEffects.ensure(a);
					AuraEffects.syncDormantFlag(a);
					SettingsStore.markDirty();
					continue;
				}
				ImGui.treePop();
			}
			ei++;
		}
		if (a.effects.length < AuraEffects.MAX && ImGui.button("Add effect##fxadd" + a.id)) {
			a.effects.push(new AuraEffect("fx" + Std.string(a.effects.length + 1), AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE));
			SettingsStore.markDirty();
		}
	}

	static function effectKindLabel(kind:String):String {
		return switch (kind) {
			case AuraEffect.KIND_WINDOW: "Aura Window";
			case AuraEffect.KIND_ALERT: "Screen Announcement";
			case AuraEffect.KIND_ICON: "Icon Glow";
			case AuraEffect.KIND_AUDIO: "DRM Export Sound";
			default: kind;
		};
	}

	static function effectWhenLabel(when:String):String {
		return switch (when) {
			case AuraEffect.WHEN_WHILE_TRUE: "While conditions are true";
			case AuraEffect.WHEN_WHILE_FALSE: "While conditions are not true";
			case AuraEffect.WHEN_ON_RISE: "When conditions become true";
			case AuraEffect.WHEN_ON_FALL: "When conditions stop being true";
			case AuraEffect.WHEN_ON_RISE_HOLD: "Briefly after conditions become true";
			case AuraEffect.WHEN_ON_FALL_HOLD: "Briefly after conditions stop being true";
			case AuraEffect.WHEN_STICKY: "Until conditions stop being true";
			default: when;
		};
	}



	function ensureRegionBuf():Void {
		if (regionBytes == null) {
			regionBytes = haxe.io.Bytes.alloc(REGION_BUF);
			writeRegionBuf(regionOverride);
		}
	}

	function writeRegionBuf(s:String):Void {
		if (regionBytes == null)
			return;
		var i = 0;
		while (i < REGION_BUF) {
			regionBytes.set(i, 0);
			i++;
		}
		if (s == null)
			return;
		var n = s.length;
		if (n > REGION_BUF - 1)
			n = REGION_BUF - 1;
		i = 0;
		while (i < n) {
			regionBytes.set(i, s.charCodeAt(i));
			i++;
		}
	}

	function readRegionBuf():String {
		if (regionBytes == null)
			return "";
		var out = "";
		var i = 0;
		while (i < REGION_BUF) {
			var c = regionBytes.get(i);
			if (c == 0)
				break;
			out += String.fromCharCode(c);
			i++;
		}
		return StringTools.trim(out);
	}

	function ensureNameBuf():Void {
		if (profileNameBytes != null)
			return;
		profileNameBytes = haxe.io.Bytes.alloc(NAME_BUF);
	}

	function readNameBuf():String {
		ensureNameBuf();
		var out = "";
		var i = 0;
		while (i < NAME_BUF) {
			var c = profileNameBytes.get(i);
			if (c == 0)
				break;
			out += String.fromCharCode(c);
			i++;
		}
		return StringTools.trim(out);
	}

	function drawPackCombiner():Void {
		if (!ImGui.collapsingHeader("Combine → export key / DRM fight script"))
			return;
		ImGui.textWrapped("Check Pack on each aura, set fight + pack id, then export one share key (Base64) or a DRM INI bundle for packs/custom/.");
		if (ImGui.inputText("Pack id##pkid", packIdBuf, PACK_ID))
			packId = bytesToString(packIdBuf, PACK_ID);
		if (ImGui.inputText("Pack name##pknm", packNameBuf, PACK_NAME))
			packName = bytesToString(packNameBuf, PACK_NAME);
		if (ImGui.beginCombo("Pack fight##pkfg", packFight)) {
			for (f in AuraPack.FIGHTS) {
				if (ImGui.selectable(f, packFight == f))
					packFight = f;
			}
			ImGui.endCombo();
		}
		if (ImGui.button("Select all##pksel")) {
			for (a in auras)
				a.packSelect.set(true);
		}
		ImGui.sameLine();
		if (ImGui.button("Select none##pknone")) {
			for (a in auras)
				a.packSelect.set(false);
		}
		var selected = selectedAuras();
		ImGui.text(Std.string(selected.length) + " selected · DRM-mappable need skillId");
		if (ImGui.button("Export pack key##pkex")) {
			if (selected.length > 0) {
				lastExport = AuraPack.encode(packFight, packId, packName, selected);
				lastDrmIni = AuraPack.drmIniBundle(packFight, packId, packName, selected);
			}
		}
		ImGui.sameLine();
		if (ImGui.button("DRM INI only##pkini")) {
			if (selected.length > 0)
				lastDrmIni = AuraPack.drmIniBundle(packFight, packId, packName, selected);
		}
	}

	function selectedAuras():Array<AuraDef> {
		var out:Array<AuraDef> = [];
		for (a in auras) {
			if (a != null && a.packSelect.get())
				out.push(a);
		}
		return out;
	}

	function nextId():String {
		return allocateAuraId("aura_" + Std.string(auras.length + 1));
	}

	/** Canonical allocator for every path that adds an Aura to this config. */
	public function allocateAuraId(requested:String):String {
		var base = requested != null && requested.length > 0 ? requested : "aura";
		var id = base;
		var suffix = 2;
		while (find(id) != null)
			id = base + "_" + suffix++;
		return id;
	}

	function drawTrigger(a:AuraDef):Void {
		var preview = a.trigger;
		if (ImGui.beginCombo("Trigger##tr" + a.id, preview)) {
			for (t in ["resource", "cooldown", "combatlog", "prayer", "status", "combo", "chaincast", "conduit"]) {
				if (ImGui.selectable(t, a.trigger == t)) {
					a.trigger = t;
					if (t == "status" && a.pct > 16) {
						a.op = "above";
						a.pct = 1;
						a.pctRef.set(1);
					}
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
		if (a.trigger == "resource") {
			if (ImGui.beginCombo("Resource##rs" + a.id, a.resource)) {
				for (t in ["hp", "rage", "mana", "spark", "shield"]) {
					if (ImGui.selectable(t, a.resource == t)) {
						a.resource = t;
						SettingsStore.markDirty();
					}
				}
				ImGui.endCombo();
			}
			if (ImGui.beginCombo("When##op" + a.id, a.op)) {
				for (t in ["below", "above"]) {
					if (ImGui.selectable(t, a.op == t)) {
						a.op = t;
						SettingsStore.markDirty();
					}
				}
				ImGui.endCombo();
			}
			if (ImGui.sliderFloat("Percent##pct" + a.id, a.pctRef, 1, 99, "%.0f")) {
				a.pct = a.pctRef.get();
				SettingsStore.markDirty();
			}
		} else if (a.trigger == "combo" || a.trigger == "chaincast" || a.trigger == "conduit") {
			if (ImGui.sliderFloat("At least##th" + a.id, a.pctRef, 1, 6, "%.0f")) {
				a.pct = a.pctRef.get();
				SettingsStore.markDirty();
			}
			if (a.trigger == "chaincast") {
				if (ImGui.inputText("Skill id (ready = proc)##sk" + a.id, a.skillBuf, AuraDef.SKILL_BUF)) {
					a.skillId = bytesToString(a.skillBuf, AuraDef.SKILL_BUF);
					SettingsStore.markDirty();
				}
			}
		} else {
			if (ImGui.inputText("Skill id##sk" + a.id, a.skillBuf, AuraDef.SKILL_BUF)) {
				a.skillId = bytesToString(a.skillBuf, AuraDef.SKILL_BUF);
				SettingsStore.markDirty();
			}
			var cdbName = CdbAuraTable.name(a.skillId);
			if (cdbName.length > 0)
				ImGui.text("CDB: " + cdbName);
			if (a.trigger == "cooldown") {
				if (ImGui.checkbox("Require affordable##af" + a.id, a.requireAfford))
					SettingsStore.markDirty();
			}
			if (a.trigger == "status") {
				if (ImGui.beginCombo("When##sop" + a.id, a.op)) {
					for (t in ["above", "below"]) {
						if (ImGui.selectable(t, a.op == t)) {
							a.op = t;
							SettingsStore.markDirty();
						}
					}
					ImGui.endCombo();
				}
				if (a.pct < 1 || a.pct > 16) {
					a.pct = 1;
					a.pctRef.set(1);
				}
				if (ImGui.sliderFloat("At least N stacks##st" + a.id, a.pctRef, 1, 15, "%.0f")) {
					a.pct = a.pctRef.get();
					SettingsStore.markDirty();
				}
			}
			if ((a.trigger == "combatlog" || a.trigger == "status") && !a.dormant.get()) {
				if (ImGui.sliderFloat("Hold (s, 0=CDB)##dur" + a.id, a.durRef, 0, 12, "%.1f")) {
					a.duration = a.durRef.get();
					SettingsStore.markDirty();
				}
			}
		}
	}

	function drawRegion(a:AuraDef):Void {
		if (ImGui.beginCombo("Region##rg" + a.id, a.region)) {
			for (t in ["bar", "icon", "text", "ring"]) {
				if (ImGui.selectable(t, a.region == t)) {
					a.region = t;
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
		if (a.region == "icon") {
			if (ImGui.inputText("Icon id##ic" + a.id, a.iconBuf, AuraDef.ICON_BUF)) {
				a.iconId = bytesToString(a.iconBuf, AuraDef.ICON_BUF);
				SettingsStore.markDirty();
			}
		}
		if (ImGui.checkbox("Show key chip##sk" + a.id, a.showKey))
			SettingsStore.markDirty();
		ImGui.sameLine();
		ImGui.setNextItemWidth(72);
		if (ImGui.inputText("Key##hk" + a.id, a.keyBuf, AuraDef.KEY_BUF)) {
			a.keyText = AuraDef.sanitizeKey(bytesToString(a.keyBuf, AuraDef.KEY_BUF));
			a.syncKeyBuf();
			SettingsStore.markDirty();
		}
	}

	function exportOne(a:AuraDef):String {
		var json = haxe.Json.stringify(AuraEngine.toObj(a));
		return Base64.encode(Bytes.ofString(json));
	}

	function importOne():Void {
		try {
			var s = bytesToString(importBuf);
			if (s.length < 4)
				return;
			var d = AuraPack.decode(s);
			if (d != null && (Std.isOfType(d, Array) || d.kind == AuraPack.KIND || d.auras != null)) {
				importPackDyn(d);
				return;
			}
			var a = fromDyn(d);
			a.id = allocateAuraId(a.id);
			if (auras.length < AuraEngine.MAX)
				auras.push(a);
			SettingsStore.markDirty();
		} catch (_:Dynamic) {}
	}

	function importPack():Void {
		try {
			var s = bytesToString(importBuf);
			var d = AuraPack.decode(s);
			importPackDyn(d);
		} catch (_:Dynamic) {}
	}

	function importPackDyn(d:Dynamic):Void {
		if (d == null)
			return;
		if (d.fight != null && Std.string(d.fight).length > 0)
			packFight = Std.string(d.fight);
		if (d.id != null)
			packId = Std.string(d.id);
		if (d.name != null)
			packName = Std.string(d.name);
		fillBuf(packIdBuf, PACK_ID, packId);
		fillBuf(packNameBuf, PACK_NAME, packName);
		var list = AuraPack.unpackAuras(d);
		var i = 0;
		while (i < list.length && auras.length < AuraEngine.MAX) {
			var a = list[i];
			a.id = allocateAuraId(a.id);
			auras.push(a);
			i++;
		}
		SettingsStore.markDirty();
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, s:String):Void ByteUtil.fillBuf(buf, cap, s);

	static function bytesToString(buf:hl.Bytes, max:Int = 0):String {
		var cap = max > 0 ? max : IMP;
		return ByteUtil.readString(buf, cap);
	}
}
