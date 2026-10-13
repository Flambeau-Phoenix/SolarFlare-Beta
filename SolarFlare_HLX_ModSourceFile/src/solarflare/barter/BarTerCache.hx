package solarflare.barter;

import solarflare.aura.ConsumableCache;
import solarflare.cdb.ConsumableCatalog;
import solarflare.extrabars.ExtraBarsUsePolicy;
import solarflare.geaux.GeauxCache;

typedef BarTerClick = {
	var barId:String;
	var slot:Int;
	var skillId:String;
	var itemKind:String;
	var gen:Int;
	var action:String;
	var nativeEpoch:Int;
	/** Queue time; drainClicks drops clicks older than CLICK_TTL_S. */
	var at:Float;
}

/**
 * Observe-only cells for BarTer. Consumable use retains the audited ExtraBars policy.
 */
class BarTerCache {
	public static var pendingClicks:Array<BarTerClick> = [];
	static var clickGen:Int = 0;
	/** A click that waited longer than this (stall, loading screen) is not replayed as a native use. */
	static inline var CLICK_TTL_S:Float = 0.25;

	public static function keep():Void {}

	public static function nextGen():Int {
		clickGen++;
		return clickGen;
	}

	public static function generation():Int return clickGen;

	public static function queueClick(barId:String, slot:Int, skillId:String = "", itemKind:String = "", action:String=""):Void {
		if (barId == null) return;
		var skill = skillId != null ? skillId : "";
		var item = itemKind != null ? itemKind : "";
		if (item.length == 0 && skill.length == 0) return;
		clickGen++;
		pendingClicks.push({barId: barId, slot: slot, skillId: skill, itemKind: item, gen: clickGen, at: haxe.Timer.stamp(),action:action,nativeEpoch:BarTerNativeKeys.epoch});
		if (pendingClicks.length > 32)
			pendingClicks.shift();
	}

	/** Expired clicks are dropped, never replayed; `blocked` drops everything without dispatch. */
	public static function drainClicks(handler:BarTerClick->Void, blocked:Bool = false):Void {
		if (handler == null) return;
		var now = haxe.Timer.stamp();
		while (pendingClicks.length > 0) {
			var c = pendingClicks.shift();
			if (c == null || blocked || now - c.at > CLICK_TTL_S) continue;
			try
				handler(c)
			catch (_:Dynamic) {}
		}
	}

	/**
	 * Gameplay eligibility for native use requests (mirrors ExtraBars.blockReason, minus the
	 * editor check: BarTer cells are clicked with the cursor free). Empty string = allowed.
	 */
	public static function gameplayBlockReason(hero:Dynamic):String {
		if (hero == null) return "No local hero.";
		try {
			var app = GameApp.get();
			var controller = client.PlayerController.inst;
			if (app == null || controller == null) return "No local hero.";
			if (!hxd.Window.getInstance().get_isFocused()) return "Game is not focused.";
			if (app.get_isLoading()) return "Loading.";
			if (app.isInCutscene() || lib.Input.cinematicCapturesKbd()) return "Cutscene input is blocked.";
			var h:ent.Hero = cast hero;
			if (h.isDead()) return "Hero is dead.";
			if (controller.isInputBlocked()) return "Chat or a native window owns input.";
		} catch (_:Dynamic) {
			return "Gameplay eligibility unavailable.";
		}
		return "";
	}

	/** Fill live snaps for one bar from GeauxCache / ConsumableCache by slot assignment. */
	public static function sampleBar(bar:BarTerBarConfig, out:Array<BarTerSnap>):Void {
		if (bar == null || out == null) return;
		while (out.length < bar.slotCount)
			out.push(new BarTerSnap());
		for (i in 0...bar.slotCount) {
			var snap = out[i];
			if (snap == null) {
				snap = new BarTerSnap();
				out[i] = snap;
			}
			var flash = snap.flashUntil;
			snap.clear();
			snap.flashUntil = flash;
			var cfg = bar.slots[i];
			snap.keyLabel = "";
			if (cfg != null && cfg.hasItem()) {
				snap.kind = "item";
				sampleItem(cfg.itemKind, snap);
				continue;
			}
			if (cfg != null && cfg.hasStatus()) { sampleStatus(cfg.statusId,snap); continue; }
			var id = cfg != null ? GeauxCache.sanitizeSkillId(cfg.skillId) : "";
			var native=cfg!=null && cfg.nativeActionId.length>0 ? BarTerNativeKeys.action(cfg.nativeActionId) : null;
			if (cfg!=null && cfg.nativeActionId.length>0) { if(native==null) continue; id=native.id; }
			if (id.length == 0) continue;
			if (cfg.nativeActionId.length > 0 && BarTerNativeKeys.actionAbsent(cfg.nativeActionId, haxe.Timer.stamp()))
				continue;
			snap.skillId = id;
			snap.kind = "skill";
			if (native==null) native=BarTerNativeKeys.find(id);
			var gs = findGeaux(id);
			if (gs == null && native != null) gs=findGeaux(native.id);
			var observed = native != null;
			for (s in GeauxCache.barSnaps()) if (s.present && s.id == id) { observed=true; break; }
			// Same data Geaux shows: a live poll of this id from any Geaux list is an observation.
			if (!observed && gs != null && gs.present) observed=true;
			BarTerSkillState.apply(snap,observed,gs,native);
			if (native!=null && cfg.nativeActionId.length>0) { snap.iconId=native.icon; snap.label=native.label; }
			if (!observed) {
				snap.present = true; snap.label = solarflare.cdb.AuraCatalog.label(id);
				if (snap.label.length == 0) snap.label = id;
				snap.iconId = id; continue;
			}
			if (gs == null || !gs.present) {
				snap.present = true;
				if (native==null) { snap.label = id; snap.iconId = id; }
				continue;
			}
			snap.present = true;
			snap.iconId = gs.iconId != null && gs.iconId.length > 0 ? gs.iconId : id;
			snap.label = gs.label != null && gs.label.length > 0 ? gs.label : id;
		}
	}
	public static function prepareIcons(snap:BarTerSnap):Void {
		if (snap.kind == "empty") return;
		var candidates = snap.kind == "status" ? [snap.status.iconKey,snap.statusId]
			: snap.isItem ? [snap.iconId,"consumable_"+snap.itemKind,snap.itemKind]
			: GeauxCache.iconIdCandidates(snap.iconId.length > 0 ? snap.iconId : snap.skillId,null);
		for (id in candidates) {
			if (id == null || id.length == 0) continue;
			solarflare.ui.GameIcons.get(id);
			if (solarflare.ui.GameIcons.hasKey(id)) { snap.iconKey=id; break; }
		}
		if (snap.kind == "status" && snap.iconKey.length > 0) snap.status.iconKey=snap.iconKey;
	}
	static function sampleStatus(id:String,snap:BarTerSnap):Void {
		snap.kind="status"; snap.statusId=id; snap.iconId=id; snap.present=true;
		snap.keyLabel="";
		var s=solarflare.aura.AuraStatusCache.findExact(id);
		var out=snap.status; out.id=id; out.label=solarflare.cdb.AuraCatalog.label(id);
		if (out.label.length == 0) out.label=id;
		out.iconKey=id; snap.label=out.label;
		if (s == null) { out.known=false; return; }
		snap.available=s.known && s.present;
		out.present=s.present; out.known=s.known; out.stacks=s.stacks; out.stacksKnown=s.stacksKnown;
		out.instanceId=s.instanceId;
		out.durationKnown=s.durationKnown; out.infinite=s.infinite; out.left=s.left;
		out.progress=s.progress; out.endsAt=s.endsAt; out.totalDur=s.totalDur; out.stampSource=s.stampSource;
		for (alias in s.ids) if (solarflare.ui.GameIcons.hasKey(alias)) { out.iconKey=alias; break; }
	}

	static function sampleItem(kind:String, snap:BarTerSnap):Void {
		var entry = ConsumableCatalog.find(kind);
		snap.isItem = true;
		snap.available = true;
		snap.itemKind = kind;
		snap.present = true;
		snap.label = entry != null ? entry.name : kind;
		snap.iconId = entry != null ? ConsumableCatalog.iconKey(entry.id) : ("consumable_" + kind);
		var inv = ConsumableCache.find(kind);
		if (inv == null) {
			snap.count = 0;
			snap.usable = false;
			snap.ready = false;
			snap.affordable = false;
			return;
		}
		snap.count = inv.count;
		snap.usable = inv.usable;
		snap.ready = inv.owned && inv.count > 0 && inv.usable;
		snap.affordable = snap.ready;
		snap.onCd = false;
	}

	static function findGeaux(id:String):Dynamic {
		if (id == null || id.length == 0) return null;
		// The id's live record is the freshest poll from any list (Geaux, aura or BarTer).
		var live = GeauxCache.liveSnap(id);
		if (live != null) return live;
		// The dedicated bounded BarTer poll is fresher than dormant Geaux slots.
		for (s in GeauxCache.barTerSkills) if (s != null && s.present && s.id == id) return s;
		// Any matching snap is fine — twins refresh from the live record each pass.
		var i = 0;
		while (i < GeauxCache.count) {
			var s = GeauxCache.slots[i];
			if (s != null && s.present && s.id == id)
				return s;
			i++;
		}
		for (s in GeauxCache.auraSkills) {
			if (s != null && s.present && s.id == id)
				return s;
		}
		for (s in GeauxCache.weaponSnaps()) {
			if (s != null && s.present && s.id == id)
				return s;
		}
		for (s in GeauxCache.barTerSkills) {
			if (s != null && s.present && s.id == id)
				return s;
		}
		return null;
	}


	/**
	 * Submit consumable use through the audited ExtraBars path. Like ExtraBars.dispatch, the caller
	 * validates first (BarTer.observe: click TTL, gameplayBlockReason, slot-content match), so the
	 * policy's generation and `allowed` gates are passed as already satisfied.
	 */
	public static function useItem(kind:String, gen:Int, hero:Dynamic):{submitted:Bool, message:String, countBefore:Int} {
		var outcome = ExtraBarsUsePolicy.request(kind, ConsumableCatalog.find(kind) != null, gen, gen, true,
			function(k) return collect(hero, k),
			function(item:Dynamic) {
				var live:st.Item = item;
				live.requestUse(cast hero);
			});
		return {submitted: outcome.submitted, message: outcome.message, countBefore: outcome.countBefore};
	}

	public static function useSkill(skillId:String, action:String, hero:Dynamic):{success:Bool, message:String} {
		return BarTerSkillActivation.request(skillId, action, hero);
	}

	static function collect(hero:Dynamic, kind:String):Array<solarflare.extrabars.ExtraBarsUseCandidate> {
		var out:Array<solarflare.extrabars.ExtraBarsUseCandidate> = [];
		if (hero == null) throw "No local hero.";
		var h:ent.Hero = hero;
		var loadout = h.loadout;
		if (loadout == null || loadout.inventory == null || loadout.equipment == null)
			throw "Carried inventory unavailable.";
		function scan(inv:st.Inventory, equipped:Bool):Void {
			var n = inv.getSize();
			if (n < 0 || n > 1024) throw "Invalid inventory size.";
			for (i in 0...n) {
				if (equipped) {
					var eq:st.Equipment = inv;
					if (eq.isShortcut(i)) continue;
				}
				var stack = inv.getStack(i);
				if (stack == null || stack.item == null || solarflare.EngineText.cleanId(stack.item.kind) != kind)
					continue;
				out.push({
					item: stack.item,
					count: loadout.getDisplayStackCount(inv, stack),
					shortcut: false,
					usable: stack.item.canBeUsed(h)
				});
			}
		}
		scan(loadout.inventory, false);
		scan(loadout.equipment, true);
		return out;
	}

	public static function hasAnyItem(config:BarTerConfig):Bool {
		if (config == null) return false;
		for (bar in config.bars) {
			if (bar == null || !config.isActive(bar.id)) continue;
			for (i in 0...bar.slotCount) {
				if (bar.slots[i] != null && bar.slots[i].hasItem())
					return true;
			}
		}
		return false;
	}

	/**
	 * Stable loadout fingerprint for weapon-swap detection.
	 * Main + offhand + secondary kinds; empty when hero/weapons unavailable.
	 */
	public static function weaponLoadoutKey(hero:Dynamic):String {
		return BarTerLoadoutIdentity.key(hero);
	}

	static function weaponTag(wep:Dynamic):String {
		if (wep == null) return "";
		var kind = solarflare.EngineText.cleanId(HlxRuntime.resolveField(wep, "kind"));
		if (kind.length > 0) return kind;
		try {
			var inf:Dynamic = HlxRuntime.resolveField(wep, "inf");
			var id = solarflare.EngineText.cleanId(HlxRuntime.resolveField(inf, "id"));
			if (id.length > 0) return id;
			var type = solarflare.EngineText.cleanId(HlxRuntime.resolveField(inf, "type"));
			if (type.length > 0) return type;
		} catch (_:Dynamic) {}
		return "";
	}
}

