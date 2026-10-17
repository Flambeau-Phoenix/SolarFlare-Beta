package solarflare.aura;

import solarflare.HealthCache;
import solarflare.cdb.CdbAuraTable;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.util.ShareCodec;
import solarflare.aura.signal.AuraRuleCodec;
import solarflare.aura.signal.AuraConditionEditor;

class AuraConfig {
	public var open = new BoolRef(false);
	public var enabled = new BoolRef(true);
	/** Legacy profile field; individual runtime locks remain authoritative. */
	public var unlockAll = new BoolRef(false);
	/** Draw a countdown on every aura with a known remaining time. */
	public var countdownAll = new BoolRef(true);
	/** Seconds ceiling for the automatic countdown; 0 = no ceiling. */
	public var countdownAutoMax = new FloatRef(0);
	public var countdownScale = new FloatRef(1);
	/** Shared window that stacks every board-visible custom timer. */
	public var timerBoardHidden = new BoolRef(false);
	public var timerBoardChrome = new HudChrome(60, 320);
	public var timerBoardW = new FloatRef(240);
	public var timerBoardRowH = new FloatRef(28);
	public var timerBoardMax = new IntRef(8);
	public var auras:Array<AuraDef> = [];
	/** Aura Sets (an aura's `fight` tag is its set id). Edit through the methods below so the gate rebuilds. */
	public var sets:Array<AuraSetDef> = [];
	public static inline var MAX_SETS:Int = 32;
	var setsDirty = true;
	var gateMapRevision = -1;
	var gate:Map<String, Bool> = new Map();
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
		ensureSets();
	}

	/** Call after any change to a set (mode, maps, rename, add, remove) or an aura's `fight` tag. */
	public function markSetsDirty():Void setsDirty = true;

	/**
	 * Whether an aura with this tag is armed right now. Untagged auras, `shared`, and tags without a set always
	 * run. The table is rebuilt only after an edit or a map change, never per frame.
	 */
	public function setActive(fight:String):Bool {
		if (fight == null || fight.length == 0)
			return true;
		if (setsDirty || gateMapRevision != AuraMapContext.revision)
			rebuildGate();
		var armed = gate.get(fight);
		return armed == null ? true : armed;
	}

	function rebuildGate():Void {
		gate = new Map();
		for (s in sets)
			if (s != null)
				gate.set(s.id, s.activeOn(AuraMapContext.mapId));
		setsDirty = false;
		gateMapRevision = AuraMapContext.revision;
	}

	public function findSet(id:String):AuraSetDef {
		for (s in sets)
			if (s != null && s.id == id)
				return s;
		return null;
	}

	/** The set tag of an aura, or empty for the Shared group. */
	public static function tagOf(a:AuraDef):String {
		if (a == null || a.fight == null)
			return "";
		var t = StringTools.trim(a.fight);
		return t.toLowerCase() == "shared" ? "" : t;
	}

	public function countIn(setId:String):Int {
		var n = 0;
		for (a in auras)
			if (a != null && tagOf(a) == setId)
				n++;
		return n;
	}

	/** Every non-empty tag in use gets a set, so saves and packs from before Aura Sets keep their groups. */
	public function ensureSets():Void {
		for (a in auras) {
			var tag = tagOf(a);
			// Engine lookups use the raw tag, so keep it trimmed to match its set id.
			if (tag.length > 0 && a.fight != tag) {
				a.fight = tag;
				a.syncFightBuf();
			}
			if (tag.length > 0 && findSet(tag) == null && sets.length < MAX_SETS) {
				var shown = tag.charAt(0).toUpperCase() + tag.substr(1);
				sets.push(new AuraSetDef(tag, shown));
			}
		}
		setsDirty = true;
	}

	public function uniqueSetId(name:String):String {
		var base = ~/[^a-z0-9]+/g.replace(StringTools.trim(name).toLowerCase(), "_");
		base = ~/^_+|_+$/g.replace(base, "");
		if (base.length == 0 || base == "shared")
			base = "set";
		var id = base;
		var n = 2;
		while (findSet(id) != null)
			id = base + "_" + n++;
		return id;
	}

	public function addSet(name:String):AuraSetDef {
		if (sets.length >= MAX_SETS)
			return null;
		var shown = StringTools.trim(name);
		if (shown.length == 0)
			shown = "New set";
		var s = new AuraSetDef(uniqueSetId(shown), shown);
		sets.push(s);
		setsDirty = true;
		return s;
	}

	/** Deleting a set sends its auras back to Shared; no aura is deleted. */
	public function removeSet(id:String):Void {
		var s = findSet(id);
		if (s == null)
			return;
		sets.remove(s);
		for (a in auras)
			if (a != null && tagOf(a) == id) {
				a.fight = "";
				a.syncFightBuf();
			}
		setsDirty = true;
	}

	public function moveToSet(a:AuraDef, setId:String):Void {
		if (a == null)
			return;
		a.fight = setId == null ? "" : setId;
		a.syncFightBuf();
		setsDirty = true;
	}

	public function anySetUsesMaps():Bool {
		for (s in sets)
			if (s != null && s.mode == AuraSetDef.MODE_MAPS)
				return true;
		return false;
	}

	public function dumpSets():Array<Dynamic> {
		var out:Array<Dynamic> = [];
		for (s in sets)
			if (s != null)
				out.push(s.toObj());
		return out;
	}

	public function applySets(raw:Dynamic):Void {
		var next:Array<AuraSetDef> = [];
		if (raw != null && Std.isOfType(raw, Array)) {
			var list:Array<Dynamic> = cast raw;
			for (item in list) {
				var s = AuraSetDef.fromObj(item);
				if (s != null && next.length < MAX_SETS) {
					var dup = false;
					for (o in next)
						if (o.id == s.id)
							dup = true;
					if (!dup)
						next.push(s);
				}
			}
		}
		sets = next;
		ensureSets();
	}

	public function find(id:String):AuraDef {
		for (a in auras)
			if (a.id == id)
				return a;
		return null;
	}

	/** Disable default max_combo / resource.combo trackers that spawn unanchored pips. */
	public function disableUnanchoredComboTrackers():Void {
		if (auras == null)
			return;
		for (a in auras) {
			if (a == null)
				continue;
			var isCombo = a.id == "max_combo_finisher";
			if (!isCombo && a.rule != null && a.rule.conditions != null) {
				for (c in a.rule.conditions) {
					if (c != null && c.signal != null
						&& (c.signal == "resource.combo.count" || c.signal == "resource.combo.atMax")) {
						isCombo = true;
						break;
					}
				}
			}
			if (!isCombo && a.trigger == "combo")
				isCombo = true;
			if (isCombo) {
				a.enabled.set(false);
				a.show = false;
			}
		}
	}

	public static function fromDyn(d:Dynamic):AuraDef {
		var a = new AuraDef(Std.string(d.id), d.name != null ? Std.string(d.name) : Std.string(d.id));
		// Preserve the original face for legacy records without a region.
		a.region = d.region != null ? Std.string(d.region) : "bar";
		a.useGlobalCountdown.set(AuraPresentationPolicy.flag(d,"useGlobalCountdown",true));
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
		a.alwaysOn.set(d.alwaysOn == true);
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
		a.showIcon.set(AuraPresentationPolicy.flag(d,"showIcon",a.showIcon.get()));
		a.progressRing.set(AuraPresentationPolicy.flag(d,"progressRing",a.progressRing.get()));
		if (d.showCountdown == true)
			a.showCountdown.set(true);
		if (d.countdownScale != null)
			a.countdownScale.set(d.countdownScale);
		if (d.countdownPlace != null)
			a.countdownPlace = Std.int(d.countdownPlace);
		if (d.timerMode != null)
			a.timerMode = Std.int(d.timerMode);
		if (d.timerSource != null)
			a.timerSource = Std.int(d.timerSource);
		if (d.timerSeconds != null)
			a.timerSeconds.set(d.timerSeconds);
		if (d.timerStartEdge != null) a.timerStartEdge = d.timerStartEdge == 1 ? 1 : 0;
		if (d.timerBoard == false)
			a.timerBoard.set(false);
		if (d.timerKeepExpired != null)
			a.timerKeepExpired.set(d.timerKeepExpired);
		if (d.showFuse == true)
			a.showFuse.set(true);
		if (d.fuseBottom == true)
			a.fuseBottom.set(true);
		if (d.followBuffDuration == false)
			a.followBuffDuration.set(false);
		if (d.glowColor != null)
			a.glowColor = Std.int(d.glowColor);
		if (d.glowStyle != null) a.glowStyle = AuraGlowStyle.normalize(Std.string(d.glowStyle));
		if (d.glowStrength != null) a.glowStrength.set(AuraGlowStyle.strength(d.glowStrength));
		if (d.glowOuter != null) a.glowOuter.set(AuraGlowStyle.spread(d.glowOuter));
		if (d.glowInner != null) a.glowInner.set(AuraGlowStyle.spread(d.glowInner));
		if (d.textSize != null) a.textSize.set(AuraTextLayout.fontSize(d.textSize));
		if (d.stackCounter == true)
			a.stackCounter.set(true);
		a.stackScale.set(AuraBadgePolicy.scale(d.stackScale));
		a.stackPlace = AuraBadgePolicy.stackPlace(d);
		a.counterPlace = AuraBadgePolicy.counterPlace(d);
		a.counterScale.set(AuraBadgePolicy.counterScale(d));
		a.showLabel.set(AuraPresentationPolicy.flag(d,"showLabel",a.showLabel.get()));
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
		a.canvasElements = [];
		try {
			var rawCanvas:Dynamic = d.canvasElements;
			if (rawCanvas != null) {
				var carr:Array<Dynamic> = cast rawCanvas;
				var ci = 0;
				while (ci < carr.length) {
					if (carr[ci] != null) {
						var el = AuraCanvasElement.fromDyn(carr[ci]);
						el.content = AuraBadgePolicy.migrateContent(d, el.kind, el.content);
						a.canvasElements.push(el);
					}
					ci++;
				}
			}
		} catch (_:Dynamic) {}
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
		c.applySets(data.sets);
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
		low.region = "icon";
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

	/** One-click reaction presets, spread across the full card width instead of stacked. */
	function drawEffectPresets(a:AuraDef):Void {
		UiLayout.inlineSplit("##fx_presets_" + a.id, 4, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 26);
			var tip = "";
			switch (index) {
				case 0:
					if (ImGui.button("Ready + Alert##fxcd" + a.id, size)) {
						var label = a.announce.length > 0 ? a.announce : (a.name.length > 0 ? a.name : "READY");
						AuraEffects.applyPresetCdReady(a, label.toUpperCase());
						SettingsStore.markDirty();
					}
					tip = "Ready pulse plus the announcement text.";
				case 1:
					if (ImGui.button("While Matching##fxcont" + a.id, size)) {
						AuraEffects.applyPresetContinuous(a);
						SettingsStore.markDirty();
					}
					tip = "Stays visible the whole time the condition is true.";
				case 2:
					if (ImGui.button("Briefly##fxdor" + a.id, size)) {
						AuraEffects.applyPresetDormant(a);
						SettingsStore.markDirty();
					}
					tip = "Flashes for the hold duration when the condition becomes true.";
				case 3:
					if (ImGui.button("Not Matching##fxocd" + a.id, size)) {
						AuraEffects.applyPresetOnCd(a);
						SettingsStore.markDirty();
					}
					tip = "Shows while the condition is false, e.g. a missing buff.";
			}
			if (tip.length > 0 && ImGui.isItemHovered()) ImGui.setTooltip(tip);
		});
	}

	public function drawEffects(a:AuraDef, withHeader:Bool = true):Void {
		if (withHeader && !ImGui.collapsingHeader("Advanced Effects##fx" + a.id))
			return;
		AuraEffects.ensure(a);
		ImGui.textWrapped("Layered reactions for when the aura matches.");
		drawEffectPresets(a);
		var ei = 0;
		while (ei < a.effects.length) {
			var e = a.effects[ei];
			var tag = a.id + "_" + ei;
			if (e == null) {
				ei++;
				continue;
			}
			var removeThis = false;
			if (ImGui.treeNode("fxn" + tag, (e.enabled.get() ? "" : "(off) ") + effectKindLabel(e.kind) + " - " + effectWhenLabel(e.when))) {
				UiLayout.propertyGrid("##fx_grid_" + tag, function() {
					UiLayout.propertyRow("Enabled", function() {
						if (ImGui.checkbox("##fxen" + tag, e.enabled))
							SettingsStore.markDirty();
					});
					UiLayout.propertyRow("Reaction", function() {
						var picked = UiLayout.stringCombo("fxk" + tag, e.kind, AuraEffect.KINDS, effectKindLabel);
						if (picked != null) {
							e.kind = picked;
							SettingsStore.markDirty();
						}
					});
					UiLayout.propertyRow("Timing", function() {
						var picked = UiLayout.stringCombo("fxw" + tag, e.when, AuraEffect.WHENS, effectWhenLabel);
						if (picked != null) {
							e.when = picked;
							AuraEffects.syncDormantFlag(a);
							SettingsStore.markDirty();
						}
					});
					UiLayout.propertyRow("Hold", function() {
						if (solarflare.ui.BuilderSlider.draw("##fxh" + tag, e.holdRef, 0.1, 12, "%.1f s")) {
							e.hold = e.holdRef.get();
							SettingsStore.markDirty();
						}
					});
					if (e.kind == AuraEffect.KIND_ALERT || e.kind == AuraEffect.KIND_AUDIO) {
						UiLayout.propertyRow("Text", function() {
							if (ImGui.inputText("##fxt" + tag, e.textBuf, AuraEffect.TEXT_BUF)) {
								e.text = bytesToString(e.textBuf, AuraEffect.TEXT_BUF);
								SettingsStore.markDirty();
							}
						});
					}
					if (e.kind == AuraEffect.KIND_ICON) {
						UiLayout.propertyRow("Icon", function() {
							UiLayout.inlinePair("##fx_icon_" + tag,
								function(w:Single) {
									if (UiChrome.toggleTileRef("##fxg" + tag, "Glow", e.glow, w, 24))
										SettingsStore.markDirty();
								},
								function(w:Single) {
									if (solarflare.ui.BuilderSlider.draw("##fxa" + tag, e.alpha, 0.1, 1, "%.2f"))
										SettingsStore.markDirty();
								});
						}, "Glow adds a halo; the slider sets icon opacity.");
					}
				});
				if (ImGui.button("Remove effect##fxrm" + tag, ImGui.vec2(-1, 24)))
					removeThis = true;
				ImGui.treePop();
			}
			if (removeThis) {
				a.effects.splice(ei, 1);
				AuraEffects.ensure(a);
				AuraEffects.syncDormantFlag(a);
				SettingsStore.markDirty();
				continue;
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

	static function fillBuf(buf:hl.Bytes, cap:Int, s:String):Void ByteUtil.fillBuf(buf, cap, s);

	static function bytesToString(buf:hl.Bytes, max:Int = 0):String {
		var cap = max > 0 ? max : IMP;
		return ByteUtil.readString(buf, cap);
	}
}
