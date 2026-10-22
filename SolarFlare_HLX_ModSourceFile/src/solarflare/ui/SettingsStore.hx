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
import imgui.ImGui;

/**
 * Persist SolarFlare layout + toggles next to the installed mod.
 */
class SettingsStore {
	static inline var VERSION:Int = 35;
	static inline var TMP_SUFFIX:String = ".tmp";
	static var dirty = false;
	static var saveBlocked = false;
	/** Consecutive failed saves; automatic retries back off (1s doubling to 30s) instead of hammering the disk. */
	static var failCount = 0;
	static var retryAtMs:Float = 0;
	static var lastCfg:ConfigPanel = null;
	static var lastSaveMs:Float = 0;
	static var lastEditMs:Float = 0;
	/** First unsaved edit since the last good save; bounds how long a debounce can defer a write. */
	static var dirtySinceMs:Float = 0;
	/** First lazy (gameplay counter) edit not yet promoted to `dirty`; 0 when none. */
	static var lazyDirtySinceMs:Float = 0;
	/** Safety net: lazy state reaches disk at least this often even without a flush edge. */
	static inline var LAZY_MS:Float = 60000;
	/** A save is synchronous on the render thread (stringify, write, re-parse, rename): wait for edits to settle. */
	static inline var QUIET_MS:Float = 1500;
	static inline var MIN_GAP_MS:Float = 4000;
	static inline var MAX_DEFER_MS:Float = 30000;
	static var activeTheme:String = "purple_gold";
	static var lastCaptureWarning:String = "";

	/** A partially recovered/newer layout must never be autosaved over its source. */
	public static function blockSaving(reason:String):Void {
		ProfileTrace.note("save","BLOCKED: "+reason); if (!saveBlocked) ToastManager.error(reason + " Saving is off this session.", 8.0);
		saveBlocked=true;
	}
	public static function ensureEditorLayout():Void tryLoadIni();

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
			if (save(lastCfg))
				ToastManager.success("Solar Flare layout saved!");
			else
				ToastManager.error("Solar Flare layout could not be saved.");
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

	/** Cosmetic persistence with the exact existing debounce, retry and durability policy. */
    public static function markPresentationDirty():Void {
        var stamp=haxe.Timer.stamp()*1000;
        if(!dirty || dirtySinceMs<=0) dirtySinceMs=stamp;
        dirty=true; lastEditMs=stamp;
    }
    public static function markDirty():Void {
		var stamp = haxe.Timer.stamp() * 1000;
		if (!dirty || dirtySinceMs <= 0)
			dirtySinceMs = stamp;
		dirty = true;
		lastEditMs = stamp;
		try
			solarflare.ObserveDemand.markStatusDemandDirty()
		catch (_:Dynamic) {}
	}

	/**
	 * Gameplay-driven state that is captured from live objects at save time (aura counters): remembered here,
	 * promoted to a real dirty flag only after LAZY_MS or when a flush path (logout/title/explicit) runs.
	 * Does not touch the status-demand dirty bit, so no demand rebuild and no save inside a fight.
	 */
	public static function markDirtyLazy():Void {
		if (lazyDirtySinceMs <= 0)
			lazyDirtySinceMs = haxe.Timer.stamp() * 1000;
	}

	/**
	 * Automatic or UI-only state that must persist but never justifies its own save: the same demand invalidation as
	 * markDirty, with the save coalesced into the lazy window (LAZY_MS, or logout/title/any other save).
	 */
	public static function markDirtyDeferred():Void {
		markDirtyLazy();
		try
			solarflare.ObserveDemand.markStatusDemandDirty()
		catch (_:Dynamic) {}
	}

	static function promoteLazy():Void {
		if (lazyDirtySinceMs <= 0)
			return;
		lazyDirtySinceMs = 0;
		var stamp = haxe.Timer.stamp() * 1000;
		if (!dirty || dirtySinceMs <= 0)
			dirtySinceMs = stamp;
		dirty = true;
		lastEditMs = stamp;
	}

	public static function isDirty():Bool {
		return dirty || lazyDirtySinceMs > 0;
	}

	public static function captureWarning():String return lastCaptureWarning;

	public static function load(cfg:ConfigPanel):Void {
		if (cfg == null)
			return;
		lastCfg = cfg;
		cfg.uiLayouts.captureDefaults(cfg);
  FeatureProfiles.captureFactory(cfg);
		var path = jsonPath();
		if (path == null)
			return;
		// Recovery copies belong to the user; updates must not delete them.
		// A crash between deleting the old file and renaming the verified .tmp leaves only the .tmp.
		var data:Dynamic = null;
		var source:String = null;
		for (candidate in [path, path + TMP_SUFFIX]) {
			var text = readText(candidate);
			if (text == null || text.length == 0)
				continue;
			try {
				data = haxe.Json.parse(text);
				source = candidate;
				break;
			} catch (_:Dynamic) {}
		}
		if (data == null) {
			if (sys.FileSystem.exists(path) || sys.FileSystem.exists(path+TMP_SUFFIX)) blockSaving("Saved settings could not be parsed; original files preserved.");
			return;
		}
		if (source != path) {
			dirty = true;
			ToastManager.info("SolarFlare settings restored from " + haxe.io.Path.withoutDirectory(source) + ".", 4.0);
		}
		try {
			if(!Reflect.isObject(data) || Std.isOfType(data,Array) || Std.isOfType(data,String)) throw "Invalid settings root";
			var oldVersion = readVersion(data);
			if (oldVersion > VERSION) { blockSaving("Settings belong to a newer mod version; original files preserved."); return; }
   var savedProfiles=Reflect.field(data,"universalProfiles");
   if(oldVersion<VERSION || savedProfiles==null || !Reflect.hasField(savedProfiles,"version")) ProfileMigrationBackup.ensure(source);
			// One-time format conversion: back the file up first, then let the first save after login rewrite it. No backup, no conversion.
			var convert = SettingsFormat.needsConversion(data);
			if (convert) {
				try {
					var kept = SettingsFormat.backup(source);
					formatConversionPending = true;
					ProfileTrace.note("format", "converting settings to format " + SettingsFormat.CURRENT + "; backup " + haxe.io.Path.withoutDirectory(kept));
				} catch (e:Dynamic) {
					convert = false;
					blockSaving("Could not back up settings before the one-time format conversion (" + Std.string(e) + ").");
				}
			}
			apply(cfg, data);
			FeatureProfiles.load(cfg, data);
				ProfileTrace.note("load","settings v"+oldVersion+" -> "+VERSION+"; "+FeatureProfiles.summary());
			if (oldVersion < VERSION || convert) dirty = true;
			// v24: the first cast-bar build persisted the new overlay as hidden,
			// including in the active universal profile, so no telemetry was demanded.
			if (oldVersion < 24) {
				FeatureProfiles.migrateCastBarVisible(cfg);
				dirty = true;
			}
			applyUiState(cfg, Reflect.field(data, "uiState"));
			try
				solarflare.ObserveDemand.markStatusDemandDirty()
			catch (_:Dynamic) {}
		} catch (e:Dynamic) {
				IdentityLog.note("settings load failed: " + Std.string(e) + " | " + haxe.CallStack.toString(haxe.CallStack.exceptionStack()).split("
").join(" <- "));
			// A partial apply would be saved over the user's file on the next edit; leave the file untouched.
			saveBlocked = true;
			ToastManager.error("SolarFlare settings could not be loaded (" + Std.string(e)
				+ "). Saving is off this session so the file is left as it is.", 8.0);
		}
	}

	static function readText(path:String):String {
		try {
			if (!sys.FileSystem.exists(path))
				return null;
			return sys.io.File.getContent(path);
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function readVersion(data:Dynamic):Int {
		try {
			var raw = Reflect.field(data, "v");
			var parsed = raw == null ? 0 : Std.parseInt(Std.string(raw));
			return parsed == null ? 0 : parsed;
		} catch (_:Dynamic) {
			return 0;
		}
	}

	public static function tick(?cfg:ConfigPanel):Void {
		tryLoadIni();
		var target = cfg != null ? cfg : lastCfg;
		if (lazyDirtySinceMs > 0 && haxe.Timer.stamp() * 1000 - lazyDirtySinceMs >= LAZY_MS)
			promoteLazy();
		if (!dirty || target == null)
			return;
		var now = haxe.Timer.stamp() * 1000;
		if (dirtySinceMs <= 0)
			dirtySinceMs = now;
		var overdue = now - dirtySinceMs >= MAX_DEFER_MS;
		if (now < retryAtMs || (!overdue && (now - lastEditMs < QUIET_MS || now - lastSaveMs < MIN_GAP_MS)))
			return;
		save(target);
	}

	/** Dirty flush for per-frame callers (title screen / logout) that must respect the failure backoff. */
	public static function saveIfDue(cfg:ConfigPanel):Void {
		promoteLazy();
		if (dirty && haxe.Timer.stamp() * 1000 >= retryAtMs)
			save(cfg);
	}

	public static function flushDirty():Void {
		promoteLazy();
		if (dirty && lastCfg != null) {
			save(lastCfg);
		}
	}

	/** Explicit saves always attempt; returns whether the file was replaced. */
	public static function save(cfg:ConfigPanel):Bool {
		if (cfg == null || saveBlocked || !FeatureProfiles.ready) {
			// Back off: otherwise the 4 Hz tick retries (and appends a trace line to disk) until profiles are ready.
			if (cfg != null && haxe.Timer.stamp() * 1000 >= retryAtMs) {
				ProfileTrace.note("save","SKIPPED blocked="+saveBlocked+" ready="+FeatureProfiles.ready);
				retryAtMs = haxe.Timer.stamp() * 1000 + 2000;
			}
			return false;
		}
		try {
			var path = jsonPath();
			if (path == null)
				return false;
			ensureDir(haxe.io.Path.directory(path));
			var data=dump(cfg);
   if(lastCaptureWarning.length>0) throw lastCaptureWarning;
   var jsonText = haxe.Json.stringify(data);
			// Never write the live file in place: a crash mid-write would truncate it.
			var tmp = path + TMP_SUFFIX;
			sys.io.File.saveContent(tmp, jsonText);
			// Do not replace anything until the bytes on disk parse.
   var stagedText=sys.io.File.getContent(tmp);
   if(stagedText!=jsonText) throw "Settings verification failed";
   var verified=haxe.Json.parse(stagedText);
   // Throwaway bank over the parsed text: references, not deep copies of every profile.
   var validation=new ProfileBank({}); validation.load(verified.universalProfiles,null,null,null,1920,1080,true);
			replaceWith(tmp, path, verified);
			ProfileTrace.note("save","OK "+jsonText.length+" bytes; "+FeatureProfiles.summary());
			if (formatConversionPending) {
				formatConversionPending = false;
				ProfileTrace.note("format", "settings converted to format " + SettingsFormat.CURRENT);
				ToastManager.info("Settings file converted to the new format. The original is kept as a .bak beside it.", 6.0);
			}
			dirty = false;
			dirtySinceMs = 0;
			lazyDirtySinceMs = 0;
			lastSaveMs = haxe.Timer.stamp() * 1000;
			failCount = 0;
			retryAtMs = 0;
			try {
				var ini = iniPath();
				if (ini != null)
					ImGui.saveIniSettingsToDisk(ini);
			} catch (_:Dynamic) {}
			return true;
		} catch (e:Dynamic) {
			ProfileTrace.note("save","FAILED: "+Std.string(e)+" | "+haxe.CallStack.toString(haxe.CallStack.exceptionStack()).split("
").join(" <- "));
			failCount++;
			retryAtMs = haxe.Timer.stamp() * 1000 + Math.min(30000.0, 1000.0 * Math.pow(2, failCount - 1));
			if (failCount == 1)
				ToastManager.error("SolarFlare could not save settings; retrying.", 4.0);
			return false;
		}
	}

	/**
	 * Rename can't overwrite on Windows, so the old file is deleted once the verified .tmp is on disk.
	 * Every crash point leaves the old file or the verified .tmp; load() checks both. No backup file is kept.
	 */
	static function replaceWith(tmp:String, path:String, verified:Dynamic = null):Void {
  VerifiedSettingsWrite.replace(tmp,path,null,verified);
	}

	static function tryLoadIni():Void {
		if (iniTried)
			return;
		try {
			if (ImGui.getIO() == null) return;
			var ini = iniPath();
			if (ini != null && sys.FileSystem.exists(ini))
				ImGui.loadIniSettingsFromDisk(ini);
			iniTried = true;
		} catch (_:Dynamic) {}
	}

	static function dump(cfg:ConfigPanel):Dynamic {
		FeatureProfiles.storeAll(cfg);
		var data = dumpCore(cfg);
		// dumpCore already produced geaux, auras and the profile bank; reuse them instead of dumping (and deep-copying) again.
		// A section that failed there is absent and also sets lastCaptureWarning, which aborts the save.
		if (!Reflect.hasField(data, "geaux")) Reflect.setField(data, "geaux", geauxDump(cfg.geaux));
		if (!Reflect.hasField(data, "auras")) Reflect.setField(data, "auras", aurasDump(cfg.auras));
		// The old `featureProfiles` alias of the bank is no longer written: it duplicated universalProfiles byte for byte and the
		// loader reads it only from files that predate universalProfiles.
		Reflect.setField(data, "uiState", dumpUiState(cfg));
		return data;
	}

	static var backupSeen = false;
	/** Set on load when an old-format file was backed up; cleared by the first successful save, which performs the conversion. */
	static var formatConversionPending = false;

	/**
	 * True once a byte-exact copy of the old file sits beside the settings: either the pre-migration copy
	 * (`solarflare.json.profiles-v35-*.bak`) or the pre-format-conversion copy (`solarflare.json.pre-format*.bak`).
	 * Either one holds everything the migration recovery payloads would.
	 */
	static function migrationBackupExists():Bool {
		if (backupSeen) return true;
		try {
			var path = jsonPath();
			var dir = haxe.io.Path.directory(path);
			for (name in sys.FileSystem.readDirectory(dir))
				if (StringTools.startsWith(name, "solarflare.json.profiles-v35-") && StringTools.endsWith(name, ".bak")) { backupSeen = true; break; }
			if (!backupSeen && SettingsFormat.backupExists(path)) backupSeen = true;
		} catch (_:Dynamic) {}
		return backupSeen;
	}

 public static function captureProfileAuxiliary(cfg:ConfigPanel):Dynamic return {
  nativeHide:cfg.nativeHide.dump(),hideMove:cfg.hideMove.dump(),aimInstant:cfg.aimInstant.dump(),
  rifty:riftyDump(cfg.getRifty),clog:clogDump(cfg.combatLog),saber:saberDump(cfg.lightsaber),launchers:cfg.launchers.dump(),
  customTheme:ThemePalette.dumpCustom(),uiPack:cfg.uiPack.dump()
 };
 public static function applyProfileAuxiliary(cfg:ConfigPanel,d:Dynamic):Void {
  cfg.nativeHide.apply(d.nativeHide); cfg.hideMove.apply(d.hideMove); cfg.aimInstant.apply(d.aimInstant);
  applyRifty(cfg.getRifty,d.rifty); applyClog(cfg.combatLog,d.clog); applySaber(cfg.lightsaber,d.saber); cfg.launchers.apply(d.launchers);
  ThemePalette.applyCustomDump(d.customTheme); cfg.uiPack.apply(d.uiPack);
 }

	static function dumpCore(cfg:ConfigPanel):Dynamic {
		lastCaptureWarning = "";
		var data:Dynamic = {v: VERSION, format: SettingsFormat.CURRENT, activeTheme: activeTheme,preventCtrlFullscreen:cfg.preventCtrlFullscreen.get(),blockClickThrough:cfg.blockClickThrough.get()};
		assignDump(data, "customTheme", function() return ThemePalette.dumpCustom());
		assignDump(data, "uiPack", function() return cfg.uiPack != null ? cfg.uiPack.dump() : {id: "custom"});
		assignDump(data, "nativeHide", function() return cfg.nativeHide.dump());
		assignDump(data, "customImages", function() return CustomImages.dump());
		assignDump(data, "hideMove", function() return cfg.hideMove != null ? cfg.hideMove.dump() : {});
		assignDump(data, "barter", function() return cfg.barter != null ? cfg.barter.dump() : {});
		assignDump(data, "aimInstant", function() return cfg.aimInstant != null ? cfg.aimInstant.dump() : {});
		assignDump(data, "statusBoard", function() return cfg.statusBoard != null ? cfg.statusBoard.dump() : {});
		assignDump(data, "stacks", function() return cfg.stacks != null ? cfg.stacks.dump() : {});
		assignDump(data, "vitals", function() return vitalsDump(cfg.vitals));
		assignDump(data, "geaux", function() return geauxDump(cfg.geaux));
		assignDump(data, "extraBars", function() return cfg.extraBarsPrototype.model.dump());
		assignDump(data, "extraBarsPlacement", function() return cfg.extraBarsPrototype.dumpPlacement());
		assignDump(data, "extraBarsCharacters", function() return cfg.extraBarsPrototype.dumpCharacterSettings());
		assignDump(data, "rifty", function() return riftyDump(cfg.getRifty));
		assignDump(data, "combo", function() return comboDump(cfg.combo));
		assignDump(data, "chaincast", function() return chaincastDump(cfg.chaincast));
		assignDump(data, "conduit", function() return conduitDump(cfg.conduit));
		assignDump(data, "hemorrhage", function() return hemorrhageDump(cfg.hemorrhage));
		assignDump(data, "attackCombo", function() return attackComboDump(cfg.attackCombo));
		assignDump(data, "resourceTracker", function() return resourceTrackerDump(cfg));
		assignDump(data, "clog", function() return clogDump(cfg.combatLog));
		assignDump(data, "target", function() return targetDump(cfg.target));
		assignDump(data, "castBar", function() return castBarDump(cfg.castBar));
		assignDump(data, "launchers", function() return cfg.launchers != null ? cfg.launchers.dump() : {});
		assignDump(data, "saber", function() return saberDump(cfg.lightsaber));
		assignDump(data, "auras", function() return aurasDump(cfg.auras));
		assignDump(data, "hideAll", hideAllDump);
		assignDump(data, "alignGrid", AlignmentGrid.dump);
		assignDump(data, "uiHints", UiHints.dump);
		assignDump(data, "universalProfiles", function() return FeatureProfiles.dump(true, migrationBackupExists()));
		assignDump(data, "hub", function() return {
			w: cfg.hubW != null ? cfg.hubW.get() : 360,
			h: cfg.hubH != null ? cfg.hubH.get() : 480,
			chrome: chromeDump(cfg.hubChrome)
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
			hudLayoutVersion: 1,
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
			hpLook: v.hpLook.dump(),
			rageLook: v.rageLook.dump(),
			manaLook: v.manaLook.dump(),
			prayersLook: v.prayersLook.dump(),
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
			pipMode: c.displayMode.get(),
			pipColors: c.colorScheme.get(),
			pipGlow: c.showGlow.get(),
			pipLabels: c.showLabels.get(),
			pipSpeed: c.animationSpeed.get(),
			chrome: chromeDump(c.chrome)
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
		return {dash:cfg.dash.dump(),artwork:cfg.resourceArtwork.dump()};
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
			pointCount: c.points(),
			hidden: c.hidden.get(),
			vertical: c.vertical.get(),
			shape: c.shape.get(),
			look: c.look.dump(),
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
			look: c.look.dump(),
			w: c.width.get(),
			h: c.height.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function hemorrhageDump(c:solarflare.hemorrhage.HemorrhageConfig):Dynamic {
		return c == null ? {} : {hidden:c.hidden.get(),autoScroll:c.autoScroll.get(),floatingText:c.floatingText.get(),
			textSize:c.textSize.get(),textLifetime:c.textLifetime.get(),w:c.width.get(),h:c.height.get(),chrome:chromeDump(c.chrome)};
	}

	public static function applyHemorrhage(c:solarflare.hemorrhage.HemorrhageConfig,data:Dynamic):Void {
		if(c==null) return;
		if(data==null) { c.hidden.set(true); c.autoScroll.set(true); c.floatingText.set(false); return; }
		setBool(c.hidden,data.hidden); setBool(c.autoScroll,data.autoScroll); setBool(c.floatingText,data.floatingText);
		setFloat(c.textSize,data.textSize); setFloat(c.textLifetime,data.textLifetime);
		setFloat(c.width,data.w); setFloat(c.height,data.h);
		c.textSize.set(Math.max(12,Math.min(28,c.textSize.get())));
		c.textLifetime.set(Math.max(0.5,Math.min(3,c.textLifetime.get())));
		c.width.set(Math.max(300,Math.min(1600,c.width.get()))); c.height.set(Math.max(150,Math.min(1200,c.height.get())));
		applyChrome(c.chrome,data.chrome); c.sizeDirty=true;
	}

	public static function chaincastDump(c:ChaincastConfig):Dynamic {
		if (c == null)
			return {};
		var rotOut:Array<String> = [];
		if (c.rotation != null) {
			for (r in c.rotation) {
				var id = GeauxCache.coerceSkillId(r);
				if (id.length == 0)
					id = cleanJsonString(r);
				if (id.length > 0 && GeauxCache.isUsableSkillId(id))
					rotOut.push(id);
			}
			c.rotation = rotOut;
		}
		var spend = GeauxCache.coerceSkillId(c.spendId);
		if (spend.length == 0)
			spend = cleanJsonString(c.spendId);
		if (spend.length > 0 && !GeauxCache.isUsableSkillId(spend))
			spend = "";
		c.spendId = spend;
		return {
			hidden: c.hidden.get(),
			w: c.width.get(),
			h: c.height.get(),
			title: c.title,
			rot: rotOut,
			spend: spend,
			style: c.style.get(),
			showStackBadge: c.showStackBadge.get(),
			chrome: chromeDump(c.chrome),
			modules: chaincastModulesDump(c.modules)
		};
	}

	/** Chaincast module windows: one entry per module key; chrome carries position, lock and transparency. */
	static function chaincastModulesDump(ms:solarflare.chaincast.ChaincastModules):Dynamic {
		var out:Dynamic = {};
		if (ms == null)
			return out;
		for (m in ms.all)
			Reflect.setField(out, m.key, {
				hidden: m.hidden.get(),
				w: m.width.get(),
				h: m.height.get(),
				style: m.style.get(),
				autoHide: m.autoHide.get(),
				opt: m.opt.get(),
				chrome: chromeDump(m.chrome)
			});
		return out;
	}

	/** A module absent from the data (older profile) returns to its defaults instead of keeping the previous profile's values. */
	static function applyChaincastModules(ms:solarflare.chaincast.ChaincastModules, data:Dynamic):Void {
		if (ms == null)
			return;
		for (m in ms.all) {
			var d:Dynamic = data != null ? Reflect.field(data, m.key) : null;
			m.resetDefaults();
			if (d == null)
				continue;
			setBool(m.hidden, d.hidden);
			setFloat(m.width, d.w);
			setFloat(m.height, d.h);
			setInt(m.style, d.style);
			setBool(m.autoHide, d.autoHide);
			setBool(m.opt, d.opt);
			m.sanitize();
			applyChrome(m.chrome, d.chrome);
		}
	}

	static function clogDump(c:CombatLogConfig):Dynamic {
		if (c == null)
			return {};
		return {
			hidden: c.hidden.get(),
			you: c.showYou.get(),
			player: c.showPlayer.get(),
			playerRift: c.showPlayersInRift.get(),
			enemy: c.showEnemy.get(),
			heroes: c.showHeroes.get(),
			tgt: c.currentTargetOnly.get(),
			record: solarflare.combatlog.CombatLogRecorder.enabled.get(),
			recordWorld: c.recordWorld.get(),
			recordProx: c.recordInProximity.get(),
			w: c.width.get(),
			h: c.height.get(),
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
			targetCast: c.showCastBar.get(),
			castH: c.castBarHeight.get(),
			castSkin: c.castBarSkin.get(),
			w: c.width.get(),
			h: c.height.get(),
			chrome: chromeDump(c.chrome)
		};
	}

	public static function castBarDump(c:solarflare.castbar.CastBarConfig):Dynamic {
		if (c == null) return {};
		return {hidden: c.hidden.get(), icon: c.showIcon.get(), name: c.showName.get(), time: c.showTime.get(),
			skin: c.skin.get(), w: c.width.get(), h: c.height.get(), chrome: chromeDump(c.chrome)};
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
			countdownAll: c.countdownAll.get(),
			countdownAutoMax: c.countdownAutoMax.get(),
			countdownScale: c.countdownScale.get(),
			timerBoardHidden: c.timerBoardHidden.get(),
			timerBoardChrome: chromeDump(c.timerBoardChrome),
			timerBoardW: c.timerBoardW.get(),
			timerBoardRowH: c.timerBoardRowH.get(),
			timerBoardMax: c.timerBoardMax.get(),
			list: auraList(c),
			sets: c.dumpSets(),
			groups: c.dumpGroups(),
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
		setBool(c.countdownAll, source.countdownAll);
		setFloat(c.countdownAutoMax, source.countdownAutoMax);
		setFloat(c.countdownScale, source.countdownScale);
		setBool(c.timerBoardHidden, source.timerBoardHidden);
		applyChrome(c.timerBoardChrome, Reflect.field(source, "timerBoardChrome"));
		setFloat(c.timerBoardW, source.timerBoardW);
		setFloat(c.timerBoardRowH, source.timerBoardRowH);
		setInt(c.timerBoardMax, source.timerBoardMax);
		solarflare.aura.AuraConfig.applyListDump(c, source);
		solarflare.aura.AuraCounterState.apply(c.auras, Reflect.field(source, "auraCounter"));
	}

	/** Hide All is global HUD policy, not per-feature, so it lives outside the profile blocks. */
	static function hideAllDump():Dynamic {
		// Only the binding persists; HudSuppress.hideAll deliberately does not.
		// The retired Smart Hide category keys are no longer written or read — any
		// left in an existing save are inert.
		return {
			hideAllKey: HideAllBind.choice.get(),
			hideAllMmb: HideAllBind.middleMouse.get(),
			autoHideWindows: WindowAutoHide.enabled.get(),
			autoHideCategories: WindowAutoHide.dumpCategories()
		};
	}

	static function applyHideAll(data:Dynamic):Void {
		if (data == null)
			return;
		setInt(HideAllBind.choice, data.hideAllKey);
		setBool(HideAllBind.middleMouse, data.hideAllMmb);
		setBool(WindowAutoHide.enabled, data.autoHideWindows);
		WindowAutoHide.applyCategories(Reflect.field(data,"autoHideCategories"));
	}

	public static function chromeDump(c:HudChrome):Dynamic {
		if (c == null)
			return {};
		return {
			hudLayoutVersion: c.hudLayoutVersion,
			referenceWidth: c.referenceWidth, referenceHeight: c.referenceHeight,
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
		cfg.preventCtrlFullscreen.set(Reflect.field(data,"preventCtrlFullscreen")==true);
		cfg.blockClickThrough.set(Reflect.field(data,"blockClickThrough")!=false);
		CustomImages.apply(Reflect.field(data, "customImages"));
		if (cfg.uiPack != null)
			cfg.uiPack.apply(Reflect.field(data, "uiPack"));
		cfg.nativeHide.apply(Reflect.field(data, "nativeHide"));
		if (cfg.hideMove != null)
			cfg.hideMove.apply(Reflect.field(data, "hideMove"));
		if (cfg.barter != null)
			cfg.barter.apply(Reflect.field(data, "barter"));
		if (cfg.aimInstant != null)
			cfg.aimInstant.apply(Reflect.field(data, "aimInstant"));
		if (cfg.statusBoard != null)
			cfg.statusBoard.apply(Reflect.field(data, "statusBoard"));
		if (cfg.stacks != null) cfg.stacks.apply(Reflect.field(data, "stacks"));
		try if (data.activeTheme != null) activeTheme = Std.string(data.activeTheme) catch (_:Dynamic) {}
		try if (data.customTheme != null) ThemePalette.applyCustomDump(data.customTheme) catch (_:Dynamic) {}
		applyVitals(cfg.vitals, data.vitals);
		// Migrate flat v1 fields into vitals when nested block is absent.
		if (cfg.vitals != null && data.vitals == null) {
			setBool(cfg.vitals.hpHidden, data.hpHidden);
			setBool(cfg.vitals.rageHidden, data.rageHidden);
			setBool(cfg.vitals.prayersHidden, data.prayersHidden);
			setFloat(cfg.vitals.hpWidth, data.hpW);
			cfg.vitals.hpHeight.set(38);
			cfg.vitals.hpSizeDirty = true;
			applyChrome(cfg.vitals.chrome, data.hp);
		}
		applyGeauxProfile(cfg.geaux, data.geaux);
		var barSettings = solarflare.extrabars.ExtraBarsSettings.fromSettings(data);
		cfg.extraBarsPrototype.applyConfig(barSettings.config, barSettings.legacy);
		cfg.extraBarsPrototype.applyPlacement(Reflect.field(data, "extraBarsPlacement"), Reflect.field(data, "extraBarsPrototypeChrome"));
		cfg.extraBarsPrototype.loadCharacterSettings(Reflect.field(data, "extraBarsCharacters"));
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
				dirty = true;
			}
		} catch (_:Dynamic) {}
		applyCombo(cfg.combo, data.combo);
		applyChaincast(cfg.chaincast, data.chaincast);
		applyConduit(cfg.conduit, data.conduit);
		applyHemorrhage(cfg.hemorrhage, data.hemorrhage);
		applyAttackCombo(cfg.attackCombo, data.attackCombo);
		applyResourceTracker(cfg, data);
		applyClog(cfg.combatLog, data.clog);
		applyTarget(cfg.target, data.target);
		applyCastBar(cfg.castBar, data.castBar);
		applySaber(cfg.lightsaber, data.saber);
		applyAurasProfile(cfg.auras, data.auras);
		// Saves written earlier today carry the binding under the old `smartHide` key.
		applyHideAll(data.hideAll != null ? data.hideAll : data.smartHide);
		AlignmentGrid.apply(Reflect.field(data, "alignGrid"));
		UiHints.apply(Reflect.field(data, "uiHints"));
		if (cfg.launchers != null)
			cfg.launchers.apply(data.launchers);
		applyHub(cfg, data.hub);
		if (cfg.combo != null && data.combo == null && data.comboHidden != null)
			setBool(cfg.combo.hidden, data.comboHidden);
	}

	public static function applyVitals(v:VitalsConfig, data:Dynamic):Void {
		if (v == null || data == null)
			return;
		// Work on a shallow copy so profile/import input objects remain unchanged.
		data = Reflect.copy(data);
		CompactHudLayout.migrateVitals(data);
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
		v.hpLook.apply(data.hpLook);
		v.rageLook.apply(data.rageLook);
		v.manaLook.apply(data.manaLook);
		v.prayersLook.apply(data.prayersLook);

		v.hpSizeDirty = true;
		applyChrome(v.chrome, data.chrome != null ? data.chrome : data);
		// Position was loaded from save — mark as saved so anchorHpAboveGeaux is a no-op.
		v.hpPositionSaved = true;
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
		setInt(c.displayMode, migrated.pipMode);
		setInt(c.colorScheme, migrated.pipColors);
		setBool(c.showGlow, migrated.pipGlow);
		setBool(c.showLabels, migrated.pipLabels);
		setFloat(c.animationSpeed, migrated.pipSpeed);
		c.sizeDirty = true;
		applyChrome(c.chrome, migrated.chrome);
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
		c.pointCount.set(5);
		setInt(c.pointCount, data.pointCount);
		c.pointCount.set(c.points());
		setBool(c.hidden, data.hidden);
		setBool(c.vertical, data.vertical);
		setInt(c.shape, data.shape);
		c.look.apply(data.look);
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
					var id = GeauxCache.coerceSkillId(rot[i]);
					if (id.length == 0)
						id = cleanJsonString(rot[i]);
					if (id.length > 0 && GeauxCache.isUsableSkillId(id))
						c.rotation.push(id);
					i++;
				}
			}
		} catch (_:Dynamic) {}
		try {
			if (data.spend != null) {
				var spend = GeauxCache.coerceSkillId(data.spend);
				if (spend.length == 0)
					spend = cleanJsonString(data.spend);
				c.spendId = (spend.length > 0 && GeauxCache.isUsableSkillId(spend)) ? spend : "";
			}
		} catch (_:Dynamic) {}
		setBool(c.showStackBadge, data.showStackBadge);
		// Old profiles retain the original rail; invalid future IDs safely fall back.
		c.style.set(0);
		setInt(c.style, data.style);
		if (c.style.get() < 0 || c.style.get() >= solarflare.chaincast.ChaincastRenderer.GRAPHIC_COUNT)
			c.style.set(0);
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
		applyChaincastModules(c.modules, Reflect.field(data, "modules"));
	}

	public static function applyConduit(c:ConduitConfig, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		setBool(c.hidden, data.hidden);
		setBool(c.vertical, data.vertical);
		setInt(c.shape, data.shape);
		c.look.apply(data.look);
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
		if (rt == null) { cfg.dash.apply(null); cfg.resourceArtwork.apply(null); return; }
		cfg.dash.apply(Reflect.field(rt,"dash"));
		cfg.resourceArtwork.apply(Reflect.field(rt,"artwork"));
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
		setBool(c.showPlayersInRift, data.playerRift);
		setBool(c.showEnemy, data.enemy);
		setBool(c.showHeroes, data.heroes);
		setBool(c.currentTargetOnly, data.tgt);
		setBool(solarflare.combatlog.CombatLogRecorder.enabled, data.record);
		setBool(c.recordWorld, data.recordWorld);
		setBool(c.recordInProximity, data.recordProx);
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		c.sizeDirty = true;
		if (!c.recordWorld.get())
			c.recordInProximity.set(false);
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
		setBool(c.showCastBar, data.targetCast);
		setFloat(c.castBarHeight, data.castH);
		// castSkin ignored: target strip is unstyled; field kept for JSON dump compat.
		setFloat(c.width, data.w);
		setFloat(c.height, data.h);
		c.sizeDirty = true;
		applyChrome(c.chrome, data.chrome);
	}

	public static function applyCastBar(c:solarflare.castbar.CastBarConfig, data:Dynamic):Void {
		if (c == null || data == null) return;
		setBool(c.hidden, data.hidden);
		setBool(c.showIcon, data.icon);
		setBool(c.showName, data.name);
		setBool(c.showTime, data.time);
		setInt(c.skin, data.skin);
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
		// Resolution ledger panel is session-only (like PayloadProbe). Ignore legacy hub.ledger.
		#if solarflare_telemetry
		if (solarflare.debug.ResolutionLedger.enabled != null)
			solarflare.debug.ResolutionLedger.enabled.set(false);
		#end
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

	public static function applyChrome(c:HudChrome, data:Dynamic):Void {
		if (c == null || data == null)
			return;
		c.restoreReference(data);
		c.hudLayoutVersion = data.hudLayoutVersion != null ? Std.int(data.hudLayoutVersion) : 0;
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
