package solarflare.chaincast;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec2;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.LocalCastHistory;
import solarflare.chaincast.Chaincast.ChaincastCache;
import solarflare.chaincast.Chaincast.ChaincastConfig;
import solarflare.chaincast.ChaincastRenderer.ChaincastFrame;
import solarflare.chaincast.ChaincastRenderer.ChaincastWatchRow;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxCache.GeauxSlotSnap;
import solarflare.ui.GameIcons;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;

/**
 * Resolved skill data for Skill Watch and the Cast Trail. `GeauxCache.findSnap` lowercases and scans on
 * every call, so each id is resolved once and re-resolved only on a named trigger: the Geaux lists were
 * rebuilt (fingerprint: list identities and lengths, action-bar generation), the snap now holds another
 * skill, or a long safety interval elapsed. Cooldown numbers are read from the (mutated-in-place) snap.
 */
class ChaincastSnapMemo {
	static var memos = new Map<String, ChaincastSnapMemo>();
	static var fpSlots:Array<GeauxSlotSnap> = null;
	static var fpWeapons:Array<GeauxSlotSnap> = null;
	static var fpSigs:Array<GeauxSlotSnap> = null;
	static var fpSlotsN:Int = -1;
	static var fpWeaponsN:Int = -1;
	static var fpSigsN:Int = -1;
	static var fpGen:Int = -1;
	static var epoch:Int = 0;
	static var lastLoaded:Bool = false;

	public var id:String;
	public var snap:GeauxSlotSnap = null;
	public var name:String = "";
	public var icon:String = "";
	var snapId:String = "";
	var epochSeen:Int = -1;
	var refreshedAt:Float = -100;
	var iconLoaded:Bool = false;

	function new(id:String) {
		this.id = id;
	}

	/** Once per frame, before any `get`: bump the epoch when the Geaux data was rebuilt. */
	public static function beginFrame():Void {
		if (GeauxCache.slots != fpSlots || GeauxCache.weapons != fpWeapons || GeauxCache.signatures != fpSigs
			|| GeauxCache.slots.length != fpSlotsN || GeauxCache.weapons.length != fpWeaponsN
			|| GeauxCache.signatures.length != fpSigsN || GeauxCache.actionBarGeneration != fpGen) {
			fpSlots = GeauxCache.slots;
			fpWeapons = GeauxCache.weapons;
			fpSigs = GeauxCache.signatures;
			fpSlotsN = fpSlots.length;
			fpWeaponsN = fpWeapons.length;
			fpSigsN = fpSigs.length;
			fpGen = GeauxCache.actionBarGeneration;
			epoch++;
		}
	}

	public static function clearAll():Void {
		epoch++;
	}

	public static function get(id:String, t:Float):ChaincastSnapMemo {
		var m = memos.get(id);
		if (m == null) {
			m = new ChaincastSnapMemo(id);
			memos.set(id, m);
		}
		var retry = m.snap == null || m.iconLoaded ? 3.0 : 0.5;
		if (m.epochSeen != epoch || t - m.refreshedAt > retry || (m.snap != null && m.snap.id != m.snapId))
			m.refresh(t);
		return m;
	}

	function refresh(t:Float):Void {
		epochSeen = epoch;
		refreshedAt = t;
		snap = GeauxCache.findSnap(id);
		snapId = snap != null ? snap.id : "";
		name = ChaincastConfig.snapLabel(snap, id);
		icon = iconKey(snap, id);
		iconLoaded = lastLoaded;
	}

	/** First art key that is loaded (else the first candidate, which keeps loading in the background). */
	public static function iconKey(snap:GeauxSlotSnap, id:String):String {
		lastLoaded = false;
		var first = "";
		if (snap != null) {
			if (snap.iconId != null && snap.iconId.length > 0) {
				first = snap.iconId;
				if (GameIcons.get(first).toInt() != 0) {
					lastLoaded = true;
					return first;
				}
			}
			if (snap.iconCandidates != null)
				for (c in snap.iconCandidates) {
					if (c == null || c.length == 0)
						continue;
					if (first.length == 0)
						first = c;
					if (GameIcons.get(c).toInt() != 0) {
						lastLoaded = true;
						return c;
					}
				}
		}
		if (first.length == 0 && id != null) {
			first = id;
			if (id.length > 0 && GameIcons.get(id).toInt() != 0)
				lastLoaded = true;
		}
		return first;
	}

	/**
	 * Icon key of the newest local cast at or after `minAt` (and no older than `maxAge` seconds when set).
	 * Called on the Chaincast stack edge, never from a draw path.
	 */
	public static function latestCastIcon(minAt:Float, maxAge:Float):String {
		var best:LocalCastRecord = null;
		for (r in LocalCastHistory.shared.records)
			if (r.at >= minAt && (best == null || r.serial > best.serial))
				best = r;
		if (best == null)
			return "";
		if (maxAge > 0 && haxe.Timer.stamp() - best.at > maxAge)
			return "";
		return iconKey(GeauxCache.findSnap(best.skillId), best.skillId);
	}
}

/**
 * One independent Chaincast window: its own HudChrome (position, lock, transparent), size, style and
 * visibility. Nothing in a module's layout depends on any other window or on transient state.
 */
class ChaincastModule {
	public static inline var COUNTER:Int = 0;
	public static inline var TIMER:Int = 1;
	public static inline var GEM:Int = 2;
	public static inline var WATCH:Int = 3;
	public static inline var TRAIL:Int = 4;
	public static inline var BANNER:Int = 5;

	public final kind:Int;
	/** Stable persistence key. */
	public final key:String;
	public final name:String;
	public final blurb:String;
	/** Label of the module-specific toggle (`opt`). */
	public final optLabel:String;
	public final styleNames:Array<String>;
	public final minW:Single;
	public final minH:Single;
	public final maxW:Single;
	public final maxH:Single;

	public var hidden = new BoolRef(true);
	public var width = new FloatRef(0);
	public var height = new FloatRef(0);
	public var style = new IntRef(0);
	/** Locked windows disappear while there is nothing to show; unlocked ones stay as a layout ghost. */
	public var autoHide = new BoolRef(false);
	public var opt = new BoolRef(true);
	public var chrome:HudChrome;
	/** The module's own settings panel (registered with ConfigPanel.registerInteractive). */
	public var open = new BoolRef(false);

	public final windowId:String;
	public final panelName:String;
	public final idWin:String;
	public final idShow:String;
	public final idStyle:String;
	public final idOpen:String;
	public final idGrid:String;
	public final idPrev:String;
	public final idAuto:String;
	public final idOpt:String;
	public final idW:String;
	public final idH:String;
	public final idSize:String;
	public final idHeader:String;

	public function new(kind:Int, key:String, name:String, blurb:String, optLabel:String, styleNames:Array<String>, minW:Single, minH:Single,
			maxW:Single, maxH:Single, x0:Single, y0:Single) {
		this.kind = kind;
		this.key = key;
		this.name = name;
		this.blurb = blurb;
		this.optLabel = optLabel;
		this.styleNames = styleNames;
		this.minW = minW;
		this.minH = minH;
		this.maxW = maxW;
		this.maxH = maxH;
		chrome = new HudChrome(x0, y0);
		windowId = "SolarFlare ChainMod " + key;
		panelName = "Chaincast " + name;
		idWin = "chm_" + key;
		idShow = "##chmh_show_" + key;
		idStyle = "##chmh_style_" + key;
		idOpen = "Window settings##chmh_open_" + key;
		idGrid = "##chmh_grid_" + key;
		idPrev = "##chmh_prev_" + key;
		idAuto = "##chm_auto_" + key;
		idOpt = "##chm_opt_" + key;
		idW = "Width##chm_w_" + key;
		idH = "Height##chm_h_" + key;
		idSize = "##chm_size_" + key;
		idHeader = name + "##chmh_group_" + key;
		resetDefaults();
	}

	/** Suggested window size for a style (a style change applies it; the player resizes afterwards). */
	public function suggestW(s:Int):Float {
		return switch (kind) {
			case COUNTER: s == ChaincastRenderer.STYLE_ORBIT || s == ChaincastRenderer.STYLE_REACTOR || s == ChaincastRenderer.STYLE_ARC
				|| s == ChaincastRenderer.STYLE_PRISM || s == ChaincastRenderer.STYLE_HEXRING ? 120 : (ChaincastRenderer.isFlagship(s) ? 280 : 300);
			case TIMER: s == 2 || s == 3 ? 110 : 260;
			case GEM: s == 3 ? 260 : 100;
			case WATCH: s == 1 ? 260 : (s == 2 ? 250 : (s == 3 ? 220 : (s == 4 ? 230 : 320)));
			case TRAIL: s == 2 ? 70 : 280;
			default: 300;
		};
	}

	public function suggestH(s:Int):Float {
		return switch (kind) {
			case COUNTER: ChaincastRenderer.isFlagship(s) ? 132 : (s == ChaincastRenderer.STYLE_ORBIT || s == ChaincastRenderer.STYLE_REACTOR
				|| s == ChaincastRenderer.STYLE_PRISM || s == ChaincastRenderer.STYLE_HEXRING ? 90 : (s == ChaincastRenderer.STYLE_ARC ? 82 : 50));
			case TIMER: s == 2 || s == 3 ? 110 : (s == 4 ? 60 : 46);
			case GEM: s == 3 ? 64 : 110;
			case WATCH: s == 1 ? 190 : (s == 2 ? 190 : (s == 3 ? 220 : (s == 4 ? 52 : 88)));
			case TRAIL: s == 2 ? 250 : 56;
			default: 64;
		};
	}

	public function applyStyle(s:Int):Void {
		style.set(s);
		width.set(clampW(suggestW(s)));
		height.set(clampH(suggestH(s)));
		SettingsStore.markDirty();
	}

	public function clampW(v:Float):Float return Math.max(minW, Math.min(maxW, v));

	public function clampH(v:Float):Float return Math.max(minH, Math.min(maxH, v));

	/** Defaults for a fresh install or a profile that predates the module. */
	public function resetDefaults():Void {
		hidden.set(true);
		style.set(0);
		autoHide.set(kind == BANNER);
		opt.set(true);
		width.set(clampW(suggestW(0)));
		height.set(clampH(suggestH(0)));
	}

	/** Called after values were loaded: keep the style and size inside this module's valid range. */
	public function sanitize():Void {
		if (style.get() < 0 || style.get() >= styleNames.length)
			style.set(0);
		width.set(clampW(width.get()));
		height.set(clampH(height.get()));
	}
}

/**
 * The Chaincast module set. Owns the windows, a shared per-frame snapshot of the Chaincast caches, and the
 * hub section. Everything a window draws comes from that snapshot (frozen caches), so no module reads
 * live engine state and none can influence another's size or position.
 */
class ChaincastModules {
	public final all:Array<ChaincastModule>;
	public final counter:ChaincastModule;
	public final timer:ChaincastModule;
	public final gem:ChaincastModule;
	public final watch:ChaincastModule;
	public final trail:ChaincastModule;
	public final banner:ChaincastModule;

	var owner:ChaincastConfig;
	var theme:Theme;
	var live = new ChaincastFrame();
	var preview = new ChaincastFrame();
	var head = new ChaincastFrame();
	var cur:ChaincastModule;
	var curFrame:ChaincastFrame;
	var skillTmp = new ChaincastSkillState();

	var bodyFn:ImVec2->Void;
	var windowFn:Void->Void;
	var hideFn:Void->Void;
	var openFn:Void->Void;
	var resizeFn:Single->Single->Void;

	public function new(owner:ChaincastConfig) {
		this.owner = owner;
		counter = new ChaincastModule(ChaincastModule.COUNTER, "counter", "Chain Counter", "Charges toward the free cast: the original ten graphics plus new ones.",
			"Show N/4 count", ChaincastRenderer.COUNTER_NAMES, 60, 24, 720, 320, 60, 330);
		timer = new ChaincastModule(ChaincastModule.TIMER, "timer", "Chain Timer", "Time left in the chain window; pulses under 1.5 s.", "Show label",
			ChaincastRenderer.TIMER_NAMES, 50, 20, 720, 300, 94, 364);
		gem = new ChaincastModule(ChaincastModule.GEM, "gem", "Free Cast Gem", "Your 5th cast is free: n/4 while charging, a glowing FREE when ready.",
			"Show linked skill icon", ChaincastRenderer.GEM_NAMES, 40, 40, 400, 300, 128, 398);
		watch = new ChaincastModule(ChaincastModule.WATCH, "watch", "Skill Watch", "Assigned skills with a check or X, a cooldown ring and a fits-in-the-chain verdict.",
			"Show verdict text", ChaincastRenderer.WATCH_NAMES, 60, 30, 720, 520, 162, 432);
		trail = new ChaincastModule(ChaincastModule.TRAIL, "trail", "Cast Trail", "The casts that charged the chain, plus an open gold slot for the free cast.",
			"Show free-cast slot", ChaincastRenderer.TRAIL_NAMES, 50, 30, 520, 420, 196, 466);
		banner = new ChaincastModule(ChaincastModule.BANNER, "banner", "Free Cast Banner", "A short FREE CAST banner when the chain becomes ready.", "",
			ChaincastRenderer.BANNER_NAMES, 90, 26, 720, 200, 230, 500);
		all = [counter, timer, gem, watch, trail, banner];

		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(6, 6))
			.varF(ImGuiStyleVar.WindowRounding, 8)
			.varF(ImGuiStyleVar.WindowBorderSize, 0)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.05, 0.07, 0.12, 0.55))
			.color(ImGuiCol.Border, ImGui.vec4(0.35, 0.55, 0.90, 0.35))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.45, 0.65, 0.95, 0.40));
		bodyFn = hudBody;
		windowFn = hudWindow;
		hideFn = hudHide;
		openFn = hudOpen;
		resizeFn = hudResize;
	}

	/** True when any module window is switched on: the Chaincast statuses stay demanded for them. */
	public function anyVisible():Bool {
		for (m in all)
			if (!m.hidden.get())
				return true;
		return false;
	}

	/** Cast Trail needs the local cast history (HealthHooks records it only while demanded). */
	public function trailWanted():Bool return !trail.hidden.get();

	public function resetAll():Void {
		for (m in all)
			m.resetDefaults();
	}

	public function clearTransientState():Void {
		ChaincastSnapMemo.clearAll();
		for (m in all)
			m.open.set(false);
	}

	// ------------------------------------------------------------------ live windows

	/** Fill `f` from the frozen caches. Cheap field copies; the only lookups are memoised. */
	function fillLive(f:ChaincastFrame, t:Float, forceLink:Bool = false, forceRows:Bool = false):Void {
		f.t = t;
		f.stacks = ChaincastCache.valid ? ChaincastCache.current : 0;
		f.ready = ChaincastCache.ready;
		f.pulse = f.ready || ChaincastCache.pulseActive();
		f.remainValid = ChaincastCache.remainValid;
		f.remainLeft = ChaincastCache.remainLeft;
		f.remainProg = ChaincastCache.remainProg;
		f.readyAge = f.ready ? t - ChaincastCache.readyEdgeAt : 999;
		f.trail = ChaincastCache.trail;
		f.trailCount = ChaincastCache.trailCount;
		f.freeIcon = ChaincastCache.freeIcon;
		f.bannerGhost = false;
		ChaincastSnapMemo.beginFrame();
		var needLink = forceLink || !gem.hidden.get() || (!counter.hidden.get() && ChaincastRenderer.isFlagship(counter.style.get()));
		f.linkIcon = "";
		if (needLink) {
			var id = linkedId(t);
			var m = id.length > 0 ? ChaincastSnapMemo.get(id, t) : null;
			f.linkIcon = m != null ? m.icon : "";
			var s = m != null ? m.snap : null;
			f.skill.update(id.length > 0, s != null && s.present, s != null && s.cooldownValid, s != null && s.ready, s != null ? s.cdLeft : 0,
				s != null ? s.cdMax : 0);
		}
		if (forceRows || !watch.hidden.get())
			fillRows(f, t);
		else
			f.rowCount = 0;
	}

	/** Same rule as ChaincastConfig.linkedSkillId, through the memo (no per-frame scans). */
	function linkedId(t:Float):String {
		if (owner.spendId != null && owner.spendId.length > 0)
			return owner.spendId;
		if (owner.rotation != null)
			for (id in owner.rotation)
				if (ChaincastConfig.isWeaponSnap(ChaincastSnapMemo.get(id, t).snap))
					return id;
		return "";
	}

	/** Verdict per assigned skill: compares the skill's cooldown to the chain time left. */
	function fillRows(f:ChaincastFrame, t:Float):Void {
		var rot = owner.rotation;
		var n = rot != null ? rot.length : 0;
		if (n > ChaincastConfig.MAX_ROT)
			n = ChaincastConfig.MAX_ROT;
		f.rowCount = n;
		for (i in 0...n) {
			var r = f.rows[i];
			var m = ChaincastSnapMemo.get(rot[i], t);
			var s = m.snap;
			r.icon = m.icon;
			r.name = m.name;
			skillTmp.update(true, s != null && s.present, s != null && s.cooldownValid, s != null && s.ready, s != null ? s.cdLeft : 0,
				s != null ? s.cdMax : 0);
			r.state = skillTmp.state;
			r.progress = skillTmp.progress;
			var cd = skillTmp.remaining;
			r.cdLeft = cd;
			var v:Int;
			if (r.state == ChaincastSkillState.READY)
				v = ChaincastWatchRow.V_NOW;
			else if (r.state != ChaincastSkillState.COOLDOWN)
				v = ChaincastWatchRow.V_NONE;
			else if (!f.remainValid)
				v = ChaincastWatchRow.V_WAIT;
			else if (cd < f.remainLeft - 0.05)
				v = ChaincastWatchRow.V_FITS;
			else
				v = ChaincastWatchRow.V_LATE;
			r.verdict = v;
			// Text depends only on the verdict and the cooldown in tenths; rebuild when that key moves.
			var key = v * 100000 + Std.int(Math.min(cd, 9999) * 10);
			if (key != r.textKey) {
				r.textKey = key;
				var cs = ChaincastRenderer.fmtSec(cd);
				switch (v) {
					case ChaincastWatchRow.V_NOW:
						r.longText = "ready now";
						r.pillText = "READY";
						r.shortText = "ready";
					case ChaincastWatchRow.V_FITS:
						r.longText = "ready in " + cs + " before chain ends";
						r.pillText = cs + " - fits";
						r.shortText = cs;
					case ChaincastWatchRow.V_LATE:
						r.longText = "not in time (" + cs + ")";
						r.pillText = cs + " - late";
						r.shortText = cs;
					case ChaincastWatchRow.V_WAIT:
						// A blocked cooldown can carry no duration; never invent a time for it.
						r.longText = cd > 0 ? "ready in " + cs : "on cooldown";
						r.pillText = cd > 0 ? cs : "on CD";
						r.shortText = cd > 0 ? cs : "CD";
					default:
						r.longText = "no data";
						r.pillText = "no data";
						r.shortText = "--";
				}
			}
		}
	}

	/** Called every frame from ChaincastOverlay.draw; draws each switched-on module in its own window. */
	public function draw():Void {
  if(!solarflare.ResourceCapabilities.current.chaincast) return;
		var any = false;
		for (m in all)
			if (!m.hidden.get()) {
				any = true;
				break;
			}
		if (any && ChaincastCache.active) {
			fillLive(live, ChaincastRenderer.nowStamp());
			var idle = !live.ready && live.stacks == 0 && !live.remainValid;
			for (m in all) {
				if (m.hidden.get())
					continue;
				var locked = m.chrome.isLocked();
				if (m.kind == ChaincastModule.BANNER) {
					var active = live.ready && live.readyAge < ChaincastRenderer.BANNER_SECONDS;
					if (!active && locked)
						continue;
					live.bannerGhost = !active;
				} else if (m.autoHide.get() && locked && idle)
					continue;
				cur = m;
				curFrame = live;
				theme.wrap(windowFn);
				cur = null;
				curFrame = null;
			}
		}
		for (m in all)
			if (m.open.get())
				drawPanel(m);
	}

	function hudWindow():Void {
		var m = cur;
		var w:Single = m.clampW(m.width.get());
		var h:Single = m.clampH(m.height.get());
		HUDWidgetWindow.draw(m.windowId, m.name, m.chrome, w, h, bodyFn, openFn, hideFn, false, null, resizeFn);
	}

	function hudBody(size:ImVec2):Void {
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(size);
		render(cur, curFrame, p.x, p.y, size.x, size.y);
	}

	function hudHide():Void {
		cur.hidden.set(true);
		SettingsStore.markDirty();
	}

	function hudOpen():Void {
		cur.open.set(true);
	}

	function hudResize(newW:Single, newH:Single):Void {
		var m = cur;
		m.width.set(m.clampW(newW));
		m.height.set(m.clampH(newH));
		SettingsStore.markDirty();
	}

	/** The one place a module becomes pixels; the live window and the hub preview both call it. */
	function render(m:ChaincastModule, f:ChaincastFrame, x:Float, y:Float, w:Float, h:Float):Void {
		renderKind(m.kind, m.style.get(), m.opt.get(), f, x, y, w, h);
	}

	function renderKind(kind:Int, style:Int, opt:Bool, f:ChaincastFrame, x:Float, y:Float, w:Float, h:Float):Void {
		switch (kind) {
			case ChaincastModule.COUNTER:
				ChaincastRenderer.drawCounter(style, x + 2, y + 2, w - 4, h - 4, f, opt);
			case ChaincastModule.TIMER:
				ChaincastRenderer.drawTimerModule(style, x + 2, y + 2, w - 4, h - 4, f, opt);
			case ChaincastModule.GEM:
				ChaincastRenderer.drawGemModule(style, x, y, w, h, f, opt);
			case ChaincastModule.WATCH:
				ChaincastRenderer.drawWatchModule(style, x + 2, y + 2, w - 4, h - 4, f, opt);
			case ChaincastModule.TRAIL:
				ChaincastRenderer.drawTrailModule(style, x + 2, y + 2, w - 4, h - 4, f, opt);
			default:
				ChaincastRenderer.drawBannerModule(style, x, y, w, h, f);
		}
	}

	/** Height the combined window reserves for a module Graphic id (the module's suggested height for that style). */
	public function graphicHeight(g:Int):Float {
		return all[ChaincastRenderer.graphicKind(g)].suggestH(ChaincastRenderer.graphicStyle(g));
	}

	/**
	 * Draws a module's art for a Graphic-list pick inside the combined window: the same renderer as that
	 * module's own window, fed by the same frozen caches. Absolute rectangle, so the caller's layout is untouched.
	 */
	public function drawGraphic(g:Int, x:Float, y:Float, w:Float, h:Float, showCount:Bool):Void {
		var kind = ChaincastRenderer.graphicKind(g);
		fillLive(head, ChaincastRenderer.nowStamp(), kind == ChaincastModule.GEM, kind == ChaincastModule.WATCH);
		head.bannerGhost = !(head.ready && head.readyAge < ChaincastRenderer.BANNER_SECONDS);
		renderKind(kind, ChaincastRenderer.graphicStyle(g), kind == ChaincastModule.COUNTER ? showCount : true, head, x, y, w, h);
	}

	// ------------------------------------------------------------------ hub

	/** A looping synthetic chain (charge, charge, charge, charge, free cast) for previews. */
	function fillPreview(f:ChaincastFrame, t:Float):Void {
		var phase = t % 10.0;
		f.t = t;
		f.stacks = phase >= 6.0 ? 4 : Std.int(phase / 1.5);
		f.ready = phase >= 6.0;
		f.pulse = f.ready;
		f.remainValid = phase >= 1.5 || f.ready;
		f.remainLeft = Math.max(0.2, 12.0 - (phase - 1.5) * 1.3);
		f.remainProg = f.remainLeft / 12.0;
		f.readyAge = f.ready ? phase - 6.0 : 999;
		f.bannerGhost = !f.ready || f.readyAge >= ChaincastRenderer.BANNER_SECONDS;
		f.linkIcon = GameIcons.CHAINCAST;
		f.skill.update(true, true, true, f.ready, 3.7, 10);
		f.trail = PREVIEW_TRAIL;
		f.trailCount = f.stacks;
		f.freeIcon = "";
		f.rowCount = 3;
		for (i in 0...3) {
			var r = f.rows[i];
			r.icon = GameIcons.CHAINCAST;
			r.name = PREVIEW_NAMES[i];
			var cd = i == 0 ? 0.0 : (i == 1 ? 2.1 : 14.0);
			r.state = i == 0 ? ChaincastSkillState.READY : ChaincastSkillState.COOLDOWN;
			r.cdLeft = cd;
			r.progress = i == 0 ? 1 : (i == 1 ? 0.7 : 0.15);
			r.verdict = i == 0 ? ChaincastWatchRow.V_NOW : (i == 1 ? ChaincastWatchRow.V_FITS : ChaincastWatchRow.V_LATE);
			r.longText = PREVIEW_LONG[i];
			r.pillText = PREVIEW_PILL[i];
			r.shortText = PREVIEW_SHORT[i];
		}
	}

	static final PREVIEW_TRAIL:Array<String> = [GameIcons.CHAINCAST, GameIcons.CHAINCAST, GameIcons.CHAINCAST, GameIcons.CHAINCAST];
	static final PREVIEW_NAMES:Array<String> = ["Skill A", "Skill B", "Skill C"];
	static final PREVIEW_LONG:Array<String> = ["ready now", "ready in 2.1s before chain ends", "not in time (14s)"];
	static final PREVIEW_PILL:Array<String> = ["READY", "2.1s - fits", "14s - late"];
	static final PREVIEW_SHORT:Array<String> = ["ready", "2.1s", "14s"];

	function drawPreview(m:ChaincastModule):Void {
		var avail = ImGui.getContentRegionAvail().x;
		var pw:Single = Math.max(60, Math.min(avail - 8, m.clampW(m.width.get())));
		var ph:Single = Math.min(170, m.clampH(m.height.get()));
		fillPreview(preview, ChaincastRenderer.nowStamp());
		HudChrome.safeChild(m.idPrev, ImGui.vec2(pw + 8, ph + 8), HudChrome.CHILD_NO_SCROLL, function() {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(ImGui.vec2(pw, ph));
			var dl = ImGui.getWindowDrawList();
			ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + pw, p.y + ph), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.05, 0.07, 0.12, 0.8)), 6);
			render(m, preview, p.x, p.y, pw, ph);
		});
	}

	function styleCombo(m:ChaincastModule):Void {
		var sel = m.style.get();
		if (sel < 0 || sel >= m.styleNames.length)
			sel = 0;
		if (ImGui.beginCombo(m.idStyle, m.styleNames[sel])) {
			for (i in 0...m.styleNames.length)
				if (ImGui.selectable(m.styleNames[i] + "##chm_s_" + m.key + "_" + i, sel == i))
					m.applyStyle(i);
			ImGui.endCombo();
		}
	}

	/** The Modules section on the Chaincast page: Show, Style and a live preview for every module. */
	public function drawHub():Void {
		ImGui.separatorText("Modules");
		ImGui.textWrapped("Each module is its own window with its own position, size, style, lock and transparency, so none can move another. The combined window above keeps working.");
		for (m in all) {
			if (!UiChrome.groupHeader(m.idHeader, true))
				continue;
			ImGui.textWrapped(m.blurb);
			UiLayout.propertyGrid(m.idGrid, function() {
				UiLayout.propertyRow("Showing", function() {
					if (UiChrome.showingChip(m.idShow, m.hidden))
						SettingsStore.markDirty();
				});
				UiLayout.propertyRow("Style", function() styleCombo(m));
				UiLayout.propertyRow("Window", function() {
					if (UiChrome.ghostButton(m.idOpen, ImGui.vec2(150, 28)))
						m.open.set(true);
				});
			});
			if (m.kind == ChaincastModule.WATCH)
				ImGui.textWrapped("Skills come from the Next-cast list above (" + (owner.rotation != null ? owner.rotation.length : 0)
					+ " assigned). Cooldown data needs Geaux enabled.");
			drawPreview(m);
		}
	}

	function drawPanel(m:ChaincastModule):Void {
		ImGui.setNextWindowSize(ImGui.vec2(420, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel(m.panelName, m.open, m.name)) {
			ImGui.separatorText("Window");
			m.chrome.drawWindowSettings(m.hidden, m.idWin);
			UiLayout.propertyGrid(m.idSize, function() {
				UiLayout.propertyRow("Size", function() {
					UiLayout.inlinePair(m.idSize + "_pair", function(_:Single) {
						if (ImGui.sliderFloat(m.idW, m.width, m.minW, m.maxW, "%.0f px"))
							SettingsStore.markDirty();
					}, function(_:Single) {
						if (ImGui.sliderFloat(m.idH, m.height, m.minH, m.maxH, "%.0f px"))
							SettingsStore.markDirty();
					});
				});
				UiLayout.propertyRow("Style", function() styleCombo(m));
				if (m.optLabel.length > 0)
					UiLayout.propertyRow("Options", function() {
						if (ImGui.checkbox(m.optLabel + m.idOpt, m.opt))
							SettingsStore.markDirty();
					});
				if (m.kind != ChaincastModule.BANNER)
					UiLayout.propertyRow("When idle", function() {
						if (ImGui.checkbox("Hide while idle (locked)" + m.idAuto, m.autoHide))
							SettingsStore.markDirty();
					});
			});
			if (m.kind == ChaincastModule.WATCH) {
				owner.drawRotationEditor();
				ImGui.textWrapped("Verdict colours: green = off cooldown, amber = back before the chain ends, red = not in time.");
			}
			if (m.kind == ChaincastModule.TRAIL)
				ImGui.textWrapped("Icons come from your recent casts when a charge lands; a cast that cannot be matched shows the charge icon.");
			drawPreview(m);
		}
		HudChrome.endPanel();
	}
}
