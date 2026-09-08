package solarflare.ui;

import solarflare.attackcombo.AttackComboConfig;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.combatlog.CombatLogConfig;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxConfig;
import solarflare.getrifty.GetRifty;
import solarflare.lightsaber.Lightsaber;
import solarflare.localtime.LocalTime;
import imgui.ImGui;

/**
 * Persist SolarFlare layout + toggles next to the installed mod.
 */
class SettingsStore {
	static inline var VERSION:Int = 19;
	static var dirty = false;
	static var lastCfg:ConfigPanel = null;
	static var lastSaveMs:Float = 0;
	static var activeTheme:String = "purple_gold";
	static var lastCaptureWarning:String = "";

	public static function currentTheme():String return activeTheme;

	public static function setActiveTheme(t:String):Void {
		activeTheme = t != null ? t : "purple_gold";
		markDirty();
	}

	public static function bind(cfg:ConfigPanel):Void {
		lastCfg = cfg;
	}

	public static function saveNow():Void {
		if (lastCfg != null) {
			save(lastCfg);
			ToastManager.success("Solar Flare layout saved!");
		}
	}

	/** Enqueueable alias — prefer UiActionQueue.save() from draw paths. */
	public static function enqueueSave():Void {
		UiActionQueue.save();
	}

	public static function resetLayout():Void {
		try {
			var ini = iniPath();
			if (ini != null && sys.FileSystem.exists(ini))
				sys.FileSystem.deleteFile(ini);
		} catch (_:Dynamic) {}
		DockingHelper.resetLayout();
		markDirty();
		ToastManager.info("HUD layout reset to defaults.");
	}
	static var iniTried = false;
	static var cachedPath:String = null;
	static var saberMigrated = false;
	static var combatMigrated = false;

	public static function markDirty():Void {
		dirty = true;
	}

	public static function isDirty():Bool {
		return dirty;
	}

	public static function captureWarning():String return lastCaptureWarning;

	public static function load(cfg:ConfigPanel):Void {
		if (cfg == null)
			return;
		lastCfg = cfg;
		try {
			var path = jsonPath();
			if (path == null || !sys.FileSystem.exists(path))
				return;
			var raw = sys.io.File.getContent(path);
			if (raw == null || raw.length == 0)
				return;
			var data:Dynamic = haxe.Json.parse(raw);
			apply(cfg, data);
			FeatureProfiles.load(cfg, data);
			applyUiState(cfg, Reflect.field(data, "uiState"));
		} catch (_:Dynamic) {}
	}

	public static function tick(cfg:ConfigPanel):Void {
		tryLoadIni();
		if (!dirty || cfg == null)
			return;
		var now = Date.now().getTime();
		if (now - lastSaveMs < 300)
			return;
		save(cfg);
	}

	public static function save(cfg:ConfigPanel):Void {
		if (cfg == null)
			return;
		try {
			var path = jsonPath();
			if (path == null)
				return;
			ensureDir(haxe.io.Path.directory(path));
			var jsonText = haxe.Json.stringify(dump(cfg), null, "  ");
			sys.io.File.saveContent(path, jsonText);
			dirty = false;
			lastSaveMs = Date.now().getTime();
			try {
				var ini = iniPath();
				if (ini != null)
					ImGui.saveIniSettingsToDisk(ini);
			} catch (_:Dynamic) {}
		} catch (_:Dynamic) {}
	}

	static function tryLoadIni():Void {
		if (iniTried)
			return;
		iniTried = true;
		try {
			var ini = iniPath();
			if (ini != null && sys.FileSystem.exists(ini))
				ImGui.loadIniSettingsFromDisk(ini);
		} catch (_:Dynamic) {}
	}

	static function dump(cfg:ConfigPanel):Dynamic {
		var data = dumpCore(cfg);
		FeatureProfiles.storeAll(cfg);
		Reflect.setField(data, "geaux", geauxDump(cfg.geaux));
		Reflect.setField(data, "auras", aurasDump(cfg.auras));
		Reflect.setField(data, "featureProfiles", FeatureProfiles.dump());
		Reflect.setField(data, "uiState", dumpUiState(cfg));
		return data;
	}

	static function dumpCore(cfg:ConfigPanel):Dynamic {
		lastCaptureWarning = "";
		var data:Dynamic = {v: VERSION, activeTheme: activeTheme};
		assignDump(data, "customTheme", function() return ThemePalette.dumpCustom());
		assignDump(data, "vitals", function() return vitalsDump(cfg.vitals));
		assignDump(data, "localTime", function() return localDump(cfg.localTime));
		assignDump(data, "geaux", function() return geauxDump(cfg.geaux));
		assignDump(data, "rifty", function() return riftyDump(cfg.getRifty));
		assignDump(data, "combo", function() return comboDump(cfg.combo));
		assignDump(data, "chaincast", function() return chaincastDump(cfg.chaincast));
		assignDump(data, "conduit", function() return conduitDump(cfg.conduit));
		assignDump(data, "attackCombo", function() return attackComboDump(cfg.attackCombo));
		assignDump(data, "resourceTracker", function() return resourceTrackerDump(cfg));
		assignDump(data, "clog", function() return clogDump(cfg.combatLog));
		assignDump(data, "target", function() return targetDump(cfg.target));
		assignDump(data, "launchers", function() return cfg.launchers != null ? cfg.launchers.dump() : {});
		assignDump(data, "saber", function() return saberDump(cfg.lightsaber));
		assignDump(data, "auras", function() return aurasDump(cfg.auras));
		assignDump(data, "universalProfiles", function() return FeatureProfiles.dump());
		assignDump(data, "hub", function() return {
			w: cfg.hubW != null ? cfg.hubW.get() : 360,
			h: cfg.hubH != null ? cfg.hubH.get() : 480,
			chrome: chromeDump(cfg.hubChrome),
			ledger: solarflare.debug.ResolutionLedger.enabled.get()
		});
		return data;
	}

	static function assignDump(data:Dynamic, field:String, build:Void->Dynamic):Void {
		try
			Reflect.setField(data, field, build())
		catch (e:Dynamic) {
			Reflect.setField(data, field, {});
			var msg = field;
			try msg += ": " + Std.string(e) catch (_:Dynamic) {}
			if (lastCaptureWarning.length > 0)
				lastCaptureWarning += "; ";
			lastCaptureWarning += msg;
			trace("SolarFlare profile capture skipped " + msg);
		}
	}

	static function dumpUiState(cfg:ConfigPanel):Dynamic {
		return {hubOpen: cfg != null && cfg.open != null ? cfg.open.get() : false, hubTab: cfg != null ? cfg.profileUiTab() : 0,
			rememberHubLayout: cfg != null ? cfg.rememberHubLayout.get() : true};
	}

	static function applyUiState(cfg:ConfigPanel, data:Dynamic):Void {
		if (cfg == null || data == null) return;
		setBool(cfg.rememberHubLayout, data.rememberHubLayout);
		try if (data.hubOpen != null) cfg.open.set(data.hubOpen == true) catch (_:Dynamic) {}
		try if (data.hubTab != null) cfg.applyProfileUiTab(Std.int(data.hubTab)) catch (_:Dynamic) {}
	}

	public static function vitalsDump(v:VitalsConfig):Dynamic {
		if (v == null)
			return {};
		return {
			hpHidden: v.hpHidden.get(),
			rageHidden: v.rageHidden.get(),
			manaHidden: v.manaHidden.get(),
			prayersHidden: v.prayersHidden.get(),
			hpW: v.hpWidth.get(),
			hpH: v.hpHeight.get(),
			rageW: v.rageWidth.get(),
			rageH: v.rageHeight.get(),
			manaW: v.manaWidth.get(),
			manaH: v.manaHeight.get(),
			prayersW: v.prayersWidth.get(),
			prayersH: v.prayersHeight.get(),
			hpStyle: v.hpStyle.get(),
			rageStyle: v.rageStyle.get(),
			manaStyle: v.manaStyle.get(),
			hpVert: v.hpVertical.get(),
			rageVert: v.rageVertical.get(),
			manaVert: v.manaVertical.get(),
			layout: v.layout.get(),
			chrome: chromeDump(v.chrome),
			rageChrome: chromeDump(v.rageChrome),
			manaChrome: chromeDump(v.manaChrome),
			prayersChrome: chromeDump(v.prayersChrome)
		};
	}

	public static function attackComboDump(c:AttackComboConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			type: c.comboType.get(),
			customStyle: c.customStyle.get(),
			shape: c.shape.get(),
			vertical: c.vertical.get(),
			w: c.width.get(),
			h: c.height.get(),
			bannerH: c.bannerH.get(),
			mode: c.comboType.get() == 1 ? 2 : (c.shape.get() == PipShapes.BOX ? 1 : 0),
			art: c.customStyle.get() == 0 ? 0 : 1,
			chrome: chromeDump(c.chrome)
		};
	}

	static function localDump(l:LocalTimeConfig):Dynamic {
		if (l == null)
			return {};
		return {
			on: l.enabled.get(),
			w: l.width.get(),
			h: l.height.get(),
			chrome: chromeDump(l.chrome)
		};
	}

	public static function geauxDump(g:GeauxConfig):Dynamic {
		if (g == null)
			return {};
		g.ensureSlots();
		return {
			on: g.enabled.get(),
			rows: g.rows.get(),
			cols: g.cols.get(),
			w: g.width.get(),
			h: g.height.get(),
			slots: geauxSlotsForSave(g),
			glyphs: geauxGlyphsForSave(g),
			hotkeys: geauxHotkeysForSave(g),
			chrome: chromeDump(g.chrome),
			style: g.style != null ? g.style.dump() : {}
		};
	}

	public static function cleanJsonString(v:Dynamic):String {
		if (v == null)
			return "";
		if (Reflect.isObject(v) && !Std.isOfType(v, String)) {
			var b = Reflect.field(v, "bytes");
			if (b != null) return "";
		}
		var str = Std.string(v);
		if (str == null || str.length == 0 || str == "null" || str == "undefined")
			return "";
		if (str.indexOf("{") >= 0 && str.indexOf("bytes") >= 0)
			return "";
		var buf = new StringBuf();
		for (i in 0...str.length) {
			var code = StringTools.fastCodeAt(str, i);
			if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95 || code == 45) {
				buf.addChar(code);
			}
		}
		return buf.toString();
	}

	/** JSON-safe slot ids only — preserve user grid layout exactly as configured. */
	static function geauxSlotsForSave(g:GeauxConfig):Array<String> {
		var out:Array<String> = [];
		var n = g.visibleCount();
		for (i in 0...n) {
			var raw = i < g.slotIds.length ? g.slotIds[i] : "";
			var s = cleanJsonString(raw);
			out.push(s);
		}
		return out;
	}

	static function geauxGlyphsForSave(g:GeauxConfig):Array<String> {
		var out:Array<String> = [];
		for (i in 0...g.visibleCount()) {
			var source:Dynamic = i < g.slotGlyphs.length ? g.slotGlyphs[i] : "";
			var s = cleanJsonString(source);
			out.push(s);
			if (i < g.slotGlyphs.length) g.slotGlyphs[i] = s;
		}
		return out;
	}

	static function geauxHotkeysForSave(g:GeauxConfig):Array<String> {
		var out:Array<String> = [];
		g.ensureSlots();
		for (i in 0...g.visibleCount()) {
			var s = cleanJsonString(i < g.slotHotkeys.length ? g.slotHotkeys[i] : "");
			out.push(s);
			if (i < g.slotHotkeys.length) g.slotHotkeys[i] = s;
		}
		return out;
	}

	public static function resourceTrackerDump(cfg:ConfigPanel):Dynamic {
		return {};
	}

	static function riftyDump(r:GetRiftyConfig):Dynamic {
		if (r == null)
			return {};
		return {
			hidden: r.hidden.get(),
			size: r.size.get(),
			clockStyle: r.clockStyle.get(),
			textU0: r.textU0.get(),
			textV0: r.textV0.get(),
			textU1: r.textU1.get(),
			textV1: r.textV1.get(),
			chrome: chromeDump(r.chrome)
		};
	}

	static function saberDump(s:LightsaberConfig):Dynamic {
		if (s == null)
			return {};
		return {
			hidden: s.hidden.get(),
			expand: s.expandSkills.get(),
			log: s.showLog.get(),
			rift: s.showRiftMeter.get(),
			w: s.width.get(),
			h: s.height.get(),
			chrome: chromeDump(s.chrome),
			riftW: s.riftWidth.get(),
			riftH: s.riftHeight.get(),
			riftChrome: chromeDump(s.riftChrome)
		};
	}

	public static function comboDump(c:ComboConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			vertical: c.vertical.get(),
			shape: c.shape.get(),
			w: c.width.get(),
			h: c.height.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function conduitDump(c:ConduitConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			vertical: c.vertical.get(),
			shape: c.shape.get(),
			w: c.width.get(),
			h: c.height.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function chaincastDump(c:ChaincastConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			w: c.width.get(),
			h: c.height.get(),
			title: c.title,
			rot: c.rotation,
			spend: c.spendId,
			chrome: chromeDump(c.chrome)
		};
	}

	static function clogDump(c:CombatLogConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			you: c.showYou.get(),
			player: c.showPlayer.get(),
			enemy: c.showEnemy.get(),
			heroes: c.showHeroes.get(),
			tgt: c.currentTargetOnly.get(),
			record: solarflare.combatlog.CombatLogRecorder.enabled.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function targetDump(c:solarflare.target.TargetConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			always: c.alwaysShow.get(),
			empty: !c.alwaysShow.get(),
			name: c.showName.get(),
			badge: c.showBadge.get(),
			portrait: c.showPortrait.get(),
			pct: c.showPercent.get(),
			hp: c.showHpText.get(),
			emptyBar: c.showEmptyBar.get(),
			pulse: c.lowHpPulse.get(),
			low: c.lowHpPercent.get(),
			round: c.barRounding.get(),
			boss: c.bossesOnly.get(),
			w: c.width.get(),
			h: c.height.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function aurasDump(c:solarflare.aura.AuraConfig):Dynamic {
		if (c == null)
			return {};
		var on = true;
		var unlock = true;
		try on = c.enabled.get() catch (_:Dynamic) {}
		try unlock = c.unlockAll.get() catch (_:Dynamic) {}
		return {
			on: on,
			unlock: unlock,
			list: auraList(c),
			auraCounter: solarflare.aura.AuraCounterState.dump(c.auras)
		};
	}

	static function auraList(c:solarflare.aura.AuraConfig):Array<Dynamic> {
		var out:Array<Dynamic> = [];
		if (c == null || c.auras == null)
			return out;
		for (a in c.auras) {
			if (a == null)
				continue;
			var obj = solarflare.aura.AuraEngine.toObj(a);
			if (obj != null)
				out.push(obj);
		}
		return out;
	}

	public static function applyAurasProfile(c:solarflare.aura.AuraConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		var source = ProfileMigration.flatOrSelectedLegacy(data, "list");
		if (source.on != null)
			setBool(c.enabled, source.on);
		if (source.unlock != null)
			setBool(c.unlockAll, source.unlock);
		solarflare.aura.AuraConfig.applyListDump(c, source);
		solarflare.aura.AuraCounterState.apply(c.auras, Reflect.field(source, "auraCounter"));
	}

	static function chromeDump(c:HudChrome):Dynamic {
		if (c == null)
			return {};
		return {
			lock: c.locked.get(),
			trans: c.transparent.get(),
			collapsed: c.collapsed.get(),
			sun: c.showGrip.get(),
			x: c.x.get(),
			y: c.y.get()
		};
	}

	static function apply(cfg:ConfigPanel, data:Dynamic):Void {
		if (data == null)
			return;
		try if (data.activeTheme != null) activeTheme = Std.string(data.activeTheme) catch (_:Dynamic) {}
		try if (data.customTheme != null) ThemePalette.applyCustomDump(data.customTheme) catch (_:Dynamic) {}
		applyVitals(cfg.vitals, data.vitals);
		// Migrate flat v1 fields into vitals when nested block is absent.
		if (cfg.vitals != null && data.vitals == null) {
			setBool(cfg.vitals.hpHidden, data.hpHidden);
			setBool(cfg.vitals.rageHidden, data.rageHidden);
			setBool(cfg.vitals.prayersHidden, data.prayersHidden);
			setFloat(cfg.vitals.hpWidth, data.hpW);
			setFloat(cfg.vitals.hpHeight, data.hpH);
			cfg.vitals.hpSizeDirty = true;
			applyChrome(cfg.vitals.chrome, data.hp);
		}
		applyLocal(cfg.localTime, data.localTime);
		if (cfg.localTime != null && data.localTime != null && Std.isOfType(data.localTime, Bool)) {
			setBool(cfg.localTime.enabled, data.localTime);
			applyChrome(cfg.localTime.chrome, data.lt);
		} else if (cfg.localTime != null && data.localTime == null && data.lt != null) {
			// Legacy layout: only chrome under `lt` — leave enabled at ctor default.
			applyChrome(cfg.localTime.chrome, data.lt);
		}
		applyGeauxProfile(cfg.geaux, data.geaux);
		applyRifty(cfg.getRifty, data.rifty);
		// v5: Geaux uses Show (enabled) instead of Hide; force visible once on upgrade.
		try {
			var ver = data.v;
			var v = ver == null ? 0 : Std.parseInt(Std.string(ver));
			if (v == null)
				v = 0;
			if (v < 5) {
				if (cfg.geaux != null) {
					cfg.geaux.enabled.set(true);
					cfg.geaux.sizeDirty = true;
					if (cfg.geaux.chrome != null)
						cfg.geaux.chrome.posDirty = true;
				}
				if (cfg.getRifty != null)
					cfg.getRifty.hidden.set(false);
				if (cfg.localTime != null) {
					cfg.localTime.enabled.set(true);
					if (cfg.localTime.chrome != null)
						// Defer clampToViewport — ImGui viewport APIs AV during mod main().
						cfg.localTime.chrome.posDirty = true;
				}
				dirty = true;
			}
		} catch (_:Dynamic) {}
		applyCombo(cfg.combo, data.combo);
		applyChaincast(cfg.chaincast, data.chaincast);
		applyConduit(cfg.conduit, data.conduit);
		applyAttackCombo(cfg.attackCombo, data.attackCombo);
		applyResourceTracker(cfg, data);
		applyClog(cfg.combatLog, data.clog);
		applyTarget(cfg.target, data.target);
		applySaber(cfg.lightsaber, data.saber);
		applyAurasProfile(cfg.auras, data.auras);
		if (cfg.launchers != null)
			cfg.launchers.apply(data.launchers);
		applyHub(cfg, data.hub);
		if (cfg.combo != null && data.combo == null && data.comboHidden != null)
			setBool(cfg.combo.hidden, data.comboHidden);
		FeatureProfiles.load(cfg, data);
	}

	public static function applyVitals(v:VitalsConfig, data:Dynamic):Void {
		if (v == null || data == null)
			return;
		setBool(v.hpHidden, data.hpHidden);
		setBool(v.rageHidden, data.rageHidden);
		setBool(v.manaHidden, data.manaHidden);
		setBool(v.prayersHidden, data.prayersHidden);
		setFloat(v.hpWidth, data.hpW);
		setFloat(v.hpHeight, data.hpH);
		setFloat(v.rageWidth, data.rageW != null ? data.rageW : data.hpW);
		setFloat(v.rageHeight, data.rageH != null ? data.rageH : data.hpH);
		setFloat(v.manaWidth, data.manaW != null ? data.manaW : data.hpW);
		setFloat(v.manaHeight, data.manaH != null ? data.manaH : data.hpH);
		setFloat(v.prayersWidth, data.prayersW != null ? data.prayersW : data.hpW);
		setFloat(v.prayersHeight, data.prayersH != null ? data.prayersH : data.hpH);
		setInt(v.hpStyle, data.hpStyle);
		setInt(v.rageStyle, data.rageStyle);
		setInt(v.manaStyle, data.manaStyle);
		setBool(v.hpVertical, data.hpVert);
		setBool(v.rageVertical, data.rageVert);
		setBool(v.manaVertical, data.manaVert);
		setInt(v.layout, data.layout);
		v.hpSizeDirty = true;
		applyChrome(v.chrome, data.chrome != null ? data.chrome : data);
		v.rageSizeDirty = true;
		v.manaSizeDirty = true;
		v.prayersSizeDirty = true;
		applyChrome(v.rageChrome, data.rageChrome != null ? data.rageChrome : data.chrome);
		applyChrome(v.manaChrome, data.manaChrome != null ? data.manaChrome : data.chrome);
		applyChrome(v.prayersChrome, data.prayersChrome != null ? data.prayersChrome : data.chrome);
	}

	public static function applyAttackCombo(c:AttackComboConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		var migrated = ProfileMigration.migrateAttackCombo(data);
		setBool(c.hidden, migrated.hidden);
		if (migrated.type != null) setInt(c.comboType, migrated.type);
		if (migrated.customStyle != null) setInt(c.customStyle, migrated.customStyle);
		setBool(c.vertical, migrated.vertical);
		if (migrated.shape != null) setInt(c.shape, migrated.shape);
		setFloat(c.width, migrated.w);
		setFloat(c.height, migrated.h);
		setFloat(c.bannerH, migrated.bannerH);
		c.sizeDirty = true;
		applyChrome(c.chrome, migrated.chrome);
	}

	static function applyLocal(l:LocalTimeConfig, data:Dynamic):Void {
		if (l == null || data == null)
			return;
		if (Std.isOfType(data, Bool)) {
			setBool(l.enabled, data);
			return;
		}
		setBool(l.enabled, data.on);
		setFloat(l.width, data.w);
		setFloat(l.height, data.h);
		l.sizeDirty = true;
		applyChrome(l.chrome, data.chrome);
	}

	public static function applyGeauxProfile(g:GeauxConfig, data:Dynamic):Void {
		if (g == null || data == null)
			return;
		g.applyLayout(ProfileMigration.flatOrSelectedLegacy(data, "slots"));
		g.ensureSlots();
	}

	static function flatOrSelectedLegacy(data:Dynamic, flatField:String):Dynamic {
		return ProfileMigration.flatOrSelectedLegacy(data, flatField);
	}

	static function flattenLegacyFeature(data:Dynamic, flatField:String):Dynamic {
		return ProfileMigration.flattenLegacyFeature(data, flatField);
	}


	static function applyRifty(r:GetRiftyConfig, data:Dynamic):Void {
		if (r == null || data == null)
			return;
		setBool(r.hidden, data.hidden);
		setFloat(r.size, data.size);
		setInt(r.clockStyle, data.clockStyle);
		setFloat(r.textU0, data.textU0);
		setFloat(r.textV0, data.textV0);
		setFloat(r.textU1, data.textU1);
		setFloat(r.textV1, data.textV1);
		r.sizeDirty = true;
		applyChrome(r.chrome, data.chrome);
	}

	public static function applyCombo(c:ComboConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		setBool(c.vertical, data.vertical);
		setInt(c.shape, data.shape);
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
	}

	public static function applyChaincast(c:ChaincastConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		try {
			if (data.title != null) {
				var t = StringTools.trim(Std.string(data.title));
				if (t.length > 0)
					c.title = t;
			}
		} catch (_:Dynamic) {}
		c.syncTitleBuf();
		try {
			var rot:Dynamic = Reflect.field(data, "rot");
			if (rot != null) {
				c.rotation = [];
				var i = 0;
				var len = 0;
				try
					len = rot.length
				catch (_:Dynamic)
					len = 0;
				if (len > ChaincastConfig.MAX_ROT)
					len = ChaincastConfig.MAX_ROT;
				while (i < len) {
					var id = Std.string(rot[i]);
					if (id != null && id.length > 1 && id != "null")
						c.rotation.push(id);
					i++;
				}
			}
		} catch (_:Dynamic) {}
		try {
			if (data.spend != null)
				c.spendId = Std.string(data.spend);
		} catch (_:Dynamic) {}
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
	}

	public static function applyConduit(c:ConduitConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		setBool(c.vertical, data.vertical);
		setInt(c.shape, data.shape);
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
	}

	static function applyResourceTracker(cfg:ConfigPanel, data:Dynamic):Void {
		if (cfg == null || data == null)
			return;
		var rt:Dynamic = null;
		try
			rt = Reflect.field(data, "resourceTracker")
		catch (_:Dynamic) {}
		if (rt == null)
			return;
		// Compatibility for old files whose only resource values lived in a nested bank.
		if (data.vitals == null) {
			var legacy = ProfileMigration.flatOrSelectedLegacy(rt, "vitals");
			if (legacy != null) {
				applyVitals(cfg.vitals, legacy.vitals != null ? legacy.vitals : legacy);
				applyCombo(cfg.combo, legacy.combo);
				applyChaincast(cfg.chaincast, legacy.chaincast);
				applyConduit(cfg.conduit, legacy.conduit);
			}
		}
	}

	static function applyClog(c:CombatLogConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		setBool(c.showYou, data.you);
		setBool(c.showPlayer, data.player);
		setBool(c.showEnemy, data.enemy);
		setBool(c.showHeroes, data.heroes);
		setBool(c.currentTargetOnly, data.tgt);
		setBool(solarflare.combatlog.CombatLogRecorder.enabled, data.record);
		applyChrome(c.chrome, data.chrome);
	}

	public static function applyTarget(c:solarflare.target.TargetConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		if (data.always != null)
			setBool(c.alwaysShow, data.always);
		else if (data.empty != null)
			setBool(c.alwaysShow, data.empty != true);
		setBool(c.showName, data.name);
		setBool(c.showBadge, data.badge);
		setBool(c.showPortrait, data.portrait);
		setBool(c.showPercent, data.pct);
		setBool(c.showHpText, data.hp);
		setBool(c.showEmptyBar, data.emptyBar);
		setBool(c.lowHpPulse, data.pulse);
		if (data.low != null) {
			var lowV:Float = data.low;
			// Migrate old 0–1 ratio saves into percent.
			if (lowV > 0 && lowV <= 1)
				lowV *= 100;
			setFloat(c.lowHpPercent, lowV);
		}
		setFloat(c.barRounding, data.round);
		setBool(c.bossesOnly, data.boss);
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
	}

	static function applyHub(cfg:ConfigPanel, data:Dynamic):Void {
		if (cfg == null || data == null)
			return;
		setFloat(cfg.hubW, data.w);
		setFloat(cfg.hubH, data.h);
		cfg.hubSizeDirty = true;
		applyChrome(cfg.hubChrome, data.chrome);
		setBool(solarflare.debug.ResolutionLedger.enabled, data.ledger);
	}

	static function applySaber(s:LightsaberConfig, data:Dynamic):Void {
		if (s == null || data == null)
			return;
		setBool(s.hidden, data.hidden);
		setBool(s.expandSkills, data.expand);
		setBool(s.showLog, data.log);
		setBool(s.showRiftMeter, data.rift);
		setFloat(s.width, data.w);
		setFloat(s.height, data.h);
		s.sizeDirty = true;
		applyChrome(s.chrome, data.chrome);
		setFloat(s.riftWidth, data.riftW);
		setFloat(s.riftHeight, data.riftH);
		s.riftSizeDirty = true;
		applyChrome(s.riftChrome, data.riftChrome);
	}

	static function applyChrome(c:HudChrome, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.locked, data.lock);
		setBool(c.transparent, data.trans);
		setBool(c.collapsed, data.collapsed);
		if (data.sun != null)
			setBool(c.showGrip, data.sun);
		setFloat(c.x, data.x);
		setFloat(c.y, data.y);
		c.posDirty = true;
	}

	static function setBool(r:imgui.ref.BoolRef, v:Dynamic):Void {
		if (r == null || v == null)
			return;
		try
			r.set(isTruthy(v))
		catch (_:Dynamic) {}
	}

	static function isTruthy(v:Dynamic):Bool {
		if (v == null)
			return false;
		if (v == true)
			return true;
		if (v == false)
			return false;
		try {
			var s = StringTools.trim(Std.string(v)).toLowerCase();
			return s == "true" || s == "1" || s == "yes";
		} catch (_:Dynamic) {
			return false;
		}
	}

	static function setFloat(r:imgui.ref.FloatRef, v:Dynamic):Void {
		if (r == null || v == null)
			return;
		try {
			var f:Float = Std.parseFloat(Std.string(v));
			if (!Math.isNaN(f))
				r.set(f);
		} catch (_:Dynamic) {}
	}

	static function setInt(r:imgui.ref.IntRef, v:Dynamic):Void {
		if (r == null || v == null)
			return;
		try {
			var i = Std.parseInt(Std.string(v));
			if (i != null)
				r.set(i);
		} catch (_:Dynamic) {}
	}

	/** `{exe}/hlx/mods/solarflare` */
	public static function modDir():String {
		return ModPaths.modDir();
	}

	/** `{modDir}/logs` — all SolarFlare JSONL/debug dumps. */
	public static function logsDir():String {
		var mod = modDir();
		if (mod == null)
			return null;
		var dir = haxe.io.Path.join([mod, "logs"]);
		ensureDir(dir);
		return dir;
	}

	public static function logSubdir(name:String):String {
		var logs = logsDir();
		if (logs == null || name == null || name.length == 0)
			return null;
		var dir = haxe.io.Path.join([logs, name]);
		ensureDir(dir);
		return dir;
	}

	public static function logFile(file:String):String {
		var logs = logsDir();
		if (logs == null || file == null || file.length == 0)
			return "";
		return haxe.io.Path.join([logs, file]);
	}

	/** Move leftover `modDir/saber-*.jsonl` into `logs/saber/`. */
	public static function migrateSaberLogs():Void {
		if (saberMigrated)
			return;
		saberMigrated = true;
		var mod = modDir();
		var dest = logSubdir("saber");
		if (mod == null || dest == null)
			return;
		try {
			if (!sys.FileSystem.exists(mod) || !sys.FileSystem.isDirectory(mod))
				return;
			var names = sys.FileSystem.readDirectory(mod);
			var i = 0;
			while (i < names.length) {
				var n = names[i];
				i++;
				if (n == null || n.length < 12)
					continue;
				if (!StringTools.startsWith(n, "saber-") || !StringTools.endsWith(n, ".jsonl"))
					continue;
				var src = haxe.io.Path.join([mod, n]);
				var dst = haxe.io.Path.join([dest, n]);
				try {
					if (sys.FileSystem.exists(dst) || sys.FileSystem.isDirectory(src))
						continue;
					sys.FileSystem.rename(src, dst);
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
	}

	/** Move leftover `modDir/combatlog/*` into `logs/combatlog/`. */
	public static function migrateCombatLogs():Void {
		if (combatMigrated)
			return;
		combatMigrated = true;
		var mod = modDir();
		var dest = logSubdir("combatlog");
		if (mod == null || dest == null)
			return;
		var old = haxe.io.Path.join([mod, "combatlog"]);
		try {
			if (!sys.FileSystem.exists(old) || !sys.FileSystem.isDirectory(old))
				return;
			var names = sys.FileSystem.readDirectory(old);
			var i = 0;
			while (i < names.length) {
				var n = names[i];
				i++;
				if (n == null || n.length == 0)
					continue;
				var src = haxe.io.Path.join([old, n]);
				var dst = haxe.io.Path.join([dest, n]);
				try {
					if (sys.FileSystem.isDirectory(src) || sys.FileSystem.exists(dst))
						continue;
					sys.FileSystem.rename(src, dst);
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
	}

	static function jsonPath():String {
		if (cachedPath != null)
			return cachedPath;
		try {
			cachedPath = haxe.io.Path.join([ModPaths.modDir(), "solarflare.json"]);
			return cachedPath;
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function iniPath():String {
		try {
			return haxe.io.Path.join([ModPaths.modDir(), "imgui.ini"]);
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function ensureDir(dir:String):Void {
		if (dir == null || dir.length == 0)
			return;
		if (sys.FileSystem.exists(dir))
			return;
		ensureDir(haxe.io.Path.directory(dir));
		try
			sys.FileSystem.createDirectory(dir)
		catch (_:Dynamic) {}
	}
}
