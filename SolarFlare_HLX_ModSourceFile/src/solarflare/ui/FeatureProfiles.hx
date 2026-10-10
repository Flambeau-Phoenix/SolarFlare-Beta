package solarflare.ui;

import haxe.Json;
import imgui.ImGui;
import solarflare.HealthCache;
import solarflare.ui.ToastManager;
import solarflare.ui.ByteUtil;

/**
 * Universal Profile Architecture for Solar Flare 2.
 * Captures, manages, and switches the entire HUD loadout (Geaux Bar + Resource Trackers + Auras + Theme)
 * in a single, atomic operation with 100% clean string persistence.
 */
class FeatureProfiles {
	public static inline var DEFAULT_KEY:String = "Default";

	public static var activeProfile:String = DEFAULT_KEY;
	public static var statusOwnerGen:Int = 0;
	public static var profiles:Map<String, Dynamic> = new Map();
	public static var order:Array<String> = [DEFAULT_KEY];
	/** One universal profile per observed GameApp.connectionInfo.heroID. */
	public static var characterProfiles:Map<String, String> = new Map();

	static var nameBuf:hl.Bytes;
	static var statusMsg:String = "";
	static var statusTimer:Float = 0;
	static var observedCharacterUid:String = "";

	public static function init(cfg:ConfigPanel):Void {
		ensureBuffer();
		if (!profiles.exists(DEFAULT_KEY)) {
			profiles.set(DEFAULT_KEY, clone(captureAll(cfg)));
			if (order.indexOf(DEFAULT_KEY) < 0)
				order.unshift(DEFAULT_KEY);
		}
		if (!profiles.exists(activeProfile))
			activeProfile = DEFAULT_KEY;
	}

	public static var activeKey(get, never):String;
	static function get_activeKey():String return activeProfile;

	public static function activeName(domain:String = ""):String return activeProfile;

	public static function load(cfg:ConfigPanel, data:Dynamic):Void {
		profiles = new Map();
		order = [];
		characterProfiles = new Map();
		observedCharacterUid = "";

		if (data != null) {
			// 1. Check for modern universal profiles
			var universal = Reflect.field(data, "universalProfiles");
			if (universal != null) {
				var proms = Reflect.field(universal, "profiles");
				if (proms != null) {
					for (k in Reflect.fields(proms)) {
						var name = normalizeName(k);
						if (name.length > 0 && !profiles.exists(name)) {
							order.push(name);
							profiles.set(name, clone(Reflect.field(proms, k)));
						}
					}
				}
				var act = normalizeName(Reflect.field(universal, "active"));
				if (act.length > 0)
					activeProfile = act;

				// Character bindings are rows instead of object fields so every UID
				// remains safe to round-trip through JSON regardless of its contents.
				var bindings = Reflect.field(universal, "characterProfiles");
				if (bindings != null && Std.isOfType(bindings, Array)) {
					var rows:Array<Dynamic> = cast bindings;
					for (row in rows) {
						var uid = normalizeUid(Reflect.field(row, "uid"));
						var profile = normalizeName(Reflect.field(row, "profile"));
						if (uid.length > 0 && profile.length > 0)
							characterProfiles.set(uid, profile);
					}
				}
			}

			// 2. Backward compatibility & Migration: check legacy domain banks
			var legacy = Reflect.field(data, "featureProfiles");
			if (legacy != null) {
				// Migrate and back up any legacy geaux/auras/resources profiles
				var geauxBank = Reflect.field(legacy, "geaux");
				if (geauxBank != null) {
					var gProfs = Reflect.field(geauxBank, "profiles");
					if (gProfs != null) {
						for (k in Reflect.fields(gProfs)) {
							var name = normalizeName(k);
							if (name.length > 0 && !profiles.exists(name)) {
								order.push(name);
								var migratedSnap = {
									geaux: {layout: Reflect.field(Reflect.field(gProfs, k), "layout")},
									auras: cfg != null ? {config: SettingsStore.aurasDump(cfg.auras)} : {},
									resources: cfg != null ? captureResources(cfg) : {}
								};
								profiles.set(name, migratedSnap);
							}
						}
					}
				}
			}
		}

		init(cfg);
		applyUniversal(cfg, activeProfile);
	}

	public static function storeCurrent(cfg:ConfigPanel, domain:String = ""):Void {
		if (cfg == null) return;
		profiles.set(activeProfile, clone(captureAll(cfg)));
		// Keep Geaux screen placement synchronized across all profiles
		if (cfg.geaux != null && cfg.geaux.chrome != null) {
			var gx = cfg.geaux.chrome.x.get();
			var gy = cfg.geaux.chrome.y.get();
			for (p in profiles.iterator()) {
				var g = Reflect.field(p, "geaux");
				var l = g != null ? Reflect.field(g, "layout") : null;
				var c = l != null ? Reflect.field(l, "chrome") : null;
				if (c != null) {
					Reflect.setField(c, "x", gx);
					Reflect.setField(c, "y", gy);
				}
			}
		}
	}

	public static function storeAll(cfg:ConfigPanel):Void {
		storeCurrent(cfg);
	}

	/** One-time v24 repair: the initial cast-bar release saved every new block hidden. */
	public static function migrateCastBarVisible(cfg:ConfigPanel):Void {
		if (cfg != null && cfg.castBar != null)
			cfg.castBar.hidden.set(false);
		for (key in profiles.keys()) {
			var snap = profiles.get(key);
			var resources = snap != null ? Reflect.field(snap, "resources") : null;
			var castBar = resources != null ? Reflect.field(resources, "castBar") : null;
			if (castBar != null)
				Reflect.setField(castBar, "hidden", false);
		}
	}

	public static function dump():Dynamic {
		var profsObj:Dynamic = {};
		for (key in order) {
			if (profiles.exists(key))
				Reflect.setField(profsObj, key, solarflare.extrabars.ExtraBarsSettings.withoutBars(profiles.get(key)));
		}
		var bindings:Array<Dynamic> = [];
		var uids:Array<String> = [];
		for (uid in characterProfiles.keys())
			uids.push(uid);
		uids.sort(function(a:String, b:String):Int return Reflect.compare(a, b));
		for (uid in uids) {
			var profile = characterProfiles.get(uid);
			if (profile != null && profiles.exists(profile))
				bindings.push({uid: uid, profile: profile});
		}
		return {
			active: activeProfile,
			profiles: profsObj,
			characterProfiles: bindings
		};
	}

	/**
	 * Profile Strip shared by the hub and every builder: selector, Save, and a More menu holding
	 * New / Copy / Delete and character assignment. A one-line status chip replaces the old
	 * Character Default table and its full-width action.
	 */
	public static function drawToolbar(cfg:ConfigPanel, domain:String = "", id:String = "main"):Void {
		drawStrip(cfg, id, false);
	}

	/** Same strip for builder title rows; fixed-width selector, no chip line. */
	public static function drawInlineBar(cfg:ConfigPanel, id:String = "ab"):Void {
		drawStrip(cfg, id, true);
	}

	/** Set from the More menu, consumed outside the popup scope so the modal's ID stack matches. */
	static var openNewFor:String = "";

	static function drawStrip(cfg:ConfigPanel, id:String, compact:Bool):Void {
		if (cfg == null) return;
		ensureBuffer();
		var rowH:Single = 26;
		var gap:Single = 6;
		var saveW:Single = 56;
		var moreW:Single = 60;
		var uid = currentCharacterUid();
		var assigned = uid.length > 0 ? characterProfiles.get(uid) : null;
		var follows = assigned != null && assigned == activeProfile;

		var comboW:Single = 160;
		if (!compact) {
			ImGui.textDisabled("Profile");
			ImGui.sameLine(0, 8);
			comboW = ImGui.getContentRegionAvail().x - saveW - moreW - gap * 2;
			if (comboW > 280) comboW = 280;
			if (comboW < 120) comboW = 120;
		}
		ImGui.setNextItemWidth(comboW);
		if (ImGui.beginCombo("##fp_select_" + id, activeProfile)) {
			for (key in order) {
				var label = key + (key == assigned ? "  (this character)" : "");
				if (ImGui.selectable(label + "##fp_opt_" + id + "_" + key, key == activeProfile)) {
					if (key != activeProfile)
						switchTo(cfg, key);
				}
			}
			ImGui.endCombo();
		}
		ImGui.sameLine(0, gap);
		if (UiChrome.ghostButton("Save##fp_save_" + id, ImGui.vec2(saveW, rowH)))
			save(cfg);
		ImGui.sameLine(0, gap);
		if (UiChrome.ghostButton("More##fp_more_" + id, ImGui.vec2(moreW, rowH)))
			ImGui.openPopup("##fp_more_pop_" + id);
		drawMoreMenu(cfg, id, uid, follows);
		if (compact && statusMsg.length > 0) {
			ImGui.sameLine(0, 10);
			ImGui.textColored(ImGui.vec4(0.45, 0.88, 0.55, 1.0), statusMsg);
		}
		if (!compact) {
			if (statusMsg.length > 0)
				ImGui.textColored(ImGui.vec4(0.45, 0.88, 0.55, 1.0), statusMsg);
			else if (uid.length == 0)
				ImGui.textDisabled("Enter the world to link a profile to your character.");
			else if (follows)
				ImGui.textColored(ImGui.vec4(0.45, 0.88, 0.55, 1.0), "Auto-loads for " + currentCharacterLabel());
			else
				ImGui.textDisabled("Not auto-loading for " + currentCharacterLabel());
			if (ImGui.isItemHovered())
				ImGui.setTooltip("More > Use this profile for your character loads it automatically when you log in.");
		}
		if (openNewFor == id) {
			openNewFor = "";
			ByteUtil.clearBytes(nameBuf, 49);
			ImGui.openPopup("New Universal Profile##fp_new_popup_" + id);
		}
		drawNewProfileModal(cfg, id);
	}

	static function drawMoreMenu(cfg:ConfigPanel, id:String, uid:String, follows:Bool):Void {
		if (!ImGui.beginPopup("##fp_more_pop_" + id))
			return;
		try {
			if (ImGui.menuItem("New profile...##fp_new_" + id)) {
				openNewFor = id;
				ImGui.closeCurrentPopup();
			}
			if (ImGui.menuItem("Copy this profile##fp_copy_" + id))
				duplicateCurrent(cfg);
			ImGui.beginDisabled(activeProfile == DEFAULT_KEY);
			var deleteClicked = ImGui.menuItem("Delete this profile##fp_del_" + id);
			ImGui.endDisabled();
			if (deleteClicked)
				delete(cfg, activeProfile);
			ImGui.separator();
			if (uid.length == 0) {
				ImGui.textDisabled("Character unavailable");
			} else if (follows) {
				if (ImGui.menuItem("Stop auto-loading for " + currentCharacterLabel() + "##fp_unassign_" + id))
					unassignCurrentCharacter(cfg);
			} else {
				if (ImGui.menuItem("Use this profile for " + currentCharacterLabel() + "##fp_assign_" + id))
					assignCurrentCharacter(cfg);
			}
		} catch (e:Dynamic) {
			ImGui.endPopup();
			throw e;
		}
		ImGui.endPopup();
	}

	static function drawNewProfileModal(cfg:ConfigPanel, id:String):Void {
		if (!ImGui.beginPopupModal("New Universal Profile##fp_new_popup_" + id, null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize))
			return;
		try {
			UiChrome.heading("New Profile", 1.15);
			ImGui.spacing();
			ImGui.text("Enter profile name:");
			ImGui.inputText("##fp_name_" + id, nameBuf, 49);
			ImGui.spacing();
			UiLayout.inlinePair("##fp_modal_btns_" + id, function(w:Single) {
				if (UiChrome.accentButton("Create##fp_create_" + id, ImGui.vec2(w, 28))) {
					var requested = ByteUtil.readBytes(nameBuf, 49);
					if (create(cfg, requested))
						ImGui.closeCurrentPopup();
				}
			}, function(w:Single) {
				if (UiChrome.ghostButton("Cancel##fp_cancel_" + id, ImGui.vec2(w, 28)))
					ImGui.closeCurrentPopup();
			}, 8);
		} catch (e:Dynamic) {
			ImGui.endPopup();
			throw e;
		}
		ImGui.endPopup();
	}

	public static function save(cfg:ConfigPanel):Void {
		storeCurrent(cfg);
		setStatus('Profile "$activeProfile" saved.');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.success('Universal Profile "$activeProfile" saved!');
	}

	public static function switchTo(cfg:ConfigPanel, key:String, automatic:Bool = false):Void {
		if (cfg == null || key == null || !profiles.exists(key)) return;
		storeCurrent(cfg);
		activeProfile = key;
		applyUniversal(cfg, key);
		setStatus(automatic ? 'Auto-loaded "$key".' : 'Loaded profile "$key".');
		SettingsStore.markDirty();
		if (automatic)
			SettingsStore.save(cfg);
		else
			SettingsStore.saveNow();
		ToastManager.info(automatic
			? 'Loaded character profile "$key"'
			: 'Switched to profile "$key"');
	}

	/** Called from the observe layer after HealthCache has frozen the current identity. */
	public static function observeCharacter(cfg:ConfigPanel):Void {
		var uid = currentCharacterUid();
		if (uid.length == 0) {
			observedCharacterUid = "";
			return;
		}
		var migrated = migrateLegacyCharacterAssignment(cfg, uid);
		if (uid == observedCharacterUid && !migrated)
			return;
		observedCharacterUid = uid;
		var assigned = characterProfiles.get(uid);
		if (assigned != null && profiles.exists(assigned) && assigned != activeProfile)
			switchTo(cfg, assigned, true);
	}

	public static function assignCurrentCharacter(cfg:ConfigPanel):Void {
		var uid = currentCharacterUid();
		if (uid.length == 0) {
			setStatus("Character unavailable.");
			ToastManager.warn("Current character is not available yet.");
			return;
		}
		characterProfiles.set(uid, activeProfile);
		observedCharacterUid = uid;
		setStatus('Assigned ${currentCharacterLabel()} to "$activeProfile".');
		SettingsStore.markDirty();
		SettingsStore.save(cfg);
		ToastManager.success('${currentCharacterLabel()} now defaults to "$activeProfile".');
	}

	public static function unassignCurrentCharacter(cfg:ConfigPanel):Void {
		var uid = currentCharacterUid();
		if (uid.length == 0)
			return;
		characterProfiles.remove(uid);
		observedCharacterUid = uid;
		setStatus('Unassigned ${currentCharacterLabel()}.');
		SettingsStore.markDirty();
		SettingsStore.save(cfg);
		ToastManager.info('${currentCharacterLabel()} no longer has a default profile.');
	}

	public static function create(cfg:ConfigPanel, requested:String):Bool {
		var name = normalizeName(requested);
		if (name.length == 0) {
			setStatus("Name required.");
			ToastManager.warn("Profile name required.");
			return false;
		}
		if (profiles.exists(name)) {
			setStatus("Profile already exists.");
			ToastManager.warn('Profile "$name" already exists.');
			return false;
		}
		storeCurrent(cfg);
		profiles.set(name, clone(captureAll(cfg)));
		order.push(name);
		activeProfile = name;
		setStatus('Created "$name".');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.success('Created Universal Profile "$name"!');
		return true;
	}

	public static function duplicateCurrent(cfg:ConfigPanel):Void {
		if (cfg == null) return;
		var base = activeProfile + " (Copy)";
		var name = base;
		var counter = 2;
		while (profiles.exists(name)) {
			name = base + " " + counter;
			counter++;
		}
		create(cfg, name);
	}

	public static function delete(cfg:ConfigPanel, key:String):Void {
		if (key == DEFAULT_KEY) {
			setStatus("Default profile cannot be deleted.");
			ToastManager.warn("Default profile cannot be deleted.");
			return;
		}
		profiles.remove(key);
		order.remove(key);
		var staleBindings:Array<String> = [];
		for (uid in characterProfiles.keys()) {
			if (characterProfiles.get(uid) == key)
				staleBindings.push(uid);
		}
		for (uid in staleBindings)
			characterProfiles.remove(uid);
		activeProfile = DEFAULT_KEY;
		applyUniversal(cfg, DEFAULT_KEY);
		setStatus('Deleted "$key".');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.info('Deleted profile "$key".');
	}

	static function captureAll(cfg:ConfigPanel):Dynamic {
		if (cfg == null) return {};
		return {
			geaux: {layout: SettingsStore.geauxDump(cfg.geaux)},
			barter: cfg.barter != null ? cfg.barter.dump() : {},
			statusBoard: cfg.statusBoard != null ? cfg.statusBoard.dump() : {},
			auras: {config: SettingsStore.aurasDump(cfg.auras)},
			resources: captureResources(cfg),
			theme: SettingsStore.currentTheme()
		};
	}

	static function captureResources(cfg:ConfigPanel):Dynamic {
		return {
			vitals: SettingsStore.vitalsDump(cfg.vitals),
			combo: SettingsStore.comboDump(cfg.combo),
			attackCombo: SettingsStore.attackComboDump(cfg.attackCombo),
			target: SettingsStore.targetDump(cfg.target),
			castBar: SettingsStore.castBarDump(cfg.castBar),
			chaincast: SettingsStore.chaincastDump(cfg.chaincast),
			conduit: SettingsStore.conduitDump(cfg.conduit)
		};
	}

	static function applyUniversal(cfg:ConfigPanel, key:String):Void {
		statusOwnerGen++;
		if (cfg == null) return;
		var snap = profiles.get(key);
		if (snap == null) return;
		if (cfg.barter != null) { cfg.barter.clearTransientState(); cfg.barter.builder.history.clear(); }

		// 1. Geaux Layout
		var geauxSnap = Reflect.field(snap, "geaux");
		if (geauxSnap != null) {
			var hasPos = (cfg.geaux != null && cfg.geaux.chrome != null);
			var curX:Single = hasPos ? cfg.geaux.chrome.x.get() : -1;
			var curY:Single = hasPos ? cfg.geaux.chrome.y.get() : -1;
			SettingsStore.applyGeauxProfile(cfg.geaux, Reflect.field(geauxSnap, "layout"));
			if (hasPos && (curX > 0 || curY > 0)) {
				cfg.geaux.chrome.x.set(curX);
				cfg.geaux.chrome.y.set(curY);
				cfg.geaux.chrome.posDirty = true;
			}
		}

		// 1b. BarTer (bars + chrome positions — per profile)
		var barterSnap = Reflect.field(snap, "barter");
		if (barterSnap != null && cfg.barter != null)
			cfg.barter.apply(barterSnap);

		var statusBoardSnap = Reflect.field(snap, "statusBoard");
        if (statusBoardSnap != null && cfg.statusBoard != null) cfg.statusBoard.apply(statusBoardSnap);

        // 2. Auras
		var aurasSnap = Reflect.field(snap, "auras");
		if (aurasSnap != null) {
			SettingsStore.applyAurasProfile(cfg.auras, Reflect.field(aurasSnap, "config"));
		}

		// 3. Resources
		var resSnap = Reflect.field(snap, "resources");
		if (resSnap != null) {
			SettingsStore.applyVitals(cfg.vitals, Reflect.field(resSnap, "vitals"));
			SettingsStore.applyCombo(cfg.combo, Reflect.field(resSnap, "combo"));
			SettingsStore.applyAttackCombo(cfg.attackCombo, Reflect.field(resSnap, "attackCombo"));
			SettingsStore.applyTarget(cfg.target, Reflect.field(resSnap, "target"));
			SettingsStore.applyCastBar(cfg.castBar, Reflect.field(resSnap, "castBar"));
			SettingsStore.applyChaincast(cfg.chaincast, Reflect.field(resSnap, "chaincast"));
			SettingsStore.applyConduit(cfg.conduit, Reflect.field(resSnap, "conduit"));
		}

		// 4. Theme
		var themeSnap = Reflect.field(snap, "theme");
		if (themeSnap != null && Std.isOfType(themeSnap, String)) {
			SettingsStore.setActiveTheme(cast themeSnap);
		}
	}

	static function setStatus(msg:String):Void {
		statusMsg = msg;
	}

	static function ensureBuffer():Void {
		if (nameBuf == null) {
			nameBuf = new hl.Bytes(49);
			ByteUtil.clearBytes(nameBuf, 49);
		}
	}

	public static function normalizeName(v:Dynamic):String {
		if (v == null) return "";
		var s = StringTools.trim(Std.string(v));
		s = StringTools.replace(s, "\n", " ");
		s = StringTools.replace(s, "\r", "");
		if (s.length > 48) s = s.substr(0, 48);
		return s;
	}

	static function currentCharacterUid():String {
		var id = normalizeUid(HealthCache.characterId);
		return id.length > 0 ? "hero:" + id : "";
	}

	/** Move the prior account-wide binding onto the first actual character observed. */
	static function migrateLegacyCharacterAssignment(cfg:ConfigPanel, uid:String):Bool {
		if (uid.length == 0 || characterProfiles.exists(uid))
			return false;
		var legacyUid = normalizeUid(HealthCache.playerUid);
		if (legacyUid.length == 0 || !characterProfiles.exists(legacyUid))
			return false;
		var assigned = characterProfiles.get(legacyUid);
		if (assigned == null || !profiles.exists(assigned))
			return false;
		characterProfiles.set(uid, assigned);
		characterProfiles.remove(legacyUid);
		SettingsStore.markDirty();
		SettingsStore.save(cfg);
		return true;
	}

	static function currentCharacterLabel():String {
		var name = HealthCache.heroName != null ? StringTools.trim(HealthCache.heroName) : "";
		return name.length > 0 ? name : "Current character";
	}

	static function normalizeUid(v:Dynamic):String {
		if (v == null) return "";
		var s = StringTools.trim(Std.string(v));
		if (s == "null" || s == "undefined") return "";
		if (s.length > 256) s = s.substr(0, 256);
		return s;
	}

	static function clone(v:Dynamic):Dynamic {
		if (v == null) return {};
		try return Json.parse(Json.stringify(v)) catch (_:Dynamic) return {};
	}
}
